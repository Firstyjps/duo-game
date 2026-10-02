class_name Player
extends CharacterBody2D
## ผู้เล่นจริง (ระบบ A) — เดิน · ฟัน · dodge + i-frames · stamina · contract damage
## docs/contracts/damage.md

signal stamina_changed(current: float, maximum: float)
signal stamina_empty

enum State { MOVE, DODGE, ATTACK, HURT, DEAD }
enum AttackPhase { NONE, WINDUP, ACTIVE, RECOVER }

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
@export var hitbox_distance: float = 24.0

@export_group("Hurt")
@export var hurt_time: float = 0.2
@export var body_y: float = -16.0

var state: State = State.MOVE
var attack_phase: AttackPhase = AttackPhase.NONE
var stamina: float = 100.0
var aim: Vector2 = Vector2.RIGHT
var move_dir: Vector2 = Vector2.ZERO
var dodge_dir: Vector2 = Vector2.RIGHT
var knock: Vector2 = Vector2.ZERO
var swing: float = 0.0
var manual_control: bool = false

var _state_t: float = 0.0
var _regen_wait: float = 0.0
var _died_emitted: bool = false
var _intent_attack: bool = false
var _intent_dodge: bool = false
var _walk_t: float = 0.0
var _flash_t: float = 0.0
var _ghost_t: float = 0.0
var _combo_side: float = 1.0

var sprite: Sprite2D
var collision_shape: CollisionShape2D
var health: Health
var hurtbox: Hurtbox
var hitbox: Hitbox


func _ready() -> void:
	setup()


## ผูก node ลูก + signal + input action — แยกจาก _ready ให้เทสต์เรียกได้โดยไม่ต้องอยู่ใน scene tree
func setup() -> void:
	ensure_input_actions()
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = Combat.LAYER_PLAYER
	collision_mask = Combat.LAYER_WORLD | Combat.LAYER_ENEMY

	sprite = get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		sprite = get_node_or_null("Sprite") as Sprite2D
	collision_shape = get_node_or_null("CollisionShape2D") as CollisionShape2D
	health = get_node_or_null("Health") as Health
	hurtbox = get_node_or_null("Hurtbox") as Hurtbox
	hitbox = get_node_or_null("Hitbox") as Hitbox

	if health != null:
		health.max_hp = max_hp
		if not is_inside_tree():
			health.reset()
		if not health.died.is_connected(_on_died):
			health.died.connect(_on_died)

	stamina = stamina_max
	_regen_wait = 0.0
	stamina_changed.emit(stamina, stamina_max)

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


## ลงทะเบียน input action ตอน runtime ถ้ายังไม่มีใน InputMap
static func ensure_input_actions() -> void:
	_register_action_if_missing(&"move_left", [_key(KEY_A), _key(KEY_LEFT)])
	_register_action_if_missing(&"move_right", [_key(KEY_D), _key(KEY_RIGHT)])
	_register_action_if_missing(&"move_up", [_key(KEY_W), _key(KEY_UP)])
	_register_action_if_missing(&"move_down", [_key(KEY_S), _key(KEY_DOWN)])
	_register_action_if_missing(&"attack", [_mouse(MOUSE_BUTTON_LEFT), _key(KEY_J)])
	_register_action_if_missing(&"dodge", [_key(KEY_SPACE), _key(KEY_SHIFT)])


static func _register_action_if_missing(action: StringName, events: Array[InputEvent]) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for event: InputEvent in events:
		if not InputMap.action_has_event(action, event):
			InputMap.action_add_event(action, event)


