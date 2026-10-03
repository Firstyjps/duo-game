extends RefCounted
## บอสมิโนทอร์ — game/systems/enemy/boss_minotaur/ · contract: docs/contracts/damage.md

const BOSS_SCENE: PackedScene = preload("res://systems/enemy/boss_minotaur/boss_minotaur.tscn")


func _spawn() -> BossMinotaur:
	var boss: BossMinotaur = BOSS_SCENE.instantiate()
	boss.setup()
	return boss


func _hit(amount: int, stagger: float = 10.0) -> DamageInfo:
	var info := DamageInfo.new()
	info.team = Combat.Team.PLAYER
	info.amount = amount
	info.stagger = stagger
	return info


func test_hurtbox_is_enemy_team_and_hitbox_starts_off() -> bool:
	var boss: BossMinotaur = _spawn()
	var ok: bool = boss.hurtbox.team == Combat.Team.ENEMY \
		and boss.hitbox.team == Combat.Team.ENEMY \
		and not boss.is_attack_active \
		and not boss.hitbox.monitoring \
		and boss.detect.collision_mask == Combat.LAYER_PLAYER
	boss.free()
	return ok


## ทุกท่ามี windup ก่อน active (ใช้ flag is_attack_active ไม่ใช่ hitbox.monitoring เพราะ set_deferred)
func test_all_attacks_have_windup_before_active() -> bool:
	var boss: BossMinotaur = _spawn()
	var dummy := Node2D.new()
	dummy.position = Vector2(50, 0)
	boss.set_target(dummy)

	var all_attacks: Array[BossMinotaur.AttackType] = [
		BossMinotaur.AttackType.CLEAVE,
		BossMinotaur.AttackType.SWEEP,
		BossMinotaur.AttackType.RISING,
		BossMinotaur.AttackType.CHARGE,
		BossMinotaur.AttackType.STOMP,
		BossMinotaur.AttackType.LEAP,
	]

	var all_ok: bool = true
	for atk: BossMinotaur.AttackType in all_attacks:
		boss.start_attack(atk)
		var is_windup: bool = boss.state == BossMinotaur.State.WINDUP
		var not_active_yet: bool = not boss.is_attack_active
		if not (is_windup and not_active_yet):
			all_ok = false
			break

		# รันจนครบ windup duration
		boss.tick(boss.get_windup_time(atk))
		var is_active: bool = boss.state == BossMinotaur.State.ACTIVE
		if atk == BossMinotaur.AttackType.LEAP:
			# LEAP ช่วงลอยตัวยังไม่เปิด hitbox
			var not_active_in_air: bool = not boss.is_attack_active
			# รันจนลงพื้น
			boss.tick(boss.leap_time)
			var active_flag: bool = boss.is_attack_active
			if not (is_active and not_active_in_air and active_flag):
				all_ok = false
				break
		else:
			var active_flag: bool = boss.is_attack_active
			if not (is_active and active_flag):
				all_ok = false
				break

		# รันจนพ้น active time
		boss.tick(0.6)
		var active_finished: bool = not boss.is_attack_active
		if not active_finished:
			all_ok = false
			break

	boss.free()
	dummy.free()
	return all_ok


## เลือกท่าตามระยะ: ใกล้ = ฟาด/กวาด/เสย, กลาง = กระทืบ, ไกล = พุ่งชน/กระโดดทุบ
func test_attack_selection_by_distance() -> bool:
	var boss: BossMinotaur = _spawn()
	var near_candidates: Array[BossMinotaur.AttackType] = boss.get_attack_candidates(50.0)
	var mid_candidates: Array[BossMinotaur.AttackType] = boss.get_attack_candidates(90.0)
	var far_candidates: Array[BossMinotaur.AttackType] = boss.get_attack_candidates(180.0)

	var near_expected: Array[BossMinotaur.AttackType] = [
		BossMinotaur.AttackType.CLEAVE,
		BossMinotaur.AttackType.SWEEP,
		BossMinotaur.AttackType.RISING,
	]
	var mid_expected: Array[BossMinotaur.AttackType] = [BossMinotaur.AttackType.STOMP]
	var far_expected: Array[BossMinotaur.AttackType] = [
		BossMinotaur.AttackType.CHARGE,
		BossMinotaur.AttackType.LEAP,
	]

	var ok: bool = near_candidates == near_expected \
		and mid_candidates == mid_expected \
		and far_candidates == far_expected

	# ทดสอบการเลือกจริงผ่าน choose_attack
	for _i: int in 20:
		var n: BossMinotaur.AttackType = boss.choose_attack(50.0)
		var m: BossMinotaur.AttackType = boss.choose_attack(90.0)
		var f: BossMinotaur.AttackType = boss.choose_attack(180.0)
		ok = ok and near_expected.has(n)
		ok = ok and mid_expected.has(m)
		ok = ok and far_expected.has(f)

	boss.free()
	return ok


