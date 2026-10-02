extends Node2D
## scene ลองกล้อง: F6 ใน editor · `-- --shot=<path>` = ถ่ายภาพหน้าจอแล้วปิด (ตรวจภาพอัตโนมัติ)
## ลูกศร/WASD = เลื่อนกล่อง · Space = add_trauma · H = hitstop · B = สลับเปิด/ปิด bounds

@export var move_speed: float = 220.0

@onready var camera: GameCamera = $GameCamera
@onready var box: CharacterBody2D = $Box
@onready var hud_label: Label = $CanvasLayer/InfoLabel

var _bounds_enabled: bool = true
const DEMO_BOUNDS := Rect2(60, 60, 1160, 720)


func _ready() -> void:
	_setup_inputs()
	if camera != null:
		camera.set_bounds(DEMO_BOUNDS)
		camera.follow(box, true)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_shoot(arg.trim_prefix("--shot="))


func _setup_inputs() -> void:
	var keys: Dictionary = {
		&"move_left": [KEY_LEFT, KEY_A],
		&"move_right": [KEY_RIGHT, KEY_D],
		&"move_up": [KEY_UP, KEY_W],
		&"move_down": [KEY_DOWN, KEY_S],
		&"camera_shake": [KEY_SPACE],
		&"camera_hitstop": [KEY_H],
		&"camera_bounds_toggle": [KEY_B],
	}
	for action: StringName in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			for k: Key in keys[action]:
				var e := InputEventKey.new()
				e.physical_keycode = k
				InputMap.action_add_event(action, e)


func _physics_process(delta: float) -> void:
	var dir: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	box.velocity = dir * move_speed
	box.move_and_slide()

	if Input.is_action_just_pressed(&"camera_shake"):
		camera.add_trauma(0.4)

	if Input.is_action_just_pressed(&"camera_hitstop"):
		GameCamera.hitstop(0.1)

	if Input.is_action_just_pressed(&"camera_bounds_toggle"):
		_bounds_enabled = not _bounds_enabled
		camera.set_bounds(DEMO_BOUNDS if _bounds_enabled else Rect2())

	_update_hud()
	queue_redraw()


func _update_hud() -> void:
	if hud_label == null:
		return
	hud_label.text = "Controls: Arrows/WASD = Move | Space = Shake | H = Hitstop | B = Toggle Bounds\n" \
		+ "Trauma: %.2f | TimeScale: %.2f | Offset: %s\n" % [camera.trauma, Engine.time_scale, camera.offset] \
		+ "Cam Pos: %s | Box Pos: %s | Bounds: %s" % [
			camera.position,
			box.position.round(),
			"ENABLED " + str(DEMO_BOUNDS) if _bounds_enabled else "DISABLED"
		]


func _draw() -> void:
	# วาดกรอบ bounds ใน world coordinate
	if _bounds_enabled:
		draw_rect(DEMO_BOUNDS, Color(0.9, 0.3, 0.3, 0.8), false, 2.0)


func _shoot(path: String) -> void:
	await get_tree().create_timer(float(OS.get_environment("SHOT_DELAY")) if OS.has_environment("SHOT_DELAY") else 1.0).timeout
	var tex: ViewportTexture = get_viewport().get_texture()
	if tex != null:
		var img: Image = tex.get_image()
		if img != null:
			img.save_png(path)
	get_tree().quit()
