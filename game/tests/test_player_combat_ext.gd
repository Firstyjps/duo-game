extends RefCounted
## เทสต์ฟีเจอร์การต่อสู้เพิ่มเติมของผู้เล่น: Lock-on, Parry, Charge Attack
## game/systems/player/ · issue #38

const PLAYER_SCENE: PackedScene = preload("res://systems/player/player.tscn")
const DUMMY_SCRIPT: GDScript = preload("res://systems/player/debug/dummy.gd")


func _spawn() -> Player:
	var player: Player = PLAYER_SCENE.instantiate()
	player.setup()
	return player


func _create_dummy(pos: Vector2, hp: int = 100) -> Node2D:
	var dummy := CharacterBody2D.new()
	dummy.set_script(DUMMY_SCRIPT)
	dummy.global_position = pos
	var health := Health.new()
	health.name = "Health"
	health.max_hp = hp
	health.reset()
	dummy.add_child(health)

	var hurtbox := Hurtbox.new()
	hurtbox.name = "Hurtbox"
	hurtbox.team = Combat.Team.ENEMY
	hurtbox.monitorable = true
	dummy.add_child(hurtbox)

	var col := CollisionShape2D.new()
	col.name = "CollisionShape2D"
	var shape := CircleShape2D.new()
	shape.radius = 12.0
	col.shape = shape
	dummy.add_child(col)

	dummy.health = health
	dummy.hurtbox = hurtbox
	dummy.collision_shape = col
	return dummy


func test_input_actions_parry_and_lock_on_registered() -> bool:
	Player.ensure_input_actions()
	return InputMap.has_action(&"parry") and InputMap.has_action(&"lock_on")


func test_lock_on_selects_closest() -> bool:
	var player: Player = _spawn()
	player.global_position = Vector2.ZERO

	var d1: Node2D = _create_dummy(Vector2(60, 0))
	var d2: Node2D = _create_dummy(Vector2(140, 0))
	player.test_targets = [d2, d1]

	var changed_targets: Array[Node2D] = []
	var cb := func(t: Node2D) -> void:
		changed_targets.append(t)
	player.lock_target_changed.connect(cb)

	# กด Lock-on (Tab / คลิกกลาง)
	player.set_intent(Vector2.ZERO, Vector2.ZERO, false, false, false, true)
	player.tick(0.0)

	var expected_aim: Vector2 = (d1.global_position - (player.global_position + Vector2(0.0, player.body_y))).normalized()
	var ok: bool = player.lock_target == d1 \
		and player.is_locked_on() \
		and player.aim.is_equal_approx(expected_aim) \
		and changed_targets.size() == 1 and changed_targets[0] == d1

	player.lock_target_changed.disconnect(cb)
	player.free()
	d1.free()
	d2.free()
	return ok


func test_lock_on_cycles_to_next() -> bool:
	var player: Player = _spawn()
	player.global_position = Vector2.ZERO

	var d1: Node2D = _create_dummy(Vector2(60, 0))
	var d2: Node2D = _create_dummy(Vector2(140, 0))
	player.test_targets = [d1, d2]

	# ครั้งแรก: เลือกตัวใกล้สุด (d1)
	player.set_intent(Vector2.ZERO, Vector2.ZERO, false, false, false, true)
	player.tick(0.0)
	var first_ok: bool = player.lock_target == d1

	# กดซ้ำ: สลับไปตัวถัดไป (d2)
	player.set_intent(Vector2.ZERO, Vector2.ZERO, false, false, false, true)
	player.tick(0.0)
	var second_ok: bool = player.lock_target == d2

	# กดซ้ำอีก: วนกลับมา d1
	player.set_intent(Vector2.ZERO, Vector2.ZERO, false, false, false, true)
	player.tick(0.0)
	var third_ok: bool = player.lock_target == d1

	player.free()
	d1.free()
	d2.free()
	return first_ok and second_ok and third_ok


