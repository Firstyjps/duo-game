class_name Player
extends CharacterBody2D
## ผู้เล่นจริง (ระบบ A) — เดิน · ฟัน · dodge + i-frames · stamina · lock-on · parry · charge attack · contract damage
## docs/contracts/damage.md

signal stamina_changed(current: float, maximum: float)
signal stamina_empty
signal lock_target_changed(target: Node2D)
signal parried(info: DamageInfo)
signal flasks_changed(current: int, maximum: int)

enum State { MOVE, DODGE, ATTACK, HURT, DEAD, PARRY, DRINK }
enum AttackPhase { NONE, WINDUP, CHARGING, ACTIVE, RECOVER }

@export_group("Stats")
@export var max_hp: int = 12
@export var defense: int = 0

@export_group("Movement")
@export var speed: float = 115.0
@export var knockback_friction: float = 900.0

@export_group("Dodge")
@export var dodge_speed: float = 320.0
@export var dodge_time: float = 0.28
@export var iframe_time: float = 0.24
@export var dodge_cost: float = 25.0

@export_group("Stamina")
@export var stamina_max: float = 100.0
@export var stamina_regen: float = 45.0
@export var regen_delay: float = 0.55

@export_group("Attack")
@export var attack_cost: float = 15.0
@export var windup_time: float = 0.07
@export var active_time: float = 0.11
@export var recover_time: float = 0.2
@export var attack_damage: int = 3
@export var attack_knockback: float = 170.0
@export var attack_stagger: float = 1.0
@export var rush_speed: float = 140.0
@export var hitbox_distance: float = 24.0

@export_group("Lock-on")
@export var lock_range: float = 240.0:
	set(val):
		lock_range = val
		_update_lock_area_radius()
@export var lock_release_mult: float = 1.2

@export_group("Parry")
@export var parry_cost: float = 15.0
@export var parry_window: float = 0.18
@export var parry_recover: float = 0.25
@export var parry_refund: float = 20.0

@export_group("Charge Attack")
@export var charge_threshold: float = 0.15
@export var charge_time: float = 0.45
@export var charge_mult: float = 2.0
@export var charge_cost: float = 30.0
@export var charge_rush_speed: float = 200.0
@export var charge_recover_mult: float = 1.2

@export_group("Flask")
@export var flask_max: int = 3
@export var flask_heal: int = 5
@export var drink_time: float = 0.9
@export var heal_at: float = 0.6

@export_group("Hurt")
@export var hurt_time: float = 0.2
@export var body_y: float = -16.0

var state: State = State.MOVE
var attack_phase: AttackPhase = AttackPhase.NONE
var stamina: float = 100.0
var flasks: int = 3
var aim: Vector2 = Vector2.RIGHT
var move_dir: Vector2 = Vector2.ZERO
var dodge_dir: Vector2 = Vector2.RIGHT
var knock: Vector2 = Vector2.ZERO
var swing: float = 0.0
var manual_control: bool = false
var lock_target: Node2D = null
var test_targets: Array[Node2D] = []
var _has_lock_target: bool = false

var _state_t: float = 0.0
var _regen_wait: float = 0.0
var _died_emitted: bool = false
var _intent_attack: bool = false
var _intent_dodge: bool = false
var _intent_parry: bool = false
var _intent_lock_on: bool = false
var _intent_attack_held: bool = false
var _intent_heal: bool = false
var _drink_healed: bool = false
var _charge_t: float = 0.0
var _is_heavy_attack: bool = false
var _walk_t: float = 0.0
var _flash_t: float = 0.0
var _flash_color: Color = Color.WHITE
var _ghost_t: float = 0.0
var _combo_side: float = 1.0

## ภาพตัวละคร: `DirSprite` (8 ทิศ iso) หรือ Sprite2D (placeholder เดิม) — เอฟเฟกต์ scale/สีใช้ร่วมกัน
var sprite: Node2D
var dir_sprite: DirSprite
var collision_shape: CollisionShape2D
var health: Health
var hurtbox: Hurtbox
var hitbox: Hitbox
var lock_area: Area2D


func _ready() -> void:
	setup()


func _enter_tree() -> void:
	if not EventBus.enemy_died.is_connected(_on_enemy_died):
		EventBus.enemy_died.connect(_on_enemy_died)
	if not EventBus.player_respawn_requested.is_connected(revive):
		EventBus.player_respawn_requested.connect(revive)


