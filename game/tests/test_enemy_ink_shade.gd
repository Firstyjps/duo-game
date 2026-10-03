extends RefCounted
## เทสต์ศัตรูเงาหมึก (Ink Shade) — game/systems/enemy/ink_shade/
## ลำดับ state ถูก · ไม่มี Hitbox active ก่อน windup ครบ · ตายแล้ว emit ครั้งเดียว · ทิศ 8 ทิศจากเวกเตอร์ถูก
## PixelLab art 8 ทิศ + contract damage v2

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


## 1. ทิศ 8 ทิศจากเวกเตอร์ถูกต้อง (screen-space) ด้วย Dir8
func test_8_directions_from_vector() -> bool:
	var ok: bool = true
	# ทิศหลักและทิศทแยง
	ok = ok and Dir8.from_vector(Vector2(0, 1)) == Dir8.SOUTH # (0)
	ok = ok and Dir8.from_vector(Vector2(1, 1)) == Dir8.SOUTH_EAST # (1)
	ok = ok and Dir8.from_vector(Vector2(1, 0)) == Dir8.EAST # (2)
	ok = ok and Dir8.from_vector(Vector2(1, -1)) == Dir8.NORTH_EAST # (3)
	ok = ok and Dir8.from_vector(Vector2(0, -1)) == Dir8.NORTH # (4)
	ok = ok and Dir8.from_vector(Vector2(-1, -1)) == Dir8.NORTH_WEST # (5)
	ok = ok and Dir8.from_vector(Vector2(-1, 0)) == Dir8.WEST # (6)
	ok = ok and Dir8.from_vector(Vector2(-1, 1)) == Dir8.SOUTH_WEST # (7)

	# เวกเตอร์ใกล้เคียงมุมเฉียง (tolerance ภายใน sector 45 องศา)
	ok = ok and Dir8.from_vector(Vector2(0.2, 1.0)) == Dir8.SOUTH
	ok = ok and Dir8.from_vector(Vector2(1.0, 0.1)) == Dir8.EAST
	ok = ok and Dir8.from_vector(Vector2(-0.1, -1.0)) == Dir8.NORTH
	ok = ok and Dir8.from_vector(Vector2(-1.0, -0.2)) == Dir8.WEST
	ok = ok and Dir8.from_vector(Vector2.ZERO) == Dir8.SOUTH
	return ok


## 2. สถานะเริ่มต้นและการตั้งค่าทีม
func test_initial_state_and_teams() -> bool:
	var shade: InkShade = _spawn()
	var ok: bool = shade.state == InkShade.State.WANDER \
		and shade.hurtbox.team == Combat.Team.ENEMY \
		and shade.hitbox.team == Combat.Team.ENEMY \
		and not shade.hitbox.monitoring \
		and shade.detect.collision_mask == Combat.LAYER_PLAYER \
		and shade.enemy_id == &"ink_shade" \
		and shade.dir_sprite != null
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


## 4. ไม่มี Hitbox/attack active ก่อน windup ครบ และ active ช่วงเฟรม 5 ของ SLASH
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

	# เมื่อเข้าสู่ SLASH: เริ่มที่เฟรม 4 (ยังไม่ active)
	shade.tick(shade.windup_time * 0.2)
	ok = ok and (shade.state == InkShade.State.SLASH)
	ok = ok and shade.dir_sprite.frame == 4
	ok = ok and not shade.is_attack_active and not shade.hitbox.monitoring

	# เมื่อเล่นถึงเฟรม 5: is_attack_active ต้องเป็น true
	shade.tick(shade.slash_time * 0.4)
	ok = ok and (shade.state == InkShade.State.SLASH)
	ok = ok and shade.dir_sprite.frame == 5
	ok = ok and shade.is_attack_active

	# เมื่อเข้าสู่ RECOVER: is_attack_active ต้องถูกเคลียร์เป็น false
	shade.tick(shade.slash_time * 0.7)
	ok = ok and (shade.state == InkShade.State.RECOVER)
	ok = ok and not shade.is_attack_active

	shade.free()
	dummy.free()
	return ok


## 5. WINDUP แสดงเฟรม telegraph (attack ค้างเฟรม 3 ยกดาบสูง)
func test_windup_shows_telegraph_frame() -> bool:
	var shade: InkShade = _spawn()
	var dummy := Node2D.new()
	dummy.position = Vector2(shade.attack_range * 0.5, 0)
	shade.set_target(dummy)

	# เข้า WINDUP
	shade.tick(0.0)
	var ok: bool = shade.state == InkShade.State.WINDUP
	ok = ok and shade.dir_sprite.frame == 3
	ok = ok and shade.dir_sprite.action == &"attack"
	ok = ok and not shade.is_attack_active

	# ค้างเฟรม 3 ตลอดช่วง windup_time
	shade.tick(shade.windup_time * 0.5)
	ok = ok and (shade.state == InkShade.State.WINDUP)
	ok = ok and shade.dir_sprite.frame == 3
	ok = ok and not shade.is_attack_active

	shade.free()
	dummy.free()
	return ok