func test_lock_on_unlocks_when_target_dies() -> bool:
	var player: Player = _spawn()
	player.global_position = Vector2.ZERO

	var d1: Node2D = _create_dummy(Vector2(80, 0), 10)
	player.test_targets = [d1]

	player.set_intent(Vector2.ZERO, Vector2.ZERO, false, false, false, true)
	player.tick(0.0)
	var locked_ok: bool = player.lock_target == d1

	# เป้าหมายตาย (HP หมด)
	var h: Health = d1.get_node("Health") as Health
	h.take_damage(999)
	player.tick(0.0)

	var unlocked_ok: bool = player.lock_target == null and not player.is_locked_on()

	player.free()
	d1.free()
	return locked_ok and unlocked_ok


func test_lock_on_unlocks_when_out_of_range() -> bool:
	var player: Player = _spawn()
	player.global_position = Vector2.ZERO

	var d1: Node2D = _create_dummy(Vector2(100, 0))
	player.test_targets = [d1]

	player.set_intent(Vector2.ZERO, Vector2.ZERO, false, false, false, true)
	player.tick(0.0)
	var locked_ok: bool = player.lock_target == d1

	# ย้ายเป้าออกนอกระยะ lock_range
	d1.global_position = Vector2(player.lock_range + 50.0, 0)
	player.tick(0.0)

	var unlocked_ok: bool = player.lock_target == null and not player.is_locked_on()

	player.free()
	d1.free()
	return locked_ok and unlocked_ok


func test_parry_within_window_prevents_damage_and_refunds_stamina() -> bool:
	var player: Player = _spawn()
	player.stamina = 50.0

	var parried_events: Array[DamageInfo] = []
	var cb := func(info: DamageInfo) -> void:
		parried_events.append(info)
	player.parried.connect(cb)

	# สั่ง Parry
	player.set_intent(Vector2.ZERO, Vector2.RIGHT, false, false, true)
	player.tick(0.0)

	var parrying: bool = player.state == Player.State.PARRY
	var stamina_after_cost: float = player.stamina
	var cost_ok: bool = is_equal_approx(stamina_after_cost, 50.0 - player.parry_cost)
	var in_window: bool = player.is_in_parry_window()

	# โดนโจมตีระหว่างหน้าต่าง parry (0.05 วิ)
	player.tick(0.05)
	var hit := DamageInfo.new()
	hit.team = Combat.Team.ENEMY
	hit.amount = 5
	player.hurtbox.receive(hit)

	var hp_preserved: bool = player.health.hp == player.max_hp
	var parried_emitted: bool = parried_events.size() == 1
	var refunded_ok: bool = is_equal_approx(player.stamina, stamina_after_cost + player.parry_refund)
	var back_to_move: bool = player.state == Player.State.MOVE

	player.parried.disconnect(cb)
	player.free()
	return parrying and cost_ok and in_window and hp_preserved and parried_emitted and refunded_ok and back_to_move


func test_parry_missed_after_window_takes_full_damage() -> bool:
	var player: Player = _spawn()

	# สั่ง Parry
	player.set_intent(Vector2.ZERO, Vector2.RIGHT, false, false, true)
	player.tick(0.0)

	# สเต็ปเวลาจนเลยหน้าต่าง parry_window เข้าสู่ recovery
	player.tick(player.parry_window + 0.05)
	var in_recovery: bool = player.state == Player.State.PARRY and not player.is_in_parry_window()

	# โดนโจมตีตอน recovery
	var hit := DamageInfo.new()
	hit.team = Combat.Team.ENEMY
	hit.amount = 4
	player.hurtbox.receive(hit)

	var took_damage: bool = player.health.hp == (player.max_hp - 4)
	var state_hurt: bool = player.state == Player.State.HURT

	player.free()
	return in_recovery and took_damage and state_hurt