func _exit_tree() -> void:
	if EventBus.enemy_died.is_connected(_on_enemy_died):
		EventBus.enemy_died.disconnect(_on_enemy_died)
	if EventBus.player_respawn_requested.is_connected(revive):
		EventBus.player_respawn_requested.disconnect(revive)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if EventBus != null and EventBus.enemy_died.is_connected(_on_enemy_died):
			EventBus.enemy_died.disconnect(_on_enemy_died)
		if EventBus != null and EventBus.player_respawn_requested.is_connected(revive):
			EventBus.player_respawn_requested.disconnect(revive)


## ผูก node ลูก + signal + input action — แยกจาก _ready ให้เทสต์เรียกได้โดยไม่ต้องอยู่ใน scene tree
func setup() -> void:
	# กล้อง/HUD แยกว่าใครโดนตีด้วย group นี้ (สั่นแรงกว่า, สีตัวเลขต่างกัน)
	add_to_group(&"player")
	ensure_input_actions()
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = Combat.LAYER_PLAYER
	collision_mask = Combat.LAYER_WORLD | Combat.LAYER_ENEMY

	dir_sprite = get_node_or_null("DirSprite") as DirSprite
	sprite = dir_sprite
	if sprite == null:
		sprite = get_node_or_null("Sprite2D") as Node2D
	if sprite == null:
		sprite = get_node_or_null("Sprite") as Node2D
	collision_shape = get_node_or_null("CollisionShape2D") as CollisionShape2D
	health = get_node_or_null("Health") as Health
	hurtbox = get_node_or_null("Hurtbox") as Hurtbox
	hitbox = get_node_or_null("Hitbox") as Hitbox
	lock_area = get_node_or_null("LockArea") as Area2D

	if health != null:
		health.max_hp = max_hp
		if not is_inside_tree():
			health.reset()
		if not health.died.is_connected(_on_died):
			health.died.connect(_on_died)

	stamina = stamina_max
	_regen_wait = 0.0
	stamina_changed.emit(stamina, stamina_max)
	refill_flasks()

	if hitbox != null:
		hitbox.source = self
		hitbox.team = Combat.Team.PLAYER
		hitbox.damage = attack_damage
		hitbox.knockback_force = attack_knockback
		hitbox.stagger = attack_stagger
		hitbox.deactivate()

	if hurtbox != null:
		hurtbox.team = Combat.Team.PLAYER
		hurtbox.invulnerable = false
		if not hurtbox.hurt.is_connected(_on_hurt):
			hurtbox.hurt.connect(_on_hurt)
		if not hurtbox.deflected.is_connected(_on_deflected):
			hurtbox.deflected.connect(_on_deflected)

	if lock_area != null:
		lock_area.collision_layer = 0
		lock_area.collision_mask = Combat.LAYER_HURTBOX
		lock_area.monitoring = true
		lock_area.monitorable = false
		var shape_node: CollisionShape2D = lock_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if shape_node != null and shape_node.shape is CircleShape2D:
			shape_node.shape = shape_node.shape.duplicate()
		_update_lock_area_radius()


func _update_lock_area_radius() -> void:
	if lock_area == null:
		return
	var shape_node: CollisionShape2D = lock_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node != null and shape_node.shape is CircleShape2D:
		(shape_node.shape as CircleShape2D).radius = lock_range


## ลงทะเบียน input action ตอน runtime ถ้ายังไม่มีใน InputMap
static func ensure_input_actions() -> void:
	_register_action_if_missing(&"move_left", [_key(KEY_A), _key(KEY_LEFT)])
	_register_action_if_missing(&"move_right", [_key(KEY_D), _key(KEY_RIGHT)])
	_register_action_if_missing(&"move_up", [_key(KEY_W), _key(KEY_UP)])
	_register_action_if_missing(&"move_down", [_key(KEY_S), _key(KEY_DOWN)])
	_register_action_if_missing(&"attack", [_mouse(MOUSE_BUTTON_LEFT), _key(KEY_J)])
	_register_action_if_missing(&"dodge", [_key(KEY_SPACE), _key(KEY_SHIFT)])
	_register_action_if_missing(&"parry", [_key(KEY_F), _mouse(MOUSE_BUTTON_RIGHT)])
	_register_action_if_missing(&"lock_on", [_key(KEY_TAB), _mouse(MOUSE_BUTTON_MIDDLE)])
	_register_action_if_missing(&"heal", [_key(KEY_R), _joy(JOY_BUTTON_Y)])


## ใส่ปุ่ม default เฉพาะตอนสร้าง action ใหม่ — action ที่มีอยู่แล้ว (ผู้เล่นเปลี่ยนปุ่มไว้) ห้ามเติม default กลับ
static func _register_action_if_missing(action: StringName, events: Array[InputEvent]) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for event: InputEvent in events:
		InputMap.action_add_event(action, event)


