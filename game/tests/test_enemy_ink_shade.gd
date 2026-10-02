extends RefCounted
## เทสต์ศัตรูเงาหมึก (Ink Shade) — game/systems/enemy/ink_shade/
## ลำดับ state ถูก · ไม่มี Hitbox active ก่อน windup ครบ · ตายแล้ว emit ครั้งเดียว · ทิศ 8 ทิศจากเวกเตอร์ถูก

const INK_SHADE_SCENE: PackedScene = preload("res://systems/enemy/ink_shade/ink_shade.tscn")


func _spawn() -> InkShade:
	var shade: InkShade = INK_SHADE_SCENE.instantiate()
	shade.setup()
	return shade


func _hit(amount: int, stagger: float = 0.0) -> DamageInfo:
	var info := DamageInfo.new()
	info.team = Combat.Team.PLAYER
	info.amount = amount
	info.stagger = stagger
	return info


## 1. ทิศ 8 ทิศจากเวกเตอร์ถูกต้อง (screen-space)
func test_8_directions_from_vector() -> bool:
	var ok: bool = true
	# ทิศหลักและทิศทแยง
	ok = ok and InkShade.vector_to_dir(Vector2(0, 1)) == InkShade.Dir.SOUTH # (0)
	ok = ok and InkShade.vector_to_dir(Vector2(1, 1)) == InkShade.Dir.SOUTH_EAST # (1)
	ok = ok and InkShade.vector_to_dir(Vector2(1, 0)) == InkShade.Dir.EAST # (2)
	ok = ok and InkShade.vector_to_dir(Vector2(1, -1)) == InkShade.Dir.NORTH_EAST # (3)
	ok = ok and InkShade.vector_to_dir(Vector2(0, -1)) == InkShade.Dir.NORTH # (4)
	ok = ok and InkShade.vector_to_dir(Vector2(-1, -1)) == InkShade.Dir.NORTH_WEST # (5)
	ok = ok and InkShade.vector_to_dir(Vector2(-1, 0)) == InkShade.Dir.WEST # (6)
	ok = ok and InkShade.vector_to_dir(Vector2(-1, 1)) == InkShade.Dir.SOUTH_WEST # (7)

	# เวกเตอร์ใกล้เคียงมุมเฉียง (tolerance ภายใน sector 45 องศา)
	ok = ok and InkShade.vector_to_dir(Vector2(0.2, 1.0)) == InkShade.Dir.SOUTH
	ok = ok and InkShade.vector_to_dir(Vector2(1.0, 0.1)) == InkShade.Dir.EAST
	ok = ok and InkShade.vector_to_dir(Vector2(-0.1, -1.0)) == InkShade.Dir.NORTH
	ok = ok and InkShade.vector_to_dir(Vector2(-1.0, -0.2)) == InkShade.Dir.WEST
	ok = ok and InkShade.vector_to_dir(Vector2.ZERO) == InkShade.Dir.SOUTH
	return ok


## 2. สถานะเริ่มต้นและการตั้งค่าทีม
func test_initial_state_and_teams() -> bool:
	var shade: InkShade = _spawn()
	var ok: bool = shade.state == InkShade.State.WANDER \
		and shade.hurtbox.team == Combat.Team.ENEMY \
		and shade.hitbox.team == Combat.Team.ENEMY \
		and not shade.hitbox.monitoring \
		and shade.detect.collision_mask == Combat.LAYER_PLAYER \
		and shade.enemy_id == &"ink_shade"
	shade.free()
	return ok


## ตรวจสอบว่า detect_range duplicate shape และปรับ radius ตามค่า
func test_detect_range_applied_to_shape() -> bool:
	var shade1: InkShade = INK_SHADE_SCENE.instantiate()
	shade1.detect_range = 220.0
	shade1.setup()

	var shade2: InkShade = INK_SHADE_SCENE.instantiate()
	shade2.detect_range = 95.0
	shade2.setup()

	var shape1: CircleShape2D = (shade1.detect.get_node("Shape") as CollisionShape2D).shape as CircleShape2D
	var shape2: CircleShape2D = (shade2.detect.get_node("Shape") as CollisionShape2D).shape as CircleShape2D

	var ok: bool = shape1 != shape2 \
		and is_equal_approx(shape1.radius, 220.0) \
		and is_equal_approx(shape2.radius, 95.0)

	shade1.free()
	shade2.free()
	return ok