## 6. SLASH active ตรงเฟรม 5 (4=startup, 5=active แสงทองฟันลง, 6=followthrough, 7–8=RECOVER)
func test_slash_active_on_frame_5() -> bool:
	var shade: InkShade = _spawn()
	var dummy := Node2D.new()
	dummy.position = Vector2(shade.attack_range * 0.5, 0)
	shade.set_target(dummy)

	# เข้า WINDUP แล้วครบ windup_time → เข้า SLASH
	shade.tick(0.0)
	shade.tick(shade.windup_time)
	var in_slash: bool = shade.state == InkShade.State.SLASH

	# เฟรม 4 (จุดเริ่มต้นของการฟัน): ยังไม่ active
	var frame_4_ok: bool = shade.dir_sprite.frame == 4 and not shade.is_attack_active

	# เฟรม 5 (แสงทองฟันลง): active!
	shade.tick(shade.slash_time * 0.4)
	var frame_5_ok: bool = shade.dir_sprite.frame == 5 and shade.is_attack_active

	# เฟรม 6 (จังหวะปลายดาบ): deactive แล้ว
	shade.tick(shade.slash_time * 0.35)
	var frame_6_ok: bool = shade.dir_sprite.frame == 6 and not shade.is_attack_active

	# จบ slash_time → RECOVER เฟรม 7–8
	shade.tick(shade.slash_time * 0.35)
	var recover_ok: bool = shade.state == InkShade.State.RECOVER and (shade.dir_sprite.frame in [7, 8])

	shade.free()
	dummy.free()
	return in_slash and frame_4_ok and frame_5_ok and frame_6_ok and recover_ok


## 7. Contract damage v2: โดน parry (deflected) เซนาน parried_stagger_time (~0.8s)
func test_hitbox_deflected_triggers_parried_stagger() -> bool:
	var shade: InkShade = _spawn()
	var defender := Hurtbox.new()
	defender.team = Combat.Team.PLAYER
	defender.deflecting = true

	var dummy := Node2D.new()
	dummy.position = Vector2(shade.attack_range * 0.5, 0)
	shade.set_target(dummy)

	# เดินหน้าจนถึงเฟรม 5 ของ SLASH (Hitbox active)
	shade.tick(0.0)
	shade.tick(shade.windup_time)
	shade.tick(shade.slash_time * 0.4)
	var is_active: bool = shade.is_attack_active and shade.dir_sprite.frame == 5

	# จำลองการโดนปัด (parry)
	var hit_success: bool = shade.hitbox.try_hit(defender)
	# deflecting = true ทำให้ try_hit คืน false และส่ง deflected signal
	var defl_handled: bool = not hit_success \
		and shade.state == InkShade.State.HURT \
		and not shade.is_attack_active \
		and not shade.hitbox.monitoring

	# เซนานเท่า parried_stagger_time (0.8s) — ผ่านไป 0.4s ต้องยังเซอยู่ (ไม่เหมือน hurt ปกติ 0.25s)
	shade.tick(shade.parried_stagger_time * 0.5)
	var still_staggered: bool = shade.state == InkShade.State.HURT

	# ผ่านจนครบ parried_stagger_time แล้วต้องออกจาก HURT
	shade.tick(shade.parried_stagger_time * 0.6)
	var recovered: bool = shade.state != InkShade.State.HURT

	shade.free()
	dummy.free()
	defender.free()
	return is_active and defl_handled and still_staggered and recovered


## 8. โดนตีกลาง SLASH -> is_attack_active กลายเป็น false
func test_hit_during_slash_clears_attack_active() -> bool:
	var shade: InkShade = _spawn()
	var dummy := Node2D.new()
	dummy.position = Vector2(shade.attack_range * 0.5, 0)
	shade.set_target(dummy)

	shade.tick(0.0)
	shade.tick(shade.windup_time)
	shade.tick(shade.slash_time * 0.4)
	var in_slash: bool = shade.state == InkShade.State.SLASH and shade.is_attack_active

	# โดนตีด้วย stagger กลาง SLASH -> เข้า HURT และ is_attack_active ต้องเป็น false
	shade.hurtbox.receive(_hit(3, 1.0))
	var hurt_ok: bool = shade.state == InkShade.State.HURT and not shade.is_attack_active

	shade.free()
	dummy.free()
	return in_slash and hurt_ok


## 9. ตายกลาง SLASH -> is_attack_active กลายเป็น false
func test_death_during_slash_clears_attack_active() -> bool:
	var shade: InkShade = _spawn()
	var dummy := Node2D.new()
	dummy.position = Vector2(shade.attack_range * 0.5, 0)
	shade.set_target(dummy)

	shade.tick(0.0)
	shade.tick(shade.windup_time)
	shade.tick(shade.slash_time * 0.4)
	var in_slash: bool = shade.state == InkShade.State.SLASH and shade.is_attack_active

	# โดนตีตายกลาง SLASH -> เข้า DEAD และ is_attack_active ต้องเป็น false
	shade.hurtbox.receive(_hit(999))
	var dead_ok: bool = shade.state == InkShade.State.DEAD and not shade.is_attack_active

	shade.free()
	dummy.free()
	return in_slash and dead_ok