static func _key(keycode: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	ev.keycode = keycode
	return ev


static func _joy(button: JoyButton) -> InputEventJoypadButton:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	return ev


static func _mouse(button: MouseButton) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	return ev


## คำนวณดาเมจหลังหัก defense — ขั้นต่ำ 1 ตาม contract damage
static func compute_damage(amount: int, def: int) -> int:
	return maxi(1, amount - def)


## รับ input intent จากภายนอก — เพื่อให้ unit test หรือ AI ป้อนได้
func set_intent(
	move: Vector2,
	aim_dir: Vector2,
	attack: bool,
	dodge: bool,
	parry: bool = false,
	lock_on: bool = false,
	attack_held: bool = false,
	heal: bool = false
) -> void:
	move_dir = move
	if aim_dir.length_squared() > 0.0001:
		aim = aim_dir.normalized()
	_intent_attack = attack
	_intent_dodge = dodge
	_intent_parry = parry
	_intent_lock_on = lock_on
	_intent_attack_held = attack_held
	_intent_heal = heal


func _physics_process(delta: float) -> void:
	if not manual_control:
		_read_input()
	tick(delta)
	move_and_slide()


## Logic 1 เฟรม (ไม่รวม move_and_slide) — เทสต์เรียกตรงได้
func tick(delta: float) -> void:
	if _intent_lock_on:
		cycle_lock_target()

	if _has_lock_target:
		if not is_instance_valid(lock_target) or not _is_valid_locked_target(lock_target):
			_set_lock_target(null)
		else:
			var to_target: Vector2 = lock_target.global_position - (global_position + Vector2(0.0, body_y))
			if to_target.length_squared() > 0.0001:
				aim = to_target.normalized()

	var prev_state: State = state
	match state:
		State.MOVE:
			_state_move()
		State.DODGE:
			_state_dodge(delta)
		State.ATTACK:
			_state_attack(delta)
		State.HURT:
			_state_hurt(delta)
		State.PARRY:
			_state_parry(delta)
		State.DRINK:
			_state_drink(delta)
		State.DEAD:
			velocity = Vector2.ZERO
	if state != State.PARRY and hurtbox != null:
		hurtbox.deflecting = false  # ออกจาก parry ทางไหนก็ตาม (dodge ยกเลิก/โดนตี) ต้องปิดหน้าต่างปัด

	knock = knock.move_toward(Vector2.ZERO, knockback_friction * delta)
	velocity += knock

	if not _is_busy_state(prev_state) and not _is_busy_state(state):
		_regen(delta)

	_intent_attack = false
	_intent_dodge = false
	_intent_parry = false
	_intent_lock_on = false
	_intent_heal = false


func _is_busy_state(s: State) -> bool:
	return s == State.DODGE or s == State.ATTACK or s == State.DEAD or s == State.PARRY or s == State.DRINK


func _process(delta: float) -> void:
	_animate(delta)
	queue_redraw()


func _read_input() -> void:
	var move: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	var mouse_pos: Vector2 = get_global_mouse_position()
	var to_mouse: Vector2 = mouse_pos - (global_position + Vector2(0.0, body_y))
	var aim_dir: Vector2 = to_mouse.normalized() if to_mouse.length() > 4.0 else aim
	if is_locked_on():
		var to_target: Vector2 = lock_target.global_position - (global_position + Vector2(0.0, body_y))
		if to_target.length_squared() > 0.0001:
			aim_dir = to_target.normalized()
	var atk: bool = Input.is_action_just_pressed(&"attack")
	var atk_held: bool = Input.is_action_pressed(&"attack")
	var ddg: bool = Input.is_action_just_pressed(&"dodge")
	var pry: bool = Input.is_action_just_pressed(&"parry")
	var lck: bool = Input.is_action_just_pressed(&"lock_on")
	var hel: bool = Input.is_action_just_pressed(&"heal")
	set_intent(move, aim_dir, atk, ddg, pry, lck, atk_held, hel)


func _state_move() -> void:
	var dir: Vector2 = move_dir.normalized() if move_dir.length_squared() > 1.0 else move_dir
	velocity = dir * speed
	if _intent_dodge:
		_start_dodge()
	elif _intent_parry:
		_start_parry()
	elif _intent_heal and _start_drink():
		pass
	elif _intent_attack:
		_start_attack()


func _start_dodge() -> bool:
	if stamina < dodge_cost:
		stamina_empty.emit()
		return false
	_spend_stamina(dodge_cost)
	state = State.DODGE
	attack_phase = AttackPhase.NONE
	_state_t = 0.0
	dodge_dir = move_dir.normalized() if move_dir.length() > 0.1 else (-aim.normalized() if aim != Vector2.ZERO else Vector2.LEFT)
	if hurtbox != null:
		hurtbox.invulnerable = true
	collision_mask = Combat.LAYER_WORLD
	if hitbox != null:
		hitbox.deactivate()
	velocity = dodge_dir * dodge_speed
	return true


func _state_dodge(delta: float) -> void:
	_state_t += delta
	var t: float = clampf(_state_t / dodge_time, 0.0, 1.0)
	velocity = dodge_dir * dodge_speed * (1.0 - t * 0.6)
	if _state_t >= iframe_time:
		if hurtbox != null:
			hurtbox.invulnerable = false
	if is_inside_tree() and get_parent() != null:
		_ghost_t -= delta
		if _ghost_t <= 0.0:
			_ghost_t = 0.035
			_spawn_ghost()
	if _state_t >= dodge_time:
		state = State.MOVE
		if hurtbox != null:
			hurtbox.invulnerable = false
		collision_mask = Combat.LAYER_WORLD | Combat.LAYER_ENEMY
		_state_t = 0.0


func _start_parry() -> bool:
	if stamina < parry_cost:
		stamina_empty.emit()
		return false
	_spend_stamina(parry_cost)
	state = State.PARRY
	attack_phase = AttackPhase.NONE
	_state_t = 0.0
	velocity = Vector2.ZERO
	if hitbox != null:
		hitbox.deactivate()
	if hurtbox != null:
		hurtbox.deflecting = true
	return true


func _state_parry(delta: float) -> void:
	velocity = Vector2.ZERO
	_state_t += delta
	if hurtbox != null:
		hurtbox.deflecting = _state_t <= parry_window
	if _state_t >= (parry_window + parry_recover):
		state = State.MOVE
		_state_t = 0.0


func can_drink() -> bool:
	if state != State.MOVE:
		return false
	if flasks <= 0:
		return false
	if health != null and health.hp >= health.max_hp:
		return false
	return true


func is_drinking() -> bool:
	return state == State.DRINK


func refill_flasks() -> void:
	flasks = flask_max
	flasks_changed.emit(flasks, flask_max)


func start_drink() -> bool:
	return _start_drink()


func _start_drink() -> bool:
	if not can_drink():
		return false
	flasks -= 1
	flasks_changed.emit(flasks, flask_max)
	state = State.DRINK
	attack_phase = AttackPhase.NONE
	_state_t = 0.0
	_drink_healed = false
	if hitbox != null:
		hitbox.deactivate()
	var dir: Vector2 = move_dir.normalized() if move_dir.length_squared() > 1.0 else move_dir
	velocity = dir * speed * 0.3
	return true


func _state_drink(delta: float) -> void:
	if _intent_dodge:
		if _start_dodge():
			return

	var dir: Vector2 = move_dir.normalized() if move_dir.length_squared() > 1.0 else move_dir
	velocity = dir * speed * 0.3

	_state_t += delta

	if not _drink_healed and _state_t >= (heal_at - 0.0001):
		_drink_healed = true
		if health != null:
			health.heal(flask_heal)
		_flash_t = 0.2
		_flash_color = Color(0.7, 2.2, 0.9)

	if _state_t >= (drink_time - 0.0001):
		state = State.MOVE
		_state_t = 0.0


func _start_attack() -> bool:
	if stamina < attack_cost:
		stamina_empty.emit()
		return false
	_spend_stamina(attack_cost)
	state = State.ATTACK
	attack_phase = AttackPhase.WINDUP
	_state_t = 0.0
	_charge_t = 0.0
	_is_heavy_attack = false
	swing = 0.0
	_combo_side = -_combo_side
	if hitbox != null:
		hitbox.position = aim * hitbox_distance + Vector2(0.0, body_y)
		hitbox.damage = attack_damage
		hitbox.knockback_force = attack_knockback
		hitbox.stagger = attack_stagger
		hitbox.deactivate()
	velocity = aim * 30.0
	return true


func _state_attack(delta: float) -> void:
	match attack_phase:
		AttackPhase.WINDUP:
			velocity = aim * 30.0
			_state_t += delta
			_charge_t += delta
			if _intent_attack_held:
				if _charge_t >= charge_threshold:
					attack_phase = AttackPhase.CHARGING
					_state_t = 0.0
			else:
				if _state_t >= windup_time:
					_unleash_attack(false)
		AttackPhase.CHARGING:
			if _intent_dodge:
				if _start_dodge():
					return
			elif _intent_parry:
				if _start_parry():
					return

			velocity = Vector2.ZERO
			_state_t += delta
			_charge_t += delta
			if not _intent_attack_held:
				if _charge_t >= charge_time:
					var extra_cost: float = charge_cost - attack_cost
					if stamina >= extra_cost:
						_spend_stamina(extra_cost)
						_unleash_attack(true)
					else:
						stamina_empty.emit()
						_unleash_attack(false)
				else:
					_unleash_attack(false)
		AttackPhase.ACTIVE:
			var k: float = clampf(1.0 - _state_t / active_time, 0.0, 1.0)
			var current_rush: float = charge_rush_speed if _is_heavy_attack else rush_speed
			velocity = aim * current_rush * k
			swing = clampf(_state_t / active_time, 0.0, 1.0)
			_state_t += delta
			if _state_t >= active_time:
				attack_phase = AttackPhase.RECOVER
				_state_t = 0.0
				swing = 1.0
				if hitbox != null:
					hitbox.deactivate()
		AttackPhase.RECOVER:
			velocity = Vector2.ZERO
			swing = 1.0
			if _intent_dodge:
				if _start_dodge():
					return
			_state_t += delta
			var rec_mult: float = charge_recover_mult if _is_heavy_attack else 1.0
			var rec_time: float = recover_time * rec_mult
			if _state_t >= rec_time:
				state = State.MOVE
				attack_phase = AttackPhase.NONE
				_state_t = 0.0
				swing = 0.0
				_is_heavy_attack = false


func _unleash_attack(is_heavy: bool) -> void:
	_is_heavy_attack = is_heavy
	attack_phase = AttackPhase.ACTIVE
	_state_t = 0.0
	swing = 0.0
	if hitbox != null:
		hitbox.position = aim * hitbox_distance + Vector2(0.0, body_y)
		if is_heavy:
			hitbox.damage = int(round(attack_damage * charge_mult))
			hitbox.knockback_force = attack_knockback * charge_mult
			hitbox.stagger = attack_stagger * charge_mult
		else:
			hitbox.damage = attack_damage
			hitbox.knockback_force = attack_knockback
			hitbox.stagger = attack_stagger
		hitbox.activate()


func _state_hurt(delta: float) -> void:
	velocity = Vector2.ZERO
	_state_t += delta
	if _state_t >= hurt_time:
		state = State.MOVE
		_state_t = 0.0


func _spend_stamina(cost: float) -> void:
	stamina = maxf(0.0, stamina - cost)
	_regen_wait = regen_delay
	stamina_changed.emit(stamina, stamina_max)


func _regen(delta: float) -> void:
	if _is_busy_state(state):
		return
	if _regen_wait > 0.0:
		if delta <= _regen_wait:
			_regen_wait -= delta
			return
		else:
			delta -= _regen_wait
			_regen_wait = 0.0
	if stamina < stamina_max:
		stamina = minf(stamina_max, stamina + stamina_regen * delta)
		stamina_changed.emit(stamina, stamina_max)


func _on_hurt(info: DamageInfo) -> void:
	if state == State.DEAD:
		return

	var final_amount: int = compute_damage(info.amount, defense)
	var dealt: int = health.take_damage(final_amount)
	EventBus.damage_dealt.emit(self, info, dealt)
	knock = info.knockback
	_flash_t = 0.1
	_flash_color = Color(2.5, 0.7, 0.7)
	if not health.is_dead:
		state = State.HURT
		attack_phase = AttackPhase.NONE
		_state_t = 0.0
		swing = 0.0
		if hitbox != null:
			hitbox.deactivate()


## parry สำเร็จ (Hurtbox.deflected ระหว่างหน้าต่าง parry) — ไม่เสียเลือด · ผู้ตีได้ Hitbox.deflected
func _on_deflected(info: DamageInfo) -> void:
	if state != State.PARRY:
		return
	if hurtbox != null:
		hurtbox.deflecting = false
	stamina = minf(stamina_max, stamina + parry_refund)
	_regen_wait = 0.0
	stamina_changed.emit(stamina, stamina_max)
	parried.emit(info)
	EventBus.attack_deflected.emit(self, info)
	_flash_t = 0.15
	_flash_color = Color(2.5, 2.3, 1.2)
	state = State.MOVE
	_state_t = 0.0


## ฟื้นเต็มที่ตำแหน่งที่ dungeon ส่งมา (EventBus.player_respawn_requested) — ใช้ได้ทั้งตอนตายและยังไม่ตาย
func revive(at: Vector2 = Vector2.ZERO) -> void:
	global_position = at
	if health != null:
		health.reset()
	stamina = stamina_max
	stamina_changed.emit(stamina, stamina_max)
	refill_flasks()
	_died_emitted = false
	state = State.MOVE
	attack_phase = AttackPhase.NONE
	_state_t = 0.0
	velocity = Vector2.ZERO
	knock = Vector2.ZERO
	unlock()
	if hurtbox != null:
		hurtbox.invulnerable = false
		hurtbox.deflecting = false
	if hitbox != null:
		hitbox.deactivate()
	collision_layer = Combat.LAYER_PLAYER
	collision_mask = Combat.LAYER_WORLD | Combat.LAYER_ENEMY
	if sprite != null:
		sprite.modulate = Color.WHITE
	if dir_sprite != null:
		dir_sprite.play_action(&"idle")


func _on_died() -> void:
	if _died_emitted:
		return
	_died_emitted = true
	state = State.DEAD
	attack_phase = AttackPhase.NONE
	if hurtbox != null:
		hurtbox.invulnerable = true
	if hitbox != null:
		hitbox.deactivate()
	set_deferred(&"collision_layer", 0)
	EventBus.player_died.emit()
	if dir_sprite != null:
		dir_sprite.self_modulate = Color.WHITE
		dir_sprite.scale = Vector2.ONE
		dir_sprite.play_action(&"death")  # ค้างเฟรมสุดท้าย (ท่า death ไม่ loop)
	elif sprite != null and is_inside_tree():
		var tw: Tween = create_tween()
		tw.tween_property(sprite, "modulate", Color(0.4, 0.2, 0.2, 0.0), 1.2)


func is_dead() -> bool:
	return state == State.DEAD


func is_locked_on() -> bool:
	return is_instance_valid(lock_target)


func is_parrying() -> bool:
	return state == State.PARRY


func is_in_parry_window() -> bool:
	return state == State.PARRY and _state_t <= parry_window


func is_charging() -> bool:
	return state == State.ATTACK and attack_phase == AttackPhase.CHARGING


func is_charged() -> bool:
	return is_charging() and _charge_t >= charge_time


func can_charge() -> bool:
	if state == State.ATTACK and attack_phase == AttackPhase.CHARGING:
		return stamina >= (charge_cost - attack_cost)
	return stamina >= charge_cost


func unlock() -> void:
	_set_lock_target(null)


func cycle_lock_target() -> void:
	var candidates: Array[Node2D] = get_lock_candidates()
	if candidates.is_empty():
		_set_lock_target(null)
		return
	candidates.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position)
	)
	if not is_instance_valid(lock_target) or not candidates.has(lock_target):
		_set_lock_target(candidates[0])
	else:
		var idx: int = candidates.find(lock_target)
		var next_idx: int = (idx + 1) % candidates.size()
		_set_lock_target(candidates[next_idx])