## ห้ามใช้ท่าเดิมซ้ำเกิน 2 ครั้งติด — ทดสอบทั้งที่ระยะกลางอย่างเดียว และระยะอื่น ๆ
func test_no_attack_repeated_more_than_twice() -> bool:
	var boss: BossMinotaur = _spawn()
	var ok: bool = true

	# 1. ทดสอบที่ระยะกลางอย่างเดียว (STOMP ไม่ถูกใช้เกิน 2 ครั้งติด แม้ candidates จะมีแค่ STOMP)
	var mid_history: Array[BossMinotaur.AttackType] = []
	boss.consecutive_attack_count = 0
	boss.last_attack = BossMinotaur.AttackType.CLEAVE
	for _i: int in 60:
		var chosen: BossMinotaur.AttackType = boss.choose_attack(90.0, true)
		mid_history.append(chosen)
		if boss.consecutive_attack_count > 2:
			ok = false
			break
		var s: int = mid_history.size()
		if s >= 3 and mid_history[s - 1] == mid_history[s - 2] and mid_history[s - 2] == mid_history[s - 3]:
			ok = false
			break

	# 2. ทดสอบที่ระยะใกล้
	var near_history: Array[BossMinotaur.AttackType] = []
	boss.consecutive_attack_count = 0
	boss.last_attack = BossMinotaur.AttackType.STOMP
	for _i: int in 60:
		var chosen: BossMinotaur.AttackType = boss.choose_attack(50.0, true)
		near_history.append(chosen)
		if boss.consecutive_attack_count > 2:
			ok = false
			break
		var s: int = near_history.size()
		if s >= 3 and near_history[s - 1] == near_history[s - 2] and near_history[s - 2] == near_history[s - 3]:
			ok = false
			break

	# 3. ทดสอบที่ระยะไกล
	var far_history: Array[BossMinotaur.AttackType] = []
	boss.consecutive_attack_count = 0
	boss.last_attack = BossMinotaur.AttackType.CLEAVE
	for _i: int in 60:
		var chosen: BossMinotaur.AttackType = boss.choose_attack(180.0, true)
		far_history.append(chosen)
		if boss.consecutive_attack_count > 2:
			ok = false
			break
		var s: int = far_history.size()
		if s >= 3 and far_history[s - 1] == far_history[s - 2] and far_history[s - 2] == far_history[s - 3]:
			ok = false
			break

	# 4. ทดสอบระยะสลับกัน
	var distances: Array[float] = [50.0, 90.0, 180.0]
	var mixed_history: Array[BossMinotaur.AttackType] = []
	boss.consecutive_attack_count = 0
	for _i: int in 60:
		var dist: float = distances[_i % distances.size()]
		var chosen: BossMinotaur.AttackType = boss.choose_attack(dist, true)
		mixed_history.append(chosen)
		if boss.consecutive_attack_count > 2:
			ok = false
			break
		var s: int = mixed_history.size()
		if s >= 3 and mixed_history[s - 1] == mixed_history[s - 2] and mixed_history[s - 2] == mixed_history[s - 3]:
			ok = false
			break

	boss.free()
	return ok


## 2 phase: HP < 50% → windup สั้นลง ×0.75
func test_phase_2_transitions_at_half_hp() -> bool:
	var boss: BossMinotaur = _spawn()
	var max_hp: int = boss.health.max_hp # 120
	var half_hp: int = int(float(max_hp) * 0.5) # 60

	boss.health.hp = max_hp
	var full_p2: bool = boss.is_phase_2() # false

	boss.health.hp = half_hp
	var half_p2: bool = boss.is_phase_2() # false (< 50%, not <=)

	boss.health.hp = half_hp - 1
	var below_half_p2: bool = boss.is_phase_2() # true!

	# เช็ค windup duration
	var p1_windup: float = boss.cleave_windup
	var p2_windup: float = boss.get_windup_time(BossMinotaur.AttackType.CLEAVE)
	var expected_p2: float = p1_windup * boss.phase_2_windup_multiplier

	boss.free()
	return (not full_p2) and (not half_p2) and below_half_p2 and is_equal_approx(p2_windup, expected_p2)


