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


## Player จริงใช้ DirSprite: เดินไปทางไหนหันทางนั้น · หยุด = idle ทิศเดิม · dodge/hurt ใช้ท่าของตัวเอง
func test_player_drives_dir_sprite() -> bool:
	var player: Player = (load("res://systems/player/player.tscn") as PackedScene).instantiate()
	player.setup()
	var has: bool = player.dir_sprite != null and player.sprite == player.dir_sprite
	player.state = Player.State.MOVE
	player.velocity = Vector2(80, 0)
	player._animate(0.016)
	var walk_ok: bool = player.dir_sprite.animation == &"walk_east"
	player.velocity = Vector2.ZERO
	player._animate(0.016)
	var idle_ok: bool = player.dir_sprite.animation == &"idle_east"
	player.state = Player.State.DODGE
	player.dodge_dir = Vector2(0, -1)
	player._animate(0.016)
	var dodge_ok: bool = player.dir_sprite.animation == &"dodge_north"
	player.state = Player.State.HURT
	player._animate(0.016)
	var hurt_ok: bool = player.dir_sprite.animation == &"hurt_north"
	player.free()
	return has and walk_ok and idle_ok and dodge_ok and hurt_ok


## ท่าฟัน: เฟรมตามเฟส (ง้าง 1–2 · ฟัน 3–4 · กลับ 5–6) · คอมโบสลับ attack1/attack2 · ชาร์จ = attack3
func test_player_attack_frames_follow_phase() -> bool:
	var player: Player = (load("res://systems/player/player.tscn") as PackedScene).instantiate()
	player.setup()
	player.stamina = 100.0
	player.set_intent(Vector2.ZERO, Vector2.RIGHT, true, false)
	player.tick(0.0)
	player._animate(0.0)
	var first_anim: StringName = player.dir_sprite.animation
	var windup_ok: bool = player.dir_sprite.frame in [1, 2] and String(first_anim).begins_with("attack")
	player.set_intent(Vector2.ZERO, Vector2.RIGHT, false, false)
	player.tick(player.windup_time + 0.001)
	player.tick(0.001)
	player._animate(0.0)
	var active_ok: bool = player.attack_phase == Player.AttackPhase.ACTIVE and player.dir_sprite.frame in [3, 4]
	for i: int in 40:
		player.tick(0.02)
	player.tick(0.0)
	player.set_intent(Vector2.ZERO, Vector2.RIGHT, true, false)
	player.tick(0.0)
	player._animate(0.0)
	var second_anim: StringName = player.dir_sprite.animation
	var alternates: bool = first_anim != second_anim and String(first_anim).ends_with("_east") \
		and (String(first_anim).begins_with("attack1") or String(first_anim).begins_with("attack2"))
	player.free()
	return windup_ok and active_ok and alternates
