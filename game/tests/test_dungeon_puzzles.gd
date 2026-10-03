extends RefCounted
## เทสต์ระบบปริศนาและศาลเจ้า (issue #57)
## ครอบคลุม: สวิตช์ latch/ไม่ latch, gate AND, push block ทิศทาง snap และ blocked_cells,
## lantern จุดเมื่อโดน Hitbox ผู้เล่น + ปลด lock-on ถาวร, crack ซ่อมด้วยเศษทอง,
## shrine จุดเกิดใหม่ + enemy safe radius + cooldown
## หมายเหตุ: เทสต์ physics จริง (กำแพง + เดิน 8 ทิศ) อยู่ใน res://systems/dungeon/puzzles/debug/puzzle_physics_runner.gd

const SWITCH_SCENE: PackedScene = preload("res://systems/dungeon/puzzles/pressure_switch.tscn")
const BLOCK_SCENE: PackedScene = preload("res://systems/dungeon/puzzles/push_block.tscn")
const LANTERN_SCENE: PackedScene = preload("res://systems/dungeon/puzzles/stone_lantern.tscn")
const GATE_SCENE: PackedScene = preload("res://systems/dungeon/puzzles/puzzle_gate.tscn")
const CRACK_SCENE: PackedScene = preload("res://systems/dungeon/puzzles/kintsugi_crack.tscn")
const SHRINE_SCENE: PackedScene = preload("res://systems/dungeon/puzzles/rest_shrine.tscn")
const SHARD_SCENE: PackedScene = preload("res://systems/dungeon/puzzles/pickup_shard.tscn")


func test_switch_non_latch_and_latch() -> bool:
	var sw: PressureSwitch = SWITCH_SCENE.instantiate()
	sw.setup()

	var dummy := CharacterBody2D.new()
	dummy.name = "Player"
	dummy.add_to_group(&"player")

	var toggled_values: Array[bool] = []
	sw.toggled.connect(func(on: bool) -> void: toggled_values.append(on))

	# Non-latch: เหยียบ -> on, ปล่อย -> off
	sw.latch = false
	sw.press(dummy)
	var on_after_press: bool = sw.is_on
	sw.release(dummy)
	var off_after_release: bool = not sw.is_on

	# Latch: เหยียบ -> on, ปล่อย -> ยังค้าง on
	sw.latch = true
	sw.press(dummy)
	var on_after_latch_press: bool = sw.is_on
	sw.release(dummy)
	var still_on_after_release: bool = sw.is_on

	sw.free()
	dummy.free()
	GoldShards.reset()

	return on_after_press and off_after_release and on_after_latch_press and still_on_after_release and toggled_values == [true, false, true]


func test_gate_and_logic() -> bool:
	var container := Node.new()
	var gate: PuzzleGate = GATE_SCENE.instantiate()
	var s1: PressureSwitch = SWITCH_SCENE.instantiate()
	var s2: PressureSwitch = SWITCH_SCENE.instantiate()
	s1.name = "Switch1"
	s2.name = "Switch2"
	container.add_child(gate)
	container.add_child(s1)
	container.add_child(s2)
	gate.setup()
	s1.setup()
	s2.setup()

	gate.required = [gate.get_path_to(s1), gate.get_path_to(s2)]

	var open_events: Array[bool] = []
	gate.toggled.connect(func(on: bool) -> void: open_events.append(on))

	# s1 เปิดตัวเดียว -> gate ต้องยังไม่เปิด
	gate.activate(s1)
	var only_s1_closed: bool = not gate.is_open

	# s2 เปิดด้วย -> ครบทั้งสองตัว -> gate เปิด (เช็ค is_open ตามรีวิว)
	gate.activate(s2)
	var both_opened: bool = gate.is_open

	# s1 ดับ (input ไม่ค้าง) -> gate ต้องปิดกลับ
	gate.deactivate(s1)
	var s1_off_closed: bool = not gate.is_open

	# s1 เปิดอีกครั้ง -> เปิดใหม่
	gate.activate(s1)
	var reopened: bool = gate.is_open

	container.free()
	GoldShards.reset()

	return only_s1_closed and both_opened and s1_off_closed and reopened and open_events == [true, false, true]


func test_push_block_direction_mapping() -> bool:
	# ทดสอบแปลงทิศบนจอ 4 แนวแกน grid isometric diamond down
	var dr: Vector2i = PushBlock.direction_to_cell_step(Vector2(2.0, 1.0))
	var dl: Vector2i = PushBlock.direction_to_cell_step(Vector2(-2.0, 1.0))
	var ul: Vector2i = PushBlock.direction_to_cell_step(Vector2(-2.0, -1.0))
	var ur: Vector2i = PushBlock.direction_to_cell_step(Vector2(2.0, -1.0))

	GoldShards.reset()
	return dr == Vector2i(1, 0) and dl == Vector2i(0, 1) and ul == Vector2i(-1, 0) and ur == Vector2i(0, -1)