## phase 2 เพิ่มคอมโบ (ฟาดเหนือหัว → กวาดขวาน ติดกัน)
func test_phase_2_combo_cleave_to_sweep() -> bool:
	var boss: BossMinotaur = _spawn()
	var dummy := Node2D.new()
	dummy.position = Vector2(40, 0)
	boss.set_target(dummy)

	# เข้า phase 2
	boss.health.hp = int(float(boss.health.max_hp) * 0.5) - 1

	boss.start_attack(BossMinotaur.AttackType.CLEAVE)
	var started_cleave: bool = boss.current_attack == BossMinotaur.AttackType.CLEAVE \
		and boss.state == BossMinotaur.State.WINDUP

	# จบ windup
	boss.tick(boss.get_windup_time(BossMinotaur.AttackType.CLEAVE))
	var active_cleave: bool = boss.state == BossMinotaur.State.ACTIVE

	# จบ active
	boss.tick(boss.melee_active_time)
	var recover_cleave: bool = boss.state == BossMinotaur.State.RECOVER

	# จบ recover → ต้องต่อด้วย SWEEP ทันที
	boss.tick(boss.get_recover_time(BossMinotaur.AttackType.CLEAVE))
	var combo_sweep_started: bool = boss.current_attack == BossMinotaur.AttackType.SWEEP \
		and boss.state == BossMinotaur.State.WINDUP

	boss.free()
	dummy.free()
	return started_cleave and active_cleave and recover_cleave and combo_sweep_started


## boss_engaged emit ครั้งเดียว
func test_boss_engaged_emitted_once() -> bool:
	var boss: BossMinotaur = _spawn()
	var dummy := Node2D.new()
	var engagements: Array[Dictionary] = []

	var cb := func(b: Node, h: Health, n: String) -> void:
		engagements.append({"boss": b, "health": h, "name": n})

	EventBus.boss_engaged.connect(cb)
	boss.set_target(dummy)
	boss.set_target(dummy)
	boss.set_target(dummy)
	EventBus.boss_engaged.disconnect(cb)

	var ok: bool = engagements.size() == 1 \
		and engagements[0]["boss"] == boss \
		and engagements[0]["health"] == boss.health \
		and engagements[0]["name"] == "มิโนทอร์"

	boss.free()
	dummy.free()
	return ok


## enemy_died emit ครั้งเดียว
func test_enemy_died_emitted_once() -> bool:
	var boss: BossMinotaur = _spawn()
	var deaths: Array[Dictionary] = []

	var cb := func(e: Node, id: StringName, pos: Vector2) -> void:
		deaths.append({"enemy": e, "id": id, "pos": pos})

	EventBus.enemy_died.connect(cb)
	boss.hurtbox.receive(_hit(9999))
	boss.hurtbox.receive(_hit(9999))
	EventBus.enemy_died.disconnect(cb)

	var ok: bool = deaths.size() == 1 \
		and deaths[0]["enemy"] == boss \
		and deaths[0]["id"] == &"boss_minotaur" \
		and boss.state == BossMinotaur.State.DEAD \
		and boss.health.is_dead

	boss.free()
	return ok


## hitbox ปิดเมื่อโดนตาย (ตรวจผ่าน is_attack_active)
func test_hitbox_closed_on_death() -> bool:
	var boss: BossMinotaur = _spawn()
	boss.start_attack(BossMinotaur.AttackType.CLEAVE)
	boss.tick(boss.get_windup_time(BossMinotaur.AttackType.CLEAVE))
	var was_active: bool = boss.is_attack_active

	boss.hurtbox.receive(_hit(9999))
	var is_dead: bool = boss.state == BossMinotaur.State.DEAD
	var active_closed: bool = not boss.is_attack_active

	boss.free()
	return was_active and is_dead and active_closed


## poise สูง: เซเฉพาะ stagger สะสมเกิน poise แล้วรีเซ็ต
func test_poise_stagger_mechanic() -> bool:
	var boss: BossMinotaur = _spawn()
	boss.poise = 60.0
	boss.accumulated_stagger = 0.0

	# ตีเบา stagger = 25 (ยังไม่เกิน 60)
	boss.hurtbox.receive(_hit(2, 25.0))
	var ok1: bool = boss.state != BossMinotaur.State.HURT \
		and is_equal_approx(boss.accumulated_stagger, 25.0)

	# ตีอีก 25 รวมเป็น 50 (ยังไม่เกิน 60)
	boss.hurtbox.receive(_hit(2, 25.0))
	var ok2: bool = boss.state != BossMinotaur.State.HURT \
		and is_equal_approx(boss.accumulated_stagger, 50.0)

	# ตีอีก 20 รวมเป็น 70 >= 60 → เซเข้า HURT และรีเซ็ต stagger เป็น 0
	boss.hurtbox.receive(_hit(2, 20.0))
	var ok3: bool = boss.state == BossMinotaur.State.HURT \
		and is_equal_approx(boss.accumulated_stagger, 0.0)

	boss.free()
	return ok1 and ok2 and ok3


