extends RefCounted
## เทสต์ฟีเจอร์การต่อสู้เพิ่มเติมของผู้เล่น: Lock-on, Parry, Charge Attack
## game/systems/player/ · issue #38

const PLAYER_SCENE: PackedScene = preload("res://systems/player/player.tscn")
const DUMMY_SCRIPT: GDScript = preload("res://systems/player/debug/dummy.gd")


func _spawn() -> Player:
	var player: Player = PLAYER_SCENE.instantiate()
	player._enter_tree()
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

	health.died.connect(func() -> void:
		EventBus.enemy_died.emit(dummy, &"dummy", dummy.global_position)
	)
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
	var locked_ok: bool = player.lock_target == d1 and player.is_locked_on()

	# เป้าหมายตาย (HP หมด -> trigger health.died -> EventBus.enemy_died)
	var h: Health = d1.get_node("Health") as Health
	h.take_damage(999)
	player.tick(0.0)

	var unlocked_ok: bool = player.lock_target == null and not player.is_locked_on()

	player.free()
	d1.free()
	return locked_ok and unlocked_ok


func test_lock_on_unlocks_when_enemy_died_signal() -> bool:
	var player: Player = _spawn()
	player.global_position = Vector2.ZERO

	var d1: Node2D = _create_dummy(Vector2(60, 0))
	player.test_targets = [d1]

	player.set_intent(Vector2.ZERO, Vector2.ZERO, false, false, false, true)
	player.tick(0.0)
	var locked_ok: bool = player.lock_target == d1 and player.is_locked_on()

	# emit EventBus.enemy_died โดยตรง
	EventBus.enemy_died.emit(d1, &"dummy", d1.global_position)
	player.tick(0.0)

	var unlocked_ok: bool = player.lock_target == null and not player.is_locked_on()

	player.free()
	d1.free()
	return locked_ok and unlocked_ok


func test_lock_on_target_freed_emits_null() -> bool:
	var player: Player = _spawn()
	player.global_position = Vector2.ZERO

	var d1: Node2D = _create_dummy(Vector2(60, 0))
	player.test_targets = [d1]

	var changed_targets: Array = []
	var cb := func(t: Node2D) -> void:
		changed_targets.append(t)
	player.lock_target_changed.connect(cb)

	# ล็อคเป้า d1
	player.set_intent(Vector2.ZERO, Vector2.ZERO, false, false, false, true)
	player.tick(0.0)
	var locked_ok: bool = player.lock_target == d1 and changed_targets.size() == 1 and changed_targets[0] == d1

	# เป้าหมายถูก free
	d1.free()

	# เรียก tick เพื่อให้ player ตรวจสอบสถานะเป้าหมายที่ถูก free
	player.tick(0.0)

	var freed_ok: bool = player.lock_target == null \
		and not player.is_locked_on() \
		and changed_targets.size() == 2 \
		and changed_targets[1] == null

	player.lock_target_changed.disconnect(cb)
	player.free()
	return locked_ok and freed_ok


func test_lock_on_unlocks_when_out_of_range() -> bool:
	var player: Player = _spawn()
	player.global_position = Vector2.ZERO

	var d1: Node2D = _create_dummy(Vector2(100, 0))
	player.test_targets = [d1]

	player.set_intent(Vector2.ZERO, Vector2.ZERO, false, false, false, true)
	player.tick(0.0)
	var locked_ok: bool = player.lock_target == d1

	# ย้ายเป้าไปที่ระยะเกิน lock_range แต่ยังไม่เกิน lock_range * lock_release_mult (1.2) -> ต้องยังล็อคอยู่
	d1.global_position = Vector2(player.lock_range + 10.0, 0)
	player.tick(0.0)
	var buffer_locked_ok: bool = player.lock_target == d1 and player.is_locked_on()

	# ย้ายเป้าออกนอกระยะ lock_range * lock_release_mult -> ต้องปลดเป้า
	d1.global_position = Vector2(player.lock_range * player.lock_release_mult + 10.0, 0)
	player.tick(0.0)
	var unlocked_ok: bool = player.lock_target == null and not player.is_locked_on()

	player.free()
	d1.free()
	return locked_ok and buffer_locked_ok and unlocked_ok


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

	# สเต็ปถึง charge_threshold (0.15s) -> เข้า CHARGING
	player.tick(player.charge_threshold)
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


func test_charge_attack_held_past_threshold_released_before_charge_time_is_normal_attack() -> bool:
	var player: Player = _spawn()

	# กดโจมตีค้าง
	player.set_intent(Vector2.ZERO, Vector2.RIGHT, true, false, false, false, true)
	player.tick(0.0)

	var initial_stamina: float = player.stamina
	var spent_attack_cost: bool = is_equal_approx(initial_stamina, player.stamina_max - player.attack_cost)

	# สเต็ปเวลาเกิน charge_threshold (0.15s) เข้าสู่ CHARGING
	player.tick(player.charge_threshold + 0.05)
	var in_charging: bool = player.is_charging()

	# ปล่อยปุ่มโจมตีก่อนครบ charge_time (0.45s)
	player.set_intent(Vector2.ZERO, Vector2.RIGHT, false, false, false, false, false)
	player.tick(0.0)

	var in_active: bool = player.attack_phase == Player.AttackPhase.ACTIVE
	var normal_damage: bool = player.hitbox.damage == player.attack_damage
	# stamina หักแค่ attack_cost เดิม
	var stamina_remains: bool = is_equal_approx(player.stamina, initial_stamina)

	player.free()
	return spent_attack_cost and in_charging and in_active and normal_damage and stamina_remains


