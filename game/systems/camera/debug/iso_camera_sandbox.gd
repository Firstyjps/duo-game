extends Node2D
## Sandbox สำหรับทดสอบกล้อง Isometric และ Silhouette การถูกบัง (Issue #41)
## F6 เพื่อรัน · --shot=<path> สำหรับถ่ายภาพหน้าจออัตโนมัติ
## ปุ่มควบคุม:
## - Arrows / WASD: บังคับตัวละครกล่องเดิน
## - 1: Slide กล้องไปยังห้อง 1 (Room 1)
## - 2: Slide กล้องไปยังห้อง 2 (Room 2)
## - L: สลับ Lock-on Focus ไปยัง Dummy
## - Space: ทดสอบกล้องสั่น (Trauma Shake)
## - H: ทดสอบ Hitstop

const ROOM_1 := Rect2(0, 0, 960, 540)
const ROOM_2 := Rect2(960, 0, 960, 540)

@export var move_speed: float = 200.0

@onready var camera: GameCamera = $GameCamera
@onready var player: CharacterBody2D = $YEntities/BoxPlayer
@onready var dummy: Node2D = $YEntities/Dummy
@onready var hud_label: Label = $CanvasLayer/InfoLabel
@onready var silhouette: OcclusionSilhouette = $YEntities/BoxPlayer/OcclusionSilhouette

var _current_room_id: int = 1


func _ready() -> void:
	_setup_inputs()
	_setup_tilemaps()
	if camera != null:
		camera.set_bounds(ROOM_1)
		camera.follow(player, true)

	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_shoot(arg.trim_prefix("--shot="))


func _setup_inputs() -> void:
	var keys: Dictionary = {
		&"move_left": [KEY_LEFT, KEY_A],
		&"move_right": [KEY_RIGHT, KEY_D],
		&"move_up": [KEY_UP, KEY_W],
		&"move_down": [KEY_DOWN, KEY_S],
		&"camera_room_1": [KEY_1],
		&"camera_room_2": [KEY_2],
		&"camera_focus_dummy": [KEY_L],
		&"camera_shake": [KEY_SPACE],
		&"camera_hitstop": [KEY_H],
	}
	for action: StringName in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			for k: Key in keys[action]:
				var e := InputEventKey.new()
				e.physical_keycode = k
				InputMap.action_add_event(action, e)


func _setup_tilemaps() -> void:
	var ts := _make_tileset()

	# 1. Floor layer สำหรับพื้น isometric
	var floor_layer := TileMapLayer.new()
	floor_layer.name = "FloorLayer"
	floor_layer.tile_set = ts
	add_child(floor_layer)
	move_child(floor_layer, 0)

	# 2. Walls layer ใน YEntities เพื่อให้ y_sort ทำงานร่วมกับตัวละคร
	var y_entities: Node2D = get_node_or_null("YEntities") as Node2D
	var walls_layer := TileMapLayer.new()
	walls_layer.name = "WallsLayer"
	walls_layer.tile_set = ts
	walls_layer.y_sort_enabled = true
	if y_entities != null:
		y_entities.add_child(walls_layer)
		y_entities.move_child(walls_layer, 0)
	else:
		add_child(walls_layer)

	# วางพื้นทั่วทั้งสองห้อง (x: 0..1920, y: 0..540)
	for gy in range(-6, 32):
		for gx in range(-6, 40):
			var world_pos: Vector2 = floor_layer.map_to_local(Vector2i(gx, gy))
			if world_pos.x >= -64.0 and world_pos.x <= 1984.0 and world_pos.y >= -32.0 and world_pos.y <= 580.0:
				var kind: int = (abs(gx) + abs(gy)) % 3
				floor_layer.set_cell(Vector2i(gx, gy), 0, Vector2i(kind, 1))

	# วางกำแพง TileMapLayer เพื่อพิสูจน์การตรวจจับ occlusion ของ silhouette
	var wall_coords_room1: Array[Vector2i] = [
		Vector2i(6, 8), Vector2i(7, 8), Vector2i(8, 8),
		Vector2i(12, 12), Vector2i(13, 12),
		Vector2i(4, 14), Vector2i(10, 6)
	]
	for c in wall_coords_room1:
		walls_layer.set_cell(c, 0, Vector2i(3, 0))

	var wall_coords_room2: Array[Vector2i] = [
		Vector2i(20, 8), Vector2i(21, 8), Vector2i(22, 8),
		Vector2i(26, 12), Vector2i(27, 12),
		Vector2i(18, 14), Vector2i(24, 6)
	]
	for c in wall_coords_room2:
		walls_layer.set_cell(c, 0, Vector2i(3, 0))