## TelegraphMarker ซ่อนตอนเข้า RECOVER (ไม่ซ่อนตอนเริ่มกระโดด) + AoE hitbox scale squash + STOMP แสดง marker ตอน windup
func test_telegraph_marker_lifecycle_and_squash() -> bool:
	var boss: BossMinotaur = _spawn()
	var dummy := Node2D.new()
	dummy.position = Vector2(120, 40)
	boss.set_target(dummy)

	# 1. LEAP: แสดงที่จุดตกตอน windup
	boss.start_attack(BossMinotaur.AttackType.LEAP)
	var leap_marker_windup: bool = boss.telegraph_marker != null \
		and boss.telegraph_marker.visible \
		and boss.telegraph_marker.global_position.is_equal_approx(dummy.global_position)

	# ระหว่างลอยตัวใน ACTIVE: marker ยังต้องแสดงอยู่
	boss.tick(boss.get_windup_time(BossMinotaur.AttackType.LEAP))
	boss.tick(boss.leap_time * 0.5)
	var leap_marker_in_air: bool = boss.telegraph_marker.visible

	# ตอนลงพื้น: hitbox_shape.scale เป็น squash วงรี และ marker ยังอยู่
	boss.tick(boss.leap_time * 0.5 + 0.02)
	var leap_squash_ok: bool = is_equal_approx(boss.hitbox_shape.scale.y, boss.telegraph_marker.squash)
	var leap_marker_on_land: bool = boss.telegraph_marker.visible

	# เข้า RECOVER: marker ซ่อน
	boss.tick(boss.leap_active_time + 0.05)
	var leap_hidden_in_recover: bool = not boss.telegraph_marker.visible \
		and boss.state == BossMinotaur.State.RECOVER

	# 2. STOMP: แสดง marker ตอน windup ที่จุดบอสยืน
	boss.start_attack(BossMinotaur.AttackType.STOMP)
	var stomp_marker_windup: bool = boss.telegraph_marker.visible \
		and boss.telegraph_marker.global_position.is_equal_approx(boss.global_position)

	boss.tick(boss.get_windup_time(BossMinotaur.AttackType.STOMP))
	# ใน active hitbox ของ STOMP เป็น squash วงรี
	var stomp_squash_ok: bool = is_equal_approx(boss.hitbox_shape.scale.y, boss.telegraph_marker.squash)
	var stomp_marker_active: bool = boss.telegraph_marker.visible

	# เข้า RECOVER: marker ซ่อน
	boss.tick(boss.stomp_active_time + 0.05)
	var stomp_hidden_in_recover: bool = not boss.telegraph_marker.visible \
		and boss.state == BossMinotaur.State.RECOVER

	boss.free()
	dummy.free()
	return leap_marker_windup and leap_marker_in_air and leap_squash_ok and leap_marker_on_land \
		and leap_hidden_in_recover and stomp_marker_windup and stomp_squash_ok and stomp_marker_active \
		and stomp_hidden_in_recover


## พุ่งชน: ล็อคทิศตอน telegraph
func test_charge_locks_direction() -> bool:
	var boss: BossMinotaur = _spawn()
	var dummy := Node2D.new()
	dummy.position = Vector2(150, 0) # ทิศขวา (EAST)
	boss.set_target(dummy)

	boss.start_attack(BossMinotaur.AttackType.CHARGE)
	var locked_dir: Vector2 = boss._charge_dir

	# ย้ายเป้าหมายไประหว่าง windup
	dummy.position = Vector2(0, 150) # ทิศล่าง (SOUTH)
	boss.tick(boss.charge_windup * 0.5)

	# ทิศพุ่งยังต้องเป็นทิศเดิมที่ล็อคไว้ตอนเริ่ม windup
	var still_locked: bool = boss._charge_dir.is_equal_approx(locked_dir)

	boss.free()
	dummy.free()
	return locked_dir.is_equal_approx(Vector2.RIGHT) and still_locked


## โดนเซกลาง ACTIVE → hitbox ปิดทันที
func test_stagger_in_active_closes_hitbox() -> bool:
	var boss: BossMinotaur = _spawn()
	boss.start_attack(BossMinotaur.AttackType.CLEAVE)
	boss.tick(boss.get_windup_time(BossMinotaur.AttackType.CLEAVE))
	var was_active: bool = boss.is_attack_active

	# โดนตีจนเซกลาง active (stagger >= poise 60.0)
	boss.hurtbox.receive(_hit(10, 80.0))
	var is_hurt: bool = boss.state == BossMinotaur.State.HURT
	var hitbox_closed: bool = not boss.is_attack_active

	boss.free()
	return was_active and is_hurt and hitbox_closed


