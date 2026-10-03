extends RefCounted
## การทดสอบระบบนักธนูหมึก (InkArcher) และลูกธนูหมึก (InkArrow)
## issue #61 · contract: docs/contracts/damage.md

const ARCHER_SCENE: PackedScene = preload("res://systems/enemy/ink_archer/ink_archer.tscn")
const ARROW_SCENE: PackedScene = preload("res://systems/enemy/ink_archer/ink_arrow.tscn")


func _spawn_archer() -> InkArcher:
	var archer: InkArcher = ARCHER_SCENE.instantiate() as InkArcher
	archer.setup()
	return archer


func _spawn_arrow() -> InkArrow:
	var arrow: InkArrow = ARROW_SCENE.instantiate() as InkArrow
	arrow.setup()
	return arrow


func _hit_info(amount: int, team: Combat.Team = Combat.Team.PLAYER, stagger: float = 10.0) -> DamageInfo:
	var info := DamageInfo.new()
	info.amount = amount
	info.team = team
	info.stagger = stagger
	return info


func test_setup_nodes_and_defaults() -> bool:
	var archer: InkArcher = _spawn_archer()
	var ok: bool = archer.collision_layer == Combat.LAYER_ENEMY \
		and archer.collision_mask == (Combat.LAYER_WORLD | Combat.LAYER_PLAYER | Combat.LAYER_ENEMY) \
		and archer.hurtbox != null and archer.hurtbox.team == Combat.Team.ENEMY \
		and archer.detect != null and archer.detect.collision_mask == Combat.LAYER_PLAYER \
		and archer.health != null and archer.health.max_hp == 10 \
		and archer.state == InkArcher.State.WANDER \
		and archer.dir_sprite != null
	archer.free()
	return ok


func test_compute_damage_min_one() -> bool:
	return InkArcher.compute_damage(5, 2) == 3 and InkArcher.compute_damage(1, 10) == 1


func test_state_sequence_wander_to_keep_distance_to_aim_to_shoot_to_recover() -> bool:
	var archer: InkArcher = _spawn_archer()
	var dummy := Node2D.new()
	dummy.position = Vector2(160, 0) # อยู่ใน preferred_range

	var start_wander: bool = archer.state == InkArcher.State.WANDER

	# เห็นผู้เล่น -> KEEP_DISTANCE
	archer.set_target(dummy)
	var entering_kd: bool = archer.state == InkArcher.State.KEEP_DISTANCE

	# อยู่ในระยะจนครบ attack_delay_in_range -> AIM
	archer.tick(archer.attack_delay_in_range + 0.05)
	var entering_aim: bool = archer.state == InkArcher.State.AIM

	# AIM จนครบ aim_time -> SHOOT
	archer.tick(archer.aim_time + 0.05)
	var entering_shoot: bool = archer.state == InkArcher.State.SHOOT and archer.get_arrows_shot_count() == 1

	# SHOOT จนครบ shoot_duration -> RECOVER
	archer.tick(archer.shoot_duration + 0.05)
	var entering_recover: bool = archer.state == InkArcher.State.RECOVER

	# RECOVER จนครบ recover_time -> KEEP_DISTANCE
	archer.tick(archer.recover_time + 0.05)
	var back_to_kd: bool = archer.state == InkArcher.State.KEEP_DISTANCE

	archer.free()
	dummy.free()
	return start_wander and entering_kd and entering_aim and entering_shoot and entering_recover and back_to_kd


func test_does_not_shoot_before_aim_time_completes() -> bool:
	var archer: InkArcher = _spawn_archer()
	var dummy := Node2D.new()
	dummy.position = Vector2(160, 0)
	archer.set_target(dummy)
	archer.tick(archer.attack_delay_in_range + 0.05) # เข้า AIM

	var in_aim: bool = archer.state == InkArcher.State.AIM
	var shot_before: int = archer.get_arrows_shot_count()

	# ผ่านไป 50% ของ aim_time -> ยังไม่ยิง และยังอยู่ใน AIM
	archer.tick(archer.aim_time * 0.5)
	var still_aim_1: bool = archer.state == InkArcher.State.AIM and archer.get_arrows_shot_count() == shot_before

	# ผ่านไปอีก 40% (รวม 90%) -> ยังไม่ยิง
	archer.tick(archer.aim_time * 0.4)
	var still_aim_2: bool = archer.state == InkArcher.State.AIM and archer.get_arrows_shot_count() == shot_before

	# สเต็ปจนเกิน 100% -> ยิงลูกธนูและเปลี่ยนเป็น SHOOT
	archer.tick(archer.aim_time * 0.2)
	var shot_now: bool = archer.state == InkArcher.State.SHOOT and archer.get_arrows_shot_count() == shot_before + 1

	archer.free()
	dummy.free()
	return in_aim and still_aim_1 and still_aim_2 and shot_now


func test_aim_direction_locked_at_start_of_aim() -> bool:
	var archer: InkArcher = _spawn_archer()
	var dummy := Node2D.new()
	dummy.position = Vector2(160, 0) # ทางขวา (Vector2.RIGHT)
	archer.set_target(dummy)
	archer.tick(archer.attack_delay_in_range + 0.05) # เข้า AIM

	var dir_at_start: Vector2 = archer.get_aim_direction()
	var locked_right: bool = dir_at_start.is_equal_approx(Vector2.RIGHT)

	# ผู้เล่นย้ายตำแหน่งไปข้างล่าง (Vector2.DOWN) ระหว่างที่นักธนูกำลังเล็ง
	dummy.position = Vector2(0, 160)
	archer.tick(archer.aim_time * 0.5)

	# ทิศเล็งต้องยังคงล็อคอยู่ที่เดิม (ทางขวา)
	var dir_mid_aim: Vector2 = archer.get_aim_direction()
	var still_locked: bool = dir_mid_aim.is_equal_approx(Vector2.RIGHT)

	archer.free()
	dummy.free()
	return locked_right and still_locked


