class_name InkArcher
extends CharacterBody2D
## นักธนูหมึก — ศัตรูยิงไกลเฟส 4 (issue #61)
## WANDER -> KEEP_DISTANCE (ถอยเมื่อใกล้) -> AIM (telegraph ล็อคทิศ) -> SHOOT -> RECOVER

enum State { WANDER, KEEP_DISTANCE, AIM, SHOOT, RECOVER, HURT, DEAD }

const ARROW_SCENE: PackedScene = preload("res://systems/enemy/ink_archer/ink_arrow.tscn")

@export var enemy_id: StringName = &"ink_archer"
@export var defense: int = 0
@export var max_poise: float = 10.0

@export_group("Movement")
@export var move_speed: float = 60.0
@export var flee_speed: float = 85.0
@export var wander_speed: float = 30.0
@export var preferred_range: float = 160.0
@export var flee_range: float = 80.0
@export var knockback_friction: float = 800.0

@export_group("Attack")
@export var aim_time: float = 0.7
@export var shoot_duration: float = 0.18
@export var recover_time: float = 0.6
@export var attack_delay_in_range: float = 0.3
@export var telegraph_length: float = 240.0
@export var arrow_damage: int = 2
@export var arrow_speed: float = 260.0

@export_group("Death")
@export var corpse_time: float = 0.8
@export var hurt_time: float = 0.3

var state: State = State.WANDER
var target: Node2D = null

var _state_t: float = 0.0
var _range_t: float = 0.0
var _wander_t: float = 0.0
var _wander_dir: Vector2 = Vector2.ZERO
var _aim_direction: Vector2 = Vector2.DOWN
var _current_poise: float = 0.0
var _died_emitted: bool = false
var _arrows_shot: int = 0
var _last_spawned_arrow: InkArrow = null

var dir_sprite: DirSprite
var health: Health
var hurtbox: Hurtbox
var detect: Area2D


func _ready() -> void:
	setup()


func setup() -> void:
	dir_sprite = $DirSprite if has_node("DirSprite") else null
	health = $Health if has_node("Health") else null
	hurtbox = $Hurtbox if has_node("Hurtbox") else null
	detect = $Detect if has_node("Detect") else null

	if health != null and not is_inside_tree():
		health.reset()

	if hurtbox != null and not hurtbox.hurt.is_connected(_on_hurt):
		hurtbox.hurt.connect(_on_hurt)

	if health != null and not health.died.is_connected(_on_died):
		health.died.connect(_on_died)

	if detect != null:
		detect.collision_layer = 0
		detect.collision_mask = Combat.LAYER_PLAYER
		if not detect.body_entered.is_connected(_on_body_entered):
			detect.body_entered.connect(_on_body_entered)
		if not detect.body_exited.is_connected(_on_body_exited):
			detect.body_exited.connect(_on_body_exited)

	if dir_sprite != null:
		dir_sprite.play_action(&"idle")
	_enter(State.WANDER)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if _last_spawned_arrow != null and is_instance_valid(_last_spawned_arrow):
			if not _last_spawned_arrow.is_inside_tree():
				_last_spawned_arrow.free()


static func compute_damage(amount: int, def: int) -> int:
	return maxi(1, amount - def)


func set_target(node: Node2D) -> void:
	target = node
	if (state == State.WANDER or state == State.KEEP_DISTANCE) and node != null:
		_enter(State.KEEP_DISTANCE)


func get_aim_direction() -> Vector2:
	return _aim_direction


func get_arrows_shot_count() -> int:
	return _arrows_shot


func get_last_spawned_arrow() -> InkArrow:
	return _last_spawned_arrow


func _physics_process(delta: float) -> void:
	tick(delta)
	move_and_slide()


func tick(delta: float) -> void:
	match state:
		State.WANDER:
			_tick_wander(delta)
		State.KEEP_DISTANCE:
			_tick_keep_distance(delta)
		State.AIM:
			_tick_aim(delta)
		State.SHOOT:
			_tick_shoot(delta)
		State.RECOVER:
			_tick_recover(delta)
		State.HURT:
			_tick_hurt(delta)
		State.DEAD:
			_tick_dead(delta)


func _tick_wander(delta: float) -> void:
	if _has_target():
		_enter(State.KEEP_DISTANCE)
		return

	_wander_t += delta
	if _wander_t >= 2.5:
		_wander_t = 0.0
		if randf() < 0.5:
			var rand_ang: float = randf() * TAU
			_wander_dir = Vector2.from_angle(rand_ang)
			if dir_sprite != null:
				dir_sprite.set_facing(_wander_dir)
				dir_sprite.play_action(&"walk")
		else:
			_wander_dir = Vector2.ZERO
			if dir_sprite != null:
				dir_sprite.play_action(&"idle")

	velocity = _wander_dir * wander_speed


func _tick_keep_distance(delta: float) -> void:
	if not _has_target():
		_enter(State.WANDER)
		return

	var to_target: Vector2 = target.global_position - global_position
	var dist: float = to_target.length()

	if dist < flee_range:
		_range_t = 0.0
		var flee_dir: Vector2 = -to_target.normalized() if dist > 0.0001 else Vector2.LEFT
		velocity = flee_dir * flee_speed
		if dir_sprite != null:
			dir_sprite.set_facing(flee_dir)
			dir_sprite.play_action(&"walk")
	elif dist > preferred_range + 20.0:
		_range_t = 0.0
		var chase_dir: Vector2 = to_target.normalized()
		velocity = chase_dir * move_speed
		if dir_sprite != null:
			dir_sprite.set_facing(chase_dir)
			dir_sprite.play_action(&"walk")
	else:
		velocity = Vector2.ZERO
		if dir_sprite != null:
			dir_sprite.set_facing(to_target)
			dir_sprite.play_action(&"idle")
		_range_t += delta
		if _range_t >= attack_delay_in_range:
			_enter(State.AIM)


