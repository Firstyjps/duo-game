class_name QaMonitor
extends Node
## QA Monitor (เฟส 7 · #66) — ตัววัดสถิติและตรวจจับ Anomaly / Memory Leak
## ทุกวินาทีบันทึก:
## - FPS, frame time p95 / max (Performance.TIME_PROCESS)
## - จำนวน node (Performance.OBJECT_NODE_COUNT), orphan nodes, memory (Performance.MEMORY_STATIC)
## - นับ event จาก EventBus: damage_dealt, enemy_died, player_died, attack_deflected
## - ตรวจจับ error: หาก Player ค้างในสถานะที่ไม่ใช่ MOVE / DEAD เกิน 5 วินาที → บันทึก anomaly
## เมื่อครบกำหนดเวลา (--qa-seconds=N):
## - เขียน user://qa_report.json
## - พิมพ์สรุปบรรทัดเดียว:
##   QA: fps_avg=.. p95_ms=.. max_ms=.. nodes_max=.. orphans=.. kills=.. deaths=.. anomalies=..
## - ออกจากเกมด้วย exit code 1 หาก anomaly > 0 หรือ orphans เพิ่มขึ้นต่อเนื่อง (leak)

@export var target_seconds: float = 60.0
@export var report_path: String = "user://qa_report.json"
@export var anomaly_stuck_threshold: float = 5.0
@export var auto_quit: bool = true

var player: Player
var elapsed_seconds: float = 0.0
var total_frames: int = 0

# Event counters
var damage_dealt_count: int = 0
var total_damage: int = 0
var kills: int = 0
var deaths: int = 0
var deflections: int = 0

# Datasets
var frame_times_ms: Array[float] = []
var snapshots: Array[Dictionary] = []
var anomalies: Array[Dictionary] = []

var _second_acc: float = 0.0
var _second_frames: int = 0
var _stuck_state_timer: float = 0.0
var _stuck_state_reported: bool = false
var _finished: bool = false


func _ready() -> void:
	if player == null:
		setup()


func _enter_tree() -> void:
	_connect_event_bus()


func _exit_tree() -> void:
	_disconnect_event_bus()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_disconnect_event_bus()


func setup(target_player: Player = null) -> void:
	if target_player != null:
		player = target_player
	elif get_parent() != null and "player" in get_parent() and get_parent().get("player") is Player:
		player = get_parent().get("player") as Player

	_connect_event_bus()


func _connect_event_bus() -> void:
	if EventBus == null:
		return
	if not EventBus.damage_dealt.is_connected(_on_damage_dealt):
		EventBus.damage_dealt.connect(_on_damage_dealt)
	if not EventBus.enemy_died.is_connected(_on_enemy_died):
		EventBus.enemy_died.connect(_on_enemy_died)
	if not EventBus.player_died.is_connected(_on_player_died):
		EventBus.player_died.connect(_on_player_died)
	if not EventBus.attack_deflected.is_connected(_on_attack_deflected):
		EventBus.attack_deflected.connect(_on_attack_deflected)


func _disconnect_event_bus() -> void:
	if EventBus == null:
		return
	if EventBus.damage_dealt.is_connected(_on_damage_dealt):
		EventBus.damage_dealt.disconnect(_on_damage_dealt)
	if EventBus.enemy_died.is_connected(_on_enemy_died):
		EventBus.enemy_died.disconnect(_on_enemy_died)
	if EventBus.player_died.is_connected(_on_player_died):
		EventBus.player_died.disconnect(_on_player_died)
	if EventBus.attack_deflected.is_connected(_on_attack_deflected):
		EventBus.attack_deflected.disconnect(_on_attack_deflected)


func _on_damage_dealt(_target: Node, _info: DamageInfo, final_amount: int) -> void:
	damage_dealt_count += 1
	total_damage += final_amount


func _on_enemy_died(_enemy: Node, _enemy_id: StringName, _pos: Vector2) -> void:
	kills += 1


func _on_player_died() -> void:
	deaths += 1


func _on_attack_deflected(_defender: Node, _info: DamageInfo) -> void:
	deflections += 1


func _process(delta: float) -> void:
	tick(delta)


## ตรรกะตรวจวัด 1 เฟรม — แยกจาก _process ให้เทสต์เรียกตรงได้
func tick(delta: float) -> void:
	if _finished:
		return

	elapsed_seconds += delta
	total_frames += 1
	_second_frames += 1
	_second_acc += delta

	# 1. วัด Process frame time
	var proc_time: float = Performance.get_monitor(Performance.TIME_PROCESS)
	var frame_ms: float = proc_time * 1000.0 if proc_time > 0.0 else delta * 1000.0
	frame_times_ms.append(frame_ms)

	# 2. ตรวจสอบ Player state anomaly (ค้างเกิน 5s ในสถานะไม่ใช่ MOVE / DEAD)
	if player != null and is_instance_valid(player):
		var s: int = player.state
		if s != Player.State.MOVE and s != Player.State.DEAD:
			_stuck_state_timer += delta
			if _stuck_state_timer >= anomaly_stuck_threshold and not _stuck_state_reported:
				_stuck_state_reported = true
				var state_name: String = Player.State.keys()[s] if s >= 0 and s < Player.State.size() else str(s)
				anomalies.append({
					"type": "player_stuck_state",
					"state": state_name,
					"state_id": s,
					"duration": _stuck_state_timer,
					"time": elapsed_seconds
				})
		else:
			_stuck_state_timer = 0.0
			_stuck_state_reported = false

	# 3. บันทึกสถิติทุก ๆ 1 วินาที
	if _second_acc >= 1.0:
		_second_acc -= 1.0
		_record_snapshot()
		_second_frames = 0

	# 4. สิ้นสุดการทำงานตาม target_seconds
	if target_seconds > 0.0 and elapsed_seconds >= target_seconds:
		finish_and_report()


