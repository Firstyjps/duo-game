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
