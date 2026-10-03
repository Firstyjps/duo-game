extends SceneTree
## Physics Test Runner สำหรับบอสสไลม์ (Boss Slime Physics Runner)
## รัน: godot --headless --path game --script res://tests/run_boss_slime_physics.gd

const LAYER_WORLD: int = 1 << 0
const LAYER_HURTBOX: int = 1 << 3

var _passed: int = 0
var _failed: int = 0
var boss_scene: PackedScene
var slime_scene: PackedScene


func _initialize() -> void:
	boss_scene = load("res://systems/enemy/boss_slime/boss_slime.tscn")
	slime_scene = load("res://systems/enemy/slime/slime.tscn")

	print("========================================")
	print("Running Boss Slime Real Physics Tests...")
	print("========================================")

	await _test_leap_blocked_by_wall()
	await _test_leap_unblocked_by_minion_slime()
	await _test_aoe_physics_8_directions_with_player_hurtbox()
	await _test_spawn_minions_in_non_origin_room()

	print("========================================")
	print("Physics tests finished: %d passed, %d failed" % [_passed, _failed])
	print("========================================")

	quit(1 if _failed > 0 else 0)


func _assert_test(cond: bool, test_name: String, details: String = "") -> void:
	if cond:
		_passed += 1
		print("  [PASS] %s" % test_name)
	else:
		_failed += 1
		printerr("  [FAIL] %s - %s" % [test_name, details])


## 1. มีกำแพงขวาง -> shape-cast ตัด _leap_to ลงหน้ากำแพงตรง marker
func _test_leap_blocked_by_wall() -> void:
	print("\nTest 1: Leap blocked by wall")

	var wall := StaticBody2D.new()
	wall.collision_layer = LAYER_WORLD
	wall.position = Vector2(80, 0)
	var wall_col := CollisionShape2D.new()
	var wall_rect := RectangleShape2D.new()
	wall_rect.size = Vector2(20, 200)
	wall_col.shape = wall_rect
	wall.add_child(wall_col)
	root.add_child(wall)

	var boss: CharacterBody2D = boss_scene.instantiate()
	boss.position = Vector2(0, 0)
	root.add_child(boss)

	var target := Node2D.new()
	target.position = Vector2(140, 0)
	root.add_child(target)
	boss.set_target(target)

	# รอ physics frame 2 เฟรมให้ broadphase ของ wall อัปเดต
	await process_frame
	await process_frame

	boss._enter(boss.State.LEAP_WINDUP)

	# _leap_to ต้องถูกตัดให้หยุดหน้ากำแพง (กำแพงขอบซ้ายอยู่ที่ 80 - 10 = 70, รัศมีบอส 16 -> จุดตก <= 70 - 16 = 54)
	var truncated_ok: bool = boss._leap_to.x < 70.0 and boss._leap_to.x > 30.0
	var marker_at_target_ok: bool = boss.telegraph_marker.global_position.is_equal_approx(boss._leap_to)
	_assert_test(truncated_ok, "Leap destination truncated before wall", "leap_to=%s" % str(boss._leap_to))
	_assert_test(marker_at_target_ok, "Marker shown at truncated destination")

	# เข้าสู่ LEAP_AIRBORNE และเคลื่อนที่จนถึงเวลาตก
	var total_dur: float = boss.leap_windup_time * boss.get_speed_multiplier()
	boss.tick(total_dur + 0.01)
	_assert_test(boss.state == boss.State.LEAP_AIRBORNE and boss.telegraph_marker.visible, "Marker visible while airborne")

	# จำลอง physics_process ระหว่างลอย
	var air_time: float = boss.leap_air_time * boss.get_speed_multiplier()
	var step: float = 0.02
	var elapsed: float = 0.0
	while elapsed < air_time:
		boss._physics_process(step)
		elapsed += step

	var landed_at_marker_ok: bool = boss.global_position.distance_to(boss._leap_to) < 0.5
	var velocity_zero_ok: bool = boss.velocity == Vector2.ZERO
	var in_front_of_wall: bool = boss.global_position.x < 70.0
	_assert_test(landed_at_marker_ok and in_front_of_wall, "Boss landed in front of wall exactly at marker", "pos=%s, leap_to=%s" % [str(boss.global_position), str(boss._leap_to)])
	_assert_test(velocity_zero_ok, "Velocity reset to ZERO on impact")

	wall.queue_free()
	target.queue_free()
	boss.queue_free()
	await process_frame


## 1. มีลูกสไลม์ขวาง -> ไม่ชนลูกสไลม์ ยังลงตรง marker
func _test_leap_unblocked_by_minion_slime() -> void:
	print("\nTest 2: Leap over minion slime")

	var minion: CharacterBody2D = slime_scene.instantiate()
	minion.position = Vector2(70, 0)
	root.add_child(minion)

	var boss: CharacterBody2D = boss_scene.instantiate()
	boss.position = Vector2(0, 0)
	root.add_child(boss)

	var target := Node2D.new()
	target.position = Vector2(140, 0)
	root.add_child(target)
	boss.set_target(target)

	await process_frame
	await process_frame

	boss._enter(boss.State.LEAP_WINDUP)

	# ลูกสไลม์อยู่บน layer enemy (ไม่ใช่ layer world) -> _leap_to ต้องไม่ถูกตัด
	var expected_pos: Vector2 = boss.leap_target(boss.position, target.position, boss.leap_distance)
	var not_blocked_ok: bool = boss._leap_to.is_equal_approx(expected_pos)
	_assert_test(not_blocked_ok, "Leap not blocked by enemy minion during windup", "leap_to=%s" % str(boss._leap_to))

	# ลอยข้ามลูกสไลม์โดยไม่ชน
	var total_dur: float = boss.leap_windup_time * boss.get_speed_multiplier()
	boss.tick(total_dur + 0.01)

	var air_time: float = boss.leap_air_time * boss.get_speed_multiplier()
	var step: float = 0.02
	var elapsed: float = 0.0
	while elapsed < air_time:
		boss._physics_process(step)
		elapsed += step

	var landed_exact: bool = boss.global_position.distance_to(boss._leap_to) < 0.5
	_assert_test(landed_exact, "Boss flew straight over minion and landed on marker", "pos=%s" % str(boss.global_position))

	minion.queue_free()
	target.queue_free()
	boss.queue_free()
	await process_frame