## 3. ลำดับ state ถูกต้อง: WANDER → CHASE → WINDUP → SLASH → RECOVER
func test_state_sequence_wander_to_chase_to_windup_to_slash_to_recover() -> bool:
	var shade: InkShade = _spawn()
	var dummy := Node2D.new()
	dummy.position = Vector2(100, 0)

	var is_wander: bool = shade.state == InkShade.State.WANDER
	shade.set_target(dummy)
	var is_chase: bool = shade.state == InkShade.State.CHASE

	# ขยับ dummy เข้ามาในระยะโจมตี
	dummy.position = Vector2(shade.attack_range * 0.8, 0)
	shade.tick(0.0)
	var is_windup: bool = shade.state == InkShade.State.WINDUP

	# ตลอด windup_time ต้องยังไม่ออกท่า
	shade.tick(shade.windup_time * 0.5)
	var still_windup: bool = shade.state == InkShade.State.WINDUP

	# ครบ windup_time เข้าสู่ SLASH
	shade.tick(shade.windup_time * 0.5)
	var is_slash: bool = shade.state == InkShade.State.SLASH

	# ครบ slash_time เข้าสู่ RECOVER
	shade.tick(shade.slash_time)
	var is_recover: bool = shade.state == InkShade.State.RECOVER

	# ครบ recover_time กลับไป CHASE เมื่อยังมี target
	shade.tick(shade.recover_time)
	var back_to_chase: bool = shade.state == InkShade.State.CHASE

	shade.free()
	dummy.free()
	return is_wander and is_chase and is_windup and still_windup and is_slash and is_recover and back_to_chase


## 4. ไม่มี Hitbox/attack active ก่อน windup ครบ และ active เมื่อเข้า SLASH
func test_no_hitbox_active_before_windup_complete() -> bool:
	var shade: InkShade = _spawn()
	var dummy := Node2D.new()
	dummy.position = Vector2(shade.attack_range * 0.5, 0)
	shade.set_target(dummy)

	var ok: bool = true
	# ใน CHASE: attack ต้องไม่ active
	ok = ok and not shade.is_attack_active and not shade.hitbox.monitoring

	# เข้า WINDUP: attack ต้องไม่ active
	shade.tick(0.0)
	ok = ok and (shade.state == InkShade.State.WINDUP)
	ok = ok and not shade.is_attack_active and not shade.hitbox.monitoring

	# วน tick ระหว่าง windup หลาย ๆ จุดเวลา: ต้องไม่มีจังหวะไหนที่ is_attack_active เป็น true
	for i: int in 10:
		shade.tick(shade.windup_time * 0.09)
		ok = ok and (shade.state == InkShade.State.WINDUP)
		ok = ok and not shade.is_attack_active and not shade.hitbox.monitoring

	# เมื่อเข้าสู่ SLASH: is_attack_active ต้องเป็น true
	shade.tick(shade.windup_time * 0.2)
	ok = ok and (shade.state == InkShade.State.SLASH)
	ok = ok and shade.is_attack_active

	# เมื่อเข้าสู่ RECOVER: is_attack_active ต้องถูกเคลียร์เป็น false
	shade.tick(shade.slash_time)
	ok = ok and (shade.state == InkShade.State.RECOVER)
	ok = ok and not shade.is_attack_active

	shade.free()
	dummy.free()
	return ok


## โดนตีกลาง SLASH -> is_attack_active กลายเป็น false
func test_hit_during_slash_clears_attack_active() -> bool:
	var shade: InkShade = _spawn()
	var dummy := Node2D.new()
	dummy.position = Vector2(shade.attack_range * 0.5, 0)
	shade.set_target(dummy)

	shade.tick(0.0)
	shade.tick(shade.windup_time)
	var in_slash: bool = shade.state == InkShade.State.SLASH and shade.is_attack_active

	# โดนตีด้วย stagger กลาง SLASH -> เข้า HURT และ is_attack_active ต้องเป็น false
	shade.hurtbox.receive(_hit(3, 1.0))
	var hurt_ok: bool = shade.state == InkShade.State.HURT and not shade.is_attack_active

	shade.free()
	dummy.free()
	return in_slash and hurt_ok


