extends RefCounted
## ระบบผู้เล่น — game/systems/player/ · contract: docs/contracts/damage.md

const PLAYER_SCENE: PackedScene = preload("res://systems/player/player.tscn")


func _spawn() -> Player:
	var player: Player = PLAYER_SCENE.instantiate()
	player.setup()
	return player


func test_setup_nodes_and_defaults() -> bool:
	var player: Player = _spawn()
	var ok: bool = player.collision_layer == Combat.LAYER_PLAYER \
		and player.collision_mask == (Combat.LAYER_WORLD | Combat.LAYER_ENEMY) \
		and player.health != null and player.health.max_hp == 12 and player.health.hp == 12 \
		and player.hurtbox != null and player.hurtbox.team == Combat.Team.PLAYER \
		and player.hitbox != null and player.hitbox.team == Combat.Team.PLAYER \
		and player.hitbox.damage == 3 and is_equal_approx(player.hitbox.knockback_force, 170.0) \
		and not player.hitbox.monitoring \
		and player.sprite != null and player.collision_shape != null
	player.free()
	return ok


func test_input_actions_registered() -> bool:
	Player.ensure_input_actions()
	var actions: Array[StringName] = [&"move_left", &"move_right", &"move_up", &"move_down", &"attack", &"dodge"]
	for a: StringName in actions:
		if not InputMap.has_action(a):
			return false
	return true


func test_stamina_spent_and_regens_after_delay() -> bool:
	var player: Player = _spawn()
	var changes: Array[float] = []
	var cb := func(cur: float, _max: float) -> void:
		changes.append(cur)
	player.stamina_changed.connect(cb)

	# สั่ง dodge เพื่อหัก stamina 25
	player.set_intent(Vector2.ZERO, Vector2.RIGHT, false, true)
	player.tick(0.0)
	var spent_ok: bool = is_equal_approx(player.stamina, 75.0)

	# สเต็ปจน dodge จบ (0.28 วิ) สู่ MOVE
	player.tick(player.dodge_time)
	var in_move: bool = player.state == Player.State.MOVE

	# หน่วงเวลา regen_delay (0.55 วิ) — สเต็ปไป 0.50 วิ stamina ต้องยังไม่ฟื้น
	player.tick(0.50)
	var still_delaying: bool = is_equal_approx(player.stamina, 75.0)

	# สเต็ปต่ออีก 0.05 วิ (ครบ 0.55 วิ)
	player.tick(0.05)

	# สเต็ปต่ออีก 0.20 วิ — stamina ต้องฟื้น 45 * 0.20 = 9.0 -> 75 + 9 = 84.0
	player.tick(0.20)
	var regened_ok: bool = is_equal_approx(player.stamina, 84.0)

	player.stamina_changed.disconnect(cb)
	player.free()
	return spent_ok and in_move and still_delaying and regened_ok


func test_dodge_insufficient_stamina_fails_and_emits_empty() -> bool:
	var player: Player = _spawn()
	player.stamina = 10.0
	var empty_events: Array[bool] = []
	var cb := func() -> void:
		empty_events.append(true)
	player.stamina_empty.connect(cb)

	player.set_intent(Vector2.ZERO, Vector2.RIGHT, false, true)
	player.tick(0.0)

	var ok: bool = empty_events.size() == 1 and player.state == Player.State.MOVE \
		and is_equal_approx(player.stamina, 10.0) \
		and not player.hurtbox.invulnerable \
		and player.collision_mask == (Combat.LAYER_WORLD | Combat.LAYER_ENEMY)

	player.stamina_empty.disconnect(cb)
	player.free()
	return ok


