extends RefCounted
## สไลม์ — game/systems/enemy/slime/ · contract: docs/contracts/damage.md

const SLIME_SCENE: PackedScene = preload("res://systems/enemy/slime/slime.tscn")


func _spawn() -> Slime:
	var slime: Slime = SLIME_SCENE.instantiate()
	slime.setup()
	return slime


func _hit(amount: int) -> DamageInfo:
	var info := DamageInfo.new()
	info.team = Combat.Team.PLAYER
	info.amount = amount
	return info


func test_compute_damage_min_one() -> bool:
	return Slime.compute_damage(5, 2) == 3 and Slime.compute_damage(1, 10) == 1


func test_leap_target_clamped_to_max_distance() -> bool:
	var near: Vector2 = Slime.leap_target(Vector2.ZERO, Vector2(30, 40), 80.0)
	var far: Vector2 = Slime.leap_target(Vector2.ZERO, Vector2(300, 400), 80.0)
	return near == Vector2(30, 40) and far.is_equal_approx(Vector2(48, 64))


func test_hurtbox_is_enemy_team_and_hitbox_starts_off() -> bool:
	var slime: Slime = _spawn()
	var ok: bool = slime.hurtbox.team == Combat.Team.ENEMY and slime.hitbox.team == Combat.Team.ENEMY \
		and not slime.hitbox.monitoring and slime.detect.collision_mask == Combat.LAYER_PLAYER
	slime.free()
	return ok


func test_player_hit_damages_and_emits_damage_dealt() -> bool:
	var slime: Slime = _spawn()
	var dealt: Array[int] = []
	var cb := func(t: Node, _i: DamageInfo, amount: int) -> void:
		if t == slime:
			dealt.append(amount)
	EventBus.damage_dealt.connect(cb)
	var landed: bool = slime.hurtbox.receive(_hit(5))
	var same_team: bool = slime.hurtbox.receive(_enemy_hit())
	EventBus.damage_dealt.disconnect(cb)
	var ok: bool = landed and not same_team and dealt == [5] \
		and slime.health.hp == slime.health.max_hp - 5 and slime.state == Slime.State.HURT
	slime.free()
	return ok


func _enemy_hit() -> DamageInfo:
	var info: DamageInfo = _hit(5)
	info.team = Combat.Team.ENEMY
	return info


func test_dies_once_and_emits_enemy_died_once() -> bool:
	var slime: Slime = _spawn()
	var deaths: Array[StringName] = []
	var cb := func(e: Node, id: StringName, _p: Vector2) -> void:
		if e == slime:
			deaths.append(id)
	EventBus.enemy_died.connect(cb)
	slime.hurtbox.receive(_hit(999))
	slime.hurtbox.receive(_hit(999))
	EventBus.enemy_died.disconnect(cb)
	var ok: bool = deaths == [&"slime"] and slime.state == Slime.State.DEAD and slime.health.is_dead
	slime.free()
	return ok


## telegraph ของสไลม์ = ท่าย่อตัว + กระพริบ (state WINDUP) ก่อนเปิด Hitbox
func test_windup_before_leap() -> bool:
	var slime: Slime = _spawn()
	var dummy := Node2D.new()
	dummy.position = Vector2(40, 0)
	slime.set_target(dummy)
	var chasing: bool = slime.state == Slime.State.CHASE
	# ครึ่งหลังของรอบเด้ง (อยู่บนพื้น) + อยู่ในระยะ → windup
	slime._state_t = slime.hop_interval * 0.6
	slime.tick(0.0)
	var winding: bool = slime.state == Slime.State.WINDUP and not slime.hitbox.monitoring
	slime.tick(slime.windup_time)
	var leaping: bool = slime.state == Slime.State.LEAP
	slime.free()
	dummy.free()
	return chasing and winding and leaping


## เฟรมทุกท่าต้องอยู่ใน sprite sheet (กัน sheet กับ ANIMS ไม่ตรงกันหลัง regen)
func test_anim_frames_within_sheet() -> bool:
	var slime: Slime = _spawn()
	var total: int = slime.sprite.hframes * slime.sprite.vframes
	var ok: bool = slime.sprite.texture.get_width() == slime.sprite.hframes * 32
	for anim: StringName in Slime.ANIMS:
		for fr: int in Slime.ANIMS[anim]["frames"]:
			ok = ok and fr >= 0 and fr < total
	slime.free()
	return ok


func test_idle_loops_and_can_blink() -> bool:
	var slime: Slime = _spawn()
	slime.blink_chance = 1.0
	slime._play(&"idle")
	# เกิน 1 รอบหายใจ → รอบใหม่ต้องเป็นรอบกระพริบตา
	slime._tick_anim(1.05)
	var blinking: bool = slime._anim == &"idle_blink"
	slime.blink_chance = 0.0
	slime._tick_anim(1.0)
	var normal: bool = slime._anim == &"idle"
	slime.free()
	return blinking and normal


