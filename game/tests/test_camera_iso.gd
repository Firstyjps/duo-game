extends RefCounted
## เทสต์กล้อง iso และ silhouette — game/systems/camera/ และ game/systems/player/occlusion/ · Issue #41
## รันผ่าน godot --headless --path game --script res://tests/run_tests.gd


func test_slide_to_ends_at_rect_and_pixel_rounded() -> bool:
	var cam := GameCamera.new()
	cam.setup()
	cam.set_camera_position(Vector2(480.2, 270.8))

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
	cam.set_camera_position(Vector2(100.2, 100.8))

	var target_rect := Rect2(800, 400, 600, 400) # Center = (1100, 600)
	cam.slide_to(target_rect, 0.0)

	var not_sliding: bool = not cam.is_sliding()
	var bounds_ok: bool = cam.bounds == target_rect
	var pos_ok: bool = cam.position == Vector2(1100, 600)

	cam.free()
	return not_sliding and bounds_ok and pos_ok


func test_slide_in_tree_screen_center_smooth_without_jump() -> bool:
	var root: Window = (Engine.get_main_loop() as SceneTree).root
	var cam: Variant = GameCamera.new()
	var room1 := Rect2(0, 0, 960, 540)
	var room2 := Rect2(960, 0, 960, 540)

	cam.set_bounds(room1)
	cam.set_camera_position(room1.get_center()) # (480, 270)
	cam.setup()
	root.add_child(cam)

	var start_screen_pos: Vector2 = cam.get_screen_center_position()
	var start_pos_ok: bool = start_screen_pos.is_equal_approx(Vector2(480, 270))
	var start_limits_ok: bool = cam.limit_left == 0 and cam.limit_right == 960

	# เริ่ม slide ไป room 2
	cam.slide_to(room2, 0.5)

	# limits ต้องขยายเป็น union ระหว่าง room 1 และ room 2 (x: 0..1920)
	var union_limits_ok: bool = cam.limit_left == 0 and cam.limit_right == 1920

	# ก้าวแรก (ครึ่งทาง): 0.25s
	cam.tick(0.25)
	var mid_screen_pos: Vector2 = cam.get_screen_center_position()
	# หน้าจอต้องค่อย ๆ เปลี่ยน ไม่กระโดดไป 1440 ทันที และไม่ค้างอยู่ที่ 480
	var mid_changed: bool = mid_screen_pos.x > 480.0 and mid_screen_pos.x < 1440.0
	var mid_smooth: bool = is_equal_approx(mid_screen_pos.x, 960.0)

	# ก้าวที่สอง: เลื่อนจนเสร็จสิ้น (อีก 0.3s)
	cam.tick(0.3)
	var final_screen_pos: Vector2 = cam.get_screen_center_position()
	var final_pos_ok: bool = final_screen_pos.is_equal_approx(room2.get_center())
	var final_limits_ok: bool = cam.limit_left == 960 and cam.limit_right == 1920
	var final_bounds_ok: bool = cam.bounds == room2
	var final_not_sliding: bool = not cam.is_sliding()

	root.remove_child(cam)
	cam.free()

	return start_pos_ok \
		and start_limits_ok \
		and union_limits_ok \
		and mid_changed \
		and mid_smooth \
		and final_pos_ok \
		and final_limits_ok \
		and final_bounds_ok \
		and final_not_sliding



func test_camera_does_not_follow_during_slide() -> bool:
	var cam := GameCamera.new()
	cam.setup()
	cam.set_camera_position(Vector2(480, 270))

	var target := Node2D.new()
	target.position = Vector2(480, 270)
	cam.follow(target, false)

	var room2 := Rect2(960, 0, 960, 540) # Center = (1440, 270)
	cam.slide_to(room2, 1.0)

	# ระหว่าง slide ให้ target กระโดดไปที่อื่นไกล ๆ
	target.position = Vector2(-1000, -1000)

	# tick กล้องครึ่งทาง (0.5s)
	cam.tick(0.5)

	# กล้องต้องไม่ตาม target (-1000, -1000) แต่ต้องกำลังมุ่งหน้าไปทาง room2 (1440)
	var mid_pos: Vector2 = cam.position
	var ignore_target: bool = mid_pos.x > 480.0 and mid_pos.x < 1440.0 and mid_pos.y == 270.0

	# tick จนจบ slide (อีก 0.6s)
	cam.tick(0.6)
	var finished_sliding: bool = not cam.is_sliding()
	var at_destination: bool = cam.position == Vector2(1440, 270)

	# หลังจาก slide จบแล้ว ใน tick ถัดไป กล้องจึงกลับมา follow target
	cam.tick(0.1)
	var resumed_follow: bool = cam.position.x < 1440.0 # เริ่มขยับตาม target ที่อยู่ติดลบ

	target.free()
	cam.free()

	return ignore_target and finished_sliding and at_destination and resumed_follow


