extends RefCounted
## บอสสไลม์ — game/systems/enemy/boss_slime/ · issue #67
## contract: docs/contracts/damage.md, feedback.md

const BOSS_SCENE: PackedScene = preload("res://systems/enemy/boss_slime/boss_slime.tscn")


func _spawn() -> BossSlime:
	var boss: BossSlime = BOSS_SCENE.instantiate()
	boss.setup()
	return boss


func _hit(amount: int, stagger: float = 0.0) -> DamageInfo:
	var info := DamageInfo.new()
	info.team = Combat.Team.PLAYER
	info.amount = amount
	info.stagger = stagger
	return info


func test_setup_nodes_and_defaults() -> bool:
	var boss: BossSlime = _spawn()
	var ok: bool = boss.enemy_id == &"boss_slime" \
		and boss.sprite != null and boss.sprite.hframes == 20 \
		and boss.sprite.offset == Vector2(0, -56) \
		and boss.health != null and boss.health.max_hp == 150 and boss.health.hp == 150 \
		and boss.hurtbox != null and boss.hurtbox.team == Combat.Team.ENEMY \
		and boss.hitbox != null and boss.hitbox.team == Combat.Team.ENEMY \
		and not boss.hitbox.monitoring and not boss.is_attack_active \
		and boss.detect != null and boss.detect.collision_mask == Combat.LAYER_PLAYER \
		and boss.telegraph_marker != null and boss.telegraph_marker.top_level \
		and is_equal_approx(boss.telegraph_marker.squash, 0.55) \
		and boss.hitbox_shape != null and is_equal_approx(boss.hitbox_shape.scale.y, 0.55)
	boss.free()
	return ok


## boss_engaged ครั้งแรกที่เห็นผู้เล่น · enemy_died ครั้งเดียวเมื่อตาย
func test_boss_engaged_emitted_once_and_enemy_died_emitted_once() -> bool:
	var boss: BossSlime = _spawn()
	var engaged_events: Array[Dictionary] = []
	var on_engaged := func(b: Node, h: Health, dname: String) -> void:
		if b == boss:
			engaged_events.append({"boss": b, "health": h, "name": dname})
	EventBus.boss_engaged.connect(on_engaged)

	var died_events: Array[Dictionary] = []
	var on_died := func(e: Node, id: StringName, pos: Vector2) -> void:
		if e == boss:
			died_events.append({"enemy": e, "id": id, "pos": pos})
	EventBus.enemy_died.connect(on_died)

	var dummy := Node2D.new()
	dummy.position = Vector2(80, 0)

	# เห็นผู้เล่นครั้งแรก -> emit boss_engaged
	boss.set_target(dummy)
	var first_engage_ok: bool = engaged_events.size() == 1 \
		and engaged_events[0]["boss"] == boss \
		and engaged_events[0]["name"] == boss.display_name

	# กระตุ้น target หรือ body ซ้ำ -> ต้องไม่ emit ซ้ำ
	boss.set_target(dummy)
	boss._on_body_entered(dummy)
	var engage_once_ok: bool = engaged_events.size() == 1

	# โดนดาเมจถึงตาย -> emit enemy_died ครั้งเดียว
	boss.hurtbox.receive(_hit(999))
	var dead_first_ok: bool = died_events.size() == 1 \
		and died_events[0]["id"] == &"boss_slime" \
		and boss.state == BossSlime.State.DEAD and boss.health.is_dead

	# ตีซ้ำตอนตายแล้ว -> ต้องไม่ emit ซ้ำ
	boss.hurtbox.receive(_hit(999))
	var dead_once_ok: bool = died_events.size() == 1

	EventBus.boss_engaged.disconnect(on_engaged)
	EventBus.enemy_died.disconnect(on_died)
	dummy.free()
	boss.free()
	return first_engage_ok and engage_once_ok and dead_first_ok and dead_once_ok


