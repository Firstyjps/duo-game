extends SceneTree
## QA Smoke Runner (เฟส 7 · #66) — สคริปต์รันฉาก GameRun และรอ physics_frame จริง 600 เฟรม
## ตรวจสอบการต่อสู้จริง: exit code 1 หาก damage_dealt == 0 หรือมี anomaly
## รันด้วยคำสั่ง:
## godot --headless --path game --script res://systems/ui/run/qa/qa_smoke_runner.gd

var _run: Node = null
var _monitor: Node = null
var _bot: Node = null
var _frames_left: int = 600
var _is_finished: bool = false
var _hang_timeout_seconds: float = 25.0


func _initialize() -> void:
	_start()


func _start() -> void:
	# ตั้งเวลาป้องกัน hang เสมอ (hang protection timer)
	var timer: SceneTreeTimer = create_timer(_hang_timeout_seconds, true, false, true)
	timer.timeout.connect(_on_hang_timeout)

	var scene: PackedScene = load("res://systems/ui/run/game_run.tscn")
	if scene == null:
		printerr("QA Smoke Runner: โหลด res://systems/ui/run/game_run.tscn ไม่สำเร็จ")
		quit(1)
		return

	_run = scene.instantiate()
	root.add_child(_run)
	_run.call("setup")
	_run.call("start_qa", 60.0)

	_monitor = _run.get("qa_monitor")
	_bot = _run.get("qa_bot")

	if _monitor != null:
		_monitor.set("auto_quit", false)

	physics_frame.connect(_on_physics_frame)


func _on_physics_frame() -> void:
	if _is_finished:
		return
	_frames_left -= 1
	if _frames_left <= 0:
		_finish()


func _on_hang_timeout() -> void:
	if _is_finished:
		return
	_is_finished = true
	printerr("QA Smoke Runner TIMEOUT: ทำงานเกินกำหนด %.1f วินาที (hang protection)" % _hang_timeout_seconds)
	if physics_frame.is_connected(_on_physics_frame):
		physics_frame.disconnect(_on_physics_frame)
	quit(1)


func _finish() -> void:
	if _is_finished:
		return
	_is_finished = true

	if physics_frame.is_connected(_on_physics_frame):
		physics_frame.disconnect(_on_physics_frame)

	var damage: int = _monitor.get("damage_dealt_count") if _monitor != null else 0
	var total_dmg: int = _monitor.get("total_damage") if _monitor != null else 0
	var kills: int = _monitor.get("kills") if _monitor != null else 0
	var anomalies_arr: Array = _monitor.get("anomalies") if _monitor != null else []
	var anomalies_count: int = anomalies_arr.size()
	var is_leak: bool = false
	if _monitor != null and _monitor.has_method("detect_orphan_leak"):
		is_leak = _monitor.call("detect_orphan_leak")

	print("QA Smoke Runner: 600 physics frames completed.")
	print("damage_dealt_count=%d, total_damage=%d, kills=%d, anomalies=%d, leak=%s" % [
		damage,
		total_dmg,
		kills,
		anomalies_count,
		str(is_leak)
	])

	if _run != null and is_instance_valid(_run):
		root.remove_child(_run)
		_run.queue_free()

	if damage == 0 or anomalies_count > 0:
		printerr("QA Smoke Runner FAILED: damage_dealt=%d, anomalies=%d" % [damage, anomalies_count])
		quit(1)
	else:
		print("QA Smoke Runner PASSED")
		quit(0)