func test_dodge_iframes_turn_off_after_240ms() -> bool:
	var player: Player = _spawn()
	player.set_intent(Vector2.ZERO, Vector2.RIGHT, false, true)
	player.tick(0.0)

	var dodging: bool = player.state == Player.State.DODGE
	var iframes_start: bool = player.hurtbox.invulnerable
	var mask_during_dodge: bool = player.collision_mask == Combat.LAYER_WORLD

	# ผ่านไป 0.20 วิ (ยังไม่ถึง 0.24 วิ) -> ต้องยังคง invulnerable
	player.tick(0.20)
	var iframes_during: bool = player.hurtbox.invulnerable

	# ผ่านไปอีก 0.04 วิ (รวม 0.24 วิ) -> invulnerable ต้องปิด แต่ยังอยู่ใน DODGE (DODGE_TIME = 0.28)
	player.tick(0.04)
	var iframes_ended: bool = not player.hurtbox.invulnerable
	var still_dodging: bool = player.state == Player.State.DODGE

	# ผ่านไปอีก 0.04 วิ (รวม 0.28 วิ) -> จบ dodge กลับสู่ MOVE และ mask คืนค่าเดิม
	player.tick(0.04)
	var back_to_move: bool = player.state == Player.State.MOVE
	var mask_restored: bool = player.collision_mask == (Combat.LAYER_WORLD | Combat.LAYER_ENEMY)

	player.free()
	return dodging and iframes_start and mask_during_dodge and iframes_during \
		and iframes_ended and still_dodging and back_to_move and mask_restored


func test_attack_cycles_through_phases_and_returns_to_move() -> bool:
	var player: Player = _spawn()
	# เริ่มโจมตี
	player.set_intent(Vector2.ZERO, Vector2.RIGHT, true, false)
	player.tick(0.0)

	var phase_windup: bool = player.state == Player.State.ATTACK \
		and player.attack_phase == Player.AttackPhase.WINDUP \
		and not player.hitbox.monitoring

	# จบ WINDUP (0.07 วิ) เข้าสู่ ACTIVE (0.11 วิ)
	player.tick(player.windup_time)
	var phase_active: bool = player.state == Player.State.ATTACK \
		and player.attack_phase == Player.AttackPhase.ACTIVE

	# จบ ACTIVE (0.11 วิ) เข้าสู่ RECOVER (0.20 วิ)
	player.tick(player.active_time)
	var phase_recover: bool = player.state == Player.State.ATTACK \
		and player.attack_phase == Player.AttackPhase.RECOVER

	# จบ RECOVER (0.20 วิ) กลับสู่ MOVE
	player.tick(player.recover_time)
	var phase_move: bool = player.state == Player.State.MOVE \
		and player.attack_phase == Player.AttackPhase.NONE

	player.free()
	return phase_windup and phase_active and phase_recover and phase_move


func test_dodge_cancels_attack_recover_phase() -> bool:
	var player: Player = _spawn()
	# เริ่มโจมตี
	player.set_intent(Vector2.ZERO, Vector2.RIGHT, true, false)
	player.tick(0.0)
	player.tick(player.windup_time)
	player.tick(player.active_time)

	var in_recover: bool = player.state == Player.State.ATTACK \
		and player.attack_phase == Player.AttackPhase.RECOVER

	# กด dodge ตอนอยู่ใน RECOVER -> ต้อง cancel เข้า DODGE ทันที
	player.set_intent(Vector2.ZERO, Vector2.RIGHT, false, true)
	player.tick(0.0)

	var cancelled_into_dodge: bool = player.state == Player.State.DODGE \
		and player.hurtbox.invulnerable \
		and player.attack_phase == Player.AttackPhase.NONE

	player.free()
	return in_recover and cancelled_into_dodge