## 3. AoE วงรี 8 ทิศ physics จริงด้วย Hurtbox แบบ player.tscn (r13 @ (0, -22)): 0.85x โดน, 1.15x ไม่โดน
func _test_aoe_physics_8_directions_with_player_hurtbox() -> void:
	print("\nTest 3: Real physics AoE 8 directions with Player Hurtbox (r13 @ (0,-22))")

	var boss: CharacterBody2D = boss_scene.instantiate()
	boss.position = Vector2(300, 300)
	root.add_child(boss)

	var angles: Array[float] = [0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0]
	var in_hurtboxes: Array[Area2D] = []
	var out_hurtboxes: Array[Area2D] = []

	var r: float = boss.slam_radius
	var sq: float = boss.squash

	for a: float in angles:
		var rad: float = deg_to_rad(a)
		var pt_boundary: Vector2 = boss.position + Vector2(cos(rad) * r, sin(rad) * r * sq)
		var pt_in: Vector2 = boss.position + (pt_boundary - boss.position) * 0.85
		var pt_out: Vector2 = boss.position + (pt_boundary - boss.position) * 1.15

		# Hurtbox ผู้เล่น: Area2D วางที่ตำแหน่งเท้า CollisionShape2D รัศมี 13 ที่ (0, -22)
		var h_in := Area2D.new()
		h_in.name = "HurtIn_%d" % int(a)
		h_in.collision_layer = LAYER_HURTBOX
		h_in.collision_mask = 0
		h_in.position = pt_in
		var col_in := CollisionShape2D.new()
		var c_in := CircleShape2D.new()
		c_in.radius = 13.0
		col_in.shape = c_in
		col_in.position = Vector2(0, -22)
		h_in.add_child(col_in)
		root.add_child(h_in)
		in_hurtboxes.append(h_in)

		var h_out := Area2D.new()
		h_out.name = "HurtOut_%d" % int(a)
		h_out.collision_layer = LAYER_HURTBOX
		h_out.collision_mask = 0
		h_out.position = pt_out
		var col_out := CollisionShape2D.new()
		var c_out := CircleShape2D.new()
		c_out.radius = 13.0
		col_out.shape = c_out
		col_out.position = Vector2(0, -22)
		h_out.add_child(col_out)
		root.add_child(h_out)
		out_hurtboxes.append(h_out)

	boss.set_physics_process(false)  # ไม่ให้หมดช่วง slam_active_time ก่อนตรวจ
	boss._enter(boss.State.SLAM_ACTIVE)

	# รอ physics step จริงหลาย step (Hitbox.activate ใช้ set_deferred)
	for _i: int in 4:
		await physics_frame

	var overlapping: Array[Area2D] = boss.hitbox.get_overlapping_areas()
	var in_hits: int = 0
	var out_hits: int = 0

	for h: Area2D in in_hurtboxes:
		if overlapping.has(h):
			in_hits += 1

	for h: Area2D in out_hurtboxes:
		if overlapping.has(h):
			out_hits += 1

	_assert_test(in_hits == 8, "All 8 inner hurtboxes (0.85x) hit by physics AoE", "got %d/8" % in_hits)
	_assert_test(out_hits == 0, "All 8 outer hurtboxes (1.15x) missed by physics AoE", "got %d/8 hit" % out_hits)

	for h: Area2D in in_hurtboxes:
		h.queue_free()
	for h: Area2D in out_hurtboxes:
		h.queue_free()
	boss.queue_free()
	await process_frame


## 2. แตกลูกในห้องที่ไม่อยู่ origin
func _test_spawn_minions_in_non_origin_room() -> void:
	print("\nTest 4: Minions spawn in non-origin room")

	var room := Node2D.new()
	room.position = Vector2(600, 400)
	root.add_child(room)

	var boss: CharacterBody2D = boss_scene.instantiate()
	boss.position = Vector2(80, 80) # global = (680, 480)
	room.add_child(boss)

	var dummy := Node2D.new()
	dummy.position = Vector2(680, 400)
	root.add_child(dummy)
	boss.set_target(dummy)

	boss.health.take_damage(100) # เข้า Phase 2
	boss._spawn_minions()

	await process_frame
	await process_frame

	var spawned_count: int = boss.get_alive_minions_count()
	var count_ok: bool = spawned_count >= 2 and spawned_count <= 3
	var positions_ok: bool = true
	var parent_ok: bool = true

	for m: Node in boss._minions:
		if is_instance_valid(m) and m is Node2D:
			if m.get_parent() != room:
				parent_ok = false
			var dist: float = (m as Node2D).global_position.distance_to(boss.global_position)
			if dist < 18.0 or dist > 70.0:
				positions_ok = false

	_assert_test(count_ok, "Spawned 2-3 minions in Phase 2", "got %d" % spawned_count)
	_assert_test(parent_ok, "Minions parented to room (not root)")
	_assert_test(positions_ok, "Minions positioned in world space around boss, not offset by room")

	for m: Node in boss._minions:
		if is_instance_valid(m):
			m.queue_free()
	boss._minions.clear()
	dummy.queue_free()
	boss.queue_free()
	room.queue_free()
	await process_frame
