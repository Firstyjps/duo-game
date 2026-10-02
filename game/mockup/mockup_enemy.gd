extends CharacterBody2D
## MOCKUP ศัตรู — telegraph → active → recover ตาม docs/contracts/damage.md

const Fx := preload("res://mockup/mockup_fx.gd")

enum State { DORMANT, CHASE, TELEGRAPH, ACTIVE, RECOVER, STAGGER, DEAD }

const KINDS: Dictionary = {
	&"skeleton": {
		"hp": 9, "speed": 52.0, "range": 44.0, "telegraph": 0.55, "active": 0.12, "recover": 0.75,
		"damage": 2, "knockback": 230.0, "hit_radius": 24.0, "hit_reach": 26.0, "poise": 2.0,
		"body": 9.0, "hurt_r": 12.0, "h": 52, "mass": 1.0, "lunge": 120.0, "coins": 3,
	},
	&"golem": {
		"hp": 40, "speed": 30.0, "range": 64.0, "telegraph": 1.0, "active": 0.14, "recover": 1.1,
		"damage": 4, "knockback": 380.0, "hit_radius": 66.0, "hit_reach": 0.0, "poise": 999.0,
		"body": 26.0, "hurt_r": 30.0, "h": 112, "mass": 4.0, "lunge": 0.0, "coins": 12,
	},
}

var kind: StringName = &"skeleton"
var target: Node2D
var main: Node
var state: State = State.CHASE
var cfg: Dictionary
var timer: float = 0.0
var knock: Vector2 = Vector2.ZERO
var poise: float = 0.0
var attack_dir: Vector2 = Vector2.LEFT
var danger: Vector2 = Vector2.ZERO
var walk_t: float = 0.0
var slam_t: float = 0.0
var health: Health
var hurtbox: Hurtbox
var hitbox: Hitbox
var sprite: Sprite2D
var mat: ShaderMaterial
var mark: Label


func _ready() -> void:
	cfg = KINDS[kind]
	collision_layer = Combat.LAYER_ENEMY
	collision_mask = Combat.LAYER_WORLD | Combat.LAYER_PLAYER | Combat.LAYER_ENEMY
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var body := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = cfg.body
	body.shape = c
	add_child(body)
	sprite = Sprite2D.new()
	sprite.texture = load("res://mockup/assets/%s.png" % kind)
	sprite.offset = Vector2(0, -cfg.h / 2.0)
	mat = Fx.flash_material()
	sprite.material = mat
	add_child(sprite)
	health = Health.new()
	health.max_hp = cfg.hp
	add_child(health)
	health.died.connect(_on_died)
	hurtbox = Hurtbox.new()
	hurtbox.team = Combat.Team.ENEMY
	Fx.circle_shape(hurtbox, cfg.hurt_r, Vector2(0, -cfg.h * 0.4))
	add_child(hurtbox)
	hurtbox.hurt.connect(_on_hurt)
	hitbox = Hitbox.new()
	hitbox.team = Combat.Team.ENEMY
	hitbox.damage = cfg.damage
	hitbox.knockback_force = cfg.knockback
	hitbox.source = self
	Fx.circle_shape(hitbox, cfg.hit_radius, Vector2.ZERO)
	add_child(hitbox)
	mark = Label.new()
	mark.text = "!"
	mark.add_theme_font_size_override(&"font_size", 18)
	mark.add_theme_color_override(&"font_color", Color(1.0, 0.25, 0.2))
	mark.add_theme_constant_override(&"outline_size", 4)
	mark.add_theme_color_override(&"font_outline_color", Color.BLACK)
	mark.position = Vector2(-4, -cfg.h - 22)
	mark.z_index = 5
	mark.visible = false
	add_child(mark)
	if kind == &"golem":
		state = State.DORMANT
		sprite.modulate = Color(0.5, 0.5, 0.58)


func is_targetable() -> bool:
	return state != State.DEAD and state != State.DORMANT


func body_radius() -> float:
	return cfg.body


func danger_center() -> Vector2:
	return global_position + danger


func is_threatening(point: Vector2) -> bool:
	if state != State.TELEGRAPH:
		return false
	var hit_at: Vector2 = global_position + hitbox.position
	return hit_at.distance_to(point) < cfg.hit_radius + 14.0


## ช่วงสวนได้ (หลังตีพลาด / เซ)
func is_punishable() -> bool:
	return state == State.RECOVER or state == State.STAGGER