## 10. damage_dealt ยิงหลังหัก HP (เช็ค health.hp ใน callback)
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


## 11. ตายแล้ว emit EventBus.enemy_died ครั้งเดียว และเปลี่ยน state เป็น DEAD
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


## 12. ดาเมจและการเซตาม stagger เทียบ poise
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


## 13. ทิศทางสไปรต์เปลี่ยนตามทิศเป้าหมาย (DirSprite.facing / animation)
func test_facing_direction_follows_target() -> bool:
	var shade: InkShade = _spawn()
	var dummy := Node2D.new()

	# เป้าหมายอยู่ขวา -> หัน EAST (2)
	dummy.global_position = Vector2(80, 0)
	dummy.position = Vector2(80, 0)
	shade.set_target(dummy)
	shade.tick(0.0)
	var east_ok: bool = shade.dir_sprite.facing == Dir8.EAST and shade.dir_sprite.animation == &"walk_east"

	# เป้าหมายอยู่บนขวา -> หัน NORTH_EAST (3)
	dummy.global_position = Vector2(80, -80)
	dummy.position = Vector2(80, -80)
	shade.tick(0.0)
	var ne_ok: bool = shade.dir_sprite.facing == Dir8.NORTH_EAST and shade.dir_sprite.animation == &"walk_north-east"

	# เป้าหมายอยู่ซ้ายล่าง -> หัน SOUTH_WEST (7)
	dummy.global_position = Vector2(-80, 80)
	dummy.position = Vector2(-80, 80)
	shade.tick(0.0)
	var sw_ok: bool = shade.dir_sprite.facing == Dir8.SOUTH_WEST and shade.dir_sprite.animation == &"walk_south-west"

	shade.free()
	dummy.free()
	return east_ok and ne_ok and sw_ok


## 14. WANDER ถ้าไม่คืบหน้าระยะไม่ลดเกิน wander_stuck_time (~1.2s) ให้สุ่มจุดใหม่
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


## 15. DEAD = death แล้วละลายด้วยโค้ด (scale.y -> 0.2, alpha -> 0.0 ตาม corpse_time)
func test_death_melts_via_code() -> bool:
	var shade: InkShade = _spawn()
	shade.hurtbox.receive(_hit(999))
	var dead_ok: bool = shade.state == InkShade.State.DEAD
	var init_scale: bool = is_equal_approx(shade.dir_sprite.scale.y, 1.0)
	var init_alpha: bool = is_equal_approx(shade.dir_sprite.self_modulate.a, 1.0)

	# ช่วงเล่นท่า death (death_anim_time = 1.0s): ยังไม่ละลาย
	shade.tick(shade.death_anim_time * 0.8)
	var before_melt: bool = is_equal_approx(shade.dir_sprite.scale.y, 1.0) and is_equal_approx(shade.dir_sprite.self_modulate.a, 1.0)

	# จบท่า death เริ่มละลาย: scale.y ยุบลงเรื่อย ๆ และ alpha จางลง
	shade.tick(shade.death_anim_time * 0.2 + shade.corpse_time * 0.5)
	var mid_melt: bool = shade.dir_sprite.scale.y < 0.8 and shade.dir_sprite.scale.y > 0.2 \
		and shade.dir_sprite.self_modulate.a < 0.8 and shade.dir_sprite.self_modulate.a > 0.2

	# ครบ corpse_time ละลายสุด scale.y -> 0.2, alpha -> 0.0
	shade.tick(shade.corpse_time * 0.5)
	var final_melt: bool = is_equal_approx(shade.dir_sprite.scale.y, 0.2) \
		and is_equal_approx(shade.dir_sprite.self_modulate.a, 0.0)

	shade.free()
	return dead_ok and init_scale and init_alpha and before_melt and mid_melt and final_melt


## 16. SpriteFrames มีครบทุกท่า (idle, walk, attack, hurt, death) ทั้ง 8 ทิศ
func test_sprite_frames_has_all_anims() -> bool:
	var shade: InkShade = _spawn()
	var sf: SpriteFrames = shade.dir_sprite.sprite_frames
	var ok: bool = sf != null

	var expected_anims := {
		&"idle": 4,
		&"walk": 6,
		&"attack": 9,
		&"hurt": 6,
		&"death": 9,
	}

	for act: StringName in expected_anims:
		var expected_f: int = expected_anims[act]
		for d: int in Dir8.COUNT:
			var anim_name: StringName = DirSprite.anim_name(act, d)
			if not sf.has_animation(anim_name):
				ok = false
				break
			if sf.get_frame_count(anim_name) != expected_f:
				ok = false
				break

	shade.free()
	return ok