## ท่าทุบพื้น: rise ค้าง telegraph ก่อน active (flag is_attack_active) + screen_shake_requested 0.5
func test_slam_telegraph_before_active_and_shake() -> bool:
	var boss: BossSlime = _spawn()
	var dummy := Node2D.new()
	dummy.position = Vector2(40, 0)
	boss.set_target(dummy)

	boss._enter(BossSlime.State.SLAM_WINDUP)
	var telegraph_start_ok: bool = not boss.is_attack_active \
		and boss.telegraph_marker.visible \
		and is_equal_approx(boss.telegraph_marker.progress, 0.0)

	# ระหว่าง windup hitbox ต้องยังไม่ active
	boss.tick(boss.slam_windup_time * 0.5)
	var during_windup_ok: bool = not boss.is_attack_active and boss.telegraph_marker.visible

	var shakes: Array[float] = []
	var on_shake := func(strength: float, _pos: Vector2) -> void:
		shakes.append(strength)
	EventBus.screen_shake_requested.connect(on_shake)

	# ครบเวลา windup -> SLAM_ACTIVE: is_attack_active = true, shake 0.5
	boss.tick(boss.slam_windup_time * 0.5 + 0.01)
	var active_ok: bool = boss.state == BossSlime.State.SLAM_ACTIVE \
		and boss.is_attack_active \
		and not boss.telegraph_marker.visible \
		and shakes.size() == 1 and is_equal_approx(shakes[0], 0.5)

	# จบช่วง active -> SLAM_RECOVER: is_attack_active ปิด
	boss.tick(boss.slam_active_time + 0.01)
	var recover_ok: bool = boss.state == BossSlime.State.SLAM_RECOVER and not boss.is_attack_active

	EventBus.screen_shake_requested.disconnect(on_shake)
	dummy.free()
	boss.free()
	return telegraph_start_ok and during_windup_ok and active_ok and recover_ok


## ท่ากระโดดทับ: telegraph ที่จุดตก -> ลอย (ไม่มี hitbox) -> ตกทับ AoE active + shake 0.6
func test_leap_no_hitbox_while_airborne_and_shake_on_landing() -> bool:
	var boss: BossSlime = _spawn()
	var dummy := Node2D.new()
	dummy.position = Vector2(100, 0)
	boss.set_target(dummy)

	boss._enter(BossSlime.State.LEAP_WINDUP)
	var windup_ok: bool = not boss.is_attack_active and boss.telegraph_marker.visible

	# จบ windup เข้าสู่ LEAP_AIRBORNE
	boss.tick(boss.leap_windup_time + 0.01)
	boss.tick(0.05)
	var airborne_ok: bool = boss.state == BossSlime.State.LEAP_AIRBORNE \
		and not boss.is_attack_active \
		and boss._lift > 0.0

	var shakes: Array[float] = []
	var on_shake := func(strength: float, _pos: Vector2) -> void:
		shakes.append(strength)
	EventBus.screen_shake_requested.connect(on_shake)

	# จบการลอย (เวลาที่เหลือของ leap_air_time) -> ตกทับ (LEAP_IMPACT) -> active + shake 0.6
	boss.tick(boss.leap_air_time - 0.05 + 0.01)
	var impact_ok: bool = boss.state == BossSlime.State.LEAP_IMPACT \
		and boss.is_attack_active \
		and not boss.telegraph_marker.visible \
		and shakes.size() == 1 and is_equal_approx(shakes[0], 0.6)

	# จบ impact -> LEAP_RECOVER -> ปิด active
	boss.tick(boss.leap_impact_time + 0.01)
	var recover_ok: bool = boss.state == BossSlime.State.LEAP_RECOVER and not boss.is_attack_active

	EventBus.screen_shake_requested.disconnect(on_shake)
	dummy.free()
	boss.free()
	return windup_ok and airborne_ok and impact_ok and recover_ok