func test_focus_target_freed_midway() -> bool:
	var cam := GameCamera.new()
	cam.setup()
	cam.follow_smooth_speed = 100.0 # snap เร็วสำหรับเทสต์

	var player := Node2D.new()
	player.position = Vector2(100, 100)
	cam.follow(player, true)

	var dummy := Node2D.new()
	dummy.position = Vector2(200, 100) # target_pos ระหว่างสองตัว ~ (135, 100)
	cam.set_focus_target(dummy)

	cam.tick(0.1)
	var framing_ok: bool = cam.position.x > 100.0 and cam.position.x <= 135.0

	# ทำลาย dummy กลางทาง
	dummy.free()

	# กล้องต้องไม่ error หรือ crash และต้อง fallback กลับมาติดตาม player (100, 100)
	cam.tick(0.5)
	var fallback_ok: bool = cam.position == Vector2(100, 100)

	# ทดสอบ snap_to_target ตอน focus_target ถูก free
	cam.snap_to_target()
	var snap_ok: bool = cam.position == Vector2(100, 100)

	player.free()
	cam.free()

	return framing_ok and fallback_ok and snap_ok


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


func test_occlusion_real_mode_helpers() -> bool:
	# 1. ทดสอบ get_occluder_y และ get_occluder_rect สำหรับ Node2D ทั่วไปและ meta
	var dummy_node := Node2D.new()
	dummy_node.position = Vector2(300, 400)
	var def_y: float = OcclusionSilhouette.get_occluder_y(dummy_node)
	var def_rect: Rect2 = OcclusionSilhouette.get_occluder_rect(dummy_node)
	var node_ok: bool = def_y == 400.0 and def_rect.get_center().is_equal_approx(Vector2(300, 400))

	# กำหนด meta occluder_y และ occluder_rect
	dummy_node.set_meta(&"occluder_y", 450.0)
	dummy_node.set_meta(&"occluder_rect", Rect2(250, 350, 100, 80))
	var meta_y: float = OcclusionSilhouette.get_occluder_y(dummy_node)
	var meta_rect: Rect2 = OcclusionSilhouette.get_occluder_rect(dummy_node)
	var meta_ok: bool = meta_y == 450.0 and meta_rect == Rect2(250, 350, 100, 80)
	dummy_node.free()

	# 2. ทดสอบ get_tile_occluder_y และ get_tile_world_rect กับ TileMapLayer
	var ts := TileSet.new()
	ts.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	ts.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	ts.tile_size = Vector2i(64, 32)

	var layer := TileMapLayer.new()
	layer.tile_set = ts

	var coords := Vector2i(2, 3)
	var expected_center: Vector2 = layer.map_to_local(coords)
	var tile_y: float = OcclusionSilhouette.get_tile_occluder_y(layer, coords)
	var tile_rect: Rect2 = OcclusionSilhouette.get_tile_world_rect(layer, coords)

	var tile_y_ok: bool = tile_y == expected_center.y
	var tile_rect_center_ok: bool = tile_rect.get_center().is_equal_approx(expected_center)
	var tile_rect_size_ok: bool = tile_rect.size == Vector2(64, 32)

	layer.free()

	return node_ok and meta_ok and tile_y_ok and tile_rect_center_ok and tile_rect_size_ok


func test_silhouette_global_transform_and_scale_flip() -> bool:
	var tree_root: Window = (Engine.get_main_loop() as SceneTree).root
	var root := Node2D.new()
	root.position = Vector2(100, 100)
	root.scale = Vector2(-2.0, 2.0) # Parent scale flip and scaled 2x
	tree_root.add_child(root)

	var spr := Sprite2D.new()
	spr.name = "CharacterSprite"
	spr.position = Vector2(10, 20)
	spr.rotation = 0.5
	root.add_child(spr)

	var sil := OcclusionSilhouette.new()
	sil.sprite_path = NodePath("../CharacterSprite")
	root.add_child(sil)
	sil.setup()

	# sync
	sil.sync_with_sprite()

	# ตรวจว่า silhouette_sprite มี global_transform ตรงกับ spr.global_transform
	var gt_matched: bool = sil.silhouette_sprite.global_transform.is_equal_approx(spr.global_transform)
	var flip_detected: bool = sil.silhouette_sprite.global_transform.determinant() < 0.0

	tree_root.remove_child(root)
	root.free()
	return gt_matched and flip_detected


