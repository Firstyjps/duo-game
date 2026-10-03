class_name InkShade
extends CharacterBody2D
## เงาหมึก (Ink Shade) — วิญญาณหมึกดำม่วง ขอบเรืองแสงทอง ถือดาบสั้น
## AI: WANDER → CHASE → WINDUP (telegraph) → SLASH (Hitbox) → RECOVER · HURT · DEAD
## มุมมอง Isometric / top-down 3/4: การเคลื่อนที่เป็น screen-space (ขึ้น = ขึ้นจอ)
## สไปรต์ 8 ทิศ: DirSprite (Dir8)

enum State {
	WANDER,
	CHASE,
	WINDUP,
	SLASH,
	RECOVER,
	HURT,
	DEAD,
}

const FLASH_HURT: Color = Color(3.0, 3.0, 3.0)
const FLASH_GOLD: Color = Color(2.5, 2.0, 0.6)

@export var enemy_id: StringName = &"ink_shade"
@export var defense: int = 0
## ค่าความทนทานต่อการขัดท่า — ถ้า stagger >= poise จะเซ (HURT)
@export var poise: float = 0.0

@export_group("Movement")
@export var wander_speed: float = 35.0
@export var wander_radius: float = 60.0
@export var wander_pause_time: float = 1.5
@export var wander_stuck_time: float = 1.2
@export var chase_speed: float = 75.0
@export var detect_range: float = 150.0:
	set(val):
		detect_range = val
		if detect != null:
			var detect_col: CollisionShape2D = detect.get_node_or_null("Shape") as CollisionShape2D
			if detect_col != null and detect_col.shape is CircleShape2D:
				(detect_col.shape as CircleShape2D).radius = detect_range
@export var knockback_friction: float = 800.0

@export_group("Combat")
@export var attack_range: float = 48.0
## เวลา telegraph ค้างง้าง (attack เฟรม 3) + กระพริบทอง ก่อนฟัน
@export var windup_time: float = 0.6
@export var slash_time: float = 0.25
@export var slash_dash_speed: float = 120.0
@export var slash_reach: float = 20.0
## เวลาเปิดช่องให้ผู้เล่นสวนกลับหลังฟันเสร็จ (attack เฟรม 7–8)
@export var recover_time: float = 0.7
@export var hurt_time: float = 0.25
## เวลาเซเมื่อถูกผู้เล่น parry (deflected) เปิดช่องให้สวนกลับ
@export var parried_stagger_time: float = 0.8
## เวลาเล่นท่า death (9 เฟรม @ 9 fps = 1.0s) ก่อนเริ่มละลาย
@export var death_anim_time: float = 1.0
## เวลาที่ศพยุบและจางหายหลังจบท่า death
@export var corpse_time: float = 1.0

var state: State = State.WANDER
var target: Node2D = null
var spawn_position: Vector2 = Vector2.ZERO
var is_attack_active: bool = false

var facing_dir: int:
	get:
		return dir_sprite.facing if dir_sprite != null else Dir8.SOUTH
	set(val):
		if dir_sprite != null:
			dir_sprite.facing = posmod(val, Dir8.COUNT)
			dir_sprite._apply(true)

var _state_t: float = 0.0
var _flash_t: float = 0.0
var _died_emitted: bool = false
var _attack_dir: Vector2 = Vector2.DOWN
var _wander_target: Vector2 = Vector2.ZERO
var _wander_pause_t: float = 0.0
var _wander_stuck_t: float = 0.0
var _wander_last_dist: float = INF
var _poise_damage: float = 0.0
var _current_hurt_time: float = 0.25

var dir_sprite: DirSprite
var sprite: CanvasItem
var health: Health
var hurtbox: Hurtbox
var hitbox: Hitbox
var detect: Area2D


func _ready() -> void:
	setup()


## ผูก node ลูก + signal แยกจาก _ready ให้เทสต์เรียกได้โดยไม่ต้องอยู่ใน tree
func setup() -> void:
	dir_sprite = (get_node_or_null("DirSprite") if has_node("DirSprite") else get_node_or_null("Sprite")) as DirSprite
	sprite = dir_sprite
	health = $Health
	hurtbox = $Hurtbox
	hitbox = $Hitbox
	detect = $Detect

	if not is_inside_tree():
		health.reset()

	hitbox.source = self
	hitbox.team = Combat.Team.ENEMY
	hurtbox.team = Combat.Team.ENEMY

	hurtbox.hurt.connect(_on_hurt)
	health.died.connect(_on_died)
	hitbox.deflected.connect(_on_hitbox_deflected)

	detect.collision_layer = 0
	detect.collision_mask = Combat.LAYER_PLAYER
	detect.body_entered.connect(_on_body_entered)
	detect.body_exited.connect(_on_body_exited)

	var detect_col: CollisionShape2D = detect.get_node_or_null("Shape") as CollisionShape2D
	if detect_col != null and detect_col.shape is CircleShape2D:
		var dup_shape := detect_col.shape.duplicate() as CircleShape2D
		dup_shape.radius = detect_range
		detect_col.shape = dup_shape

	is_attack_active = false
	spawn_position = global_position
	_wander_target = spawn_position
	_wander_last_dist = INF
	_wander_stuck_t = 0.0
	_current_hurt_time = hurt_time
	if dir_sprite != null:
		dir_sprite.facing = Dir8.SOUTH
		dir_sprite.scale = Vector2.ONE
		dir_sprite.self_modulate = Color.WHITE
	_enter(State.WANDER)