func _set_lock_target(target: Node2D) -> void:
	if is_instance_valid(lock_target) and lock_target == target:
		return
	lock_target = target
	_has_lock_target = is_instance_valid(target)
	lock_target_changed.emit(lock_target)


func get_lock_candidates() -> Array[Node2D]:
	var candidates: Array[Node2D] = []
	var seen: Dictionary = {}

	if lock_area != null and lock_area.is_inside_tree():
		for area: Area2D in lock_area.get_overlapping_areas():
			if area is Hurtbox and (area as Hurtbox).team != Combat.Team.PLAYER and (area as Hurtbox).monitorable:
				var entity: Node2D = _resolve_target_entity(area)
				if entity != null and is_instance_valid(entity) and not seen.has(entity):
					if global_position.distance_to(entity.global_position) <= lock_range:
						seen[entity] = true
						candidates.append(entity)

	for t: Node2D in test_targets:
		if is_instance_valid(t) and not seen.has(t):
			if global_position.distance_to(t.global_position) <= lock_range:
				seen[t] = true
				candidates.append(t)

	return candidates


## เป้า = parent ของ Hurtbox (ตัวศัตรู) — ไม่ใช้ owner: ศัตรูที่วางตรง ๆ ใน .tscn ของห้อง owner = ห้องทั้งห้อง
static func _resolve_target_entity(area: Area2D) -> Node2D:
	if area is Hurtbox:
		var p: Node = area.get_parent()
		if p is Node2D:
			return p as Node2D
		if area.owner is Node2D:
			return area.owner as Node2D
	return area


