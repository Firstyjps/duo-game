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

var _shader_mat: ShaderMaterial = null


func _ready() -> void:
	setup()


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


## อัปเดตข้อมูลภาพของ silhouette ให้ตรงกับ target sprite (Sprite2D หรือ AnimatedSprite2D)
func sync_with_sprite() -> void:
	if target_sprite == null or silhouette_sprite == null:
		return

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
		silhouette_sprite.transform = s.transform
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
		silhouette_sprite.transform = a.transform


## ดึงตำแหน่ง bounding box ของสไปรต์ใน world coordinate
func get_sprite_world_rect() -> Rect2:
	var base_pos: Vector2 = global_position
	if target_sprite is Sprite2D:
		var s: Sprite2D = target_sprite as Sprite2D
		var sz: Vector2 = detection_size
		if s.texture != null:
			sz = s.texture.get_size()
			if s.hframes > 1:
				sz.x /= float(s.hframes)
			if s.vframes > 1:
				sz.y /= float(s.vframes)
		var top_left: Vector2 = s.global_position + s.offset - (sz * 0.5 if s.centered else Vector2.ZERO)
		return Rect2(top_left, sz)
	elif target_sprite is AnimatedSprite2D:
		var a: AnimatedSprite2D = target_sprite as AnimatedSprite2D
		var sz: Vector2 = detection_size
		var frames: SpriteFrames = a.sprite_frames
		if frames != null and frames.has_animation(a.animation):
			var tex: Texture2D = frames.get_frame_texture(a.animation, a.frame)
			if tex != null:
				sz = tex.get_size()
		var top_left: Vector2 = a.global_position + a.offset - (sz * 0.5 if a.centered else Vector2.ZERO)
		return Rect2(top_left, sz)

	return Rect2(base_pos + detection_offset - detection_size * 0.5, detection_size)


## ตัดสินว่าขณะนี้ตัวละครถูกวัตถุบังหรือไม่
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
				var occ_y: float = occ_node.global_position.y
				if occ_node.has_meta(&"occluder_y"):
					occ_y = float(occ_node.get_meta(&"occluder_y"))
				if is_in_front(feet_y, occ_y):
					return true
		return false

	# 2. โหมดรันจริงผ่าน Area2D physics overlap
	if detection_area != null:
		var parent_node: Node = get_parent()
		var bodies: Array[Node2D] = detection_area.get_overlapping_bodies()
		for body: Node2D in bodies:
			if body == parent_node or body == self:
				continue
			var occ_y: float = body.global_position.y
			if body.has_meta(&"occluder_y"):
				occ_y = float(body.get_meta(&"occluder_y"))
			if is_in_front(feet_y, occ_y):
				return true

		var areas: Array[Area2D] = detection_area.get_overlapping_areas()
		for area: Area2D in areas:
			if area == detection_area or area == self or area.get_parent() == parent_node:
				continue
			var occ_y: float = area.global_position.y
			if area.has_meta(&"occluder_y"):
				occ_y = float(area.get_meta(&"occluder_y"))
			elif area.get_parent() != null and area.get_parent() is Node2D:
				occ_y = (area.get_parent() as Node2D).global_position.y
			if is_in_front(feet_y, occ_y):
				return true

	return false


## อัปเดตสถานะ silhouette 1 เฟรม — คืนค่า true หากถูกบัง
func tick(_delta: float = 0.0) -> bool:
	sync_with_sprite()
	var occluded: bool = evaluate_occlusion()
	if silhouette_sprite != null:
		silhouette_sprite.visible = occluded
		if _shader_mat != null:
			_shader_mat.set_shader_parameter("silhouette_color", color)
	return occluded


func _physics_process(delta: float) -> void:
	tick(delta)


# ── Static Logic สำหรับ Unit Test ──

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