## ตายกลาง SLASH -> is_attack_active กลายเป็น false
func test_death_during_slash_clears_attack_active() -> bool:
	var shade: InkShade = _spawn()
	var dummy := Node2D.new()
	dummy.position = Vector2(shade.attack_range * 0.5, 0)
	shade.set_target(dummy)

	shade.tick(0.0)
	shade.tick(shade.windup_time)
	var in_slash: bool = shade.state == InkShade.State.SLASH and shade.is_attack_active

	# โดนตีตายกลาง SLASH -> เข้า DEAD และ is_attack_active ต้องเป็น false
	shade.hurtbox.receive(_hit(999))
	var dead_ok: bool = shade.state == InkShade.State.DEAD and not shade.is_attack_active

	shade.free()
	dummy.free()
	return in_slash and dead_ok


## damage_dealt ยิงหลังหัก HP (เช็ค health.hp ใน callback)
func test_damage_dealt_emitted_after_hp_deducted() -> bool:
	var shade: InkShade = _spawn()
	var initial_hp: int = shade.health.hp
	var dmg: int = 5
	var hp_recorded: Array[int] = []
	var cb := func(t: Node, _i: DamageInfo, _amt: int) -> void:
		if t == shade:
			hp_recorded.append(shade.health.hp)
	EventBus.damage_dealt.connect(cb)

	var received: bool = shade.hurtbox.receive(_hit(dmg))

	EventBus.damage_dealt.disconnect(cb)
	var expected_hp: int = initial_hp - dmg
	var ok: bool = received \
		and hp_recorded.size() == 1 \
		and hp_recorded[0] == expected_hp \
		and shade.health.hp == expected_hp
	shade.free()
	return ok


## 5. ตายแล้ว emit EventBus.enemy_died ครั้งเดียว และเปลี่ยน state เป็น DEAD
func test_dies_once_and_emits_enemy_died_once() -> bool:
	var shade: InkShade = _spawn()
	var deaths: Array[StringName] = []
	var cb := func(e: Node, id: StringName, _p: Vector2) -> void:
		if e == shade:
			deaths.append(id)
	EventBus.enemy_died.connect(cb)

	# โจมตีด้วยดาเมจรุนแรงสองครั้ง
	shade.hurtbox.receive(_hit(999))
	shade.hurtbox.receive(_hit(999))

	EventBus.enemy_died.disconnect(cb)
	var ok: bool = deaths == [&"ink_shade"] and shade.state == InkShade.State.DEAD and shade.health.is_dead
	shade.free()
	return ok


## 6. ดาเมจและการเซตาม stagger เทียบ poise
func test_damage_and_poise_stagger() -> bool:
	var shade: InkShade = _spawn()
	var dealt_list: Array[int] = []
	var cb := func(t: Node, _i: DamageInfo, amount: int) -> void:
		if t == shade:
			dealt_list.append(amount)
	EventBus.damage_dealt.connect(cb)

	# ค่าเริ่มต้น poise = 0.0: โดนตีแล้วเซ (HURT)
	var landed: bool = shade.hurtbox.receive(_hit(5, 0.0))
	var hurt_ok: bool = landed and dealt_list == [5] and shade.state == InkShade.State.HURT
	shade.tick(shade.hurt_time)

	# ทดสอบ poise สูง (เช่น mini-boss / poise armor = 10.0)
	shade.poise = 10.0
	shade._enter(InkShade.State.WANDER)
	# ตีเบา stagger = 4.0 < 10.0 -> ยังไม่เซ
	shade.hurtbox.receive(_hit(3, 4.0))
	var not_staggered: bool = shade.state != InkShade.State.HURT
	# ตีเพิ่มอีก stagger = 7.0 (รวม 11.0 >= 10.0) -> เซ!
	shade.hurtbox.receive(_hit(3, 7.0))
	var staggered_now: bool = shade.state == InkShade.State.HURT

	EventBus.damage_dealt.disconnect(cb)
	shade.free()
	return hurt_ok and not_staggered and staggered_now


