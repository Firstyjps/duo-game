extends RefCounted
## Smoke test และ Unit tests สำหรับ QaBot และ QaMonitor — issue #66

const GAME_RUN_SCENE: PackedScene = preload("res://systems/ui/run/game_run.tscn")
const QA_BOT_SCRIPT: GDScript = preload("res://systems/ui/run/qa/qa_bot.gd")
const QA_MONITOR_SCRIPT: GDScript = preload("res://systems/ui/run/qa/qa_monitor.gd")
const PLAYER_SCENE: PackedScene = preload("res://systems/player/player.tscn")


## 1. ทดสอบการเชื่อมต่อ GameRun กับ QaBot และ QaMonitor (Sync Unit Test)
func test_game_run_qa_wiring_sync() -> bool:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return false

	var run: GameRun = GAME_RUN_SCENE.instantiate()
	tree.root.add_child(run)
	run.setup()
	run.start_qa(60.0)

	var bot: QaBot = run.qa_bot as QaBot
	var monitor: QaMonitor = run.qa_monitor as QaMonitor

	var wired_ok: bool = (run.player != null) \
		and (bot != null) \
		and (monitor != null) \
		and (bot.player == run.player) \
		and (monitor.player == run.player)

	if monitor != null:
		monitor.auto_quit = false

	tree.root.remove_child(run)
	run.free()
	return wired_ok


## 2. ทดสอบ QaBot เลือกเป้าหมายจาก player.test_targets พร้อม Aim และ Lock-on ถูกต้อง
func test_qa_bot_targets_and_aims_with_test_targets() -> bool:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return false

	var player: Player = PLAYER_SCENE.instantiate()
	tree.root.add_child(player)
	player.setup()
	player.global_position = Vector2(300, 300)

	var dummy := Node2D.new()
	tree.root.add_child(dummy)
	dummy.global_position = player.global_position + Vector2(0.0, player.body_y) + Vector2(100, 0)

	player.test_targets = [dummy]

	var bot: QaBot = QA_BOT_SCRIPT.new()
	tree.root.add_child(bot)
	bot.setup(player)

	bot.tick(1.0 / 60.0)
	player.tick(1.0 / 60.0)

	var target_selected: bool = (bot._current_target == dummy)
	var aimed_correctly: bool = player.aim.x > 0.9 and absf(player.aim.y) < 0.1
	var locked_on: bool = player.is_locked_on() and player.lock_target == dummy

	tree.root.remove_child(bot)
	bot.free()
	tree.root.remove_child(dummy)
	dummy.free()
	tree.root.remove_child(player)
	player.free()

	return target_selected and aimed_correctly and locked_on


## 3. ด่านว่าง physics จริง 300 เฟรม: เปลี่ยนทิศ <= 4 ครั้ง และเคลื่อนที่สุทธิ > 100 px
func test_qa_bot_empty_stage_300_frames_no_false_stuck() -> bool:
	seed(66)  # เส้นทางเดินสุ่มต้อง deterministic (ไม่ seed = พังเอง ~7%)
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return false

	var player: Player = PLAYER_SCENE.instantiate()
	tree.root.add_child(player)
	player.setup()
	player.global_position = Vector2(500, 500)

	var bot: QaBot = QA_BOT_SCRIPT.new()
	tree.root.add_child(bot)
	bot.setup(player)

	var start_pos: Vector2 = player.global_position
	var dir_changes: int = 0
	var last_dir: Vector2 = bot._wander_dir
	var delta: float = 1.0 / 60.0

	for i: int in 300:
		bot.tick(delta)
		player.tick(delta)
		player.global_position += player.velocity * delta
		if not bot._wander_dir.is_equal_approx(last_dir):
			dir_changes += 1
			last_dir = bot._wander_dir

	var net_dist: float = player.global_position.distance_to(start_pos)

	tree.root.remove_child(bot)
	bot.free()
	tree.root.remove_child(player)
	player.free()

	return dir_changes <= 4 and net_dist > 100.0


## 4. ทดสอบ QaBot: ดื่มขวดเมื่อ HP < 40%
func test_qa_bot_drinks_flask_when_low_hp() -> bool:
	var player: Player = PLAYER_SCENE.instantiate()
	player.setup()
	var bot: QaBot = QA_BOT_SCRIPT.new()
	bot.setup(player)

	# ลด HP ให้เหลือ < 40% (max_hp = 12 -> ลด 8 เหลือ 4 ซึ่ง 4/12 = 33% < 40%)
	player.health.take_damage(8)
	var initial_flasks: int = player.flasks
	var can_drink_before: bool = player.can_drink()

	bot.tick(1.0 / 60.0)
	player.tick(1.0 / 60.0)

	var drank: bool = (player.is_drinking() or player.flasks < initial_flasks)
	var ok: bool = can_drink_before and drank

	bot.free()
	player.free()
	return ok


