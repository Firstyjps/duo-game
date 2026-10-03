extends SceneTree
## Physics Test Runner สำหรับระบบปริศนาและบล็อกดัน (issue #57)
## ใช้ physics จริงผ่าน physics_frame โดยไม่ hack body_set_space
## วิธีรัน: godot --headless --path game --script res://systems/dungeon/puzzles/debug/puzzle_physics_runner.gd

const BLOCK_SCENE: PackedScene = preload("res://systems/dungeon/puzzles/push_block.tscn")

func _initialize() -> void:
	var runner := PhysicsTestNode.new()
	root.add_child(runner)


class PhysicsTestNode extends Node:
	func _ready() -> void:
		call_deferred(&"run_all")

	func run_all() -> void:
		print("========================================")
		print("Running Puzzle Physics Real-World Tests")
		print("========================================")

		var passed: int = 0
		var failed: int = 0

		if await test_wall_collision_no_penetration():
			print("[PASS] test_wall_collision_no_penetration")
			passed += 1
		else:
			printerr("[FAIL] test_wall_collision_no_penetration")
			failed += 1

		if await test_keyboard_8_directions_and_grace():
			print("[PASS] test_keyboard_8_directions_and_grace")
			passed += 1
		else:
			printerr("[FAIL] test_keyboard_8_directions_and_grace")

		print("----------------------------------------")
		print("Physics Tests: %d passed, %d failed" % [passed, failed])
		print("========================================")

		get_tree().quit(0 if failed == 0 else 1)

	func test_wall_collision_no_penetration() -> bool:
		var wall := StaticBody2D.new()
		wall.name = "TestWall"
		wall.collision_layer = Combat.LAYER_WORLD
		var wcol := CollisionShape2D.new()
		var wpoly := ConvexPolygonShape2D.new()
		wpoly.points = PackedVector2Array([
			Vector2(0, -16), Vector2(32, 0), Vector2(0, 16), Vector2(-32, 0)
		])
		wcol.shape = wpoly
		wall.add_child(wcol)

		var block: PushBlock = BLOCK_SCENE.instantiate()
		block.setup()

		add_child(wall)
		add_child(block)

		var origin_pos := Vector2(200, 200)
		block.global_position = origin_pos
		var wall_pos := origin_pos + Vector2(32, 16)
		wall.global_position = wall_pos

		# รอ 2 physics frames ให้ physics server ซิงค์ shapes จริง
		await get_tree().physics_frame
		await get_tree().physics_frame

		# 1. ดันไปทางกำแพง cell (1, 0) ลง-ขวา -> ต้องติด ไม่เลื่อน
		var pushed_into_wall: bool = block.try_push_step(Vector2i(1, 0))
		var pos_unchanged: bool = block.global_position == origin_pos

		# 2. ดันไปทางว่าง cell (-1, 0) ขึ้น-ซ้าย -> เลื่อนสำเร็จ
		var pushed_into_empty: bool = block.try_push_step(Vector2i(-1, 0))
		var target_pos := origin_pos + Vector2(-32, -16)

		# รอจน tween เคลื่อนที่จบ
		while block.is_moving:
			await get_tree().physics_frame

		var pos_moved: bool = block.global_position.distance_to(target_pos) < 1.0

		remove_child(wall)
		remove_child(block)
		wall.free()
		block.free()

		return (not pushed_into_wall) and pos_unchanged and pushed_into_empty and pos_moved

	func test_keyboard_8_directions_and_grace() -> bool:
		var block: PushBlock = BLOCK_SCENE.instantiate()
		block.setup()
		add_child(block)

		var dummy := CharacterBody2D.new()
		dummy.name = "Player"
		dummy.add_to_group(&"player")
		dummy.collision_layer = Combat.LAYER_PLAYER
		var dcol := CollisionShape2D.new()
		var dpoly := CircleShape2D.new()
		dpoly.radius = 8.0
		dcol.shape = dpoly
		dummy.add_child(dcol)
		add_child(dummy)

		await get_tree().physics_frame
		await get_tree().physics_frame

		var origin_pos := Vector2(300, 300)

		# ทดสอบเวกเตอร์คีย์บอร์ด 8 ทิศ:
		# (direction_key, player_start_offset, keyboard_dir, expected_valid_steps)
		var cases: Array[Dictionary] = [
			{
				"name": "S+D (South-East)",
				"offset": Vector2(-16, -8),
				"dir": Vector2(1, 1).normalized(),
				"expected": [Vector2i(1, 0)] # down-right
			},
			{
				"name": "S+A (South-West)",
				"offset": Vector2(16, -8),
				"dir": Vector2(-1, 1).normalized(),
				"expected": [Vector2i(0, 1)] # down-left
			},
			{
				"name": "W+D (North-East)",
				"offset": Vector2(-16, 8),
				"dir": Vector2(1, -1).normalized(),
				"expected": [Vector2i(0, -1)] # up-right
			},
			{
				"name": "W+A (North-West)",
				"offset": Vector2(16, 8),
				"dir": Vector2(-1, -1).normalized(),
				"expected": [Vector2i(-1, 0)] # up-left
			},
			{
				"name": "S (Pure South from North)",
				"offset": Vector2(0, -14),
				"dir": Vector2(0, 1),
				"expected": [Vector2i(1, 0), Vector2i(0, 1)] # down-right or down-left
			},
			{
				"name": "W (Pure North from South)",
				"offset": Vector2(0, 14),
				"dir": Vector2(0, -1),
				"expected": [Vector2i(-1, 0), Vector2i(0, -1)] # up-left or up-right
			},
			{
				"name": "D (Pure East from West)",
				"offset": Vector2(-20, 0),
				"dir": Vector2(1, 0),
				"expected": [Vector2i(1, 0), Vector2i(0, -1)] # down-right or up-right
			},
			{
				"name": "A (Pure West from East)",
				"offset": Vector2(20, 0),
				"dir": Vector2(-1, 0),
				"expected": [Vector2i(-1, 0), Vector2i(0, 1)] # up-left or down-left
			},
		]

		var all_ok := true
		for tc: Dictionary in cases:
			block.global_position = origin_pos
			block.is_moving = false
			dummy.global_position = origin_pos + tc["offset"]
			block.set_pushing_player(dummy)

			var pushed_box: Array[Vector2i] = [Vector2i.ZERO]
			var on_pushed := func(step: Vector2) -> void:
				pushed_box[0] = Vector2i(step)
			block.pushed.connect(on_pushed)

			# ดันด้วยการเดินต่อเนื่อง 26 เฟรม (~0.41s > push_time 0.35s)
			var dt: float = 0.016
			for f: int in range(26):
				dummy.global_position += tc["dir"] * 25.0 * dt
				block.tick(dt)
				if pushed_box[0] != Vector2i.ZERO:
					break

			block.pushed.disconnect(on_pushed)

			var expected_arr: Array = tc["expected"]
			if not (pushed_box[0] in expected_arr):
				printerr("Keyboard direction case failed: %s expected one of %s got %s" % [tc["name"], expected_arr, pushed_box[0]])
				all_ok = false

		# ทดสอบ Grace timer 0.12s
		block.global_position = origin_pos
		block.is_moving = false
		dummy.global_position = origin_pos + Vector2(-16, -8)
		block.set_pushing_player(dummy)
		var pushed_with_grace: Array[bool] = [false]
		var grace_cb := func(_s: Vector2) -> void: pushed_with_grace[0] = true
		block.pushed.connect(grace_cb)

		var dt_grace: float = 0.016
		# เดิน 12 เฟรม (0.192s < 0.35s)
		for f: int in range(12):
			dummy.global_position += Vector2(1, 1).normalized() * 25.0 * dt_grace
			block.tick(dt_grace)

		# หยุดเดิน 4 เฟรม (0.064s < grace 0.12s)
		for f: int in range(4):
			block.tick(dt_grace)

		# เดินต่ออีก 14 เฟรม -> ต้องดันสำเร็จเพราะอยู่ในช่วง grace
		for f: int in range(14):
			dummy.global_position += Vector2(1, 1).normalized() * 25.0 * dt_grace
			block.tick(dt_grace)
			if pushed_with_grace[0]:
				break

		block.pushed.disconnect(grace_cb)

		if not pushed_with_grace[0]:
			printerr("Grace timer test failed: push did not trigger with grace")
			all_ok = false

		remove_child(dummy)
		remove_child(block)
		dummy.free()
		block.free()

		return all_ok