func test_push_block_snap_and_tie_breaking() -> bool:
	# บล็อกหินหาทิศดันจากตำแหน่ง (บล็อก - ผู้เล่น) snap เป็นแกน cell
	# และกรณีทิศเสมอกัน เลือกตามทิศที่ผู้เล่นขยับล่าสุด (รีวิวข้อ 1)
	# ผู้เล่นอยู่ใต้บล็อก (South): to_block ชี้ขึ้นเหนือ (0, -1)
	var to_block := Vector2(0.0, -50.0)

	# ถ้าผู้เล่นเดินเฉียงขึ้น-ขวา (W+D): เสมอกันระหว่าง up-left กับ up-right -> ต้องเลือก up-right (0, -1)
	var step_wd: Vector2i = PushBlock.snap_to_cell_step(to_block, Vector2(1.0, -1.0))

	# ถ้าผู้เล่นเดินเฉียงขึ้น-ซ้าย (W+A): ต้องเลือก up-left (-1, 0)
	var step_wa: Vector2i = PushBlock.snap_to_cell_step(to_block, Vector2(-1.0, -1.0))

	# ผู้เล่นอยู่เหนือบล็อก (North): to_block ชี้ลงใต้ (0, 1)
	var to_block_south := Vector2(0.0, 50.0)
	# ผู้เล่นเดินเฉียงลง-ขวา (S+D) -> down-right (1, 0)
	var step_sd: Vector2i = PushBlock.snap_to_cell_step(to_block_south, Vector2(1.0, 1.0))
	# ผู้เล่นเดินเฉียงลง-ซ้าย (S+A) -> down-left (0, 1)
	var step_sa: Vector2i = PushBlock.snap_to_cell_step(to_block_south, Vector2(-1.0, 1.0))

	GoldShards.reset()
	return step_wd == Vector2i(0, -1) and step_wa == Vector2i(-1, 0) and step_sd == Vector2i(1, 0) and step_sa == Vector2i(0, 1)


func test_push_block_blocked_cells() -> bool:
	# ทดสอบว่า blocked_cells กันบล็อกดันเข้าเซลล์ที่ห้ามไว้ (รีวิวข้อ 6)
	var block: PushBlock = BLOCK_SCENE.instantiate()
	block.setup()
	block.current_cell = Vector2i(5, 3)
	block.blocked_cells = [Vector2i(5, 2), Vector2i(5, 4)]

	# พยายามดันไป cell (0, 1) ซึ่งคือ cell (5, 4) -> ติด blocked_cells
	var push_blocked: bool = block.try_push_step(Vector2i(0, 1))

	# ดันไป cell (1, 0) ซึ่งคือ cell (6, 3) -> ทางโล่ง ดันผ่าน
	var push_allowed: bool = block.try_push_step(Vector2i(1, 0))

	block.free()
	GoldShards.reset()
	return (not push_blocked) and push_allowed


func test_lantern_ignites_on_player_hitbox_only() -> bool:
	var lantern: StoneLantern = LANTERN_SCENE.instantiate()
	lantern.lit_time = 0.5
	lantern.setup()

	# โดนตีจากทีม ENEMY -> NEUTRAL โดนได้แต่ StoneLantern ต้องเช็คไม่จุดไฟ
	var enemy_hit := DamageInfo.new()
	enemy_hit.team = Combat.Team.ENEMY
	enemy_hit.amount = 2
	lantern.hurtbox.receive(enemy_hit)
	var not_lit_by_enemy: bool = not lantern.is_lit and not lantern.point_light.enabled

	# โดนตีจากทีม PLAYER -> จุดไฟ + เปิด PointLight2D
	var player_hit := DamageInfo.new()
	player_hit.team = Combat.Team.PLAYER
	player_hit.amount = 3
	lantern.hurtbox.receive(player_hit)
	var lit_by_player: bool = lantern.is_lit and lantern.point_light.enabled

	# นับเวลาดับตาม lit_time
	lantern.tick(0.3)
	var still_lit: bool = lantern.is_lit
	lantern.tick(0.25)
	var extinguished_after_time: bool = not lantern.is_lit and not lantern.point_light.enabled

	# ทดสอบโคมติดถาวร (lit_time = 0.0) -> hurtbox.set_deferred("monitorable", false) (รีวิวข้อ 7)
	var permanent_lantern: StoneLantern = LANTERN_SCENE.instantiate()
	permanent_lantern.lit_time = 0.0
	permanent_lantern.setup()
	permanent_lantern.hurtbox.receive(player_hit)
	var perm_lit: bool = permanent_lantern.is_lit

	lantern.free()
	permanent_lantern.free()
	GoldShards.reset()

	return not_lit_by_enemy and lit_by_player and still_lit and extinguished_after_time and perm_lit