func test_silhouette_hides_when_target_sprite_invisible_in_tree() -> bool:
	var root: Window = (Engine.get_main_loop() as SceneTree).root
	var char_root := Node2D.new()
	char_root.position = Vector2(100, 200)

	var spr := Sprite2D.new()
	spr.name = "CharSprite"
	char_root.add_child(spr)

	var sil := OcclusionSilhouette.new()
	sil.sprite_path = NodePath("../CharSprite")
	char_root.add_child(sil)
	sil.setup()

	root.add_child(char_root)

	# วัตถุอยู่ข้างหน้าและทับสไปรต์ -> ขณะ sprite แสดงอยู่ silhouette ต้องปรากฏ
	sil.mock_occluders = [
		{"y": 250.0, "rect": Rect2(80, 150, 40, 60)}
	]
	sil.tick(0.0)
	var visible_when_active: bool = sil.silhouette_sprite != null and sil.silhouette_sprite.visible

	# ซ่อน target_sprite -> sil.tick() ต้องซ่อน silhouette_sprite
	spr.visible = false
	sil.tick(0.0)
	var hidden_when_target_hidden: bool = sil.silhouette_sprite != null and not sil.silhouette_sprite.visible

	# หรือหาก parent ของ sprite ซ่อน
	spr.visible = true
	char_root.visible = false
	sil.tick(0.0)
	var hidden_when_parent_hidden: bool = sil.silhouette_sprite != null and not sil.silhouette_sprite.visible

	root.remove_child(char_root)
	char_root.free()

	return visible_when_active and hidden_when_target_hidden and hidden_when_parent_hidden


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


func test_occlusion_real_tilemap_layer_diamond_down() -> bool:
	var ts := TileSet.new()
	ts.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	ts.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	ts.tile_size = Vector2i(64, 32)

	var src := TileSetAtlasSource.new()
	src.texture = load("res://systems/player/debug/iso/iso_tiles.png")
	src.texture_region_size = Vector2i(64, 32)
	ts.add_source(src, 0)
	src.create_tile(Vector2i(3, 0), Vector2i(1, 2))
	var block: TileData = src.get_tile_data(Vector2i(3, 0), 0)
	block.texture_origin = Vector2i(0, 16)

	var walls_layer := TileMapLayer.new()
	walls_layer.tile_set = ts
	var wall_cell := Vector2i(2, 2)
	walls_layer.set_cell(wall_cell, 0, Vector2i(3, 0))

	var wall_center: Vector2 = walls_layer.map_to_local(wall_cell)
	var wall_base_y: float = wall_center.y
	var tile_rect: Rect2 = OcclusionSilhouette.get_tile_world_rect(walls_layer, wall_cell)

	var tile_rect_ok: bool = tile_rect.size == Vector2(64, 64) and is_equal_approx(tile_rect.position.y, wall_base_y - 48.0)

	var char_root := Node2D.new()
	var spr := Sprite2D.new()
	spr.name = "HeroSprite"
	var img := Image.create(32, 48, false, Image.FORMAT_RGBA8)
	spr.texture = ImageTexture.create_from_image(img)
	spr.centered = true
	spr.offset = Vector2(0, -24)
	char_root.add_child(spr)

	var sil := OcclusionSilhouette.new()
	sil.sprite_path = NodePath("../HeroSprite")
	sil.direct_occluder_layers = [walls_layer]
	char_root.add_child(sil)
	sil.setup()

	# 1. เท้าอยู่หลังกำแพง (y น้อยกว่าฐาน) สไปรต์ทับภาพ -> บัง
	char_root.position = Vector2(wall_center.x, wall_base_y - 8.0)
	var occluded_behind: bool = sil.tick(0.0)
	var visible_behind: bool = sil.silhouette_sprite != null and sil.silhouette_sprite.visible

	# 2. อยู่หน้ากำแพง (y มากกว่าฐาน) -> ไม่บัง
	char_root.position = Vector2(wall_center.x, wall_base_y + 8.0)
	var occluded_in_front: bool = sil.tick(0.0)
	var visible_in_front: bool = sil.silhouette_sprite != null and sil.silhouette_sprite.visible

	# 3. ไกลกำแพง -> ไม่บัง
	char_root.position = Vector2(wall_center.x + 200.0, wall_base_y - 8.0)
	var occluded_far: bool = sil.tick(0.0)
	var visible_far: bool = sil.silhouette_sprite != null and sil.silhouette_sprite.visible

	char_root.free()
	walls_layer.free()

	return tile_rect_ok \
		and occluded_behind and visible_behind \
		and not occluded_in_front and not visible_in_front \
		and not occluded_far and not visible_far