## LEAP: hitbox เปิดเฉพาะตอนลงพื้น (ไม่เปิดตอนลอยตัว)
func test_leap_hitbox_active_only_on_landing() -> bool:
	var boss: BossMinotaur = _spawn()
	var dummy := Node2D.new()
	dummy.position = Vector2(150, 0)
	boss.set_target(dummy)

	boss.start_attack(BossMinotaur.AttackType.LEAP)
	boss.tick(boss.get_windup_time(BossMinotaur.AttackType.LEAP))
	var is_active_state: bool = boss.state == BossMinotaur.State.ACTIVE

	# ระหว่างลอยตัว (ยังไม่ถึง leap_time) → hitbox ต้องยังไม่เปิด!
	boss.tick(boss.leap_time * 0.5)
	var not_active_in_air: bool = not boss.is_attack_active

	# ถึงจุดตก (ลงพื้น) → hitbox เปิด!
	boss.tick(boss.leap_time * 0.5 + 0.01)
	var active_on_land: bool = boss.is_attack_active

	# พ้น active time → ปิด
	boss.tick(boss.leap_active_time + 0.05)
	var closed_in_recover: bool = not boss.is_attack_active and boss.state == BossMinotaur.State.RECOVER

	boss.free()
	dummy.free()
	return is_active_state and not_active_in_air and active_on_land and closed_in_recover


## โดนตีระหว่าง windup ของ LEAP → marker หาย
func test_hit_during_leap_windup_hides_marker() -> bool:
	var boss: BossMinotaur = _spawn()
	var dummy := Node2D.new()
	dummy.position = Vector2(150, 0)
	boss.set_target(dummy)

	boss.start_attack(BossMinotaur.AttackType.LEAP)
	var marker_visible_before: bool = boss.telegraph_marker != null and boss.telegraph_marker.visible

	# โดนตีจนเซระหว่าง windup (stagger >= poise)
	boss.hurtbox.receive(_hit(10, 80.0))
	var is_hurt: bool = boss.state == BossMinotaur.State.HURT
	var marker_hidden_after_hit: bool = not boss.telegraph_marker.visible

	boss.free()
	dummy.free()
	return marker_visible_before and is_hurt and marker_hidden_after_hit


## ทุกท่าที่ถูกเลือกที่ระยะ d ตีถึง d (reach >= d)
func test_every_chosen_attack_reaches_target_distance() -> bool:
	var boss: BossMinotaur = _spawn()
	var ok: bool = true
	var test_dists: Array[float] = [10.0, 30.0, 50.0, 70.0, 85.0, 95.0, 110.0, 140.0, 180.0, 220.0, 240.0]
	for d: float in test_dists:
		for _i: int in 30:
			var atk: BossMinotaur.AttackType = boss.choose_attack(d, true)
			var reach: float = boss.get_attack_reach(atk)
			if reach < d:
				ok = false
				break
		if not ok:
			break

	boss.free()
	return ok


## เซแล้วมีแรงกระเด็น (velocity ตั้งหลัง _enter(State.HURT))
func test_hurt_sets_knockback_velocity() -> bool:
	var boss: BossMinotaur = _spawn()
	boss.velocity = Vector2.ZERO
	var hit_info: DamageInfo = _hit(10, 80.0)
	hit_info.knockback = Vector2(240, 120)

	boss.hurtbox.receive(hit_info)
	var is_hurt: bool = boss.state == BossMinotaur.State.HURT
	var has_knockback: bool = boss.velocity.is_equal_approx(hit_info.knockback * 0.5)

	boss.free()
	return is_hurt and has_knockback


## กวาด (SWEEP) = ครึ่งวงหน้าจริง (ไม่ล้นหลังบอส)
func test_sweep_hitbox_is_front_semicircle() -> bool:
	var boss: BossMinotaur = _spawn()
	boss.start_attack(BossMinotaur.AttackType.SWEEP)
	boss.tick(boss.get_windup_time(BossMinotaur.AttackType.SWEEP))

	var is_poly: bool = boss.hitbox_shape.shape is ConvexPolygonShape2D
	var poly: ConvexPolygonShape2D = boss.hitbox_shape.shape as ConvexPolygonShape2D
	var pts: PackedVector2Array = poly.points

	var facing_vec: Vector2 = boss._attack_facing_vec
	var no_leak_behind: bool = true
	for pt: Vector2 in pts:
		if pt.length_squared() > 1.0:
			if pt.normalized().dot(facing_vec) < -0.05:
				no_leak_behind = false
				break

	boss.free()
	return is_poly and no_leak_behind


## กระโดดทุบ: จุดตก clamp ไม่ให้ลงในกำแพง (ถ้าอยู่นอก tree หรือไม่มี space_state ให้คืนตำแหน่งเดิมอย่างปลอดภัย)
func test_leap_clamp_wall_safe_fallback() -> bool:
	var boss: BossMinotaur = _spawn()
	var pos: Vector2 = boss._clamp_leap_position(Vector2(100, 0), Vector2.ZERO)
	var ok: bool = pos.is_equal_approx(Vector2(100, 0))
	boss.free()
	return ok