func _tick_aim(delta: float) -> void:
	velocity = Vector2.ZERO
	_state_t += delta

	# เฟรม 4–6 ค้างง้างสาย
	var p: float = clampf(_state_t / aim_time, 0.0, 1.0)
	var f: int = 4 + int(p * 2.99)
	if dir_sprite != null:
		dir_sprite.show_frame(&"shoot", f)

	queue_redraw()

	if _state_t >= aim_time:
		_enter(State.SHOOT)


func _tick_shoot(delta: float) -> void:
	velocity = Vector2.ZERO
	_state_t += delta

	if _state_t >= shoot_duration * 0.5 and dir_sprite != null:
		dir_sprite.show_frame(&"shoot", 8)

	if _state_t >= shoot_duration:
		_enter(State.RECOVER)


func _tick_recover(delta: float) -> void:
	velocity = Vector2.ZERO
	_state_t += delta

	if _state_t >= recover_time:
		if _has_target():
			_enter(State.KEEP_DISTANCE)
		else:
			_enter(State.WANDER)


func _tick_hurt(delta: float) -> void:
	_state_t += delta
	velocity = velocity.move_toward(Vector2.ZERO, knockback_friction * delta)

	if _state_t >= hurt_time:
		if _has_target():
			_enter(State.KEEP_DISTANCE)
		else:
			_enter(State.WANDER)


func _tick_dead(delta: float) -> void:
	velocity = Vector2.ZERO
	_state_t += delta
	if _state_t >= corpse_time:
		var fade_p: float = clampf((_state_t - corpse_time) / 0.5, 0.0, 1.0)
		modulate.a = 1.0 - fade_p
		if fade_p >= 1.0 and is_inside_tree():
			queue_free()


func _enter(next: State) -> void:
	if state == State.DEAD:
		return

	state = next
	_state_t = 0.0

	match next:
		State.WANDER:
			velocity = Vector2.ZERO
			queue_redraw()
			if dir_sprite != null:
				dir_sprite.play_action(&"idle")
		State.KEEP_DISTANCE:
			_range_t = 0.0
			queue_redraw()
		State.AIM:
			velocity = Vector2.ZERO
			_lock_aim_direction()
			if dir_sprite != null:
				dir_sprite.set_facing(_aim_direction)
				dir_sprite.show_frame(&"shoot", 4)
			queue_redraw()
		State.SHOOT:
			velocity = Vector2.ZERO
			queue_redraw()
			if dir_sprite != null:
				dir_sprite.show_frame(&"shoot", 7)
			_spawn_arrow()
		State.RECOVER:
			velocity = Vector2.ZERO
			queue_redraw()
			if dir_sprite != null:
				dir_sprite.play_action(&"idle")
		State.HURT:
			queue_redraw()
			if dir_sprite != null:
				dir_sprite.play_action(&"hurt")
		State.DEAD:
			velocity = Vector2.ZERO
			queue_redraw()
			if dir_sprite != null:
				dir_sprite.play_action(&"death")


func _lock_aim_direction() -> void:
	if _has_target():
		var diff: Vector2 = target.global_position - global_position
		if diff.length_squared() > 0.0001:
			_aim_direction = diff.normalized()
			return
	if dir_sprite != null:
		_aim_direction = Dir8.to_vector(dir_sprite.facing)
	else:
		_aim_direction = Vector2.DOWN


func _spawn_arrow() -> void:
	_arrows_shot += 1
	var arrow: InkArrow = ARROW_SCENE.instantiate() as InkArrow
	arrow.setup()
	arrow.global_position = global_position + Vector2(0, -16) + _aim_direction * 12.0
	arrow.set_direction(_aim_direction)
	arrow.speed = arrow_speed
	arrow.damage = arrow_damage
	if arrow.hitbox != null:
		arrow.hitbox.damage = arrow_damage
		arrow.hitbox.source = self
	_last_spawned_arrow = arrow

	var p: Node = get_parent()
	if p != null:
		p.add_child(arrow)


func _on_hurt(info: DamageInfo) -> void:
	if state == State.DEAD:
		return

	var dealt: int = health.take_damage(compute_damage(info.amount, defense)) if health != null else info.amount
	EventBus.damage_dealt.emit(self, info, dealt)
	velocity = info.knockback

	if max_poise <= 0.0:
		if health == null or not health.is_dead:
			_enter(State.HURT)
	else:
		_current_poise += info.stagger
		if _current_poise >= max_poise:
			_current_poise = 0.0
			if health == null or not health.is_dead:
				_enter(State.HURT)


func _on_died() -> void:
	_enter(State.DEAD)
	if hurtbox != null:
		hurtbox.set_deferred(&"monitorable", false)
	set_deferred(&"collision_layer", 0)
	if not _died_emitted:
		_died_emitted = true
		EventBus.enemy_died.emit(self, enemy_id, global_position)


func _on_body_entered(body: Node2D) -> void:
	if target == null:
		set_target(body)


func _on_body_exited(body: Node2D) -> void:
	if body == target:
		target = null


func _has_target() -> bool:
	return target != null and is_instance_valid(target)


func _draw() -> void:
	if state == State.AIM:
		var start_pos := Vector2(0, -18)
		var end_pos := start_pos + _aim_direction * telegraph_length
		var alpha: float = lerpf(0.2, 0.6, clampf(_state_t / aim_time, 0.0, 1.0))
		var line_color := Color(0.9, 0.2, 0.2, alpha)
		draw_line(start_pos, end_pos, line_color, 1.5)
