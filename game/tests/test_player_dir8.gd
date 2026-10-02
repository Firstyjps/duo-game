extends RefCounted
## เทสต์ทิศ 8 ทิศของสไปรต์ isometric — game/systems/player/iso/ · Issue #37


func test_cardinal_and_diagonal() -> bool:
	return Dir8.from_vector(Vector2(0, 1)) == Dir8.SOUTH \
		and Dir8.from_vector(Vector2(1, 1)) == Dir8.SOUTH_EAST \
		and Dir8.from_vector(Vector2(1, 0)) == Dir8.EAST \
		and Dir8.from_vector(Vector2(1, -1)) == Dir8.NORTH_EAST \
		and Dir8.from_vector(Vector2(0, -1)) == Dir8.NORTH \
		and Dir8.from_vector(Vector2(-1, -1)) == Dir8.NORTH_WEST \
		and Dir8.from_vector(Vector2(-1, 0)) == Dir8.WEST \
		and Dir8.from_vector(Vector2(-1, 1)) == Dir8.SOUTH_WEST


func test_zero_vector_keeps_fallback() -> bool:
	return Dir8.from_vector(Vector2.ZERO, Dir8.WEST) == Dir8.WEST \
		and Dir8.from_vector_sticky(Vector2.ZERO, Dir8.NORTH) == Dir8.NORTH


func test_round_trip_every_direction() -> bool:
	for d: int in Dir8.COUNT:
		if Dir8.from_vector(Dir8.to_vector(d)) != d:
			return false
	return true


func test_names_match_pixellab() -> bool:
	return Dir8.name_of(Dir8.SOUTH_EAST) == "south-east" \
		and Dir8.name_of(Dir8.NORTH_WEST) == "north-west" \
		and Dir8.name_of(8) == "south"


func test_sticky_holds_near_boundary() -> bool:
	# 25° จาก east (ขอบ east/south-east อยู่ที่ 22.5°) → sticky ยังเป็น east · ไม่ sticky = south-east
	var v := Vector2.from_angle(deg_to_rad(25.0))
	var held: bool = Dir8.from_vector_sticky(v, Dir8.EAST) == Dir8.EAST
	var plain: bool = Dir8.from_vector(v) == Dir8.SOUTH_EAST
	# เกินขอบ+margin ชัด ๆ → เปลี่ยน
	var moved: bool = Dir8.from_vector_sticky(Vector2(0, 1), Dir8.EAST) == Dir8.SOUTH
	return held and plain and moved


func test_dir_sprite_switches_animation_and_keeps_frame() -> bool:
	var frames := SpriteFrames.new()
	for act: String in ["idle", "walk"]:
		for d: int in Dir8.COUNT:
			var n: StringName = DirSprite.anim_name(StringName(act), d)
			frames.add_animation(n)
			for i: int in 4:
				frames.add_frame(n, PlaceholderTexture2D.new())
	var s := DirSprite.new()
	s.sprite_frames = frames
	s.play_action(&"walk")
	var ok_start: bool = s.animation == &"walk_south"
	s.frame = 2
	s.set_facing(Vector2(1, 0))
	var ok_turn: bool = s.animation == &"walk_east" and s.frame == 2
	s.play_action(&"roll")  # ไม่มีท่านี้ → idle
	var ok_fallback: bool = s.animation == &"idle_east"
	s.free()
	return ok_start and ok_turn and ok_fallback
