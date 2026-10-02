extends RefCounted
## เทสต์กล้อง iso และ silhouette — game/systems/camera/ และ game/systems/player/occlusion/ · Issue #41
## รันผ่าน godot --headless --path game --script res://tests/run_tests.gd


func test_slide_to_ends_at_rect_and_pixel_rounded() -> bool:
	var cam := GameCamera.new()
	cam.setup()
	cam.position = Vector2(480.2, 270.8)

	var target_rect := Rect2(960, 0, 960, 540) # Center = Vector2(1440, 270)
	var duration: float = 0.5
	cam.slide_to(target_rect, duration)

	var start_sliding: bool = cam.is_sliding()

	# ก้าวที่ 1: เลื่อนไปครึ่งทาง
	cam.tick(0.25)
	var mid_pos: Vector2 = cam.position
	var mid_sliding: bool = cam.is_sliding()
	var mid_rounded: bool = mid_pos.x == roundf(mid_pos.x) and mid_pos.y == roundf(mid_pos.y)
	var moved_toward_dest: bool = mid_pos.x > 480.0 and mid_pos.x < 1440.0

	# ก้าวที่ 2: เลื่อนจนครบเวลา
	cam.tick(0.3)
	var final_pos: Vector2 = cam.position
	var finished_sliding: bool = not cam.is_sliding()
	var rect_correct: bool = cam.bounds == target_rect
	var target_reached: bool = final_pos == Vector2(1440, 270)
	var final_rounded: bool = final_pos.x == roundf(final_pos.x) and final_pos.y == roundf(final_pos.y)

	cam.free()

	return start_sliding \
		and mid_sliding \
		and mid_rounded \
		and moved_toward_dest \
		and finished_sliding \
		and rect_correct \
		and target_reached \
		and final_rounded


func test_slide_instant_zero_duration() -> bool:
	var cam := GameCamera.new()
	cam.setup()
	cam.position = Vector2(100.2, 100.8)

	var target_rect := Rect2(800, 400, 600, 400) # Center = (1100, 600)
	cam.slide_to(target_rect, 0.0)

	var not_sliding: bool = not cam.is_sliding()
	var bounds_ok: bool = cam.bounds == target_rect
	var pos_ok: bool = cam.position == Vector2(1100, 600)

	cam.free()
	return not_sliding and bounds_ok and pos_ok


func test_slide_static_interpolation() -> bool:
	var start := Vector2(100, 100)
	var dest := Vector2(300, 500)

	var at_0: Vector2 = GameCamera.compute_slide_position(start, dest, 0.0)
	var at_1: Vector2 = GameCamera.compute_slide_position(start, dest, 1.0)
	var at_mid: Vector2 = GameCamera.compute_slide_position(start, dest, 0.5)
	var at_neg: Vector2 = GameCamera.compute_slide_position(start, dest, -0.5)
	var at_over: Vector2 = GameCamera.compute_slide_position(start, dest, 1.5)

	var ok_0: bool = at_0 == start
	var ok_1: bool = at_1 == dest
	var ok_mid: bool = at_mid.is_equal_approx(Vector2(200, 300)) # smoothstep(0.5) = 0.5
	var ok_neg: bool = at_neg == start
	var ok_over: bool = at_over == dest

	return ok_0 and ok_1 and ok_mid and ok_neg and ok_over


