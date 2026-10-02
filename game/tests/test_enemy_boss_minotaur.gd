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
	var mid_candidates: Array[BossMinotaur.AttackType] = boss.get_attack_candidates(100.0)
	var far_candidates: Array[BossMinotaur.AttackType] = boss.get_attack_candidates(200.0)

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
		var m: BossMinotaur.AttackType = boss.choose_attack(100.0)
		var f: BossMinotaur.AttackType = boss.choose_attack(200.0)
		ok = ok and near_expected.has(n)
		ok = ok and mid_expected.has(m)
		ok = ok and far_expected.has(f)

	boss.free()
	return ok


## ห้ามใช้ท่าเดิมซ้ำเกิน 2 ครั้งติด
func test_no_attack_repeated_more_than_twice() -> bool:
	var boss: BossMinotaur = _spawn()
	var distances: Array[float] = [50.0, 100.0, 200.0]
	var history: Array[BossMinotaur.AttackType] = []

	var ok: bool = true
	for _i: int in 120:
		var dist: float = distances[_i % distances.size()]
		var chosen: BossMinotaur.AttackType = boss.choose_attack(dist, true)
		history.append(chosen)
		if boss.consecutive_attack_count > 2:
			ok = false
			break
		if history.size() >= 3:
			var s: int = history.size()
			if history[s - 1] == history[s - 2] and history[s - 2] == history[s - 3]:
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


## hitbox ปิดเมื่อโดนตาย
func test_hitbox_closed_on_death() -> bool:
	var boss: BossMinotaur = _spawn()
	boss.start_attack(BossMinotaur.AttackType.CLEAVE)
	boss.tick(boss.get_windup_time(BossMinotaur.AttackType.CLEAVE))
	var was_active: bool = boss.is_attack_active

	boss.hurtbox.receive(_hit(9999))
	var is_dead: bool = boss.state == BossMinotaur.State.DEAD
	var active_closed: bool = not boss.is_attack_active
	var monitoring_closed: bool = not boss.hitbox.monitoring

	boss.free()
	return was_active and is_dead and active_closed and monitoring_closed


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


## กระโดดทุบ: แสดง TelegraphMarker ที่จุดตกตอน telegraph และซ่อนเมื่อลงพื้น
func test_leap_shows_telegraph_marker() -> bool:
	var boss: BossMinotaur = _spawn()
	var dummy := Node2D.new()
	dummy.position = Vector2(120, 40)
	boss.set_target(dummy)

	boss.start_attack(BossMinotaur.AttackType.LEAP)
	var marker_visible_in_windup: bool = boss.telegraph_marker != null \
		and boss.telegraph_marker.visible \
		and boss.telegraph_marker.global_position.is_equal_approx(dummy.global_position)

	boss.tick(boss.get_windup_time(BossMinotaur.AttackType.LEAP))
	# ใน active บอสกระโดดไปหาจุดตก
	boss.tick(boss.leap_time + 0.05)
	var marker_hidden_after_land: bool = not boss.telegraph_marker.visible

	boss.free()
	dummy.free()
	return marker_visible_in_windup and marker_hidden_after_land


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