func _make_tileset() -> TileSet:
	var img := _generate_tiles_image()
	var tex := ImageTexture.create_from_image(img)

	var ts := TileSet.new()
	ts.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	ts.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	ts.tile_size = Vector2i(64, 32)
	ts.add_physics_layer()

	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(64, 32)
	ts.add_source(src, 0)

	# พื้น 3 แบบ (ขนาด 64x32 อยู่แถวล่างของ atlas)
	for i: int in 3:
		src.create_tile(Vector2i(i, 1))

	# บล็อกกำแพง 64x64 (ขนาด 1x2 ช่อง)
	src.create_tile(Vector2i(3, 0), Vector2i(1, 2))
	var block: TileData = src.get_tile_data(Vector2i(3, 0), 0)
	block.texture_origin = Vector2i(0, 16)
	block.add_collision_polygon(0)
	block.set_collision_polygon_points(0, 0, PackedVector2Array([
		Vector2(0, -16), Vector2(32, 0), Vector2(0, 16), Vector2(-32, 0)
	]))

	return ts


func _generate_tiles_image() -> Image:
	var img := Image.create(256, 64, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	# 1. Floor 0: (0..63, 32..63)
	_draw_iso_diamond(img, Vector2(31.5, 47.5), Color(0.20, 0.23, 0.29), Color(0.28, 0.32, 0.40))
	# 2. Floor 1: (64..127, 32..63)
	_draw_iso_diamond(img, Vector2(95.5, 47.5), Color(0.18, 0.21, 0.27), Color(0.25, 0.29, 0.37))
	# 3. Floor 2: (128..191, 32..63)
	_draw_iso_diamond(img, Vector2(159.5, 47.5), Color(0.22, 0.26, 0.33), Color(0.30, 0.35, 0.44))

	# 4. Wall Block: (192..255, 0..63)
	_draw_iso_wall_block(img, 192)

	return img


func _draw_iso_diamond(img: Image, center: Vector2, fill_col: Color, border_col: Color) -> void:
	var hw: float = 32.0
	var hh: float = 16.0
	var min_x: int = int(center.x - hw)
	var max_x: int = int(center.x + hw)
	var min_y: int = int(center.y - hh)
	var max_y: int = int(center.y + hh)

	for y in range(min_y, max_y + 1):
		for x in range(min_x, max_x + 1):
			var dx: float = absf(float(x) - center.x) / hw
			var dy: float = absf(float(y) - center.y) / hh
			var dist: float = dx + dy
			if dist <= 1.0:
				if dist >= 0.88:
					img.set_pixel(x, y, border_col)
				else:
					img.set_pixel(x, y, fill_col)


func _draw_iso_wall_block(img: Image, start_x: int) -> void:
	var top_center := Vector2(float(start_x) + 31.5, 15.5)
	var hw: float = 32.0
	var hh: float = 16.0

	var top_col := Color(0.42, 0.48, 0.58)
	var top_border := Color(0.55, 0.62, 0.72)
	var left_col := Color(0.26, 0.30, 0.38)
	var left_border := Color(0.18, 0.20, 0.26)
	var right_col := Color(0.18, 0.22, 0.28)
	var right_border := Color(0.12, 0.15, 0.20)

	for y in range(16, 64):
		for x in range(start_x, start_x + 64):
			var rel_x: float = float(x - start_x)
			var side_is_left: bool = rel_x < 32.0
			var bot_y: float = 47.5 + (1.0 - absf(rel_x - 31.5) / hw) * hh
			var top_edge_y: float = 15.5 + (1.0 - absf(rel_x - 31.5) / hw) * hh

			if float(y) >= top_edge_y and float(y) <= bot_y:
				if side_is_left:
					if rel_x <= 1.0 or float(y) >= bot_y - 1.0:
						img.set_pixel(x, y, left_border)
					else:
						img.set_pixel(x, y, left_col)
				else:
					if rel_x >= 62.0 or float(y) >= bot_y - 1.0 or rel_x == 32.0:
						img.set_pixel(x, y, right_border)
					else:
						img.set_pixel(x, y, right_col)

	for y in range(0, 32):
		for x in range(start_x, start_x + 64):
			var dx: float = absf(float(x) - top_center.x) / hw
			var dy: float = absf(float(y) - top_center.y) / hh
			var dist: float = dx + dy
			if dist <= 1.0:
				if dist >= 0.88:
					img.set_pixel(x, y, top_border)
				else:
					img.set_pixel(x, y, top_col)


func _physics_process(_delta: float) -> void:
	# การเคลื่อนที่ตัวละครแบบ screen-space (ขึ้น = ขึ้นจอ, ตามกติกาข้อ 5)
	var dir: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	if player != null:
		player.velocity = dir * move_speed
		player.move_and_slide()

	# ปุ่ม 1/2 สำหรับเลื่อนกล้องข้ามห้อง
	if Input.is_action_just_pressed(&"camera_room_1"):
		_current_room_id = 1
		camera.slide_to(ROOM_1, 0.8)

	if Input.is_action_just_pressed(&"camera_room_2"):
		_current_room_id = 2
		camera.slide_to(ROOM_2, 0.8)

	# ปุ่ม L สำหรับตั้ง / ยกเลิก focus ไปที่หุ่น
	if Input.is_action_just_pressed(&"camera_focus_dummy"):
		if camera.focus_target == null:
			camera.set_focus_target(dummy)
		else:
			camera.set_focus_target(null)

	# ปุ่ม Space / H สำหรับสั่นและ hitstop
	if Input.is_action_just_pressed(&"camera_shake"):
		camera.add_trauma(0.4)

	if Input.is_action_just_pressed(&"camera_hitstop"):
		GameCamera.hitstop(0.1)

	_update_hud()
	queue_redraw()


func _update_hud() -> void:
	if hud_label == null:
		return

	var is_sil_active: bool = silhouette != null and silhouette.silhouette_sprite != null and silhouette.silhouette_sprite.visible
	var focus_text: String = "Dummy (%s)" % [dummy.position.round()] if camera.focus_target != null else "NONE (Press L)"
	var slide_text: String = "SLIDING..." if camera.is_sliding() else "IDLE (Room %d)" % _current_room_id

	hud_label.text = "=== ISO CAMERA & OCCLUSION SILHOUETTE SANDBOX ===\n" \
		+ "Controls: Arrows/WASD = Move | 1/2 = Slide Room 1/2 | L = Toggle Lock-on Focus | Space = Shake | H = Hitstop\n" \
		+ "TileSet: ISOMETRIC DIAMOND_DOWN 64x32 | Walls: TileMapLayer\n" \
		+ "Room Target: %d | Slide: %s | Focus Target: %s\n" % [_current_room_id, slide_text, focus_text] \
		+ "Cam Pos: %s | Player Pos: %s | Bounds: %s\n" % [camera.position, player.position.round() if player != null else Vector2.ZERO, camera.bounds] \
		+ "Silhouette Active (Behind wall/block): %s" % ["YES (Tinted Purple)" if is_sil_active else "NO"]


func _draw() -> void:
	# วาดขอบเขตของ Room 1 และ Room 2
	draw_rect(ROOM_1, Color(0.3, 0.8, 0.4, 0.6), false, 2.0)
	draw_rect(ROOM_2, Color(0.3, 0.5, 0.9, 0.6), false, 2.0)


func _shoot(path: String) -> void:
	await get_tree().create_timer(float(OS.get_environment("SHOT_DELAY")) if OS.has_environment("SHOT_DELAY") else 1.0).timeout
	if DisplayServer.get_name() != "headless":
		var tex: ViewportTexture = get_viewport().get_texture()
		if tex != null:
			var img: Image = tex.get_image()
			if img != null:
				img.save_png(path)
	get_tree().quit()