## ดาเมจหลังหัก defense — ขั้นต่ำ 1 ตาม contract damage
static func compute_damage(amount: int, def: int) -> int:
	return maxi(1, amount - def)


## เช็คการเซเทียบ poise
static func should_stagger(stagger_amt: float, poise_threshold: float) -> bool:
	return stagger_amt >= poise_threshold


func set_target(node: Node2D) -> void:
	target = node
	if state == State.WANDER and node != null:
		_enter(State.CHASE)


func _physics_process(delta: float) -> void:
	tick(delta)
	move_and_slide()


## AI logic 1 เฟรม (ไม่รวม physics) — เทสต์เรียกตรงได้แบบ deterministic
func tick(delta: float) -> void:
	_state_t += delta

	match state:
		State.WANDER:
			_tick_wander(delta)
		State.CHASE:
			_tick_chase()
		State.WINDUP:
			velocity = Vector2.ZERO
			_hold_attack_frame(3)
			if _state_t >= windup_time:
				_enter(State.SLASH)
		State.SLASH:
			velocity = _attack_dir * slash_dash_speed
			var progress: float = clampf(_state_t / slash_time, 0.0, 0.999)
			var f: int = mini(4 + int(progress * 3.0), 6)
			_hold_attack_frame(f)
			if f == 5:
				if not is_attack_active:
					is_attack_active = true
					hitbox.position = _attack_dir * slash_reach
					hitbox.activate()
			else:
				if is_attack_active:
					is_attack_active = false
					hitbox.deactivate()
			if _state_t >= slash_time:
				_enter(State.RECOVER)
		State.RECOVER:
			velocity = Vector2.ZERO
			var progress: float = clampf(_state_t / recover_time, 0.0, 0.999)
			var f: int = mini(7 + int(progress * 2.0), 8)
			_hold_attack_frame(f)
			if _state_t >= recover_time:
				_enter(State.CHASE if _has_target() else State.WANDER)
		State.HURT:
			velocity = velocity.move_toward(Vector2.ZERO, knockback_friction * delta)
			if _state_t >= _current_hurt_time:
				_enter(State.CHASE if _has_target() else State.WANDER)
		State.DEAD:
			velocity = velocity.move_toward(Vector2.ZERO, knockback_friction * delta)
			_tick_death_dissolve()
			if _state_t >= death_anim_time + corpse_time:
				queue_free()


func _process(delta: float) -> void:
	_tick_flash(delta)
	queue_redraw()


func _draw() -> void:
	# เงาบนพื้น
	var alpha: float = 0.35
	if state == State.DEAD:
		var dissolve_t: float = clampf((_state_t - death_anim_time) / corpse_time, 0.0, 1.0) if _state_t >= death_anim_time else 0.0
		alpha *= (1.0 - dissolve_t)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 10.0, Color(0, 0, 0, alpha))


func _tick_wander(delta: float) -> void:
	if _has_target():
		_enter(State.CHASE)
		return

	if _wander_pause_t > 0.0:
		_wander_pause_t -= delta
		velocity = Vector2.ZERO
		_play_action(&"idle")
		if _wander_pause_t <= 0.0:
			_pick_wander_target()
		return

	var to_dest: Vector2 = _wander_target - global_position
	var dist: float = to_dest.length()
	if dist <= 4.0:
		velocity = Vector2.ZERO
		_wander_pause_t = wander_pause_time
		_wander_stuck_t = 0.0
		_wander_last_dist = INF
		_play_action(&"idle")
	else:
		if dir_sprite != null:
			dir_sprite.set_facing(to_dest)
		velocity = to_dest.normalized() * wander_speed
		_play_action(&"walk")
		if dist < _wander_last_dist - 0.01:
			_wander_last_dist = dist
			_wander_stuck_t = 0.0
		else:
			_wander_stuck_t += delta
			if _wander_stuck_t >= wander_stuck_time:
				_pick_wander_target()