## บอสตื่น → EventBus.boss_engaged (HUD ของระบบ A แสดงหลอด HP)
func wake() -> void:
	if state != State.DORMANT:
		return
	state = State.CHASE
	var tw: Tween = create_tween()
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.4)
	tw.parallel().tween_property(sprite, "scale", Vector2(1.15, 1.15), 0.15)
	tw.tween_property(sprite, "scale", Vector2.ONE, 0.25)
	if main != null:
		main.shake = 7.0
	EventBus.boss_engaged.emit(self, health, "EMBER GOLEM")


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	slam_t = maxf(0.0, slam_t - delta)
	match state:
		State.DORMANT:
			velocity = Vector2.ZERO
		State.CHASE:
			var to: Vector2 = target.global_position - global_position
			if target.is_dead():
				velocity = Vector2.ZERO
			elif to.length() <= cfg.range:
				_start_telegraph(to)
			else:
				velocity = to.normalized() * cfg.speed
		State.TELEGRAPH:
			velocity = Vector2.ZERO
			timer -= delta
			var p: float = 1.0 - timer / cfg.telegraph
			mat.set_shader_parameter(&"tint", Color(1.0, 0.2, 0.15))
			mat.set_shader_parameter(&"flash", 0.25 + 0.3 * p + 0.15 * sin(p * 40.0))
			if timer <= 0.0:
				_start_active()
		State.ACTIVE:
			timer -= delta
			velocity = attack_dir * cfg.lunge * (timer / cfg.active)
			if timer <= 0.0:
				hitbox.deactivate()
				state = State.RECOVER
				timer = cfg.recover
		State.RECOVER, State.STAGGER:
			velocity = Vector2.ZERO
			timer -= delta
			if timer <= 0.0:
				state = State.CHASE
	knock = knock.move_toward(Vector2.ZERO, 900.0 * delta)
	velocity += knock
	move_and_slide()
	_animate(delta)
	queue_redraw()


func _start_telegraph(to: Vector2) -> void:
	attack_dir = to.normalized()
	state = State.TELEGRAPH
	timer = cfg.telegraph
	danger = attack_dir * cfg.hit_reach
	hitbox.position = danger + Vector2(0, -16)
	mark.visible = true


func _start_active() -> void:
	state = State.ACTIVE
	timer = cfg.active
	mat.set_shader_parameter(&"flash", 0.0)
	mark.visible = false
	hitbox.activate()
	if kind == &"golem":
		slam_t = 0.35
		if main != null:
			main.shake = 9.0


func _on_hurt(info: DamageInfo) -> void:
	var final: int = maxi(1, info.amount)
	health.take_damage(final)
	EventBus.damage_dealt.emit(self, info, final)
	knock = info.knockback / cfg.mass
	Fx.flash(mat, self, Color.WHITE)
	if health.is_dead:
		return
	poise += info.stagger
	if poise >= cfg.poise:
		poise = 0.0
		state = State.STAGGER
		timer = 0.45
		mark.visible = false
		hitbox.deactivate()


func _on_died() -> void:
	state = State.DEAD
	hitbox.deactivate()
	hurtbox.invulnerable = true
	collision_layer = 0
	mark.visible = false
	EventBus.enemy_died.emit(self, kind, global_position)
	var tw: Tween = create_tween()
	tw.tween_property(sprite, "scale", Vector2(1.25, 0.5), 0.35)
	tw.parallel().tween_property(sprite, "modulate:a", 0.0, 0.35)
	tw.tween_callback(queue_free)


func _animate(delta: float) -> void:
	if target != null and kind == &"skeleton":
		sprite.flip_h = target.global_position.x > global_position.x
	var moving: bool = state == State.CHASE and velocity.length() > 5.0
	if moving:
		walk_t += delta * 10.0
	sprite.position = Vector2(0, -absf(sin(walk_t)) * 2.0) if moving else Vector2.ZERO
	match state:
		State.TELEGRAPH:
			var p: float = 1.0 - timer / cfg.telegraph
			if kind == &"golem":
				sprite.scale = Vector2(1.0 - 0.06 * p, 1.0 + 0.1 * p)
			else:
				sprite.position = (-attack_dir * 4.0 * p).round()
		State.ACTIVE:
			sprite.position = (attack_dir * 4.0).round()
			sprite.scale = Vector2(1.15, 0.85) if kind == &"golem" else Vector2.ONE
		State.STAGGER:
			sprite.position = Vector2(roundf(sin(timer * 60.0) * 2.0), 0)
			sprite.scale = Vector2.ONE
		_:
			if state != State.DORMANT:
				sprite.scale = Vector2.ONE


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, cfg.body + 5.0, Color(0, 0, 0, 0.45))
	draw_set_transform(Vector2.ZERO)
	if state == State.TELEGRAPH:
		var p: float = 1.0 - timer / cfg.telegraph
		_ellipse(danger, cfg.hit_radius, Color(1.0, 0.15, 0.1, 0.16), true)
		_ellipse(danger, cfg.hit_radius * p, Color(1.0, 0.2, 0.1, 0.32), true)
		_ellipse(danger, cfg.hit_radius, Color(1.0, 0.35, 0.25, 0.8), false)
	if slam_t > 0.0:
		var q: float = 1.0 - slam_t / 0.35
		_ellipse(Vector2.ZERO, cfg.hit_radius * (0.6 + 0.6 * q), Color(1.0, 0.75, 0.4, 0.8 * (1.0 - q)), false, 4.0)


func _ellipse(at: Vector2, r: float, color: Color, filled: bool, width: float = 2.0) -> void:
	draw_set_transform(at, 0.0, Vector2(1.0, 0.55))
	if filled:
		draw_circle(Vector2.ZERO, r, color)
	else:
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, color, width)
	draw_set_transform(Vector2.ZERO)