func test_kintsugi_crack_repair_shards() -> bool:
	GoldShards.reset()
	var crack: KintsugiCrack = CRACK_SCENE.instantiate()
	crack.cost = 3
	crack.setup()

	var repaired_events: Array[int] = []
	crack.repaired.connect(func() -> void: repaired_events.append(1))

	# เศษไม่พอ (มี 2 ต้องใช้ 3) -> ซ่อมไม่ผ่าน (เช็ค is_repaired ตามรีวิว)
	GoldShards.count = 2
	var failed_repair: bool = not crack.try_repair()
	var still_cracked: bool = not crack.is_repaired

	# เศษพอ (เก็บเพิ่มอีก 2 เป็น 4) -> ซ่อมผ่าน หักเศษเหลือ 1
	GoldShards.add(2)
	var success_repair: bool = crack.try_repair()
	var now_repaired: bool = crack.is_repaired and GoldShards.count == 1

	crack.free()
	GoldShards.reset()
	return failed_repair and still_cracked and success_repair and now_repaired and repaired_events == [1]


func test_pickup_shard_collect() -> bool:
	GoldShards.reset()
	var shard: PickupShard = SHARD_SCENE.instantiate()
	shard.value = 2
	shard.setup()

	var collected_amount: Array[int] = []
	shard.collected.connect(func(val: int) -> void: collected_amount.append(val))

	shard.collect()
	var ok: bool = GoldShards.count == 2 and collected_amount == [2]

	GoldShards.reset()
	return ok


func test_rest_shrine_checkpoint_and_respawn_signal() -> bool:
	var shrine: RestShrine = SHRINE_SCENE.instantiate()
	shrine.setup()
	shrine.global_position = Vector2(200, 300)
	var expected_spawn := Vector2(200, 318)
	shrine.spawn_marker.global_position = expected_spawn

	var respawn_positions: Array[Vector2] = []
	var respawn_cb := func(pos: Vector2) -> void:
		respawn_positions.append(pos)
	EventBus.player_respawn_requested.connect(respawn_cb)

	var checkpoint_positions: Array[Vector2] = []
	var cp_cb := func(pos: Vector2) -> void:
		checkpoint_positions.append(pos)
	shrine.checkpoint_set.connect(cp_cb)

	var rest_ok: bool = shrine.rest()

	EventBus.player_respawn_requested.disconnect(respawn_cb)
	shrine.checkpoint_set.disconnect(cp_cb)

	var ok: bool = rest_ok \
		and respawn_positions == [expected_spawn] \
		and checkpoint_positions == [expected_spawn] \
		and shrine.is_active \
		and shrine.point_light.enabled

	shrine.free()
	GoldShards.reset()
	return ok


func test_rest_shrine_cooldown_and_safe_radius() -> bool:
	# ทดสอบ cooldown ~3s และ safe radius ไม่ให้พักเมื่อมีศัตรูอยู่ใกล้ (รีวิวข้อ 8)
	var shrine: RestShrine = SHRINE_SCENE.instantiate()
	shrine.rest_cooldown = 3.0
	shrine.rest_safe_radius = 240.0
	shrine.setup()

	# 1. พักครั้งแรกสำเร็จ
	var first_rest: bool = shrine.rest()

	# 2. กดพักทันที -> ติด cooldown 3.0s ต้องพักไม่ได้
	var cooldown_blocked: bool = not shrine.rest()
	var cannot_rest_on_cd: bool = not shrine.can_rest()

	# 3. เวลาผ่านไป 3.1s -> พ้น cooldown กลับมาพักได้
	shrine.tick(3.1)
	var can_rest_after_cd: bool = shrine.can_rest()

	# 4. มีศัตรูเข้ามาใน safe radius -> พักไม่ได้
	var enemy := Node2D.new()
	enemy.add_to_group(&"enemy")
	shrine._on_enemy_entered(enemy)

	var enemy_blocked: bool = not shrine.can_rest()
	var enemy_rest_failed: bool = not shrine.rest()

	# 5. ศัตรูออกไป -> พักได้
	shrine._on_enemy_exited(enemy)
	var safe_again: bool = shrine.can_rest()

	enemy.free()
	shrine.free()
	GoldShards.reset()

	return first_rest and cooldown_blocked and cannot_rest_on_cd and can_rest_after_cd and enemy_blocked and enemy_rest_failed and safe_again