## 7. ทิศทางสไปรต์เปลี่ยนตามทิศเป้าหมาย
func test_facing_direction_follows_target() -> bool:
	var shade: InkShade = _spawn()
	var dummy := Node2D.new()

	# เป้าหมายอยู่ขวา -> หัน EAST (2)
	dummy.global_position = Vector2(80, 0)
	dummy.position = Vector2(80, 0)
	shade.set_target(dummy)
	shade.tick(0.0)
	var east_ok: bool = shade.facing_dir == InkShade.Dir.EAST and shade.sprite.frame_coords.y == InkShade.Dir.EAST

	# เป้าหมายอยู่บนขวา -> หัน NORTH_EAST (3)
	dummy.global_position = Vector2(80, -80)
	dummy.position = Vector2(80, -80)
	shade.tick(0.0)
	var ne_ok: bool = shade.facing_dir == InkShade.Dir.NORTH_EAST and shade.sprite.frame_coords.y == InkShade.Dir.NORTH_EAST

	# เป้าหมายอยู่ซ้ายล่าง -> หัน SOUTH_WEST (7)
	dummy.global_position = Vector2(-80, 80)
	dummy.position = Vector2(-80, 80)
	shade.tick(0.0)
	var sw_ok: bool = shade.facing_dir == InkShade.Dir.SOUTH_WEST and shade.sprite.frame_coords.y == InkShade.Dir.SOUTH_WEST

	shade.free()
	dummy.free()
	return east_ok and ne_ok and sw_ok


## 8. WANDER ถ้าไม่คืบหน้าระยะไม่ลดเกิน wander_stuck_time (~1.2s) ให้สุ่มจุดใหม่
func test_wander_stuck_repicks_target() -> bool:
	var shade: InkShade = _spawn()
	shade.global_position = Vector2(100, 100)
	shade.spawn_position = Vector2(100, 100)
	shade._wander_pause_t = 0.0
	seed(40)
	# จุดหมายไกลเกิน 4 px เสมอ (ใกล้กว่านั้นจะหยุดพักแทนเดิน) — ไม่ขึ้นกับการสุ่ม
	shade._wander_target = shade.global_position + Vector2(60, 0)
	var initial_target: Vector2 = shade._wander_target
	shade.tick(0.05)  # tick แรกบันทึกระยะตั้งต้น (ระยะลด → stuck_t = 0)

	# tick ผ่านไป 0.6s (น้อยกว่า wander_stuck_time 1.2s) โดยที่ตำแหน่งติดอยู่กับที่ไม่ขยับ
	shade.tick(0.6)
	var still_same_target: bool = shade._wander_target == initial_target

	# tick เพิ่มอีก 0.7s (รวม 1.3s > wander_stuck_time) โดยไม่ขยับ -> สุ่มจุดใหม่
	shade.tick(0.7)
	var stuck_triggered: bool = shade._wander_target != initial_target

	shade.free()
	return still_same_target and stuck_triggered


## 9. เฟรมและแอนิเมชันทุกท่าอยู่ใน sprite sheet และเฟรมสุดท้ายของท่าตายไม่ว่างเปล่า
func test_anim_frames_within_sheet() -> bool:
	var shade: InkShade = _spawn()
	var tex: Texture2D = shade.sprite.texture
	var total_w: int = shade.sprite.hframes * 64
	var total_h: int = shade.sprite.vframes * 64
	var dim_ok: bool = tex.get_width() == total_w and tex.get_height() == total_h

	var frames_ok: bool = true
	for anim_name: StringName in InkShade.ANIMS:
		var frames: Array = InkShade.ANIMS[anim_name]["frames"]
		for f: int in frames:
			frames_ok = frames_ok and (f >= 0 and f < shade.sprite.hframes)

	# ตรวจสอบว่าเฟรมสุดท้ายของท่าตาย (คอลัมน์ 23) มีภาพจาง ๆ ไม่ว่างเปล่า
	var img: Image = tex.get_image()
	var col23_rect := Rect2i(23 * 64, 0, 64, 64)
	var col23_img: Image = img.get_region(col23_rect)
	var has_col23_pixels: bool = false
	for y: int in 64:
		for x: int in 64:
			if col23_img.get_pixel(x, y).a > 0.01:
				has_col23_pixels = true
				break
		if has_col23_pixels:
			break

	shade.free()
	return dim_ok and frames_ok and has_col23_pixels
