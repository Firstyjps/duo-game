extends RefCounted
## เทสต์ระบบกล้อง — game/systems/camera/ · Issue #24
## รันผ่าน godot --headless --path game --script res://tests/run_tests.gd


func test_trauma_decay_to_zero() -> bool:
	# 1. ทดสอบ static decay_trauma
	var t1: float = GameCamera.decay_trauma(1.0, 2.0, 0.3) # 1.0 - 0.6 = 0.4
	var t2: float = GameCamera.decay_trauma(0.4, 2.0, 0.3) # 0.4 - 0.6 -> clamp 0.0
	var t_zero_delta: float = GameCamera.decay_trauma(0.5, 2.0, 0.0) # 0.5
	var static_ok: bool = is_equal_approx(t1, 0.4) and is_equal_approx(t2, 0.0) and is_equal_approx(t_zero_delta, 0.5)

	# 2. ทดสอบ instance GameCamera ผ่าน tick()
	var cam := GameCamera.new()
	cam.setup()
	cam.trauma_decay = 2.0
	cam.add_trauma(0.8)
	cam.tick(0.2) # เหลือ 0.4
	var mid_ok: bool = is_equal_approx(cam.trauma, 0.4)
	cam.tick(0.3) # 0.4 - 0.6 -> 0.0
	var final_ok: bool = is_equal_approx(cam.trauma, 0.0) and cam.offset == Vector2.ZERO
	cam.free()

	return static_ok and mid_ok and final_ok


func test_clamp_to_bounds() -> bool:
	var rect := Rect2(10, 20, 100, 200) # x: 10..110, y: 20..220

	# 1. ทดสอบ static clamp_to_bounds
	var inside: Vector2 = GameCamera.clamp_to_bounds(Vector2(50, 100), rect)
	var out_min: Vector2 = GameCamera.clamp_to_bounds(Vector2(-50, -100), rect)
	var out_max: Vector2 = GameCamera.clamp_to_bounds(Vector2(999, 999), rect)
	var empty_rect: Vector2 = GameCamera.clamp_to_bounds(Vector2(500, 600), Rect2())
	var static_ok: bool = inside == Vector2(50, 100) \
		and out_min == Vector2(10, 20) \
		and out_max == Vector2(110, 220) \
		and empty_rect == Vector2(500, 600)

	# 2. ทดสอบ instance GameCamera follow และ set_bounds
	var cam := GameCamera.new()
	cam.setup()
	cam.set_bounds(rect)
	var dummy := Node2D.new()
	dummy.position = Vector2(999, 999)
	cam.follow(dummy, true)
	var clamped_high: bool = cam.position == Vector2(110, 220)

	dummy.position = Vector2(-200, -200)
	cam.follow(dummy, true)
	var clamped_low: bool = cam.position == Vector2(10, 20)

	cam.set_bounds(Rect2()) # เคลียร์ bounds
	cam.follow(dummy, true)
	var unclamped: bool = cam.position == Vector2(-200, -200)

	dummy.free()
	cam.free()

	return static_ok and clamped_high and clamped_low and unclamped


func test_hitstop_stacking_and_restore_time_scale() -> bool:
	GameCamera.reset_hitstop()
	var initial_ok: bool = is_equal_approx(Engine.time_scale, 1.0)

	# เรียก hitstop ครั้งที่ 1
	var t1: SceneTreeTimer = GameCamera.hitstop(10.0)
	var scale_during_first: float = Engine.time_scale

	# เรียก hitstop ครั้งที่ 2 ซ้อนกัน
	var t2: SceneTreeTimer = GameCamera.hitstop(10.0)
	var scale_during_second: float = Engine.time_scale

	# ปล่อยให้ timer 1 หมดเวลา (emit timeout) -> time_scale ต้องยังไม่คืน 1.0 เพราะ timer 2 ยังทำงานอยู่
	t1.timeout.emit()
	var scale_after_first_timeout: float = Engine.time_scale

	# ปล่อยให้ timer 2 หมดเวลา -> time_scale ต้องคืนเป็น 1.0
	t2.timeout.emit()
	var scale_after_all_timeouts: float = Engine.time_scale

	GameCamera.reset_hitstop()

	return initial_ok \
		and scale_during_first < 1.0 \
		and scale_during_second < 1.0 \
		and scale_after_first_timeout < 1.0 \
		and is_equal_approx(scale_after_all_timeouts, 1.0)