func test_focus_offset_clamping_and_framing() -> bool:
	# 1. ทดสอบ static compute_focus_offset และ compute_focus_point
	var player_pos := Vector2(100, 100)
	var target_near := Vector2(200, 100) # diff = (100, 0)
	var target_far := Vector2(1000, 100) # diff = (900, 0)
	var weight: float = 0.35
	var max_offset: float = 64.0

	# ใกล้: offset = 100 * 0.35 = 35 <= 64 -> ไม่ถูก clamp
	var offset_near: Vector2 = GameCamera.compute_focus_offset(player_pos, target_near, weight, max_offset)
	var point_near: Vector2 = GameCamera.compute_focus_point(player_pos, target_near, weight, max_offset)
	var near_ok: bool = offset_near.is_equal_approx(Vector2(35, 0)) and point_near.is_equal_approx(Vector2(135, 100))

	# ไกล: offset = 900 * 0.35 = 315 > 64 -> ถูก clamp เหลือ 64 พอดี
	var offset_far: Vector2 = GameCamera.compute_focus_offset(player_pos, target_far, weight, max_offset)
	var point_far: Vector2 = GameCamera.compute_focus_point(player_pos, target_far, weight, max_offset)
	var far_ok: bool = offset_far.is_equal_approx(Vector2(64, 0)) and point_far.is_equal_approx(Vector2(164, 100))

	# 2. ทดสอบ instance GameCamera กับ set_focus_target
	var cam := GameCamera.new()
	cam.setup()
	cam.follow_smooth_speed = 10.0
	cam.focus_weight = 0.35
	cam.max_focus_offset = 64.0

	var player_node := Node2D.new()
	player_node.position = player_pos
	var target_node := Node2D.new()
	target_node.position = target_far

	cam.follow(player_node, true)
	var initial_cam_pos: Vector2 = cam.position
	var initial_at_player: bool = initial_cam_pos == player_pos

	# ตั้ง focus target -> กล้องต้อง lerp ไปยังจุดที่ clamp แล้ว (164, 100)
	cam.set_focus_target(target_node)
	cam.tick(3.0)
	var framed_pos: Vector2 = cam.position
	var framed_correct: bool = framed_pos == Vector2(164, 100)
	var framed_rounded: bool = framed_pos.x == roundf(framed_pos.x) and framed_pos.y == roundf(framed_pos.y)

	# เลิก focus target (ส่ง null) -> กล้องต้องกลับไปตาม player (100, 100)
	cam.set_focus_target(null)
	cam.tick(3.0)
	var restored_pos: Vector2 = cam.position
	var restored_correct: bool = restored_pos == player_pos

	player_node.free()
	target_node.free()
	cam.free()

	return near_ok and far_ok and initial_at_player and framed_correct and framed_rounded and restored_correct


func test_occlusion_decision_front_vs_back() -> bool:
	var feet_y: float = 200.0
	var sprite_rect := Rect2(90, 150, 20, 50) # x: 90..110, y: 150..200
	var overlapping_wall_rect := Rect2(80, 160, 40, 60) # overlaps sprite_rect
	var separate_wall_rect := Rect2(300, 160, 40, 60) # doesn't overlap sprite_rect

	# กรณี 1: วัตถุอยู่ข้างหน้า (occluder_y = 220 > 200) และทับสไปรต์ -> บัง (true)
	var case1_front_overlap: bool = OcclusionSilhouette.is_occluding(feet_y, 220.0, sprite_rect, overlapping_wall_rect)

	# กรณี 2: วัตถุอยู่ข้างหลัง (occluder_y = 180 <= 200) แม้ทับสไปรต์ -> ไม่บัง (false)
	var case2_back_overlap: bool = OcclusionSilhouette.is_occluding(feet_y, 180.0, sprite_rect, overlapping_wall_rect)

	# กรณี 3: วัตถุอยู่ข้างหน้า (occluder_y = 220 > 200) แต่ไม่ทับสไปรต์ -> ไม่บัง (false)
	var case3_front_no_overlap: bool = OcclusionSilhouette.is_occluding(feet_y, 220.0, sprite_rect, separate_wall_rect)

	# กรณี 4: วัตถุอยู่ข้างหลัง (occluder_y = 180 <= 200) และไม่ทับสไปรต์ -> ไม่บัง (false)
	var case4_back_no_overlap: bool = OcclusionSilhouette.is_occluding(feet_y, 180.0, sprite_rect, separate_wall_rect)

	# ทดสอบ is_in_front
	var in_front_ok: bool = OcclusionSilhouette.is_in_front(feet_y, 201.0)
	var not_in_front_ok: bool = not OcclusionSilhouette.is_in_front(feet_y, 199.0)
	var same_y_ok: bool = not OcclusionSilhouette.is_in_front(feet_y, 200.0)

	return case1_front_overlap \
		and not case2_back_overlap \
		and not case3_front_no_overlap \
		and not case4_back_no_overlap \
		and in_front_ok \
		and not_in_front_ok \
		and same_y_ok


