extends CharacterBody2D
## MOCKUP ผู้เล่น (อัศวิน) — เดิน · ฟัน · dodge + i-frames · stamina · ใช้ contract damage

signal stamina_changed(current: float, maximum: float)
signal stamina_empty

const Fx := preload("res://mockup/mockup_fx.gd")

const SPEED: float = 115.0
const DODGE_SPEED: float = 320.0
const DODGE_TIME: float = 0.28
const IFRAME_TIME: float = 0.24
const DODGE_COST: float = 25.0
const ATTACK_COST: float = 15.0
const STAMINA_MAX: float = 100.0
const STAMINA_REGEN: float = 45.0
const REGEN_DELAY: float = 0.55
const WINDUP: float = 0.07
const ACTIVE: float = 0.11
const RECOVER: float = 0.2
const HURT_TIME: float = 0.2
const BODY_Y: float = -16.0

enum State { MOVE, DODGE, ATTACK, HURT, DEAD }

var main: Node
var autoplay: bool = false
var state: State = State.MOVE
var stamina: float = STAMINA_MAX
var regen_wait: float = 0.0
var aim: Vector2 = Vector2.RIGHT
var move_dir: Vector2 = Vector2.ZERO
var timer: float = 0.0
var attack_phase: int = 0
var dodge_dir: Vector2 = Vector2.RIGHT
var knock: Vector2 = Vector2.ZERO
var walk_t: float = 0.0
var ghost_t: float = 0.0
var swing: float = 0.0
var combo_side: float = 1.0
var health: Health
var hurtbox: Hurtbox
var hitbox: Hitbox
var sprite: Sprite2D
var fx: Node2D
var mat: ShaderMaterial
var bot_move: Vector2 = Vector2.ZERO
var bot_attack: bool = false
var bot_dodge: bool = false


func _ready() -> void:
	collision_layer = Combat.LAYER_PLAYER
	collision_mask = Combat.LAYER_WORLD | Combat.LAYER_ENEMY
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var body := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 8.0
	body.shape = c
	add_child(body)
	sprite = Sprite2D.new()
	sprite.texture = load("res://mockup/assets/knight.png")
	sprite.offset = Vector2(0, -28)
	mat = Fx.flash_material()
	sprite.material = mat
	add_child(sprite)
	fx = Node2D.new()
	fx.z_index = 1
	fx.draw.connect(_draw_fx)
	add_child(fx)
	health = Health.new()
	health.max_hp = 12
	add_child(health)
	health.died.connect(_on_died)
	hurtbox = Hurtbox.new()
	hurtbox.team = Combat.Team.PLAYER
	Fx.circle_shape(hurtbox, 10.0, Vector2(0, BODY_Y))
	add_child(hurtbox)
	hurtbox.hurt.connect(_on_hurt)
	hitbox = Hitbox.new()
	hitbox.team = Combat.Team.PLAYER
	hitbox.damage = 3
	hitbox.knockback_force = 170.0
	hitbox.stagger = 1.0
	hitbox.source = self
	Fx.circle_shape(hitbox, 22.0, Vector2.ZERO)
	add_child(hitbox)
	add_child(Fx.light(Color(1.0, 0.9, 0.75), 0.6, 1.1))


func is_dead() -> bool:
	return state == State.DEAD


func _physics_process(delta: float) -> void:
	if autoplay:
		_bot_think()
	_read_input()
	match state:
		State.MOVE:
			_state_move()
		State.DODGE:
			_state_dodge(delta)
		State.ATTACK:
			_state_attack(delta)
		State.HURT:
			velocity = Vector2.ZERO
			timer -= delta
			if timer <= 0.0:
				state = State.MOVE
		State.DEAD:
			velocity = Vector2.ZERO
	knock = knock.move_toward(Vector2.ZERO, 900.0 * delta)
	velocity += knock
	move_and_slide()
	_regen(delta)
	_animate(delta)
	fx.queue_redraw()


