class_name OcclusionSilhouette
extends Node2D
## Silhouette เมื่อตัวละครถูกวัตถุบัง (Occlusion)
## node ลูกใต้ตัวละคร ชี้ไปที่ CanvasItem สไปรต์ของตัวนั้น
## เมื่อมีวัตถุบัง (y มากกว่าเท้าตัวละคร และทับสไปรต์) จะวาดสำเนาสไปรต์เป็นสีเดียวม่วงอ่อนด้วย z_index สูงกว่ากำแพง

const DEFAULT_COLOR := Color(0.7843, 0.7216, 1.0, 0.55)
const SHADER_RES_PATH := "res://systems/player/occlusion/occlusion_silhouette.gdshader"

@export var sprite_path: NodePath = NodePath("")
## สีของ silhouette (ม่วงอ่อนโปร่งใส ~ #c8b8ff alpha 0.55)
@export var color: Color = DEFAULT_COLOR
## z_index ที่สูงกว่ากำแพง เพื่อให้วาดทับสิ่งกีดขวาง
@export var silhouette_z_index: int = 10
## physics layer ที่ใช้ตรวจวัตถุกีดขวาง (ค่าเริ่มต้นคือ layer 1: world)
@export var collision_mask: int = 1
## ขนาดพื้นที่ตรวจจับของ Area2D (หากไม่ได้ตรวจจาก bounding box สไปรต์โดยตรง)
@export var detection_size: Vector2 = Vector2(32.0, 48.0)
## ตำแหน่งกึ่งกลางของพื้นที่ตรวจจับสัมพันธ์กับเท้าตัวละคร (origin อยู่ที่เท้า)
@export var detection_offset: Vector2 = Vector2(0.0, -24.0)

var target_sprite: CanvasItem = null
var silhouette_sprite: Sprite2D = null
var detection_area: Area2D = null
var detection_shape: CollisionShape2D = null
var mock_occluders: Array = []
var _overlapping_tiles: Dictionary = {} # RID -> { "layer": TileMapLayer, "coords": Vector2i }

var _shader_mat: ShaderMaterial = null


func _ready() -> void:
	setup()


func _exit_tree() -> void:
	_overlapping_tiles.clear()


## กำหนดค่าเริ่มต้นและผูก node — แยกจาก _ready ให้เทสต์เรียกได้โดยไม่ต้องอยู่ใน scene tree
func setup() -> void:
	_resolve_target_sprite()
	_setup_silhouette_sprite()
	_setup_detection_area()
	sync_with_sprite()


func _resolve_target_sprite() -> void:
	if not sprite_path.is_empty():
		target_sprite = get_node_or_null(sprite_path) as CanvasItem

	if target_sprite == null and get_parent() != null:
		# ลองค้นหา Sprite2D หรือ AnimatedSprite2D ใน parent หรือ sibling
		for child: Node in get_parent().get_children():
			if child != self and (child is Sprite2D or child is AnimatedSprite2D):
				target_sprite = child as CanvasItem
				break


func _setup_silhouette_sprite() -> void:
	if silhouette_sprite == null:
		silhouette_sprite = get_node_or_null("SilhouetteSprite") as Sprite2D
		if silhouette_sprite == null:
			silhouette_sprite = Sprite2D.new()
			silhouette_sprite.name = "SilhouetteSprite"
			add_child(silhouette_sprite)

	silhouette_sprite.z_as_relative = false
	silhouette_sprite.z_index = silhouette_z_index
	silhouette_sprite.visible = false

	if _shader_mat == null:
		var shader: Shader = load(SHADER_RES_PATH) as Shader
		if shader != null:
			_shader_mat = ShaderMaterial.new()
			_shader_mat.shader = shader
	if _shader_mat != null:
		_shader_mat.set_shader_parameter("silhouette_color", color)
		silhouette_sprite.material = _shader_mat


func _setup_detection_area() -> void:
	if detection_area == null:
		detection_area = get_node_or_null("DetectionArea") as Area2D
		if detection_area == null:
			detection_area = Area2D.new()
			detection_area.name = "DetectionArea"
			add_child(detection_area)

	detection_area.collision_layer = 0
	detection_area.collision_mask = collision_mask
	detection_area.monitoring = true
	detection_area.monitorable = false

	if not detection_area.body_shape_entered.is_connected(_on_body_shape_entered):
		detection_area.body_shape_entered.connect(_on_body_shape_entered)
	if not detection_area.body_shape_exited.is_connected(_on_body_shape_exited):
		detection_area.body_shape_exited.connect(_on_body_shape_exited)

	if detection_shape == null:
		detection_shape = detection_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if detection_shape == null:
			detection_shape = CollisionShape2D.new()
			detection_shape.name = "CollisionShape2D"
			detection_area.add_child(detection_shape)

	var rect_shape: RectangleShape2D = detection_shape.shape as RectangleShape2D
	if rect_shape == null:
		rect_shape = RectangleShape2D.new()
		detection_shape.shape = rect_shape
	rect_shape.size = detection_size
	detection_shape.position = detection_offset