func test_camera_screen_shake_requested() -> bool:
	var cam := GameCamera.new()
	cam._enter_tree()

	var initial_trauma_zero: bool = cam.trauma == 0.0

	# 1. ส่ง screen_shake_requested(0.6, pos) -> trauma เพิ่มขึ้น 0.6
	EventBus.screen_shake_requested.emit(0.6, Vector2(100, 200))
	var trauma_06: bool = is_equal_approx(cam.trauma, 0.6)

	# 2. ส่งค่าเกิน 1.0 (0.8) -> trauma ต้องถูก clamp ไม่เกิน 1.0
	EventBus.screen_shake_requested.emit(0.8, Vector2.ZERO)
	var trauma_clamped_max: bool = is_equal_approx(cam.trauma, 1.0)

	# 3. ส่งค่าติดลบ (-0.5) ขณะ trauma = 0.5 -> clampf(-0.5, 0, 1) = 0.0 -> trauma ยังคงเป็น 0.5 ไม่ลดลง
	cam.trauma = 0.5
	EventBus.screen_shake_requested.emit(-0.5, Vector2.ZERO)
	var trauma_clamped_min: bool = is_equal_approx(cam.trauma, 0.5)

	# 4. เมื่อออกจาก tree (_exit_tree) ต้อง disconnect สัญญาณ
	cam._exit_tree()
	EventBus.screen_shake_requested.emit(0.4, Vector2.ZERO)
	var disconnected_ok: bool = is_equal_approx(cam.trauma, 0.5)

	cam.free()

	return initial_trauma_zero and trauma_06 and trauma_clamped_max and trauma_clamped_min and disconnected_ok




## EventBus.room_started: ห้องแรก = ตั้ง bounds ทันที · ห้องถัดไป = slide · respawn = เลิก bounds
func test_room_started_sets_bounds_then_slides() -> bool:
	var cam := GameCamera.new()
	cam.setup()
	var r1 := Rect2(0, 0, 960, 540)
	var r2 := Rect2(960, 0, 960, 540)
	EventBus.room_started.emit(null, r1)
	var first_ok: bool = cam.bounds == r1
	EventBus.room_started.emit(null, r2)
	var sliding: bool = cam._is_sliding and cam._slide_target_rect == r2
	EventBus.player_respawn_requested.emit(Vector2(-5000, -5000))  # นอกทุกห้อง → เลิกขอบ
	var cleared: bool = cam.bounds.size == Vector2.ZERO
	cam._disconnect_bus()
	cam.free()
	return first_ok and sliding and cleared


## remove/add กล้องกลับเข้า tree แล้วยังฟัง damage_dealt
func test_reenter_tree_reconnects_damage() -> bool:
	var cam := GameCamera.new()
	cam.setup()
	cam._exit_tree()
	var off: bool = not EventBus.damage_dealt.is_connected(cam._on_damage_dealt)
	cam._enter_tree()
	var on: bool = EventBus.damage_dealt.is_connected(cam._on_damage_dealt)
	cam._disconnect_bus()
	cam.free()
	return off and on


## ฟื้นในห้องเดิม (เช่นพักศาลเจ้า) → คงขอบ · ฟื้นนอกห้อง → เลิกขอบ
func test_respawn_keeps_bounds_inside_room() -> bool:
	var cam := GameCamera.new()
	cam.setup()
	var r := Rect2(0, 0, 960, 540)
	cam.set_bounds(r)
	EventBus.player_respawn_requested.emit(Vector2(100, 100))
	var kept: bool = cam.bounds == r
	EventBus.player_respawn_requested.emit(Vector2(5000, 100))
	var cleared: bool = cam.bounds.size == Vector2.ZERO
	cam._disconnect_bus()
	cam.free()
	return kept and cleared