func test_parry_insufficient_stamina_fails() -> bool:
	var player: Player = _spawn()
	player.stamina = 5.0 # น้อยกว่า parry_cost (15)

	var empty_events: Array[bool] = []
	var cb := func() -> void:
		empty_events.append(true)
	player.stamina_empty.connect(cb)

	# สั่ง Parry
	player.set_intent(Vector2.ZERO, Vector2.RIGHT, false, false, true)
	player.tick(0.0)

	var failed_ok: bool = player.state == Player.State.MOVE \
		and is_equal_approx(player.stamina, 5.0) \
		and empty_events.size() == 1

	player.stamina_empty.disconnect(cb)
	player.free()
	return failed_ok


func test_charge_attack_full_charge_deals_multiplied_damage() -> bool:
	var player: Player = _spawn()

	# กดโจมตีค้าง (attack=true, attack_held=true)
	player.set_intent(Vector2.ZERO, Vector2.RIGHT, true, false, false, false, true)
	player.tick(0.0)

	var in_windup: bool = player.state == Player.State.ATTACK and player.attack_phase == Player.AttackPhase.WINDUP

	# สเต็ปจบ windup -> เข้า CHARGING
	player.tick(player.windup_time)
	var in_charging: bool = player.state == Player.State.ATTACK and player.attack_phase == Player.AttackPhase.CHARGING

	# ชาร์จต่อจนครบ charge_time
	player.tick(player.charge_time)
	var charged_ok: bool = player.is_charged()

	# ปล่อยปุ่มโจมตี (attack_held=false)
	player.set_intent(Vector2.ZERO, Vector2.RIGHT, false, false, false, false, false)
	player.tick(0.0)

	var in_active: bool = player.attack_phase == Player.AttackPhase.ACTIVE
	var mult_damage: int = int(round(player.attack_damage * player.charge_mult))
	var damage_ok: bool = player.hitbox.damage == mult_damage
	var knockback_ok: bool = is_equal_approx(player.hitbox.knockback_force, player.attack_knockback * player.charge_mult)
	var stagger_ok: bool = is_equal_approx(player.hitbox.stagger, player.attack_stagger * player.charge_mult)
	var stamina_ok: bool = is_equal_approx(player.stamina, player.stamina_max - player.charge_cost)

	player.free()
	return in_windup and in_charging and charged_ok and in_active and damage_ok and knockback_ok and stagger_ok and stamina_ok


func test_charge_attack_short_press_is_normal_attack() -> bool:
	var player: Player = _spawn()

	# กดสั้น (attack_held=false)
	player.set_intent(Vector2.ZERO, Vector2.RIGHT, true, false, false, false, false)
	player.tick(0.0)

	# จบ windup
	player.tick(player.windup_time)

	var in_active: bool = player.attack_phase == Player.AttackPhase.ACTIVE
	var damage_normal: bool = player.hitbox.damage == player.attack_damage
	var stamina_normal: bool = is_equal_approx(player.stamina, player.stamina_max - player.attack_cost)

	player.free()
	return in_active and damage_normal and stamina_normal


func test_charge_attack_insufficient_stamina_fails() -> bool:
	var player: Player = _spawn()
	# stamina พอฟันธรรมดา (15) แต่ไม่พอชาร์จ (30)
	player.stamina = 20.0

	var empty_events: Array[bool] = []
	var cb := func() -> void:
		empty_events.append(true)
	player.stamina_empty.connect(cb)

	# กดโจมตีค้าง
	player.set_intent(Vector2.ZERO, Vector2.RIGHT, true, false, false, false, true)
	player.tick(0.0)

	# สเต็ปจบ windup -> ตรวจสอบว่า stamina ไม่พอชาร์จ
	player.tick(player.windup_time)

	var empty_emitted: bool = empty_events.size() == 1
	# ไม่ได้เข้า charging แต่ปล่อยเป็นท่าธรรมดา
	var not_charging: bool = not player.is_charging()
	var normal_damage: bool = player.hitbox.damage == player.attack_damage

	player.stamina_empty.disconnect(cb)
	player.free()
	return empty_emitted and not_charging and normal_damage