func _make_player_dummy() -> CharacterBody2D:
	var dummy := CharacterBody2D.new()
	var hb := Hurtbox.new()
	hb.name = "Hurtbox"
	hb.team = Combat.Team.PLAYER
	var col := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 10.0
	col.shape = c
	col.position = Vector2(0, -16)
	hb.add_child(col)
	dummy.add_child(hb)
	return dummy


## STOMP โดนทุกทิศ 8 ทิศที่ระยะที่ AI เลือก ด้วย physics จริง (Hurtbox รัศมี 10 ที่ y -16)
func test_stomp_hits_all_8_directions_real_physics() -> bool:
	var root: Window = Engine.get_main_loop().root
	var boss: BossMinotaur = _spawn()
	boss.global_position = Vector2(400, 400)
	root.add_child(boss)

	var dummy: CharacterBody2D = _make_player_dummy()
	root.add_child(dummy)

	await (Engine.get_main_loop() as SceneTree).physics_frame
	await (Engine.get_main_loop() as SceneTree).physics_frame

	var hurtbox: Hurtbox = dummy.get_node("Hurtbox") as Hurtbox
	var hit_count: Array[int] = [0]
	hurtbox.hurt.connect(func(_i: DamageInfo) -> void: hit_count[0] += 1)

	var sq: float = boss.telegraph_marker.squash
	var test_ground_dist: float = 90.0
	var all_hit: bool = true

	var dir_angles: Array[float] = [
		0.0,
		PI * 0.25,
		PI * 0.5,
		PI * 0.75,
		PI,
		-PI * 0.75,
		-PI * 0.5,
		-PI * 0.25,
	]

	for angle: float in dir_angles:
		hit_count[0] = 0
		boss.consecutive_attack_count = 0
		boss.last_attack = BossMinotaur.AttackType.CLEAVE
		var dx: float = cos(angle) * test_ground_dist
		var dy: float = sin(angle) * (test_ground_dist * sq)
		dummy.global_position = boss.global_position + Vector2(dx, dy)
		boss.set_target(dummy)

		var chosen: BossMinotaur.AttackType = boss.choose_attack(Vector2(dx, dy))
		if chosen != BossMinotaur.AttackType.STOMP:
			all_hit = false
			break

		boss.start_attack(BossMinotaur.AttackType.STOMP)
		boss.tick(boss.get_windup_time(BossMinotaur.AttackType.STOMP) + 0.01)

		await (Engine.get_main_loop() as SceneTree).physics_frame
		await (Engine.get_main_loop() as SceneTree).physics_frame
		await (Engine.get_main_loop() as SceneTree).physics_frame

		if hit_count[0] == 0:
			all_hit = false
			break

		boss._enter(BossMinotaur.State.IDLE)

	root.remove_child(boss)
	root.remove_child(dummy)
	boss.free()
	dummy.free()
	return all_hit


## LEAP โดนทุกทิศ 8 ทิศที่ระยะที่ AI เลือก ด้วย physics จริง
func test_leap_hits_all_8_directions_real_physics() -> bool:
	var root: Window = Engine.get_main_loop().root
	var boss: BossMinotaur = _spawn()
	boss.global_position = Vector2(400, 400)
	root.add_child(boss)

	var dummy: CharacterBody2D = _make_player_dummy()
	root.add_child(dummy)

	await (Engine.get_main_loop() as SceneTree).physics_frame
	await (Engine.get_main_loop() as SceneTree).physics_frame

	var hurtbox: Hurtbox = dummy.get_node("Hurtbox") as Hurtbox
	var hit_count: Array[int] = [0]
	hurtbox.hurt.connect(func(_i: DamageInfo) -> void: hit_count[0] += 1)

	var sq: float = boss.telegraph_marker.squash
	var test_ground_dist: float = 160.0
	var all_hit: bool = true

	var dir_angles: Array[float] = [
		0.0,
		PI * 0.25,
		PI * 0.5,
		PI * 0.75,
		PI,
		-PI * 0.75,
		-PI * 0.5,
		-PI * 0.25,
	]

	for angle: float in dir_angles:
		hit_count[0] = 0
		boss.global_position = Vector2(400, 400)
		boss.consecutive_attack_count = 0
		boss.last_attack = BossMinotaur.AttackType.CLEAVE

		var dx: float = cos(angle) * test_ground_dist
		var dy: float = sin(angle) * (test_ground_dist * sq)
		dummy.global_position = boss.global_position + Vector2(dx, dy)
		boss.set_target(dummy)

		var candidates: Array[BossMinotaur.AttackType] = boss.get_attack_candidates(test_ground_dist, Vector2(dx, dy))
		if not candidates.has(BossMinotaur.AttackType.LEAP):
			all_hit = false
			break

		boss.start_attack(BossMinotaur.AttackType.LEAP)
		boss.tick(boss.get_windup_time(BossMinotaur.AttackType.LEAP))
		boss.tick(boss.leap_time)

		await (Engine.get_main_loop() as SceneTree).physics_frame
		await (Engine.get_main_loop() as SceneTree).physics_frame
		await (Engine.get_main_loop() as SceneTree).physics_frame

		if hit_count[0] == 0:
			all_hit = false
			break

		boss._enter(BossMinotaur.State.IDLE)
		await (Engine.get_main_loop() as SceneTree).physics_frame

	root.remove_child(boss)
	root.remove_child(dummy)
	boss.free()
	dummy.free()
	return all_hit