func _record_snapshot() -> void:
	var fps_val: float = Performance.get_monitor(Performance.TIME_FPS)
	if fps_val <= 0.0:
		fps_val = float(_second_frames)
	var node_count: int = int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	var orphan_count: int = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	var memory_bytes: int = int(Performance.get_monitor(Performance.MEMORY_STATIC))

	snapshots.append({
		"second": int(round(elapsed_seconds)),
		"fps": fps_val,
		"nodes": node_count,
		"orphans": orphan_count,
		"memory_bytes": memory_bytes,
		"kills": kills,
		"deaths": deaths,
		"damage_events": damage_dealt_count,
		"deflections": deflections
	})


static func compute_p95(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var sorted: Array[float] = values.duplicate()
	sorted.sort()
	var idx: int = int(ceil(0.95 * sorted.size())) - 1
	idx = clampi(idx, 0, sorted.size() - 1)
	return sorted[idx]


static func compute_max(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var max_val: float = values[0]
	for v: float in values:
		if v > max_val:
			max_val = v
	return max_val


func detect_orphan_leak() -> bool:
	return detect_orphan_leak_snapshots(snapshots)


static func detect_orphan_leak_snapshots(snaps: Array[Dictionary]) -> bool:
	if snaps.size() < 4:
		return false
	var strictly_increasing: bool = true
	for i: int in range(snaps.size() - 3, snaps.size()):
		var cur: int = int(snaps[i].get("orphans", 0))
		var prev: int = int(snaps[i - 1].get("orphans", 0))
		if cur <= prev:
			strictly_increasing = false
			break
	if strictly_increasing and int(snaps[-1].get("orphans", 0)) > int(snaps[0].get("orphans", 0)):
		return true
	return false


## ปิดรอบบันทึกผล เขียนไฟล์ JSON พิมพ์สรุป และ quit หาก auto_quit = true
func finish_and_report() -> Dictionary:
	if _finished:
		return {}
	_finished = true

	# บันทึก snapshot สุดท้ายหากยังไม่มี
	if snapshots.is_empty() or snapshots[-1]["second"] != int(round(elapsed_seconds)):
		_record_snapshot()

	var fps_sum: float = 0.0
	var nodes_max: int = 0
	var last_orphans: int = 0

	for s: Dictionary in snapshots:
		fps_sum += float(s.get("fps", 0.0))
		var n: int = int(s.get("nodes", 0))
		if n > nodes_max:
			nodes_max = n
		last_orphans = int(s.get("orphans", 0))

	var fps_avg: float = fps_sum / float(snapshots.size()) if not snapshots.is_empty() else (float(total_frames) / maxf(0.001, elapsed_seconds))
	var p95_ms: float = compute_p95(frame_times_ms)
	var max_ms: float = compute_max(frame_times_ms)
	var is_leak: bool = detect_orphan_leak()

	var report := {
		"summary": {
			"fps_avg": fps_avg,
			"p95_ms": p95_ms,
			"max_ms": max_ms,
			"nodes_max": nodes_max,
			"orphans": last_orphans,
			"kills": kills,
			"deaths": deaths,
			"anomalies": anomalies.size(),
			"deflections": deflections,
			"damage_dealt_count": damage_dealt_count,
			"total_damage": total_damage,
			"total_seconds": elapsed_seconds,
			"total_frames": total_frames,
			"orphan_leak_detected": is_leak
		},
		"anomalies": anomalies,
		"snapshots": snapshots
	}

	# เขียน JSON ลง user://qa_report.json
	var file: FileAccess = FileAccess.open(report_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()

	# พิมพ์สรุปบรรทัดเดียวตาม format ของ contract QA
	var summary_line: String = "QA: fps_avg=%.1f p95_ms=%.1f max_ms=%.1f nodes_max=%d orphans=%d kills=%d deaths=%d anomalies=%d" % [
		fps_avg,
		p95_ms,
		max_ms,
		nodes_max,
		last_orphans,
		kills,
		deaths,
		anomalies.size()
	]
	print(summary_line)

	if auto_quit:
		var exit_code: int = 1 if (anomalies.size() > 0 or is_leak) else 0
		var tree: SceneTree = Engine.get_main_loop() as SceneTree
		if tree != null:
			tree.quit(exit_code)

	return report