func _on_body_shape_entered(body_rid: RID, body: Node, _body_shape_index: int, _local_shape_index: int) -> void:
	if body is TileMapLayer:
		var layer: TileMapLayer = body as TileMapLayer
		var coords: Vector2i = layer.get_coords_for_body_rid(body_rid)
		if coords != Vector2i(-1, -1):
			_overlapping_tiles[body_rid] = {
				"layer": layer,
				"coords": coords
			}


func _on_body_shape_exited(body_rid: RID, _body: Node, _body_shape_index: int, _local_shape_index: int) -> void:
	_overlapping_tiles.erase(body_rid)


## อัปเดตข้อมูลภาพของ silhouette ให้ตรงกับ target sprite (Sprite2D หรือ AnimatedSprite2D)
## ใช้ global_transform ตาม target เพื่อรองรับสไปรต์ซ้อน node หรือ scale flip
func sync_with_sprite() -> void:
	if target_sprite == null or silhouette_sprite == null:
		return

	silhouette_sprite.global_transform = target_sprite.global_transform

	if target_sprite is Sprite2D:
		var s: Sprite2D = target_sprite as Sprite2D
		silhouette_sprite.texture = s.texture
		silhouette_sprite.hframes = s.hframes
		silhouette_sprite.vframes = s.vframes
		silhouette_sprite.frame = s.frame
		silhouette_sprite.flip_h = s.flip_h
		silhouette_sprite.flip_v = s.flip_v
		silhouette_sprite.offset = s.offset
		silhouette_sprite.centered = s.centered
		silhouette_sprite.region_enabled = s.region_enabled
		silhouette_sprite.region_rect = s.region_rect
	elif target_sprite is AnimatedSprite2D:
		var a: AnimatedSprite2D = target_sprite as AnimatedSprite2D
		var frames: SpriteFrames = a.sprite_frames
		if frames != null and frames.has_animation(a.animation):
			silhouette_sprite.texture = frames.get_frame_texture(a.animation, a.frame)
			silhouette_sprite.hframes = 1
			silhouette_sprite.vframes = 1
			silhouette_sprite.frame = 0
			silhouette_sprite.region_enabled = false
		silhouette_sprite.flip_h = a.flip_h
		silhouette_sprite.flip_v = a.flip_v
		silhouette_sprite.offset = a.offset
		silhouette_sprite.centered = a.centered


## ดึงตำแหน่ง bounding box ของสไปรต์ใน world coordinate
func get_sprite_world_rect() -> Rect2:
	var base_pos: Vector2 = global_position
	if target_sprite is Sprite2D:
		var s: Sprite2D = target_sprite as Sprite2D
		var sz: Vector2 = detection_size
		if s.region_enabled and s.region_rect.size != Vector2.ZERO:
			sz = s.region_rect.size
		elif s.texture != null:
			sz = s.texture.get_size()
			if s.hframes > 1:
				sz.x /= float(s.hframes)
			if s.vframes > 1:
				sz.y /= float(s.vframes)
		var scale_factor: Vector2 = s.global_scale.abs()
		sz = sz * scale_factor
		var top_left: Vector2 = s.global_position + (s.offset * s.global_scale) - (sz * 0.5 if s.centered else Vector2.ZERO)
		return Rect2(top_left, sz)
	elif target_sprite is AnimatedSprite2D:
		var a: AnimatedSprite2D = target_sprite as AnimatedSprite2D
		var sz: Vector2 = detection_size
		var frames: SpriteFrames = a.sprite_frames
		if frames != null and frames.has_animation(a.animation):
			var tex: Texture2D = frames.get_frame_texture(a.animation, a.frame)
			if tex != null:
				sz = tex.get_size()
		var scale_factor: Vector2 = a.global_scale.abs()
		sz = sz * scale_factor
		var top_left: Vector2 = a.global_position + (a.offset * a.global_scale) - (sz * 0.5 if a.centered else Vector2.ZERO)
		return Rect2(top_left, sz)

	return Rect2(base_pos + detection_offset - detection_size * 0.5, detection_size)