func _is_valid_locked_target(t: Node2D) -> bool:
	if not is_instance_valid(t) or t.is_queued_for_deletion():
		return false
	if global_position.distance_to(t.global_position) > lock_range * lock_release_mult:
		return false
	return true


func _on_enemy_died(enemy: Node, _id: StringName, _pos: Vector2) -> void:
	if not is_instance_valid(enemy):
		return
	if is_instance_valid(lock_target):
		if lock_target == enemy or lock_target.owner == enemy or lock_target.get_parent() == enemy:
			_set_lock_target(null)
		elif enemy.is_inside_tree() and lock_target.is_inside_tree() and enemy.is_ancestor_of(lock_target):
			_set_lock_target(null)


func _draw() -> void:
	# เงาใต้เท้า
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 13.0, Color(0.0, 0.0, 0.0, 0.45))
	draw_set_transform(Vector2.ZERO)

	# วงดาบตอนฟัน
	if state == State.ATTACK and attack_phase != AttackPhase.WINDUP and attack_phase != AttackPhase.CHARGING and attack_phase != AttackPhase.NONE:
		var a0: float = aim.angle() - 1.3 * _combo_side
		var sweep: float = 2.6 * _combo_side * swing
		var alpha: float = 1.0 if attack_phase == AttackPhase.ACTIVE else clampf(1.0 - _state_t / recover_time, 0.0, 1.0)
		if _is_heavy_attack:
			draw_arc(Vector2(0.0, body_y), 36.0, a0, a0 + sweep, 20, Color(1.0, 0.7, 0.2, 0.95 * alpha), 7.0)
			draw_arc(Vector2(0.0, body_y), 42.0, a0, a0 + sweep, 20, Color(1.0, 0.95, 0.5, 0.7 * alpha), 3.0)
		else:
			draw_arc(Vector2(0.0, body_y), 25.0, a0, a0 + sweep, 16, Color(1.0, 1.0, 0.9, 0.9 * alpha), 5.0)
			draw_arc(Vector2(0.0, body_y), 30.0, a0, a0 + sweep, 16, Color(0.6, 0.85, 1.0, 0.5 * alpha), 2.0)

	# เอฟเฟกต์ชาร์จ
	if state == State.ATTACK and attack_phase == AttackPhase.CHARGING:
		var prog: float = clampf(_charge_t / charge_time, 0.0, 1.0)
		var col: Color = Color(1.0, 0.85, 0.2, 0.85) if prog >= 1.0 else Color(0.6, 0.8, 1.0, 0.4 + 0.4 * prog)
		var rad: float = 22.0 if prog >= 1.0 else (12.0 + 10.0 * prog)
		draw_arc(Vector2(0.0, body_y), rad, 0.0, TAU, 20, col, 2.5 if prog >= 1.0 else 1.5)

	# โล่ Parry
	if state == State.PARRY:
		var is_active: bool = _state_t <= parry_window
		var parry_col: Color = Color(0.3, 0.8, 1.0, 0.9) if is_active else Color(0.5, 0.5, 0.5, 0.4)
		var arc_width: float = 4.0 if is_active else 2.0
		var a0: float = aim.angle() - 1.0
		draw_arc(Vector2(0.0, body_y), 22.0, a0, a0 + 2.0, 16, parry_col, arc_width)

	# เอฟเฟกต์ฟื้นพลังขวดชา
	if state == State.DRINK and _drink_healed:
		draw_arc(Vector2(0.0, body_y), 18.0, 0.0, TAU, 16, Color(0.4, 1.0, 0.5, 0.6), 2.0)

	# ล็อคเป้า
	if is_locked_on():
		var rel_pos: Vector2 = lock_target.global_position - global_position
		var target_center: Vector2 = rel_pos + Vector2(0.0, -16.0)
		var lock_col := Color(1.0, 0.8, 0.2, 0.85)
		var d: float = 14.0
		draw_line(target_center + Vector2(-d, -d), target_center + Vector2(-d + 6, -d), lock_col, 2.0)
		draw_line(target_center + Vector2(-d, -d), target_center + Vector2(-d, -d + 6), lock_col, 2.0)
		draw_line(target_center + Vector2(d, -d), target_center + Vector2(d - 6, -d), lock_col, 2.0)
		draw_line(target_center + Vector2(d, -d), target_center + Vector2(d, -d + 6), lock_col, 2.0)
		draw_line(target_center + Vector2(-d, d), target_center + Vector2(-d + 6, d), lock_col, 2.0)
		draw_line(target_center + Vector2(-d, d), target_center + Vector2(-d, d - 6), lock_col, 2.0)
		draw_line(target_center + Vector2(d, d), target_center + Vector2(d - 6, d), lock_col, 2.0)
		draw_line(target_center + Vector2(d, d), target_center + Vector2(d, d - 6), lock_col, 2.0)