func test_flee_when_player_is_too_close() -> bool:
	var archer: InkArcher = _spawn_archer()
	var dummy := Node2D.new()
	# ผู้เล่นอยู่ใกล้เกินไป (50 px < flee_range 80 px) ทางขวา
	dummy.position = Vector2(50, 0)
	archer.set_target(dummy)

	archer.tick(0.01)
	var is_fleeing: bool = archer.velocity.x < 0.0 # ต้องถอยหนีไปทางซ้าย
	var flee_speed_ok: bool = is_equal_approx(archer.velocity.length(), archer.flee_speed)

	archer.free()
	dummy.free()
	return is_fleeing and flee_speed_ok


func test_arrow_disappears_on_wall_collision() -> bool:
	var arrow: InkArrow = _spawn_arrow()

	var wall := StaticBody2D.new()
	wall.collision_layer = Combat.LAYER_WORLD

	arrow._on_body_entered(wall)
	var ok: bool = arrow.is_queued_for_deletion()

	wall.free()
	arrow.free()
	return ok


func test_arrow_parry_deflection_reverses_direction_and_changes_team_to_player() -> bool:
	var arrow: InkArrow = _spawn_arrow()
	arrow.set_direction(Vector2.RIGHT)

	var hurtbox := Hurtbox.new()
	hurtbox.team = Combat.Team.PLAYER
	hurtbox.deflecting = true # ผู้เล่นกำลัง parry

	var initial_team_ok: bool = arrow.hitbox.team == Combat.Team.ENEMY

	# ชน Hurtbox ที่กำลัง parry -> สะท้อนกลับ
	var hit_result: bool = arrow.hitbox.try_hit(hurtbox)

	var deflected_ok: bool = not hit_result and arrow.is_reflected()
	var dir_reversed: bool = arrow.direction.is_equal_approx(Vector2.LEFT)
	var team_changed: bool = arrow.hitbox.team == Combat.Team.PLAYER

	# ถ้า parry ซ้ำตอนลูกธนูกำลังบินกลับ -> ไม่สะท้อนซ้ำ
	hurtbox.deflecting = true
	arrow.hitbox.activate()
	var _second_hit: bool = arrow.hitbox.try_hit(hurtbox)
	var no_double_deflect: bool = arrow.direction.is_equal_approx(Vector2.LEFT)

	arrow.free()
	hurtbox.free()
	return initial_team_ok and deflected_ok and dir_reversed and team_changed and no_double_deflect


func test_arrow_hits_hurtbox_and_vanishes() -> bool:
	var arrow: InkArrow = _spawn_arrow()
	var hurtbox := Hurtbox.new()
	hurtbox.team = Combat.Team.PLAYER
	hurtbox.deflecting = false

	var hit_landed: bool = arrow.hitbox.try_hit(hurtbox)
	var destroyed: bool = arrow.is_queued_for_deletion()

	arrow.free()
	hurtbox.free()
	return hit_landed and destroyed


func test_arrow_tick_lifetime() -> bool:
	var arrow: InkArrow = _spawn_arrow()
	arrow.set_direction(Vector2.RIGHT)
	arrow.arrow_life = 1.0

	arrow.tick(0.5)
	var still_alive: bool = not arrow.is_queued_for_deletion()

	arrow.tick(0.6)
	var expired: bool = arrow.is_queued_for_deletion()

	arrow.free()
	return still_alive and expired


func test_dies_once_and_emits_enemy_died_once() -> bool:
	var archer: InkArcher = _spawn_archer()
	var death_ids: Array[StringName] = []

	var cb := func(e: Node, id: StringName, _p: Vector2) -> void:
		if e == archer:
			death_ids.append(id)

	EventBus.enemy_died.connect(cb)

	# โดนตีจนตาย
	archer.hurtbox.receive(_hit_info(999))
	archer.hurtbox.receive(_hit_info(999))

	EventBus.enemy_died.disconnect(cb)

	var ok: bool = death_ids == [&"ink_archer"] \
		and archer.state == InkArcher.State.DEAD \
		and archer.health.is_dead

	archer.free()
	return ok


func test_poise_interruption_during_aim() -> bool:
	var archer: InkArcher = _spawn_archer()
	archer.max_poise = 10.0
	var dummy := Node2D.new()
	dummy.position = Vector2(160, 0)
	archer.set_target(dummy)
	archer.tick(archer.attack_delay_in_range + 0.05) # เข้า AIM

	var in_aim: bool = archer.state == InkArcher.State.AIM

	# โดนตีเบา stagger 4 (< 10) -> ยังไม่หลุด AIM
	archer.hurtbox.receive(_hit_info(1, Combat.Team.PLAYER, 4.0))
	var still_aim: bool = archer.state == InkArcher.State.AIM

	# โดนตีอีก stagger 6 (รวม 10) -> หลุด poise เข้า HURT
	archer.hurtbox.receive(_hit_info(1, Combat.Team.PLAYER, 6.0))
	var in_hurt: bool = archer.state == InkArcher.State.HURT

	archer.free()
	dummy.free()
	return in_aim and still_aim and in_hurt