## ตัดสินว่าขณะนี้ตัวละครถูกวัตถุบังหรือไม่ โดยเรียก is_occluding() เสมอ
func evaluate_occlusion() -> bool:
	var feet_y: float = global_position.y
	if get_parent() != null and get_parent() is Node2D:
		feet_y = (get_parent() as Node2D).global_position.y

	var spr_rect: Rect2 = get_sprite_world_rect()

	# 1. โหมด mock สำหรับ unit test แบบ deterministic
	if mock_occluders.size() > 0:
		for item in mock_occluders:
			if item is Dictionary:
				var occ_y: float = float(item.get("y", 0.0))
				var occ_rect: Rect2 = item.get("rect", Rect2())
				if is_occluding(feet_y, occ_y, spr_rect, occ_rect):
					return true
			elif item is Node2D:
				var occ_node: Node2D = item as Node2D
				var occ_y: float = get_occluder_y(occ_node)
				var occ_rect: Rect2 = get_occluder_rect(occ_node)
				if is_occluding(feet_y, occ_y, spr_rect, occ_rect):
					return true
		return false

	# 2. โหมดรันจริง: TileMapLayer ที่ทับซ้อน (บันทึกจาก body_shape_entered/exited)
	var invalid_rids: Array[RID] = []
	for rid: RID in _overlapping_tiles:
		var item: Dictionary = _overlapping_tiles[rid]
		var layer: TileMapLayer = item.get("layer") as TileMapLayer
		if not is_instance_valid(layer) or not layer.is_inside_tree():
			invalid_rids.append(rid)
			continue
		var coords: Vector2i = item.get("coords", Vector2i(-1, -1))
		if coords == Vector2i(-1, -1):
			invalid_rids.append(rid)
			continue
		var occ_y: float = get_tile_occluder_y(layer, coords)
		var occ_rect: Rect2 = get_tile_world_rect(layer, coords)
		if is_occluding(feet_y, occ_y, spr_rect, occ_rect):
			return true

	for rid: RID in invalid_rids:
		_overlapping_tiles.erase(rid)

	# 3. โหมดรันจริง: Area2D และ Bodies อื่น ๆ
	if detection_area != null:
		var parent_node: Node = get_parent()

		var areas: Array[Area2D] = detection_area.get_overlapping_areas()
		for area: Area2D in areas:
			if area == detection_area or area == self or area.get_parent() == parent_node:
				continue
			var occ_y: float = get_occluder_y(area)
			var occ_rect: Rect2 = get_occluder_rect(area)
			if is_occluding(feet_y, occ_y, spr_rect, occ_rect):
				return true

		var bodies: Array[Node2D] = detection_area.get_overlapping_bodies()
		for body: Node2D in bodies:
			if body == parent_node or body == self or body is TileMapLayer:
				continue
			var occ_y: float = get_occluder_y(body)
			var occ_rect: Rect2 = get_occluder_rect(body)
			if is_occluding(feet_y, occ_y, spr_rect, occ_rect):
				return true

	return false


## อัปเดตสถานะ silhouette 1 เฟรม — คืนค่า true หากถูกบัง
## ซ่อนทันทีหาก target_sprite ไม่อยู่ในสถานะ visible_in_tree
func tick(_delta: float = 0.0) -> bool:
	sync_with_sprite()

	var is_target_visible: bool = is_node_visible_in_hierarchy(target_sprite)

	var occluded: bool = false
	if is_target_visible:
		occluded = evaluate_occlusion()

	if silhouette_sprite != null:
		silhouette_sprite.visible = occluded
		if _shader_mat != null:
			_shader_mat.set_shader_parameter("silhouette_color", color)
	return occluded


## ตรวจสอบว่า CanvasItem และบรรพบุรุษทั้งหมดแสดงผลอยู่หรือไม่ (รองรับทั้งใน tree และ node hierarchy นอก tree)
static func is_node_visible_in_hierarchy(node: CanvasItem) -> bool:
	if node == null:
		return false
	if node.is_inside_tree():
		return node.is_visible_in_tree()
	var cur: Node = node
	while cur != null:
		if cur is CanvasItem:
			if not (cur as CanvasItem).visible:
				return false
		cur = cur.get_parent()
	return true


## ซิงก์ใน _process เพื่อให้ทันตาม frame อนิเมชันและการเคลื่อนไหวในจอ render
func _process(delta: float) -> void:
	tick(delta)


# ── Static Logic สำหรับ Unit Test & Helper ที่โหมดจริงใช้ ──

## ตัดสินว่าวัตถุบังตัวละครหรือไม่ (static สำหรับเทสต์)
## - occluder_y > feet_y: วัตถุอยู่ "ข้างหน้า" ในแกนลึก (y มากกว่า = หน้ากว่าใน iso y-sort)
## - sprite_rect.intersects(occluder_rect): วัตถุทับพื้นที่สไปรต์ตัวละคร
static func is_occluding(feet_y: float, occluder_y: float, sprite_rect: Rect2, occluder_rect: Rect2) -> bool:
	if occluder_y <= feet_y:
		return false
	return sprite_rect.intersects(occluder_rect)