func _animate(delta: float) -> void:
	if sprite == null or state == State.DEAD:
		return
	var moving: bool = state == State.MOVE and velocity.length() > 10.0
	if dir_sprite != null:
		_animate_dir_sprite(moving)
	elif sprite is Sprite2D:
		(sprite as Sprite2D).flip_h = aim.x < 0.0
	if moving:
		_walk_t += delta * 14.0
	# ภาพ 8 ทิศมีท่าเดินเองแล้ว → ไม่เด้งตัวด้วยโค้ด
	var bob: float = absf(sin(_walk_t)) * 2.0 if moving and dir_sprite == null else 0.0
	sprite.position = Vector2(0.0, -bob)
	sprite.scale = Vector2.ONE
	sprite.skew = 0.0

	if _flash_t > 0.0:
		_flash_t -= delta
		sprite.self_modulate = _flash_color
	else:
		sprite.self_modulate = Color.WHITE

	match state:
		State.DODGE:
			sprite.scale = Vector2(1.12, 0.88)
			sprite.skew = dodge_dir.x * 0.25
			sprite.modulate.a = 0.6 if (hurtbox != null and hurtbox.invulnerable) else 1.0
		State.PARRY:
			sprite.scale = Vector2(0.95, 1.05)
			if _state_t <= parry_window:
				sprite.self_modulate = Color(1.4, 1.8, 2.5)
		State.ATTACK:
			if attack_phase == AttackPhase.WINDUP:
				sprite.scale = Vector2(1.06, 0.94)
			elif attack_phase == AttackPhase.CHARGING:
				var prog: float = clampf(_charge_t / charge_time, 0.0, 1.0)
				sprite.scale = Vector2(1.08 + 0.05 * sin(_charge_t * 20.0), 0.92 - 0.05 * sin(_charge_t * 20.0))
				if prog >= 1.0:
					sprite.self_modulate = Color(2.5, 2.0, 0.8)
				else:
					sprite.self_modulate = Color(1.0 + prog, 1.0 + prog, 1.0)
			else:
				sprite.position += (aim * 2.0).round()
		State.DRINK:
			if _flash_t <= 0.0 and not _drink_healed:
				sprite.scale = Vector2(0.97, 1.03)
		_:
			sprite.modulate.a = 1.0