func _read_input() -> void:
	if autoplay:
		move_dir = bot_move
		return
	move_dir = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	var to_mouse: Vector2 = get_global_mouse_position() - (global_position + Vector2(0, BODY_Y))
	if to_mouse.length() > 4.0:
		aim = to_mouse.normalized()


func _wants(action: StringName) -> bool:
	if autoplay:
		if action == &"attack" and bot_attack:
			bot_attack = false
			return true
		if action == &"dodge" and bot_dodge:
			bot_dodge = false
			return true
		return false
	return Input.is_action_just_pressed(action)


func _state_move() -> void:
	velocity = move_dir * SPEED
	if _wants(&"dodge"):
		_start_dodge()
	elif _wants(&"attack"):
		_start_attack()


func _start_dodge() -> void:
	if stamina < DODGE_COST:
		stamina_empty.emit()
		return
	_spend(DODGE_COST)
	state = State.DODGE
	timer = DODGE_TIME
	swing = 0.0
	dodge_dir = move_dir.normalized() if move_dir.length() > 0.1 else -aim
	hurtbox.invulnerable = true
	collision_mask = Combat.LAYER_WORLD
	hitbox.deactivate()


func _state_dodge(delta: float) -> void:
	timer -= delta
	var t: float = 1.0 - timer / DODGE_TIME
	velocity = dodge_dir * DODGE_SPEED * (1.0 - t * 0.6)
	if DODGE_TIME - timer >= IFRAME_TIME:
		hurtbox.invulnerable = false
	ghost_t -= delta
	if ghost_t <= 0.0:
		ghost_t = 0.035
		_ghost()
	if timer <= 0.0:
		state = State.MOVE
		hurtbox.invulnerable = false
		collision_mask = Combat.LAYER_WORLD | Combat.LAYER_ENEMY


func _start_attack() -> void:
	if stamina < ATTACK_COST:
		stamina_empty.emit()
		return
	_spend(ATTACK_COST)
	state = State.ATTACK
	attack_phase = 0
	timer = WINDUP
	swing = 0.0
	combo_side = -combo_side
	hitbox.position = aim * 24.0 + Vector2(0, BODY_Y)


func _state_attack(delta: float) -> void:
	timer -= delta
	match attack_phase:
		0:
			velocity = aim * 30.0
			if timer <= 0.0:
				attack_phase = 1
				timer = ACTIVE
				hitbox.activate()
		1:
			velocity = aim * 140.0 * (timer / ACTIVE)
			swing = 1.0 - timer / ACTIVE
			if timer <= 0.0:
				attack_phase = 2
				timer = RECOVER
				hitbox.deactivate()
		2:
			velocity = Vector2.ZERO
			swing = 1.0
			if _wants(&"dodge"):
				_start_dodge()
			elif timer <= 0.0:
				state = State.MOVE
				swing = 0.0


func _spend(cost: float) -> void:
	stamina -= cost
	regen_wait = REGEN_DELAY
	stamina_changed.emit(stamina, STAMINA_MAX)


func _regen(delta: float) -> void:
	if state == State.DODGE or state == State.ATTACK or state == State.DEAD:
		return
	if regen_wait > 0.0:
		regen_wait -= delta
		return
	if stamina < STAMINA_MAX:
		stamina = minf(STAMINA_MAX, stamina + STAMINA_REGEN * delta)
		stamina_changed.emit(stamina, STAMINA_MAX)


func _on_hurt(info: DamageInfo) -> void:
	if state == State.DEAD:
		return
	var final: int = maxi(1, info.amount)
	health.take_damage(final)
	EventBus.damage_dealt.emit(self, info, final)
	knock = info.knockback
	Fx.flash(mat, self, Color(1.0, 0.35, 0.3), 0.18)
	if not health.is_dead:
		state = State.HURT
		timer = HURT_TIME
		swing = 0.0
		hitbox.deactivate()


func _on_died() -> void:
	state = State.DEAD
	hurtbox.invulnerable = true
	hitbox.deactivate()
	EventBus.player_died.emit()
	var tw: Tween = create_tween()
	tw.tween_property(sprite, "modulate", Color(0.4, 0.2, 0.2, 0.0), 1.2)