## ตัดสินว่าตำแหน่ง Y ของวัตถุอยู่ข้างหน้าเท้าของตัวละครหรือไม่
static func is_in_front(feet_y: float, occluder_y: float) -> bool:
	return occluder_y > feet_y


## คำนวณค่า Y สำหรับ Y-sort occlusion ของ tile ใน TileMapLayer
static func get_tile_occluder_y(layer: TileMapLayer, coords: Vector2i) -> float:
	if layer == null:
		return 0.0
	var local_pos: Vector2 = layer.map_to_local(coords)
	var world_pos: Vector2 = layer.to_global(local_pos)
	var tile_data: TileData = layer.get_cell_tile_data(coords)
	if tile_data != null and tile_data.has_meta(&"occluder_y"):
		return float(tile_data.get_meta(&"occluder_y"))
	return world_pos.y


## คำนวณ bounding box ของ tile ใน world coordinate
static func get_tile_world_rect(layer: TileMapLayer, coords: Vector2i) -> Rect2:
	if layer == null or layer.tile_set == null:
		return Rect2()
	var local_center: Vector2 = layer.map_to_local(coords)
	var world_center: Vector2 = layer.to_global(local_center)
	var source_id: int = layer.get_cell_source_id(coords)
	if source_id == -1:
		var sz: Vector2 = Vector2(layer.tile_set.tile_size)
		return Rect2(world_center - sz * 0.5, sz)

	var tile_data: TileData = layer.get_cell_tile_data(coords)
	if tile_data != null and tile_data.has_meta(&"occluder_rect"):
		var rel_rect: Rect2 = tile_data.get_meta(&"occluder_rect") as Rect2
		return Rect2(world_center + rel_rect.position, rel_rect.size)

	var atlas_coords: Vector2i = layer.get_cell_atlas_coords(coords)
	var source: TileSetSource = layer.tile_set.get_source(source_id)
	var tile_size: Vector2 = Vector2(layer.tile_set.tile_size)
	var origin: Vector2 = Vector2.ZERO
	if source is TileSetAtlasSource:
		var atlas: TileSetAtlasSource = source as TileSetAtlasSource
		var reg_size: Vector2i = atlas.get_tile_texture_region_size(atlas_coords)
		if reg_size != Vector2i.ZERO:
			tile_size = Vector2(reg_size)
		if tile_data != null:
			origin = Vector2(tile_data.texture_origin)

	var top_left: Vector2 = world_center - origin - (tile_size * 0.5)
	return Rect2(top_left, tile_size)


## คำนวณค่า Y สำหรับ Y-sort occlusion ของ node วัตถุ (meta "occluder_y" หรือ parent global_position.y)
static func get_occluder_y(node: Node) -> float:
	if node == null:
		return 0.0
	if node.has_meta(&"occluder_y"):
		return float(node.get_meta(&"occluder_y"))
	if node.get_parent() != null and node.get_parent().has_meta(&"occluder_y"):
		return float(node.get_parent().get_meta(&"occluder_y"))
	if node is Area2D and node.get_parent() != null and node.get_parent() is Node2D:
		return (node.get_parent() as Node2D).global_position.y
	if node is Node2D:
		return (node as Node2D).global_position.y
	return 0.0


## คำนวณ bounding box ของ node วัตถุใน world coordinate
static func get_occluder_rect(node: Node) -> Rect2:
	if node == null:
		return Rect2()
	if node.has_meta(&"occluder_rect"):
		return node.get_meta(&"occluder_rect") as Rect2
	if node.get_parent() != null and node.get_parent().has_meta(&"occluder_rect"):
		return node.get_parent().get_meta(&"occluder_rect") as Rect2

	var shape_owner: Node = node
	if not (node is CollisionObject2D) and node.has_node("OcclusionArea"):
		shape_owner = node.get_node("OcclusionArea")

	for child: Node in shape_owner.get_children():
		if child is CollisionShape2D:
			var cs: CollisionShape2D = child as CollisionShape2D
			if cs.shape != null:
				if cs.shape is RectangleShape2D:
					var sz: Vector2 = (cs.shape as RectangleShape2D).size
					return Rect2(cs.global_position - sz * 0.5, sz)
				elif cs.shape is CircleShape2D:
					var r: float = (cs.shape as CircleShape2D).radius
					return Rect2(cs.global_position - Vector2(r, r), Vector2(r * 2.0, r * 2.0))
				else:
					var lr: Rect2 = cs.shape.get_rect()
					return Rect2(cs.global_position + lr.position, lr.size)

	if node is Node2D:
		var n2d: Node2D = node as Node2D
		return Rect2(n2d.global_position - Vector2(16, 16), Vector2(32, 32))
	return Rect2()