## ท่าของ DirSprite ตาม state · หันตามทิศเดิน (ตอนเดิน) หรือทิศเล็ง (โจมตี/parry/lock-on)
func _animate_dir_sprite(moving: bool) -> void:
	var face: Vector2 = aim
	if state == State.MOVE and moving and not is_locked_on():
		face = velocity
	elif state == State.DODGE:
		face = dodge_dir
	elif state == State.HURT:
		face = Vector2.ZERO  # โดนตีแล้วคงทิศเดิม
	elif state == State.DRINK and moving and not is_locked_on():
		face = velocity
	dir_sprite.set_facing(face)
	match state:
		State.MOVE:
			dir_sprite.play_action(&"walk" if moving else &"idle")
		State.DODGE:
			dir_sprite.play_action(&"dodge")
		State.HURT:
			dir_sprite.play_action(&"hurt")
		State.DRINK:
			dir_sprite.play_action(&"idle")
		_:
			dir_sprite.play_action(&"idle")  # ATTACK/PARRY ใช้ idle + เอฟเฟกต์จนกว่าจะมีท่าฟัน


func _spawn_ghost() -> void:
	if sprite == null:
		return
	var tex: Texture2D = null
	var off: Vector2 = Vector2.ZERO
	var flip: bool = false
	if dir_sprite != null and dir_sprite.sprite_frames != null:
		tex = dir_sprite.sprite_frames.get_frame_texture(dir_sprite.animation, dir_sprite.frame)
		off = dir_sprite.offset
	elif sprite is Sprite2D:
		tex = (sprite as Sprite2D).texture
		off = (sprite as Sprite2D).offset
		flip = (sprite as Sprite2D).flip_h
	if tex == null:
		return
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	var g := Sprite2D.new()
	g.texture = tex
	g.offset = off
	g.flip_h = flip
	g.global_position = global_position + sprite.position
	g.modulate = Color(0.55, 0.8, 1.0, 0.5)
	parent_node.add_child(g)
	var tw: Tween = g.create_tween()
	tw.tween_property(g, "modulate:a", 0.0, 0.25)
	tw.tween_callback(g.queue_free)