## ท่าพุ่ง: วงรีชี้ไปทางที่ลอยตลอดทาง (ยอดโค้ง = ยาวไปข้างหน้า) · ตกพื้นแบน · เด้งต่อ 1 ครั้ง · จบที่ระยะรวม
func test_leap_pose_forward_ellipse_and_one_rebound() -> bool:
	var slime: Slime = _spawn()
	var dir := Vector2.RIGHT
	var start: Transform2D = slime.leap_pose(0.01, 80.0, dir)["basis"]
	var apex: Dictionary = slime.leap_pose(slime.leap_time * 0.5, 80.0, dir)
	var hit: Dictionary = slime.leap_pose(slime.leap_time + 0.001, 80.0, dir)
	var total: float = slime.leap_time + slime.squash_time * 2.0 + slime.rebound_time
	var rebound: Dictionary = slime.leap_pose(slime.leap_time + slime.squash_time + slime.rebound_time * 0.5, 80.0, dir)
	var end: Dictionary = slime.leap_pose(total + 0.01, 80.0, dir)
	var apex_b: Transform2D = apex["basis"]
	var hit_b: Transform2D = hit["basis"]
	# ออกตัว: ยืดไปทางขวาบน (แกนยาวชี้ขึ้น+ไปข้างหน้า) · ยอด: ยาวแนวนอน เตี้ยลง
	var start_up_right: Vector2 = start.basis_xform(Vector2(1, -1).normalized())
	var ok: bool = start_up_right.length() > 1.2 \
		and apex_b.x.x > 1.3 and apex_b.y.y < 0.8 and absf(apex["lift"] - slime.leap_height) < 0.01 \
		and hit["landings"] == 1 and hit_b.x.x > 1.4 and hit["lift"] == 0.0 \
		and rebound["lift"] > 0.0 and rebound["lift"] <= slime.rebound_height \
		and end["done"] and end["landings"] == 2 \
		and is_equal_approx(end["travel"], 80.0 + slime.rebound_distance)
	slime.free()
	return ok


## ตกพื้นครั้งแรกแล้วยังอยู่ใน LEAP (เด้งต่อ) → จบเข้า RECOVER ตัวกลับทรงปกติ
## (Hitbox.monitoring เป็น set_deferred เช็คในเทสต์ไม่ได้ — เช็คจำนวนครั้งที่แตะพื้นแทน)
func test_leap_lands_then_rebounds_then_recovers() -> bool:
	var slime: Slime = _spawn()
	var dummy := Node2D.new()
	dummy.position = Vector2(40, 0)
	slime.set_target(dummy)
	slime._enter(Slime.State.WINDUP)
	slime._enter(Slime.State.LEAP)
	slime.tick(slime.leap_time + 0.01)
	var first_land: bool = slime._landings == 1 and slime.state == Slime.State.LEAP
	# เด้งต่อ + แบนรวม ~0.2 วิ (ไม่ถึง recover_time ที่จะกลับไป CHASE)
	for i: int in 24:
		slime.tick(1.0 / 60.0)
	var recovered: bool = slime.state == Slime.State.RECOVER \
		and slime.sprite.transform.is_equal_approx(Transform2D.IDENTITY)
	slime.free()
	dummy.free()
	return first_land and recovered


## เดิน: ลอย = ยืด · ลงพื้น = แบน · ก่อนเด้ง = ย่อเตรียม · กลางช่วงพื้น = ทรงปกติ
func test_hop_pose_squash_and_stretch() -> bool:
	var slime: Slime = _spawn()
	var air: Dictionary = slime.hop_pose(0.05, Vector2.RIGHT)
	var land: Transform2D = slime.hop_pose(0.51, Vector2.RIGHT)["basis"]
	var rest: Transform2D = slime.hop_pose(0.7, Vector2.RIGHT)["basis"]
	var ready: Transform2D = slime.hop_pose(0.99, Vector2.RIGHT)["basis"]
	var air_b: Transform2D = air["basis"]
	var ok: bool = air["lift"] > 0.0 and air_b.basis_xform(Vector2(1, -0.6).normalized()).length() > 1.1 \
		and land.x.x > 1.2 and rest.is_equal_approx(Transform2D.IDENTITY) and ready.x.x > 1.15
	slime.free()
	return ok


## โดนตี: เล่นท่า hurt (ตาหยี) · บี้ตามทิศที่โดน แล้วสั่นจนเกือบนิ่ง
func test_hurt_plays_squint_and_wobble_decays() -> bool:
	var slime: Slime = _spawn()
	var info: DamageInfo = _hit(1)
	info.knockback = Vector2(180, 0)
	slime.hurtbox.receive(info)
	var squint: bool = slime._anim == &"hurt" and slime.sprite.frame == 17
	var hit_b: Transform2D = slime.hurt_pose(0.0, Vector2.RIGHT)
	var late_b: Transform2D = slime.hurt_pose(0.5, Vector2.RIGHT)
	var ok: bool = squint and hit_b.x.x < 0.7 and hit_b.y.y > 1.3 \
		and absf(late_b.x.x - 1.0) < 0.05 and absf(late_b.y.y - 1.0) < 0.05
	slime.free()
	return ok