## จุดตก LEAP: ตรวจด้วย shape วงกลมรัศมีตัวบอส มีกำแพง StaticBody2D จริง
func test_leap_clamp_with_real_static_body_wall() -> bool:
	var root: Window = Engine.get_main_loop().root
	var boss: BossMinotaur = _spawn()
	boss.global_position = Vector2(100, 300)
	root.add_child(boss)

	var wall := StaticBody2D.new()
	wall.collision_layer = Combat.LAYER_WORLD
	var wcol := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(100, 100)
	wcol.shape = rect
	wall.add_child(wcol)
	wall.position = Vector2(300, 300)
	root.add_child(wall)

	await (Engine.get_main_loop() as SceneTree).physics_frame
	await (Engine.get_main_loop() as SceneTree).physics_frame

	var inside_wall_target: Vector2 = Vector2(300, 300)
	var clamped: Vector2 = boss._clamp_leap_position(inside_wall_target, boss.global_position)

	var space_state: PhysicsDirectSpaceState2D = root.get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 16.0
	query.shape = circle
	query.collision_mask = Combat.LAYER_WORLD
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.transform = Transform2D(0.0, clamped + Vector2(0, -10))

	var hits: Array[Dictionary] = space_state.intersect_shape(query, 1)
	var ok: bool = hits.is_empty() and clamped.x < 250.0

	root.remove_child(boss)
	root.remove_child(wall)
	boss.free()
	wall.free()
	return ok


## Screen shake contract: กระทืบ 0.5, กระโดดทุบลงพื้น 0.6, เดินคอลัมน์ 4/8 0.12, เข่ากระแทกตาย 0.3
func test_screen_shake_requested_emits() -> bool:
	var boss: BossMinotaur = _spawn()
	var shakes: Array[Dictionary] = []
	var cb := func(strength: float, pos: Vector2) -> void:
		shakes.append({"strength": strength, "pos": pos})
	EventBus.screen_shake_requested.connect(cb)

	# 1. กระทืบเข้า ACTIVE: 0.5
	boss.start_attack(BossMinotaur.AttackType.STOMP)
	boss.tick(boss.get_windup_time(BossMinotaur.AttackType.STOMP) + 0.01)
	var stomp_ok: bool = shakes.size() == 1 \
		and is_equal_approx(shakes[0]["strength"], boss.stomp_screen_shake)

	# 2. กระโดดทุบลงพื้น: 0.6
	boss._enter(BossMinotaur.State.IDLE)
	boss.start_attack(BossMinotaur.AttackType.LEAP)
	boss.tick(boss.get_windup_time(BossMinotaur.AttackType.LEAP) + 0.01)
	var before_land_count: int = shakes.size()
	boss.tick(boss.leap_time + 0.01) # ลงพื้น
	var leap_ok: bool = shakes.size() == before_land_count + 1 \
		and is_equal_approx(shakes[shakes.size() - 1]["strength"], boss.leap_screen_shake)

	# 3. เดิน: เท้ากระแทกตอนคอลัมน์ 4 และ 8
	var dummy := Node2D.new()
	dummy.position = boss.global_position + Vector2(300, 0)
	boss._enter(BossMinotaur.State.IDLE)
	boss.set_target(dummy)
	shakes.clear()
	# จำลองเดิน 1 รอบเต็ม (0.8 วินาที)
	for _i: int in 20:
		boss.tick(0.05)
	var walk_shakes: Array[float] = []
	for s: Dictionary in shakes:
		walk_shakes.append(s["strength"])
	var walk_ok: bool = walk_shakes.size() >= 2 and is_equal_approx(walk_shakes[0], boss.footstep_screen_shake)

	# 4. เข่ากระแทกตอนตาย (เฟรม 54): 0.3
	shakes.clear()
	boss._on_died() # เข้า State.DEAD
	boss.tick(0.1) # frame 52
	var death_not_yet: bool = shakes.is_empty()
	boss.tick(0.2) # frame 54
	var death_ok: bool = death_not_yet and shakes.size() == 1 \
		and is_equal_approx(shakes[0]["strength"], boss.death_knee_screen_shake)

	EventBus.screen_shake_requested.disconnect(cb)
	boss.free()
	dummy.free()
	return stomp_ok and leap_ok and walk_ok and death_ok