## แตกลูก: เกิดเฉพาะ Phase 2 (HP < 50%) และจำกัดจำนวนลูกที่ยังมีชีวิต <= 4
func test_split_only_in_phase_2_and_limits_alive_count() -> bool:
	var boss: BossSlime = _spawn()
	var dummy := Node2D.new()
	dummy.position = Vector2(50, 0)
	boss.set_target(dummy)

	# Phase 1: เลือดเต็ม (150/150) -> can_split ต้อง false, spawn ต้องไม่เกิดลูก
	var p1_no_split: bool = not boss.is_phase_2() and not boss.can_split()
	boss._spawn_minions()
	var p1_count_zero: bool = boss.get_alive_minions_count() == 0

	# ลดเลือดลงต่ำกว่า 50% (เช่น เหลือ 50/150) -> เข้า Phase 2
	boss.health.take_damage(100)
	var p2_ok: bool = boss.is_phase_2() and boss.can_split()

	# ทดสอบ telegraph ของท่าแตกลูก (ไม่มี hitbox active)
	boss._enter(BossSlime.State.SPLIT_WINDUP)
	var split_windup_ok: bool = not boss.is_attack_active

	# จบ windup -> แตกลูก
	boss.tick(boss.split_windup_time + 0.01)
	var spawned_count: int = boss.get_alive_minions_count()
	var spawn_first_ok: bool = spawned_count >= 2 and spawned_count <= 3

	# สั่งแตกลูกเพิ่ม -> ต้องไม่เกิน max_living_minions (4)
	boss._spawn_minions()
	var count_after_second: int = boss.get_alive_minions_count()
	var cap_ok: bool = count_after_second <= boss.max_living_minions

	# ถ้าลูกเต็ม 4 แล้ว สั่ง spawn เพิ่มต้องไม่เพิ่มเกิน 4
	boss._spawn_minions()
	var final_cap_ok: bool = boss.get_alive_minions_count() <= 4

	# ล้างลูกที่ spawn ไว้ในเทสต์
	for m: Node in boss._minions:
		if is_instance_valid(m):
			m.free()
	boss._minions.clear()
	dummy.free()
	boss.free()
	return p1_no_split and p1_count_zero and p2_ok and split_windup_ok and spawn_first_ok and cap_ok and final_cap_ok


## Phase 2: ท่าเร็วขึ้น x0.8
func test_phase_2_speed_multiplier() -> bool:
	var boss: BossSlime = _spawn()
	var p1_speed: bool = is_equal_approx(boss.get_speed_multiplier(), 1.0)
	boss.health.take_damage(boss.health.max_hp * 6 / 10)
	var p2_speed: bool = is_equal_approx(boss.get_speed_multiplier(), 0.8)
	boss.free()
	return p1_speed and p2_speed


## Poise: สะสม stagger และไม่เซ (HURT) จนกว่า poise จะหมด
func test_poise_accumulates_stagger_and_breaks_only_at_zero() -> bool:
	var boss: BossSlime = _spawn()
	var max_p: float = boss.get_max_poise()

	# ตีเบาๆ stagger 10.0 (poise 40 -> 30) -> ต้องไม่เซ
	boss.hurtbox.receive(_hit(2, 10.0))
	var hit1_ok: bool = is_equal_approx(boss.current_poise, max_p - 10.0) \
		and boss.state != BossSlime.State.HURT

	# ตีอีก 15.0 (poise 30 -> 15) -> ต้องยังไม่เซ
	boss.hurtbox.receive(_hit(2, 15.0))
	var hit2_ok: bool = is_equal_approx(boss.current_poise, max_p - 25.0) \
		and boss.state != BossSlime.State.HURT

	# ตีอีก 20.0 (poise หมด <= 0) -> poise แตก เข้า HURT และ poise รีเซ็ต
	boss.hurtbox.receive(_hit(2, 20.0))
	var broken_ok: bool = boss.state == BossSlime.State.HURT \
		and is_equal_approx(boss.current_poise, max_p)

	boss.free()
	return hit1_ok and hit2_ok and broken_ok