func test_silhouette_node_sprite_tracking_and_visibility() -> bool:
	var char_root := Node2D.new()
	char_root.position = Vector2(100, 200) # feet_y = 200

	# สร้าง Texture ทดสอบขนาด 32x48
	var img := Image.create(32, 48, false, Image.FORMAT_RGBA8)
	var tex := ImageTexture.create_from_image(img)

	var spr := Sprite2D.new()
	spr.name = "CharacterSprite"
	spr.texture = tex
	spr.hframes = 2
	spr.frame = 0
	spr.flip_h = false
	char_root.add_child(spr)

	var sil := OcclusionSilhouette.new()
	sil.sprite_path = NodePath("../CharacterSprite")
	sil.detection_size = Vector2(32, 48)
	sil.detection_offset = Vector2(0, -24)
	char_root.add_child(sil)
	sil.setup()

	# เปลี่ยนสถานะของ sprite
	spr.frame = 1
	spr.flip_h = true

	# 1. วัตถุอยู่ข้างหน้าเท้า (y = 250 > 200) และทับพื้นที่ -> ต้องแสดง silhouette
	sil.mock_occluders = [
		{"y": 250.0, "rect": Rect2(90, 160, 30, 50)}
	]
	var occluded_1: bool = sil.tick(0.0)
	var visible_1: bool = sil.silhouette_sprite != null and sil.silhouette_sprite.visible
	var frame_matched: bool = sil.silhouette_sprite != null and sil.silhouette_sprite.frame == 1
	var flip_matched: bool = sil.silhouette_sprite != null and sil.silhouette_sprite.flip_h == true
	var z_index_high: bool = sil.silhouette_sprite != null and sil.silhouette_sprite.z_index >= 10

	# 2. วัตถุอยู่ข้างหลังเท้า (y = 150 <= 200) -> ต้องซ่อน silhouette
	sil.mock_occluders = [
		{"y": 150.0, "rect": Rect2(90, 160, 30, 50)}
	]
	var occluded_2: bool = sil.tick(0.0)
	var visible_2: bool = sil.silhouette_sprite != null and sil.silhouette_sprite.visible

	char_root.free()

	return occluded_1 \
		and visible_1 \
		and frame_matched \
		and flip_matched \
		and z_index_high \
		and not occluded_2 \
		and not visible_2


func test_silhouette_animated_sprite_tracking() -> bool:
	var char_root := Node2D.new()
	char_root.position = Vector2(200, 300)

	var img1 := Image.create(32, 48, false, Image.FORMAT_RGBA8)
	var tex1 := ImageTexture.create_from_image(img1)
	var img2 := Image.create(32, 48, false, Image.FORMAT_RGBA8)
	var tex2 := ImageTexture.create_from_image(img2)

	var frames := SpriteFrames.new()
	frames.add_animation(&"idle")
	frames.add_frame(&"idle", tex1)
	frames.add_frame(&"idle", tex2)

	var anim_spr := AnimatedSprite2D.new()
	anim_spr.name = "AnimSprite"
	anim_spr.sprite_frames = frames
	anim_spr.animation = &"idle"
	anim_spr.frame = 1
	anim_spr.flip_h = true
	char_root.add_child(anim_spr)

	var sil := OcclusionSilhouette.new()
	sil.sprite_path = NodePath("../AnimSprite")
	char_root.add_child(sil)
	sil.setup()

	# วัตถุอยู่ข้างหน้า (y = 350 > 300)
	sil.mock_occluders = [
		{"y": 350.0, "rect": Rect2(190, 260, 30, 50)}
	]
	var occluded: bool = sil.tick(0.0)
	var visible_ok: bool = sil.silhouette_sprite != null and sil.silhouette_sprite.visible
	var tex_matched: bool = sil.silhouette_sprite != null and sil.silhouette_sprite.texture == tex2
	var flip_matched: bool = sil.silhouette_sprite != null and sil.silhouette_sprite.flip_h == true

	char_root.free()

	return occluded and visible_ok and tex_matched and flip_matched