func test_shake_offset_calculation() -> bool:
	var max_offset := Vector2(20.0, 10.0)
	var roll := Vector2(1.0, 1.0)

	# trauma = 0 -> offset = ZERO
	var zero_offset: Vector2 = GameCamera.calculate_shake_offset(0.0, max_offset, roll)

	# trauma = 0.5 -> trauma² = 0.25 -> offset = max_offset * 0.25
	var half_offset: Vector2 = GameCamera.calculate_shake_offset(0.5, max_offset, roll)

	# trauma = 1.0 -> trauma² = 1.0 -> offset = max_offset
	var full_offset: Vector2 = GameCamera.calculate_shake_offset(1.0, max_offset, roll)

	# trauma > 1.0 ถูก clamp ที่ 1.0
	var over_offset: Vector2 = GameCamera.calculate_shake_offset(1.5, max_offset, roll)

	# trauma < 0.0 ถูก clamp ที่ 0.0
	var neg_offset: Vector2 = GameCamera.calculate_shake_offset(-0.5, max_offset, roll)

	return zero_offset == Vector2.ZERO \
		and half_offset.is_equal_approx(Vector2(5.0, 2.5)) \
		and full_offset.is_equal_approx(Vector2(20.0, 10.0)) \
		and over_offset.is_equal_approx(Vector2(20.0, 10.0)) \
		and neg_offset == Vector2.ZERO


func test_event_bus_damage_dealt_player_vs_other() -> bool:
	var cam := GameCamera.new()
	cam.setup()
	cam.trauma_on_player_hit = 0.6
	cam.trauma_on_other_hit = 0.2

	var player_node := Node2D.new()
	player_node.add_to_group(&"player")

	var enemy_node := Node2D.new()
	enemy_node.add_to_group(&"enemy")

	# โดนตีที่ศัตรู
	cam.trauma = 0.0
	EventBus.damage_dealt.emit(enemy_node, null, 10)
	var enemy_trauma: float = cam.trauma

	# โดนตีที่ตัวผู้เล่น (ต้องสั่นแรงกว่า)
	cam.trauma = 0.0
	EventBus.damage_dealt.emit(player_node, null, 10)
	var player_trauma: float = cam.trauma

	player_node.free()
	enemy_node.free()
	cam.free()
	GameCamera.reset_hitstop()

	return is_equal_approx(enemy_trauma, 0.2) \
		and is_equal_approx(player_trauma, 0.6) \
		and player_trauma > enemy_trauma


func test_smooth_follow_and_pixel_rounding() -> bool:
	var cam := GameCamera.new()
	cam.setup()
	cam.follow_smooth_speed = 10.0

	var target := Node2D.new()
	target.position = Vector2(100.4, 200.7)
	cam.follow(target)

	# ก้าวแรก: ขยับตามแบบนุ่มนวล
	cam.tick(0.05)
	var intermediate_pos: Vector2 = cam.position
	var is_rounded_1: bool = intermediate_pos.x == roundf(intermediate_pos.x) \
		and intermediate_pos.y == roundf(intermediate_pos.y)
	var moved: bool = intermediate_pos.x > 0.0 and intermediate_pos.y > 0.0

	# ปล่อยให้ตามจนสุด
	cam.tick(3.0)
	var final_pos: Vector2 = cam.position
	var reached_rounded: bool = final_pos == Vector2(100, 201)

	target.free()
	cam.free()

	return is_rounded_1 and moved and reached_rounded


func test_exit_tree_resets_hitstop() -> bool:
	var cam := GameCamera.new()
	cam.setup()

	GameCamera.hitstop(10.0)
	var during_hitstop: bool = Engine.time_scale < 1.0

	# จำลองออกจาก scene tree
	cam._exit_tree()
	var restored: bool = is_equal_approx(Engine.time_scale, 1.0)

	cam.free()
	return during_hitstop and restored