## AoE โดน 8 ทิศที่ระยะในวง (physics จริง: add เข้า root ลบท้ายเทสต์)
func test_aoe_hits_8_directions_within_circle_and_misses_outside() -> bool:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var root: Window = tree.root

	var boss: BossSlime = _spawn()
	boss.position = Vector2(200, 200)
	root.add_child(boss)

	# 8 ทิศ: E, SE, S, SW, W, NW, N, NE
	var dirs: Array[Vector2] = [
		Vector2.RIGHT,
		Vector2(1, 1).normalized(),
		Vector2.DOWN,
		Vector2(-1, 1).normalized(),
		Vector2.LEFT,
		Vector2(-1, -1).normalized(),
		Vector2.UP,
		Vector2(1, -1).normalized()
	]

	var inner_hurtboxes: Array[Hurtbox] = []
	var geo_8_dirs_ok: bool = true
	var r: float = boss.slam_radius
	var sq: float = boss.squash

	# ระยะในวง (35 px): ในแกน y คูณ squash ให้เข้ากับวงรี
	for d: Vector2 in dirs:
		var inner_pt: Vector2 = boss.position + Vector2(d.x * 35.0, d.y * 35.0 * sq)
		if not BossSlime.is_point_in_aoe(inner_pt, boss.position, r, sq):
			geo_8_dirs_ok = false

		var outer_pt: Vector2 = boss.position + d * (r + 25.0)
		if BossSlime.is_point_in_aoe(outer_pt, boss.position, r, sq):
			geo_8_dirs_ok = false

		var hurt := Hurtbox.new()
		hurt.team = Combat.Team.PLAYER
		hurt.position = inner_pt
		var col := CollisionShape2D.new()
		var c_shape := CircleShape2D.new()
		c_shape.radius = 4.0
		col.shape = c_shape
		hurt.add_child(col)
		root.add_child(hurt)
		inner_hurtboxes.append(hurt)

	# สร้าง Hurtbox นอกวง AoE
	var far_hurt := Hurtbox.new()
	far_hurt.team = Combat.Team.PLAYER
	far_hurt.position = boss.position + Vector2(r + 30.0, 0.0)
	var far_col := CollisionShape2D.new()
	var far_shape := CircleShape2D.new()
	far_shape.radius = 4.0
	far_col.shape = far_shape
	far_hurt.add_child(far_col)
	root.add_child(far_hurt)

	# เปิดการโจมตี Slam
	boss._enter(BossSlime.State.SLAM_ACTIVE)

	var hit_count_8_dirs: int = 0
	for hurt: Hurtbox in inner_hurtboxes:
		if boss.hitbox.try_hit(hurt):
			hit_count_8_dirs += 1

	var hits_all_8: bool = hit_count_8_dirs == 8
	var outside_geo: bool = not BossSlime.is_point_in_aoe(far_hurt.position, boss.position, r, sq)

	# ลบท้ายเทสต์ (cleanup nodes from root)
	for hurt: Hurtbox in inner_hurtboxes:
		root.remove_child(hurt)
		hurt.free()
	root.remove_child(far_hurt)
	far_hurt.free()
	root.remove_child(boss)
	boss.free()

	return geo_8_dirs_ok and hits_all_8 and outside_geo


## เมื่อบอสตาย ลูกสไลม์ที่เหลือต้องไม่ถูกลบ
func test_minions_remain_after_boss_dies() -> bool:
	var boss: BossSlime = _spawn()
	boss.health.take_damage(boss.health.max_hp * 6 / 10)
	boss._spawn_minions()

	var count_before: int = boss.get_alive_minions_count()
	var has_minions: bool = count_before > 0

	# บอสตาย
	boss._on_died()
	var dead_ok: bool = boss.state == BossSlime.State.DEAD

	# ตรวจว่าลูกสไลม์ยังคงมีชีวิตและไม่ถูก free
	var still_valid: bool = true
	for m: Node in boss._minions:
		if not is_instance_valid(m) or m.is_queued_for_deletion():
			still_valid = false

	# ทำความสะอาดลูกสไลม์ในเทสต์
	for m: Node in boss._minions:
		if is_instance_valid(m):
			m.free()
	boss._minions.clear()
	boss.free()

	return has_minions and dead_ok and still_valid


## เฟรมทุกท่าใน ANIMS ต้องอยู่ในขอบเขตของ sprite sheet (20 เฟรม)
func test_anim_frames_within_sheet() -> bool:
	var boss: BossSlime = _spawn()
	var total_frames: int = boss.sprite.hframes * boss.sprite.vframes
	var ok: bool = boss.sprite.texture.get_width() == boss.sprite.hframes * 128
	for anim: StringName in BossSlime.ANIMS:
		for fr: int in BossSlime.ANIMS[anim]["frames"]:
			ok = ok and fr >= 0 and fr < total_frames
	boss.free()
	return ok
