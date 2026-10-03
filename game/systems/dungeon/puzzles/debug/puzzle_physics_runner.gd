extends SceneTree
## Physics Test Runner สำหรับระบบปริศนาและบล็อกดัน (issue #57)
## ใช้ physics จริงผ่าน physics_frame โดยใช้ res://systems/player/player.tscn จริง
## วิธีรัน: godot --headless --path game --script res://systems/dungeon/puzzles/debug/puzzle_physics_runner.gd

const BLOCK_SCENE: PackedScene = preload("res://systems/dungeon/puzzles/push_block.tscn")
var PLAYER_SCENE: PackedScene = null

func _initialize() -> void:
	PLAYER_SCENE = load("res://systems/player/player.tscn")
	var runner := PhysicsTestNode.new()
	runner.player_scene = PLAYER_SCENE
	root.add_child(runner)


class PhysicsTestNode extends Node2D:
	var passed: int = 0
	var failed: int = 0
	var player_scene: PackedScene = null

	func _ready() -> void:
		call_deferred(&"run_all")

	func run_all() -> void:
		print("========================================")
		print("Running Puzzle Physics Real-World Tests")
		print("========================================")

		await test_wall_collision_via_tick()
		await test_keyboard_8_directions_all_offsets()
		await test_keyboard_push_grace()
		await test_reset_to_kills_active_tween()

		print("----------------------------------------")
		print("Physics Tests: %d passed, %d failed" % [passed, failed])
		print("========================================")

		get_tree().quit(0 if failed == 0 else 1)

	func test_wall_collision_via_tick() -> void:
		var origin_pos := Vector2(200, 200)

		# สร้างกำแพงที่ cell (0, 1) -> down-left: Vector2(-32, 16) (ด้าน down-right ต้องว่างไว้ให้ผู้เล่นยืนดันไปทาง up-left)
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
		wall.global_position = origin_pos + Vector2(-32, 16)

		var block: PushBlock = BLOCK_SCENE.instantiate()
		block.setup()
		block.global_position = origin_pos

		var player = player_scene.instantiate()
		player.setup()
		player.manual_control = true

		add_child(wall)
		add_child(block)
		add_child(player)

		await get_tree().physics_frame
		await get_tree().physics_frame

		# 1. ผู้เล่นดันไปทางกำแพง cell (0, 1) ผ่าน S+A input intent
		var push_dir_wall := Vector2(-1, 1).normalized()
		player.global_position = origin_pos - push_dir_wall * 24.0
		player.velocity = Vector2.ZERO
		player.knock = Vector2.ZERO

		var pushed_step_wall: Array[Vector2i] = [Vector2i.ZERO]
		var cb_wall := func(step: Vector2) -> void:
			pushed_step_wall[0] = Vector2i(step)
		block.pushed.connect(cb_wall)

		# ปล่อยให้ physics เดินเอง 35 frames (~0.58s > push_time 0.35s)
		for f: int in range(35):
			player.set_intent(push_dir_wall, push_dir_wall, false, false)
			await get_tree().physics_frame

		block.pushed.disconnect(cb_wall)

		var wall_blocked := (pushed_step_wall[0] == Vector2i.ZERO) \
			and (block.global_position == origin_pos) \
			and (not block.is_moving)

		# 2. ผู้เล่นดันไปทางว่าง cell (-1, 0) ผ่าน W+A input intent
		var push_dir_empty := Vector2(-1, -1).normalized()
		player.global_position = origin_pos - push_dir_empty * 24.0
		player.velocity = Vector2.ZERO
		player.knock = Vector2.ZERO

		await get_tree().physics_frame
		await get_tree().physics_frame

		var pushed_step_empty: Array[Vector2i] = [Vector2i.ZERO]
		var cb_empty := func(step: Vector2) -> void:
			pushed_step_empty[0] = Vector2i(step)
		block.pushed.connect(cb_empty)

		for f: int in range(40):
			player.set_intent(push_dir_empty, push_dir_empty, false, false)
			await get_tree().physics_frame
			if pushed_step_empty[0] != Vector2i.ZERO:
				break

		block.pushed.disconnect(cb_empty)

		# รอจน tween ย้ายเสร็จ
		while block.is_moving:
			player.set_intent(Vector2.ZERO, Vector2.ZERO, false, false)
			await get_tree().physics_frame

		var target_empty_pos := origin_pos + Vector2(-32, -16)
		var empty_moved := (pushed_step_empty[0] == Vector2i(-1, 0)) \
			and (block.global_position.distance_to(target_empty_pos) < 1.0)

		remove_child(wall)
		remove_child(block)
		remove_child(player)
		wall.free()
		block.free()
		player.free()

		if wall_blocked and empty_moved:
			print("[PASS] test_wall_collision_via_tick")
			passed += 1
		else:
			printerr("[FAIL] test_wall_collision_via_tick (wall_blocked=%s, empty_moved=%s)" % [wall_blocked, empty_moved])
			failed += 1

	func test_keyboard_8_directions_all_offsets() -> void:
		var origin_pos := Vector2(300, 300)

		var block: PushBlock = BLOCK_SCENE.instantiate()
		block.setup()
		block.global_position = origin_pos

		var player = player_scene.instantiate()
		player.setup()
		player.manual_control = true

		add_child(block)
		add_child(player)

		await get_tree().physics_frame
		await get_tree().physics_frame

		var cases: Array[Dictionary] = [
			{
				"name": "S (Pure South)",
				"dir": Vector2(0, 1),
				"base": Vector2(0, -26),
				"perp": Vector2(1, 0),
				"expected": [Vector2i(1, 0), Vector2i(0, 1)]
			},
			{
				"name": "N (Pure North)",
				"dir": Vector2(0, -1),
				"base": Vector2(0, 26),
				"perp": Vector2(1, 0),
				"expected": [Vector2i(-1, 0), Vector2i(0, -1)]
			},
			{
				"name": "E (Pure East)",
				"dir": Vector2(1, 0),
				"base": Vector2(-38, 0),
				"perp": Vector2(0, 1),
				"expected": [Vector2i(1, 0), Vector2i(0, -1)]
			},
			{
				"name": "W (Pure West)",
				"dir": Vector2(-1, 0),
				"base": Vector2(38, 0),
				"perp": Vector2(0, 1),
				"expected": [Vector2i(-1, 0), Vector2i(0, 1)]
			},
			{
				"name": "S+D (South-East)",
				"dir": Vector2(1, 1).normalized(),
				"base": -Vector2(1, 1).normalized() * 24.0,
				"perp": Vector2(-1, 1).normalized(),
				"expected": [Vector2i(1, 0)]
			},
			{
				"name": "S+A (South-West)",
				"dir": Vector2(-1, 1).normalized(),
				"base": -Vector2(-1, 1).normalized() * 24.0,
				"perp": Vector2(1, 1).normalized(),
				"expected": [Vector2i(0, 1)]
			},
			{
				"name": "W+D (North-East)",
				"dir": Vector2(1, -1).normalized(),
				"base": -Vector2(1, -1).normalized() * 24.0,
				"perp": Vector2(1, 1).normalized(),
				"expected": [Vector2i(0, -1)]
			},
			{
				"name": "W+A (North-West)",
				"dir": Vector2(-1, -1).normalized(),
				"base": -Vector2(-1, -1).normalized() * 24.0,
				"perp": Vector2(-1, 1).normalized(),
				"expected": [Vector2i(-1, 0)]
			},
		]

		var offsets: Array[float] = [0.0, 6.0, -6.0, 12.0, -12.0]

		for tc in cases:
			var dir_name: String = tc["name"]
			var dir: Vector2 = tc["dir"]
			var base_vec: Vector2 = tc["base"]
			var perp_vec: Vector2 = tc["perp"]
			var expected_arr: Array = tc["expected"]
			var dir_all_ok := true

			for offset_val in offsets:
				block.reset_to(origin_pos)
				var start_pos := origin_pos + base_vec + perp_vec * offset_val
				player.global_position = start_pos
				player.velocity = Vector2.ZERO
				player.knock = Vector2.ZERO
				player.set_intent(Vector2.ZERO, Vector2.ZERO, false, false)

				await get_tree().physics_frame
				await get_tree().physics_frame

				var pushed_step: Array[Vector2i] = [Vector2i.ZERO]
				var on_pushed := func(step: Vector2) -> void:
					pushed_step[0] = Vector2i(step)
				block.pushed.connect(on_pushed)

				# ป้อน set_intent และปล่อย physics เดินเอง (await physics_frame)
				for f: int in range(50):
					player.set_intent(dir, dir, false, false)
					await get_tree().physics_frame
					if pushed_step[0] != Vector2i.ZERO:
						break


				block.pushed.disconnect(on_pushed)

				if not (pushed_step[0] in expected_arr):
					printerr("[FAIL] %s offset %+.0f px: expected one of %s, got %s" % [dir_name, offset_val, expected_arr, pushed_step[0]])
					dir_all_ok = false

			if dir_all_ok:
				print("[PASS] test_keyboard_push_%s (offsets 0, ±6, ±12 px)" % dir_name)
				passed += 1
			else:
				failed += 1

		remove_child(block)
		remove_child(player)
		block.free()
		player.free()

	func test_keyboard_push_grace() -> void:
		var origin_pos := Vector2(300, 300)

		var block: PushBlock = BLOCK_SCENE.instantiate()
		block.setup()
		block.global_position = origin_pos

		var player = player_scene.instantiate()
		player.setup()
		player.manual_control = true

		add_child(block)
		add_child(player)

		var dir := Vector2(1, 1).normalized()
		player.global_position = origin_pos - dir * 24.0
		player.velocity = Vector2.ZERO
		player.knock = Vector2.ZERO

		await get_tree().physics_frame
		await get_tree().physics_frame

		var pushed_with_grace: Array[bool] = [false]
		var cb := func(_s: Vector2) -> void: pushed_with_grace[0] = true
		block.pushed.connect(cb)

		# 1. เดินเข้าชน 14 เฟรม (~0.23s < 0.35s)
		for f in range(14):
			player.set_intent(dir, dir, false, false)
			await get_tree().physics_frame

		# 2. หยุดเดิน 4 เฟรม (~0.067s < grace 0.12s)
		for f in range(4):
			player.set_intent(Vector2.ZERO, Vector2.ZERO, false, false)
			await get_tree().physics_frame

		# 3. เดินต่ออีก 18 เฟรม -> ต้องดันสำเร็จเพราะ grace timer ไม่ reset push timer
		for f in range(18):
			player.set_intent(dir, dir, false, false)
			await get_tree().physics_frame
			if pushed_with_grace[0]:
				break

		block.pushed.disconnect(cb)

		remove_child(block)
		remove_child(player)
		block.free()
		player.free()

		if pushed_with_grace[0]:
			print("[PASS] test_keyboard_push_grace")
			passed += 1
		else:
			printerr("[FAIL] test_keyboard_push_grace: push did not trigger with grace")
			failed += 1

	func test_reset_to_kills_active_tween() -> void:
		var origin_pos := Vector2(300, 300)

		var block: PushBlock = BLOCK_SCENE.instantiate()
		block.setup()
		block.global_position = origin_pos
		add_child(block)

		await get_tree().physics_frame
		await get_tree().physics_frame

		# เริ่มเลื่อนบล็อกด้วย try_push_step
		var pushed: bool = block.try_push_step(Vector2i(-1, 0))
		await get_tree().physics_frame

		var was_moving: bool = block.is_moving
		var tween_alive: bool = block._move_tween != null and block._move_tween.is_valid()

		# สั่ง reset_to ทันที
		block.reset_to(origin_pos)

		var tween_dead: bool = block._move_tween == null or not block._move_tween.is_valid()
		var stopped: bool = not block.is_moving
		var pos_ok: bool = block.global_position == origin_pos

		remove_child(block)
		block.free()

		if pushed and was_moving and tween_alive and tween_dead and stopped and pos_ok:
			print("[PASS] test_reset_to_kills_active_tween")
			passed += 1
		else:
			printerr("[FAIL] test_reset_to_kills_active_tween (pushed=%s, was_moving=%s, tween_alive=%s, tween_dead=%s, stopped=%s, pos_ok=%s)" % [pushed, was_moving, tween_alive, tween_dead, stopped, pos_ok])
			failed += 1