func _pick_wander_target() -> void:
	var angle: float = randf() * TAU
	var dist: float = randf() * wander_radius
	_wander_target = spawn_position + Vector2(cos(angle), sin(angle)) * dist
	_wander_last_dist = (_wander_target - global_position).length()
	_wander_stuck_t = 0.0


func _tick_chase() -> void:
	if not _has_target():
		_enter(State.WANDER)
		return

	var to_target: Vector2 = target.global_position - global_position
	var dist: float = to_target.length()
	if dir_sprite != null:
		dir_sprite.set_facing(to_target)

	if dist <= attack_range:
		_enter(State.WINDUP)
		return

	velocity = to_target.normalized() * chase_speed
	_play_action(&"walk")


func _enter(next: State) -> void:
	var prev: State = state
	if prev == State.DEAD:
		return

	if prev == State.SLASH:
		is_attack_active = false
		hitbox.deactivate()
		hitbox.position = Vector2.ZERO
	if prev == State.WINDUP and dir_sprite != null:
		dir_sprite.self_modulate = Color.WHITE

	state = next
	_state_t = 0.0

	match next:
		State.WANDER:
			is_attack_active = false
			_wander_pause_t = 0.5
			_wander_stuck_t = 0.0
			_wander_last_dist = INF
			_play_action(&"idle")
		State.CHASE:
			is_attack_active = false
			_play_action(&"walk")
		State.WINDUP:
			is_attack_active = false
			velocity = Vector2.ZERO
			hitbox.deactivate()
			if _has_target():
				_attack_dir = (target.global_position - global_position).normalized()
				if _attack_dir.length_squared() < 0.01:
					_attack_dir = Vector2.DOWN
				if dir_sprite != null:
					dir_sprite.set_facing(_attack_dir)
			_hold_attack_frame(3)
		State.SLASH:
			is_attack_active = false
			hitbox.deactivate()
			_hold_attack_frame(4)
		State.RECOVER:
			is_attack_active = false
			velocity = Vector2.ZERO
			hitbox.deactivate()
			hitbox.position = Vector2.ZERO
			_hold_attack_frame(7)
		State.HURT:
			is_attack_active = false
			hitbox.deactivate()
			hitbox.position = Vector2.ZERO
			_play_action(&"hurt")
		State.DEAD:
			is_attack_active = false
			velocity = Vector2.ZERO
			hitbox.deactivate()
			hitbox.position = Vector2.ZERO
			_play_action(&"death")


func _hold_attack_frame(f: int) -> void:
	if dir_sprite != null:
		dir_sprite.play_action(&"attack")
		dir_sprite.frame = f
		dir_sprite.pause()


func _play_action(act: StringName) -> void:
	if dir_sprite != null:
		dir_sprite.play_action(act)


func _on_hurt(info: DamageInfo) -> void:
	if state == State.DEAD:
		return

	var dealt: int = health.take_damage(compute_damage(info.amount, defense))
	EventBus.damage_dealt.emit(self, info, dealt)
	_flash_t = 0.08
	velocity = info.knockback
	if info.knockback.length_squared() > 0.01 and dir_sprite != null:
		dir_sprite.set_facing(-info.knockback)

	if not health.is_dead:
		_poise_damage += info.stagger
		if should_stagger(_poise_damage, poise):
			_poise_damage = 0.0
			_current_hurt_time = hurt_time
			_enter(State.HURT)


func _on_hitbox_deflected(_defender_hurtbox: Hurtbox, _info: DamageInfo) -> void:
	if state == State.DEAD:
		return
	_flash_t = 0.1
	velocity = Vector2.ZERO
	_current_hurt_time = parried_stagger_time
	_enter(State.HURT)


func _on_died() -> void:
	_enter(State.DEAD)
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


func _tick_death_dissolve() -> void:
	if dir_sprite == null:
		return
	if _state_t < death_anim_time:
		dir_sprite.scale = Vector2.ONE
		dir_sprite.self_modulate.a = 1.0
	else:
		var t: float = clampf((_state_t - death_anim_time) / corpse_time, 0.0, 1.0)
		dir_sprite.scale.y = lerpf(1.0, 0.2, t)
		dir_sprite.scale.x = 1.0
		dir_sprite.self_modulate.a = 1.0 - t


func _tick_flash(delta: float) -> void:
	if dir_sprite == null:
		return
	if _flash_t > 0.0:
		_flash_t -= delta
		dir_sprite.self_modulate = FLASH_HURT
	elif state == State.WINDUP:
		var k: float = clampf(_state_t / windup_time, 0.0, 1.0)
		var pulse: float = 0.5 + 0.5 * sin(_state_t * lerpf(12.0, 32.0, k))
		dir_sprite.self_modulate = Color.WHITE.lerp(FLASH_GOLD, pulse)
	elif state == State.DEAD:
		_tick_death_dissolve()
	else:
		dir_sprite.self_modulate = Color.WHITE