## Parry deflect: ท่าประชิดและพุ่งชนโดนปัดแล้วเซเข้า State.HURT + ถอยหลัง, กระทืบ/กระโดดทุบไม่เซ
func test_hitbox_deflected_parry_behavior() -> bool:
	var boss: BossMinotaur = _spawn()
	var def_hurtbox := Hurtbox.new()
	def_hurtbox.team = Combat.Team.PLAYER
	def_hurtbox.deflecting = true

	var ok: bool = true

	# 1. ท่าประชิด CLEAVE โดน deflect -> HURT + velocity ถอยหลัง
	boss.start_attack(BossMinotaur.AttackType.CLEAVE)
	boss.tick(boss.get_windup_time(BossMinotaur.AttackType.CLEAVE))
	boss.hitbox.try_hit(def_hurtbox)
	var cleave_staggered: bool = boss.state == BossMinotaur.State.HURT \
		and is_equal_approx(boss._current_hurt_duration, boss.parried_stagger_time) \
		and boss.velocity.length() > 0.0
	ok = ok and cleave_staggered

	# 2. SWEEP
	boss._enter(BossMinotaur.State.IDLE)
	boss.start_attack(BossMinotaur.AttackType.SWEEP)
	boss.tick(boss.get_windup_time(BossMinotaur.AttackType.SWEEP))
	boss.hitbox.try_hit(def_hurtbox)
	ok = ok and (boss.state == BossMinotaur.State.HURT)

	# 3. RISING
	boss._enter(BossMinotaur.State.IDLE)
	boss.start_attack(BossMinotaur.AttackType.RISING)
	boss.tick(boss.get_windup_time(BossMinotaur.AttackType.RISING))
	boss.hitbox.try_hit(def_hurtbox)
	ok = ok and (boss.state == BossMinotaur.State.HURT)

	# 4. CHARGE โดน deflect -> HURT + velocity ถอยหลัง
	boss._enter(BossMinotaur.State.IDLE)
	boss.start_attack(BossMinotaur.AttackType.CHARGE)
	boss.tick(boss.get_windup_time(BossMinotaur.AttackType.CHARGE))
	boss.hitbox.try_hit(def_hurtbox)
	var charge_staggered: bool = boss.state == BossMinotaur.State.HURT \
		and boss.velocity.dot(boss._charge_dir) < 0.0 # velocity ถอยหลัง
	ok = ok and charge_staggered

	# 5. STOMP โดน deflect -> ไม่เซ (ยังคงเป็น ACTIVE)
	boss._enter(BossMinotaur.State.IDLE)
	boss.start_attack(BossMinotaur.AttackType.STOMP)
	boss.tick(boss.get_windup_time(BossMinotaur.AttackType.STOMP))
	boss.hitbox.try_hit(def_hurtbox)
	var stomp_not_staggered: bool = boss.state == BossMinotaur.State.ACTIVE
	ok = ok and stomp_not_staggered

	# 6. LEAP โดน deflect -> ไม่เซ (ยังคงเป็น ACTIVE)
	boss._enter(BossMinotaur.State.IDLE)
	boss.start_attack(BossMinotaur.AttackType.LEAP)
	boss.tick(boss.get_windup_time(BossMinotaur.AttackType.LEAP))
	boss.tick(boss.leap_time) # landing
	boss.hitbox.try_hit(def_hurtbox)
	var leap_not_staggered: bool = boss.state == BossMinotaur.State.ACTIVE
	ok = ok and leap_not_staggered

	boss.free()
	def_hurtbox.free()
	return ok


## setup() ไม่เขียนทับ stomp_radius · รัศมีจริงครอบระยะที่ AI เลือกกระทืบ + เผื่อ hurtbox · แต่ไม่ใหญ่จนถึงระยะไกล
func test_stomp_reach_not_inflated() -> bool:
	var boss: BossMinotaur = _spawn()
	var export_kept: bool = is_equal_approx(boss.stomp_radius, 120.0)
	var reach: float = boss.stomp_reach()
	var covers: bool = reach >= boss.mid_attack_range + boss.stomp_reach_margin
	var not_huge: bool = reach < 200.0 and boss.get_attack_reach(BossMinotaur.AttackType.STOMP) == reach
	boss.free()
	return export_kept and covers and not_huge
