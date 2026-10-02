extends Node
## ตัวช่วยของฉากทดสอบ Merakintsugi: Z = สลับซูม 1×/2× · อัดภาพอัตโนมัติสำหรับตรวจงาน
## godot --path game --windowed --resolution 960x540 --fixed-fps 30 res://mockup/merakintsugi/merakintsugi_sandbox.tscn -- --autoplay --frames=<โฟลเดอร์>

@onready var player: Player = get_node("../Player")
@onready var cam: Camera2D = get_node("../Camera2D")

var autoplay: bool = false
var frames_dir: String = ""
var _clock: float = 0.0
var _frame: int = 0
var _fired: Dictionary = {}

## เวลา (วินาที) → [move, aim, attack, dodge] สำหรับโหมด autoplay
const SCRIPT := [
	[0.0, Vector2.ZERO, Vector2.RIGHT, false, false],
	[0.8, Vector2.RIGHT, Vector2.RIGHT, false, false],
	[1.8, Vector2.ZERO, Vector2.RIGHT, true, false],
	[2.15, Vector2.ZERO, Vector2.RIGHT, true, false],
	[2.5, Vector2.ZERO, Vector2.RIGHT, true, false],
	[3.3, Vector2.LEFT, Vector2.RIGHT, false, true],
	[3.8, Vector2.LEFT, Vector2.LEFT, false, false],
	[4.6, Vector2(0.7, 0.7), Vector2.RIGHT, false, true],
	[5.2, Vector2.ZERO, Vector2.RIGHT, false, false],
]


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	autoplay = "--autoplay" in args
	for a in args:
		if a.begins_with("--frames="):
			frames_dir = a.trim_prefix("--frames=")
			DirAccess.make_dir_recursive_absolute(frames_dir)
	if autoplay:
		player.manual_control = true
		cam.zoom = Vector2(2, 2)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_Z:
		cam.zoom = Vector2.ONE if cam.zoom.x > 1.5 else Vector2(2, 2)


func _physics_process(delta: float) -> void:
	cam.global_position = player.global_position + Vector2(0, -24)
	if not autoplay:
		return
	_clock += delta
	var cur: Array = SCRIPT[0]
	var idx := 0
	for i in SCRIPT.size():
		if _clock >= SCRIPT[i][0]:
			cur = SCRIPT[i]; idx = i
	var first: bool = not _fired.has(idx)
	_fired[idx] = true
	player.set_intent(cur[1], cur[2], cur[3] and first, cur[4] and first)
	if _clock > 6.2:
		get_tree().quit()


func _process(_delta: float) -> void:
	if frames_dir == "":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/f_%04d.png" % [frames_dir, _frame])
	_frame += 1