static func _key(keycode: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	ev.keycode = keycode
	return ev


static func _mouse(button: MouseButton) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	return ev


## คำนวณดาเมจหลังหัก defense — ขั้นต่ำ 1 ตาม contract damage
static func compute_damage(amount: int, def: int) -> int:
	return maxi(1, amount - def)


## รับ input intent จากภายนอก — เพื่อให้ unit test หรือ AI ป้อนได้
func set_intent(move: Vector2, aim_dir: Vector2, attack: bool, dodge: bool) -> void:
	move_dir = move
	if aim_dir.length_squared() > 0.0001:
		aim = aim_dir.normalized()
	_intent_attack = attack
	_intent_dodge = dodge


func _physics_process(delta: float) -> void:
	if not manual_control:
		_read_input()
	tick(delta)
	move_and_slide()


## Logic 1 เฟรม (ไม่รวม move_and_slide) — เทสต์เรียกตรงได้
func tick(delta: float) -> void:
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
		State.DEAD:
			velocity = Vector2.ZERO

	knock = knock.move_toward(Vector2.ZERO, knockback_friction * delta)
	velocity += knock

	if prev_state != State.DODGE and prev_state != State.ATTACK and prev_state != State.DEAD \
		and state != State.DODGE and state != State.ATTACK and state != State.DEAD:
		_regen(delta)

	_intent_attack = false
	_intent_dodge = false


func _process(delta: float) -> void:
	_animate(delta)
	queue_redraw()


func _read_input() -> void:
	var move: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	var mouse_pos: Vector2 = get_global_mouse_position()
	var to_mouse: Vector2 = mouse_pos - (global_position + Vector2(0.0, body_y))
	var aim_dir: Vector2 = to_mouse.normalized() if to_mouse.length() > 4.0 else aim
	var atk: bool = Input.is_action_just_pressed(&"attack")
	var ddg: bool = Input.is_action_just_pressed(&"dodge")
	set_intent(move, aim_dir, atk, ddg)


func _state_move() -> void:
	var dir: Vector2 = move_dir.normalized() if move_dir.length_squared() > 1.0 else move_dir
	velocity = dir * speed
	if _intent_dodge:
		_start_dodge()
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


func _start_attack() -> bool:
	if stamina < attack_cost:
		stamina_empty.emit()
		return false
	_spend_stamina(attack_cost)
	state = State.ATTACK
	attack_phase = AttackPhase.WINDUP
	_state_t = 0.0
	swing = 0.0
	_combo_side = -_combo_side
	if hitbox != null:
		hitbox.position = aim * hitbox_distance + Vector2(0.0, body_y)
		hitbox.deactivate()
	velocity = aim * 30.0
	return true


func _state_attack(delta: float) -> void:
	match attack_phase:
		AttackPhase.WINDUP:
			velocity = aim * 30.0
			_state_t += delta
			if _state_t >= windup_time:
				attack_phase = AttackPhase.ACTIVE
				_state_t = 0.0
				swing = 0.0
				if hitbox != null:
					hitbox.position = aim * hitbox_distance + Vector2(0.0, body_y)
					hitbox.activate()
		AttackPhase.ACTIVE:
			var k: float = clampf(1.0 - _state_t / active_time, 0.0, 1.0)
			velocity = aim * 140.0 * k
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
			if _state_t >= recover_time:
				state = State.MOVE
				attack_phase = AttackPhase.NONE
				_state_t = 0.0
				swing = 0.0


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
	if state == State.DODGE or state == State.ATTACK or state == State.DEAD:
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
	if not health.is_dead:
		state = State.HURT
		attack_phase = AttackPhase.NONE
		_state_t = 0.0
		swing = 0.0
		if hitbox != null:
			hitbox.deactivate()


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
	if sprite != null and is_inside_tree():
		var tw: Tween = create_tween()
		tw.tween_property(sprite, "modulate", Color(0.4, 0.2, 0.2, 0.0), 1.2)


func is_dead() -> bool:
	return state == State.DEAD


func _draw() -> void:
	# เงาใต้เท้า
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 13.0, Color(0.0, 0.0, 0.0, 0.45))
	draw_set_transform(Vector2.ZERO)

	# วงดาบตอนฟัน
	if state == State.ATTACK and attack_phase != AttackPhase.WINDUP and attack_phase != AttackPhase.NONE:
		var a0: float = aim.angle() - 1.3 * _combo_side
		var sweep: float = 2.6 * _combo_side * swing
		var alpha: float = 1.0 if attack_phase == AttackPhase.ACTIVE else clampf(1.0 - _state_t / recover_time, 0.0, 1.0)
		draw_arc(Vector2(0.0, body_y), 25.0, a0, a0 + sweep, 16, Color(1.0, 1.0, 0.9, 0.9 * alpha), 5.0)
		draw_arc(Vector2(0.0, body_y), 30.0, a0, a0 + sweep, 16, Color(0.6, 0.85, 1.0, 0.5 * alpha), 2.0)


func _animate(delta: float) -> void:
	if sprite == null or state == State.DEAD:
		return
	sprite.flip_h = aim.x < 0.0
	var moving: bool = state == State.MOVE and velocity.length() > 10.0
	if moving:
		_walk_t += delta * 14.0
	var bob: float = absf(sin(_walk_t)) * 2.0 if moving else 0.0
	sprite.position = Vector2(0.0, -bob)
	sprite.scale = Vector2.ONE
	sprite.skew = 0.0

	if _flash_t > 0.0:
		_flash_t -= delta
		sprite.self_modulate = Color(2.5, 0.7, 0.7)
	else:
		sprite.self_modulate = Color.WHITE

	match state:
		State.DODGE:
			sprite.scale = Vector2(1.12, 0.88)
			sprite.skew = dodge_dir.x * 0.25
			sprite.modulate.a = 0.6 if (hurtbox != null and hurtbox.invulnerable) else 1.0
		State.ATTACK:
			if attack_phase == AttackPhase.WINDUP:
				sprite.scale = Vector2(1.06, 0.94)
			else:
				sprite.position += (aim * 2.0).round()
		_:
			sprite.modulate.a = 1.0


func _spawn_ghost() -> void:
	if sprite == null or sprite.texture == null:
		return
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	var g := Sprite2D.new()
	g.texture = sprite.texture
	g.offset = sprite.offset
	g.flip_h = sprite.flip_h
	g.global_position = global_position + sprite.position
	g.modulate = Color(0.55, 0.8, 1.0, 0.5)
	parent_node.add_child(g)
	var tw: Tween = g.create_tween()
	tw.tween_property(g, "modulate:a", 0.0, 0.25)
	tw.tween_callback(g.queue_free)