func test_take_damage_deducts_hp_and_emits_player_died_once() -> bool:
	var player: Player = _spawn()
	var dealt_list: Array[int] = []
	var damage_cb := func(t: Node, _i: DamageInfo, dealt: int) -> void:
		if t == player:
			dealt_list.append(dealt)
	EventBus.damage_dealt.connect(damage_cb)

	var deaths: Array[int] = []
	var death_cb := func() -> void:
		deaths.append(1)
	EventBus.player_died.connect(death_cb)

	# โดนโจมตีครั้งแรก 4 หน่วย (max_hp = 12)
	var hit1 := DamageInfo.new()
	hit1.team = Combat.Team.ENEMY
	hit1.amount = 4
	hit1.knockback = Vector2(50, 0)
	var landed1: bool = player.hurtbox.receive(hit1)

	var hp1_ok: bool = player.health.hp == 8 and player.state == Player.State.HURT \
		and is_equal_approx(player.knock.x, 50.0)

	# โดนโจมตีซ้ำจนตาย (ดาเมจเกิน HP)
	var hit2 := DamageInfo.new()
	hit2.team = Combat.Team.ENEMY
	hit2.amount = 999
	var landed2: bool = player.hurtbox.receive(hit2)

	var dead_ok: bool = player.health.is_dead and player.state == Player.State.DEAD

	# โดนโจมตีซ้ำหลังจากตายแล้ว ต้องไม่รับดาเมจและไม่ emit ซ้ำ
	var hit3 := DamageInfo.new()
	hit3.team = Combat.Team.ENEMY
	hit3.amount = 10
	var landed3: bool = player.hurtbox.receive(hit3)

	EventBus.damage_dealt.disconnect(damage_cb)
	EventBus.player_died.disconnect(death_cb)

	var ok: bool = landed1 and landed2 and not landed3 and hp1_ok and dead_ok \
		and deaths.size() == 1 and dealt_list == [4, 8]

	player.free()
	return ok


func test_dodge_backward_when_no_move_input() -> bool:
	var player: Player = _spawn()
	player.set_intent(Vector2.ZERO, Vector2(1, 0), false, true)
	player.tick(0.0)

	var ok: bool = player.state == Player.State.DODGE \
		and player.dodge_dir.is_equal_approx(Vector2(-1, 0))

	player.free()
	return ok


func test_attack_insufficient_stamina_fails() -> bool:
	var player: Player = _spawn()
	player.stamina = 5.0
	var empty_events: Array[bool] = []
	var cb := func() -> void:
		empty_events.append(true)
	player.stamina_empty.connect(cb)

	player.set_intent(Vector2.ZERO, Vector2.RIGHT, true, false)
	player.tick(0.0)

	var ok: bool = empty_events.size() == 1 and player.state == Player.State.MOVE \
		and is_equal_approx(player.stamina, 5.0)

	player.stamina_empty.disconnect(cb)
	player.free()
	return ok


func test_no_stamina_regen_during_dodge_or_attack() -> bool:
	var player: Player = _spawn()
	player.set_intent(Vector2.ZERO, Vector2.RIGHT, false, true)
	player.tick(0.0)
	var stamina_after_dodge_start: float = player.stamina

	player.tick(0.15)
	var no_regen_in_dodge: bool = is_equal_approx(player.stamina, stamina_after_dodge_start)

	player.tick(player.dodge_time)
	player.set_intent(Vector2.ZERO, Vector2.RIGHT, true, false)
	player.tick(0.0)
	var stamina_after_attack_start: float = player.stamina

	player.tick(player.windup_time)
	var no_regen_in_attack: bool = is_equal_approx(player.stamina, stamina_after_attack_start)

	player.free()
	return no_regen_in_dodge and no_regen_in_attack


func test_player_sandbox_instantiates_cleanly() -> bool:
	var scene: PackedScene = load("res://systems/player/debug/player_sandbox.tscn")
	if scene == null:
		return false
	var sandbox: Node = scene.instantiate()
	var ok: bool = sandbox != null and sandbox.has_node("Player") and sandbox.has_node("Dummy")
	sandbox.free()
	return ok


func test_player_in_player_group() -> bool:
	var p: Node = load("res://systems/player/player.tscn").instantiate()
	p.setup()
	var ok: bool = p.is_in_group(&"player")
	p.free()
	return ok