## 5. ทดสอบ QaMonitor: นับ event จาก EventBus และคำนวณ p95/max
func test_qa_monitor_counts_event_bus() -> bool:
	var monitor: QaMonitor = QA_MONITOR_SCRIPT.new()
	monitor.setup()
	monitor.auto_quit = false

	var info := DamageInfo.new()
	info.team = Combat.Team.PLAYER
	info.amount = 5

	var dummy := Node2D.new()
	EventBus.damage_dealt.emit(dummy, info, 5)
	EventBus.enemy_died.emit(dummy, &"slime", Vector2.ZERO)
	EventBus.player_died.emit()
	EventBus.attack_deflected.emit(dummy, info)
	dummy.free()

	var ok_counts: bool = (monitor.damage_dealt_count == 1) \
		and (monitor.total_damage == 5) \
		and (monitor.kills == 1) \
		and (monitor.deaths == 1) \
		and (monitor.deflections == 1)

	var values: Array[float] = [10.0, 20.0, 30.0, 40.0, 50.0, 60.0, 70.0, 80.0, 90.0, 100.0]
	var p95: float = QaMonitor.compute_p95(values)
	var max_val: float = QaMonitor.compute_max(values)
	var ok_stats: bool = is_equal_approx(p95, 100.0) and is_equal_approx(max_val, 100.0)

	monitor.free()
	return ok_counts and ok_stats


## 6. ทดสอบ QaMonitor: ตรวจจับ error anomaly เมื่อค้างในสถานะเกิน 5s
func test_qa_monitor_detects_stuck_state_anomaly() -> bool:
	var player: Player = PLAYER_SCENE.instantiate()
	player.setup()
	var monitor: QaMonitor = QA_MONITOR_SCRIPT.new()
	monitor.setup(player)
	monitor.auto_quit = false
	monitor.anomaly_stuck_threshold = 1.0

	player.state = Player.State.ATTACK

	# จำลอง tick รวม 1.2 วินาที
	for i: int in 12:
		monitor.tick(0.1)

	var has_anomaly: bool = monitor.anomalies.size() == 1 \
		and monitor.anomalies[0]["type"] == "player_stuck_state"

	monitor.free()
	player.free()
	return has_anomaly


## 7. ทดสอบ QaMonitor: ตรวจจับ orphan nodes leak เทียบ baseline หลัง warmup + threshold 20
func test_qa_monitor_detects_orphan_leak() -> bool:
	var steady_snapshots: Array[Dictionary] = [
		{"second": 0, "orphans": 0},
		{"second": 2, "orphans": 10},
		{"second": 3, "orphans": 15},
		{"second": 4, "orphans": 22}
	]
	var leaking_snapshots: Array[Dictionary] = [
		{"second": 0, "orphans": 0},
		{"second": 2, "orphans": 10},
		{"second": 3, "orphans": 25},
		{"second": 4, "orphans": 35}
	]

	# diff สำหรับ steady คือ 22 - 10 = 12 <= 20 -> ไม่รั่ว
	var no_leak: bool = not QaMonitor.detect_orphan_leak_snapshots(steady_snapshots, 20, 2.0)
	# diff สำหรับ leaking คือ 35 - 10 = 25 > 20 -> ตรวจพบการรั่ว
	var has_leak: bool = QaMonitor.detect_orphan_leak_snapshots(leaking_snapshots, 20, 2.0)

	return no_leak and has_leak


## 8. ทดสอบ QaMonitor: คำนวณ fps_avg โดยข้ามช่วง warmup 2 วินาทีแรก
func test_qa_monitor_fps_avg_skips_warmup() -> bool:
	var monitor: QaMonitor = QA_MONITOR_SCRIPT.new()
	monitor.setup()
	monitor.auto_quit = false
	monitor.warmup_seconds = 2.0

	# 120 เฟรมแรก ช่วง warmup 2 วินาที (delta = 1/60)
	var delta: float = 1.0 / 60.0
	for i: int in 120:
		monitor.tick(delta)

	# 60 เฟรมถัดมา หลัง warmup (1 วินาทีเต็ม อัตรา 60 FPS)
	for i: int in 60:
		monitor.tick(delta)

	var report: Dictionary = monitor.finish_and_report()
	var fps_avg: float = float(report.get("summary", {}).get("fps_avg", 0.0))

	monitor.free()
	# fps_avg ต้องคำนวณจาก 60 เฟรม / 1.0 วินาที ≈ 60.0 FPS
	return is_equal_approx(fps_avg, 60.0)
