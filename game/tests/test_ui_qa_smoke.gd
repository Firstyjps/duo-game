extends RefCounted
## Smoke test และ Unit tests สำหรับ QaBot และ QaMonitor — issue #66

const GAME_RUN_SCENE: PackedScene = preload("res://systems/ui/run/game_run.tscn")
const QA_BOT_SCRIPT: GDScript = preload("res://systems/ui/run/qa/qa_bot.gd")
const QA_MONITOR_SCRIPT: GDScript = preload("res://systems/ui/run/qa/qa_monitor.gd")
const PLAYER_SCENE: PackedScene = preload("res://systems/player/player.tscn")


## 1. Headless Smoke Test: จำลอง tick 600 เฟรมบน SceneTree root
func test_qa_bot_smoke_600_frames() -> bool:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return false

	var run: GameRun = GAME_RUN_SCENE.instantiate()
	tree.root.add_child(run)
	run.setup()

	if run.player == null:
		tree.root.remove_child(run)
		run.free()
		return false

	run.start_qa(60.0)
	var bot: QaBot = run.qa_bot as QaBot
	var monitor: QaMonitor = run.qa_monitor as QaMonitor
	if bot == null or monitor == null:
		tree.root.remove_child(run)
		run.free()
		return false

	# ปิด auto_quit ระหว่างเทสต์ในชุดเทสต์รวม
	monitor.auto_quit = false

	var delta: float = 1.0 / 60.0
	for i: int in 600:
		bot.tick(delta)
		run.player.tick(delta)
		monitor.tick(delta)

		if run.level != null:
			for child: Node in run.level.get_children():
				if child.has_method("tick"):
					child.call("tick", delta)

	var ok: bool = (run.player != null) and (monitor.anomalies.size() == 0)

	tree.root.remove_child(run)
	run.free()
	return ok


## 2. ทดสอบ QaBot: ดื่มขวดเมื่อ HP < 40%
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


## 3. ทดสอบ QaBot: สลับทิศทางเมื่อติดกำแพงนาน
func test_qa_bot_stuck_wall_changes_direction() -> bool:
	var player: Player = PLAYER_SCENE.instantiate()
	player.setup()
	var bot: QaBot = QA_BOT_SCRIPT.new()
	bot.setup(player)
	bot.stuck_time_threshold = 0.3

	var initial_dir: Vector2 = bot._wander_dir
	# จำลองผู้เล่นยืนนิ่งที่จุดเดิมแม้จะพยายามเดินเกิน stuck_time_threshold
	for i: int in 30:
		bot.tick(1.0 / 60.0)

	var dir_changed: bool = bot._wander_dir != initial_dir
	var ok: bool = dir_changed and (bot._stuck_timer < bot.stuck_time_threshold)

	bot.free()
	player.free()
	return ok


## 4. ทดสอบ QaMonitor: นับ event จาก EventBus และคำนวณ p95/max
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


## 5. ทดสอบ QaMonitor: ตรวจจับ error anomaly เมื่อค้างในสถานะเกิน 5s
func test_qa_monitor_detects_stuck_state_anomaly() -> bool:
	var player: Player = PLAYER_SCENE.instantiate()
	player.setup()
	var monitor: QaMonitor = QA_MONITOR_SCRIPT.new()
	monitor.setup(player)
	monitor.auto_quit = false
	monitor.anomaly_stuck_threshold = 1.0  # ย่นระยะเวลาเหลือ 1.0s เพื่อเทสต์ไว

	player.state = Player.State.ATTACK

	# จำลอง tick รวม 1.2 วินาที
	for i: int in 12:
		monitor.tick(0.1)

	var has_anomaly: bool = monitor.anomalies.size() == 1 \
		and monitor.anomalies[0]["type"] == "player_stuck_state"

	monitor.free()
	player.free()
	return has_anomaly


## 6. ทดสอบ QaMonitor: ตรวจจับ orphan nodes leak
func test_qa_monitor_detects_orphan_leak() -> bool:
	var steady_snapshots: Array[Dictionary] = [
		{"orphans": 0},
		{"orphans": 0},
		{"orphans": 0},
		{"orphans": 0}
	]
	var leaking_snapshots: Array[Dictionary] = [
		{"orphans": 0},
		{"orphans": 2},
		{"orphans": 4},
		{"orphans": 6}
	]

	var no_leak: bool = not QaMonitor.detect_orphan_leak_snapshots(steady_snapshots)
	var has_leak: bool = QaMonitor.detect_orphan_leak_snapshots(leaking_snapshots)

	return no_leak and has_leak
