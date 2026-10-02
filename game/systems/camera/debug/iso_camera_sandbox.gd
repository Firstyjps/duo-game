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


func _physics_process(delta: float) -> void:
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
		+ "Room Target: %d | Slide: %s | Focus Target: %s\n" % [_current_room_id, slide_text, focus_text] \
		+ "Cam Pos: %s | Player Pos: %s | Bounds: %s\n" % [camera.position, player.position.round() if player != null else Vector2.ZERO, camera.bounds] \
		+ "Silhouette Active (Occluded behind block): %s" % ["YES (Tinted Purple)" if is_sil_active else "NO"]


func _draw() -> void:
	# 1. วาดพื้น Isometric Diamond Grid 64x32
	var tile_w: float = 64.0
	var tile_h: float = 32.0
	var hw: float = tile_w * 0.5
	var hh: float = tile_h * 0.5

	# ครอบคลุมสองห้อง (x: 0..1920, y: 0..540)
	for y in range(0, 540 + int(tile_h), int(tile_h)):
		for x in range(0, 1920 + int(tile_w), int(tile_w)):
			var shift: float = hw if (int(y / tile_h) % 2 == 1) else 0.0
			var cx: float = float(x) + shift
			var cy: float = float(y)
			var pts := PackedVector2Array([
				Vector2(cx, cy - hh),
				Vector2(cx + hw, cy),
				Vector2(cx, cy + hh),
				Vector2(cx - hw, cy),
			])
			var col := Color(0.12, 0.14, 0.18) if ((int(x / tile_w) + int(y / tile_h)) % 2 == 0) else Color(0.14, 0.16, 0.21)
			draw_colored_polygon(pts, col)
			draw_polyline(pts, Color(0.18, 0.21, 0.27), 1.0)

	# 2. วาดขอบเขตของ Room 1 และ Room 2
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