func test_charge_attack_cancelled_by_dodge_and_parry() -> bool:
	var player: Player = _spawn()

	# 1. ชาร์จแล้ว cancel ด้วย dodge
	player.set_intent(Vector2.ZERO, Vector2.RIGHT, true, false, false, false, true)
	player.tick(0.0)
	player.tick(player.charge_threshold)
	var was_charging: bool = player.is_charging()

	player.set_intent(Vector2.ZERO, Vector2.RIGHT, false, true, false, false, false) # dodge
	player.tick(0.0)
	var dodge_cancelled: bool = player.state == Player.State.DODGE and not player.is_charging()

	# จบ dodge
	player.tick(player.dodge_time)

	# 2. ชาร์จแล้ว cancel ด้วย parry
	player.set_intent(Vector2.ZERO, Vector2.RIGHT, true, false, false, false, true)
	player.tick(0.0)
	player.tick(player.charge_threshold)

	player.set_intent(Vector2.ZERO, Vector2.RIGHT, false, false, true, false, false) # parry
	player.tick(0.0)
	var parry_cancelled: bool = player.state == Player.State.PARRY and not player.is_charging()

	player.free()
	return was_charging and dodge_cancelled and parry_cancelled


func test_hit_during_charging_interrupts_and_damages() -> bool:
	var player: Player = _spawn()

	# เริ่มกดชาร์จ
	player.set_intent(Vector2.ZERO, Vector2.RIGHT, true, false, false, false, true)
	player.tick(0.0)
	player.tick(player.charge_threshold)

	var in_charging: bool = player.is_charging()

	# โดนโจมตีระหว่าง CHARGING
	var hit := DamageInfo.new()
	hit.team = Combat.Team.ENEMY
	hit.amount = 4
	hit.knockback = Vector2(-50.0, 0.0)
	player.hurtbox.receive(hit)

	var hp_reduced: bool = player.health.hp == (player.max_hp - 4)
	var state_hurt: bool = player.state == Player.State.HURT
	var charge_cancelled: bool = not player.is_charging() and player.attack_phase == Player.AttackPhase.NONE
	var hitbox_off: bool = not player.hitbox.monitoring

	player.free()
	return in_charging and hp_reduced and state_hurt and charge_cancelled and hitbox_off


func test_charge_attack_no_stamina_empty_if_normal_attack_possible() -> bool:
	var player: Player = _spawn()
	# stamina พอฟันธรรมดา (15) แต่ไม่พอชาร์จเต็ม (30)
	player.stamina = 20.0

	var empty_events: Array[bool] = []
	var cb := func() -> void:
		empty_events.append(true)
	player.stamina_empty.connect(cb)

	# กดโจมตีค้าง
	player.set_intent(Vector2.ZERO, Vector2.RIGHT, true, false, false, false, true)
	player.tick(0.0)

	# สเต็ปผ่าน charge_threshold -> เข้า charging โดยไม่ emit stamina_empty
	player.tick(player.charge_threshold)

	var no_empty_yet: bool = empty_events.is_empty()
	var in_charging: bool = player.is_charging()

	# ปล่อยก่อน charge_time -> ฟันธรรมดา โดยไม่ emit stamina_empty
	player.set_intent(Vector2.ZERO, Vector2.RIGHT, false, false, false, false, false)
	player.tick(0.0)

	var still_no_empty: bool = empty_events.is_empty()
	var normal_damage: bool = player.hitbox.damage == player.attack_damage

	player.stamina_empty.disconnect(cb)
	player.free()
	return no_empty_yet and in_charging and still_no_empty and normal_damage


func test_charge_attack_insufficient_stamina_fails_on_releasing_full_charge() -> bool:
	var player: Player = _spawn()
	# stamina พอฟันธรรมดา (15) แต่ไม่พอชาร์จเต็ม (30)
	player.stamina = 20.0

	var empty_events: Array[bool] = []
	var cb := func() -> void:
		empty_events.append(true)
	player.stamina_empty.connect(cb)

	# กดโจมตีค้างจนครบ charge_time
	player.set_intent(Vector2.ZERO, Vector2.RIGHT, true, false, false, false, true)
	player.tick(0.0)
	player.tick(player.charge_threshold)
	player.tick(player.charge_time)

	var charged_ok: bool = player.is_charged()

	# ปล่อยท่าชาร์จเมื่อ stamina ไม่พอสำหรับค่าชาร์จส่วนเพิ่ม
	player.set_intent(Vector2.ZERO, Vector2.RIGHT, false, false, false, false, false)
	player.tick(0.0)

	var empty_emitted: bool = empty_events.size() == 1
	var normal_damage: bool = player.hitbox.damage == player.attack_damage

	player.stamina_empty.disconnect(cb)
	player.free()
	return charged_ok and empty_emitted and normal_damage


