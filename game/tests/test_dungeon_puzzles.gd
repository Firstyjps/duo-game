extends RefCounted
## เทสต์ระบบปริศนาและศาลเจ้า (issue #57)
## ครอบคลุม: สวิตช์ latch/ไม่ latch, gate AND, push block ฟิสิกส์จริงไม่ทะลุกำแพง,
## lantern จุดเมื่อโดน Hitbox ผู้เล่นเท่านั้น, crack ซ่อมด้วยเศษทองหักเศษ, shrine จุดเกิดใหม่

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

	# s2 เปิดด้วย -> ครบทั้งสองตัว -> gate เปิด
	gate.activate(s2)
	var both_opened: bool = gate.is_open and gate.collision_shape.disabled

	# s1 ดับ (input ไม่ค้าง) -> gate ต้องปิดกลับ
	gate.deactivate(s1)
	var s1_off_closed: bool = not gate.is_open and not gate.collision_shape.disabled

	# s1 เปิดอีกครั้ง -> เปิดใหม่
	gate.activate(s1)
	var reopened: bool = gate.is_open and gate.collision_shape.disabled

	container.free()

	return only_s1_closed and both_opened and s1_off_closed and reopened and open_events == [true, false, true]


func test_push_block_direction_mapping() -> bool:
	# ทดสอบแปลงทิศบนจอ 4 แนวแกน grid isometric diamond down
	var dr: Vector2i = PushBlock.direction_to_cell_step(Vector2(2.0, 1.0))
	var dl: Vector2i = PushBlock.direction_to_cell_step(Vector2(-2.0, 1.0))
	var ul: Vector2i = PushBlock.direction_to_cell_step(Vector2(-2.0, -1.0))
	var ur: Vector2i = PushBlock.direction_to_cell_step(Vector2(2.0, -1.0))

	return dr == Vector2i(1, 0) and dl == Vector2i(0, 1) and ul == Vector2i(-1, 0) and ur == Vector2i(0, -1)


func test_push_block_not_penetrate_wall() -> bool:
	var root: Window = Engine.get_main_loop().root

	# สร้างกำแพงบน world layer
	var wall := StaticBody2D.new()
	wall.collision_layer = Combat.LAYER_WORLD
	var wcol := CollisionShape2D.new()
	var wpoly := ConvexPolygonShape2D.new()
	wpoly.points = PackedVector2Array([
		Vector2(0, -16), Vector2(32, 0), Vector2(0, 16), Vector2(-32, 0)
	])
	wcol.shape = wpoly
	wall.add_child(wcol)

	# สร้าง PushBlock
	var block: PushBlock = BLOCK_SCENE.instantiate()
	block.setup()

	root.add_child(wall)
	root.add_child(block)

	var origin_pos := Vector2(100, 100)
	block.global_position = origin_pos
	# กำแพงอยู่ที่ตำแหน่ง cell (1, 0) ลง-ขวา: (100 + 32, 100 + 16)
	var wall_pos := origin_pos + Vector2(32, 16)
	wall.global_position = wall_pos

	var space: RID = root.get_world_2d().space
	PhysicsServer2D.body_set_space(wall.get_rid(), space)
	PhysicsServer2D.body_set_state(wall.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, wall.global_transform)
	PhysicsServer2D.body_set_space(block.get_rid(), space)
	PhysicsServer2D.body_set_state(block.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, block.global_transform)

	# ดันบล็อกไปทางกำแพง cell (1, 0) -> ต้องติด ไม่เลื่อน
	var pushed_into_wall: bool = block.try_push_step(Vector2i(1, 0))
	var pos_unchanged: bool = block.global_position == origin_pos

	# ดันบล็อกไปทางโล่ง cell (-1, 0) ขึ้น-ซ้าย -> ต้องเลื่อนสำเร็จ
	var pushed_into_empty: bool = block.try_push_step(Vector2i(-1, 0))
	var target_pos := origin_pos + Vector2(-32, -16)
	var pos_moved: bool = block.global_position == target_pos

	root.remove_child(wall)
	root.remove_child(block)
	wall.free()
	block.free()

	return not pushed_into_wall and pos_unchanged and pushed_into_empty and pos_moved


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

	lantern.free()
	return not_lit_by_enemy and lit_by_player and still_lit and extinguished_after_time


func test_kintsugi_crack_repair_shards() -> bool:
	GoldShards.reset()
	var crack: KintsugiCrack = CRACK_SCENE.instantiate()
	crack.cost = 3
	crack.setup()

	var repaired_events: Array[int] = []
	crack.repaired.connect(func() -> void: repaired_events.append(1))

	# เศษไม่พอ (มี 2 ต้องใช้ 3) -> ซ่อมไม่ผ่าน กำแพงยังกั้นอยู่
	GoldShards.count = 2
	var failed_repair: bool = not crack.try_repair()
	var still_cracked: bool = not crack.is_repaired and not crack.collision_shape.disabled

	# เศษพอ (เก็บเพิ่มอีก 2 เป็น 4) -> ซ่อมผ่าน หักเศษเหลือ 1 กำแพงเปิด
	GoldShards.add(2)
	var success_repair: bool = crack.try_repair()
	var now_repaired: bool = crack.is_repaired and crack.collision_shape.disabled and GoldShards.count == 1

	crack.free()
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

	shrine.rest()

	EventBus.player_respawn_requested.disconnect(respawn_cb)
	shrine.checkpoint_set.disconnect(cp_cb)

	var ok: bool = respawn_positions == [expected_spawn] \
		and checkpoint_positions == [expected_spawn] \
		and shrine.is_active \
		and shrine.point_light.enabled

	shrine.free()
	return ok