func _ghost() -> void:
	var g := Sprite2D.new()
	g.texture = sprite.texture
	g.offset = sprite.offset
	g.flip_h = sprite.flip_h
	g.global_position = global_position + sprite.position
	g.modulate = Color(0.55, 0.8, 1.0, 0.5)
	get_parent().add_child(g)
	var tw: Tween = g.create_tween()
	tw.tween_property(g, "modulate:a", 0.0, 0.25)
	tw.tween_callback(g.queue_free)


func _animate(delta: float) -> void:
	if state == State.DEAD:
		return
	sprite.flip_h = aim.x < 0.0
	var moving: bool = state == State.MOVE and velocity.length() > 10.0
	if moving:
		walk_t += delta * 14.0
	var bob: float = absf(sin(walk_t)) * 2.0 if moving else 0.0
	sprite.position = Vector2(0, -bob)
	sprite.scale = Vector2.ONE
	sprite.skew = 0.0
	sprite.modulate.a = 1.0
	match state:
		State.DODGE:
			sprite.scale = Vector2(1.12, 0.88)
			sprite.skew = dodge_dir.x * 0.25
			sprite.modulate.a = 0.6 if hurtbox.invulnerable else 1.0
		State.ATTACK:
			if attack_phase == 0:
				sprite.scale = Vector2(1.06, 0.94)
			else:
				sprite.position += (aim * 2.0).round()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 13.0, Color(0, 0, 0, 0.45))
	draw_set_transform(Vector2.ZERO)


func _draw_fx() -> void:
	if state != State.ATTACK or attack_phase == 0:
		return
	var a0: float = aim.angle() - 1.3 * combo_side
	var sweep: float = 2.6 * combo_side * swing
	var alpha: float = 1.0 if attack_phase == 1 else clampf(timer / RECOVER * 2.0 - 1.0, 0.0, 1.0)
	fx.draw_arc(Vector2(0, BODY_Y), 25.0, a0, a0 + sweep, 16, Color(1.0, 1.0, 0.9, 0.9 * alpha), 5.0)
	fx.draw_arc(Vector2(0, BODY_Y), 30.0, a0, a0 + sweep, 16, Color(0.6, 0.85, 1.0, 0.5 * alpha), 2.0)


## ── AUTOPLAY (อัดคลิป) — บอทแบบ Souls-lite: รอ telegraph → หลบจังหวะท้าย → สวนตอนศัตรู recover ──
func _bot_think() -> void:
	bot_move = Vector2.ZERO
	if state == State.DEAD or main == null:
		return
	var body: Vector2 = global_position + Vector2(0, BODY_Y)
	var target: Node2D = null
	var best: float = INF
	for e in main.enemies:
		if not is_instance_valid(e) or not e.is_targetable():
			continue
		if e.is_threatening(body) and e.timer < 0.22 and stamina >= DODGE_COST:
			if state == State.MOVE or (state == State.ATTACK and attack_phase == 2):
				var side: Vector2 = (global_position - e.danger_center()).normalized().orthogonal()
				bot_move = side if side.dot(Vector2(480, 300) - global_position) > 0.0 else -side
				bot_dodge = true
				return
		var d: float = global_position.distance_to(e.global_position)
		if e.is_punishable():
			d -= 200.0
		if d < best:
			best = d
			target = e
	if target == null:
		return
	var to: Vector2 = target.global_position - global_position
	aim = (to + Vector2(0, -6)).normalized()
	var reach: float = 24.0 + target.body_radius()
	if target.is_punishable() or target.state == target.State.TELEGRAPH:
		if to.length() > reach:
			bot_move = to.normalized()
		elif state == State.MOVE and stamina >= ATTACK_COST and target.is_punishable():
			bot_attack = true
		return
	if stamina < DODGE_COST + 5.0:
		bot_move = -to.normalized() * 0.7
	elif to.length() > reach:
		bot_move = to.normalized()
	elif state == State.MOVE and stamina >= ATTACK_COST + DODGE_COST:
		bot_attack = true