## เป้าที่วางตรง ๆ ใน scene ห้อง (owner = ห้อง) ต้อง resolve เป็นตัวศัตรู ไม่ใช่ห้อง
func test_resolve_target_uses_parent_not_scene_owner() -> bool:
	var room := Node2D.new()
	var enemy := Node2D.new()
	enemy.position = Vector2(200, 100)
	room.add_child(enemy)
	enemy.owner = room
	var hb := Hurtbox.new()
	enemy.add_child(hb)
	hb.owner = room
	var ok: bool = Player._resolve_target_entity(hb) == enemy
	room.free()
	return ok


## ผู้เล่นเปลี่ยนปุ่มแล้ว ensure_input_actions() ต้องไม่เติมปุ่ม default กลับ
func test_ensure_input_actions_keeps_rebind() -> bool:
	Player.ensure_input_actions()
	var saved: Array[InputEvent] = InputMap.action_get_events(&"parry")
	InputMap.action_erase_events(&"parry")
	var k := InputEventKey.new()
	k.physical_keycode = KEY_O
	InputMap.action_add_event(&"parry", k)
	Player.ensure_input_actions()
	var events: Array[InputEvent] = InputMap.action_get_events(&"parry")
	var ok: bool = events.size() == 1 and (events[0] as InputEventKey).physical_keycode == KEY_O
	InputMap.action_erase_events(&"parry")
	for e: InputEvent in saved:
		InputMap.action_add_event(&"parry", e)
	return ok


## parry สำเร็จ → EventBus.attack_deflected + Hurtbox ปิดหน้าต่างปัด · ออกจาก parry ด้วยวิธีอื่น deflecting ต้องปิด
func test_parry_emits_attack_deflected_and_closes_window() -> bool:
	var player: Player = _spawn()
	var got: Array[Node] = []
	var cb := func(defender: Node, _i: DamageInfo) -> void: got.append(defender)
	EventBus.attack_deflected.connect(cb)
	player.set_intent(Vector2.ZERO, Vector2.RIGHT, false, false, true)
	player.tick(0.0)
	var open_ok: bool = player.hurtbox.deflecting
	var hit := DamageInfo.new()
	hit.team = Combat.Team.ENEMY
	hit.amount = 5
	var result: Hurtbox.Result = player.hurtbox.receive_result(hit)
	var ok: bool = open_ok and result == Hurtbox.Result.DEFLECTED and got == [player] \
		and not player.hurtbox.deflecting and player.health.hp == player.max_hp
	EventBus.attack_deflected.disconnect(cb)
	player.free()
	return ok


## ตายแล้ว dungeon สั่ง respawn → ฟื้นเต็ม ที่ตำแหน่งใหม่ ควบคุมได้อีก และตายซ้ำแล้ว emit player_died อีกครั้ง
func test_respawn_requested_revives_player() -> bool:
	var player: Player = _spawn()
	player._enter_tree()  # ต่อ EventBus แบบตอนอยู่ใน tree
	var hit := DamageInfo.new()
	hit.team = Combat.Team.ENEMY
	hit.amount = 999
	player.hurtbox.receive(hit)
	var dead: bool = player.is_dead()
	EventBus.player_respawn_requested.emit(Vector2(64, 32))
	var revived: bool = not player.is_dead() and player.state == Player.State.MOVE \
		and player.health.hp == player.max_hp and player.global_position == Vector2(64, 32) \
		and not player.hurtbox.invulnerable and player.collision_layer == Combat.LAYER_PLAYER \
		and is_equal_approx(player.stamina, player.stamina_max)
	var deaths: Array[bool] = []
	var cb := func() -> void: deaths.append(true)
	EventBus.player_died.connect(cb)
	player.hurtbox.receive(hit)
	var died_again: bool = deaths.size() == 1
	EventBus.player_died.disconnect(cb)
	player._exit_tree()
	player.free()
	return dead and revived and died_again


## เป้าที่ Hurtbox ปิด monitorable (โคมจุดแล้ว/ตาย) → ปลดล็อคเอง
func test_lock_releases_when_hurtbox_unmonitorable() -> bool:
	var player: Player = _spawn()
	var enemy := Node2D.new()
	enemy.position = Vector2(40, 0)
	var hb := Hurtbox.new()
	hb.team = Combat.Team.NEUTRAL
	enemy.add_child(hb)
	player._candidate_hurtboxes[enemy] = hb
	player._set_lock_target(enemy)
	var locked: bool = player.is_locked_on()
	hb.monitorable = false
	var released: bool = not player._is_valid_locked_target(enemy)
	enemy.free()
	player.free()
	return locked and released
