extends RefCounted
## contract: docs/contracts/damage.md


func _hit(team: Combat.Team, amount: int = 3) -> DamageInfo:
	var info := DamageInfo.new()
	info.team = team
	info.amount = amount
	return info


func test_team_rules() -> bool:
	return not Combat.can_hit(Combat.Team.PLAYER, Combat.Team.PLAYER) \
		and Combat.can_hit(Combat.Team.PLAYER, Combat.Team.ENEMY) \
		and Combat.can_hit(Combat.Team.ENEMY, Combat.Team.PLAYER) \
		and Combat.can_hit(Combat.Team.NEUTRAL, Combat.Team.ENEMY) \
		and Combat.can_hit(Combat.Team.NEUTRAL, Combat.Team.NEUTRAL)


func test_hurtbox_rejects_same_team_and_iframes() -> bool:
	var hb := Hurtbox.new()
	hb.team = Combat.Team.PLAYER
	var got: Array[int] = []
	hb.hurt.connect(func(i: DamageInfo) -> void: got.append(i.amount))
	var same: bool = hb.receive(_hit(Combat.Team.PLAYER))
	hb.invulnerable = true
	var during_iframes: bool = hb.receive(_hit(Combat.Team.ENEMY))
	hb.invulnerable = false
	var landed: bool = hb.receive(_hit(Combat.Team.ENEMY, 5))
	hb.free()
	return not same and not during_iframes and landed and got == [5]


func test_hitbox_hits_each_hurtbox_once_per_activation() -> bool:
	var hit := Hitbox.new()
	hit.team = Combat.Team.ENEMY
	hit.damage = 4
	var hurt := Hurtbox.new()
	hurt.team = Combat.Team.PLAYER
	var landed: Array[int] = []
	hit.hit_landed.connect(func(_h: Hurtbox, i: DamageInfo) -> void: landed.append(i.amount))
	var first: bool = hit.try_hit(hurt)
	var second: bool = hit.try_hit(hurt)
	hit.activate()
	var after_reactivate: bool = hit.try_hit(hurt)
	hit.free()
	hurt.free()
	return first and not second and after_reactivate and landed == [4, 4]


func test_hitbox_blocked_hit_can_land_later() -> bool:
	var hit := Hitbox.new()
	hit.team = Combat.Team.ENEMY
	var hurt := Hurtbox.new()
	hurt.team = Combat.Team.PLAYER
	hurt.invulnerable = true
	var blocked: bool = hit.try_hit(hurt)
	hurt.invulnerable = false
	var landed: bool = hit.try_hit(hurt)
	hit.free()
	hurt.free()
	return not blocked and landed


func test_hitbox_collision_defaults() -> bool:
	var hit := Hitbox.new()
	var hurt := Hurtbox.new()
	var ok: bool = hit.collision_mask == Combat.LAYER_HURTBOX and hit.collision_layer == 0 \
		and hurt.collision_layer == Combat.LAYER_HURTBOX and hurt.collision_mask == 0
	hit.free()
	hurt.free()
	return ok


func test_health_damage_clamp_and_die_once() -> bool:
	var h := Health.new()
	h.max_hp = 10
	h.reset()
	var deaths: Array[int] = []
	h.died.connect(func() -> void: deaths.append(1))
	var a: int = h.take_damage(4)
	var b: int = h.take_damage(100)
	var c: int = h.take_damage(5)
	var dead: bool = h.is_dead
	h.free()
	return a == 4 and b == 6 and c == 0 and dead and deaths == [1]


func test_health_heal_caps_at_max() -> bool:
	var h := Health.new()
	h.max_hp = 10
	h.reset()
	h.take_damage(3)
	var healed: int = h.heal(50)
	var hp: int = h.hp
	h.free()
	return healed == 3 and hp == 10


## Hurtbox.deflecting: ไม่ emit hurt · Hitbox ได้ deflected (ไม่ใช่ hit_landed) · นับ 1 ครั้งของ activate
func test_deflect_emits_deflected_not_hit_landed() -> bool:
	var hb := Hitbox.new()
	hb.team = Combat.Team.ENEMY
	hb.damage = 4
	var hurt := Hurtbox.new()
	hurt.team = Combat.Team.PLAYER
	hurt.deflecting = true
	var log: Array[String] = []
	hurt.hurt.connect(func(_i: DamageInfo) -> void: log.append("hurt"))
	hurt.deflected.connect(func(_i: DamageInfo) -> void: log.append("hurtbox_deflected"))
	hb.hit_landed.connect(func(_h: Hurtbox, _i: DamageInfo) -> void: log.append("hit_landed"))
	hb.deflected.connect(func(_h: Hurtbox, _i: DamageInfo) -> void: log.append("hitbox_deflected"))
	var first: bool = hb.try_hit(hurt)
	hurt.deflecting = false
	var second: bool = hb.try_hit(hurt)  # activate รอบเดียวกัน → ไม่โดนซ้ำหลังถูกปัด
	var ok: bool = not first and not second and log == ["hurtbox_deflected", "hitbox_deflected"]
	hb.free()
	hurt.free()
	return ok


func test_receive_result_rejected_for_same_team_even_if_deflecting() -> bool:
	var hurt := Hurtbox.new()
	hurt.team = Combat.Team.ENEMY
	hurt.deflecting = true
	var info := DamageInfo.new()
	info.team = Combat.Team.ENEMY
	var ok: bool = hurt.receive_result(info) == Hurtbox.Result.REJECTED and not hurt.receive(info)
	hurt.free()
	return ok
