class_name InkShade
extends CharacterBody2D
## เงาหมึก (Ink Shade) — วิญญาณหมึกดำม่วง ขอบเรืองแสงทอง ถือดาบสั้น
## AI: WANDER → CHASE → WINDUP (telegraph) → SLASH (Hitbox) → RECOVER · HURT · DEAD
## มุมมอง Isometric / top-down 3/4: การเคลื่อนที่เป็น screen-space (ขึ้น = ขึ้นจอ)
## สไปรต์ 8 ทิศ: S(0), SE(1), E(2), NE(3), N(4), NW(5), W(6), SW(7)

enum Dir {
	SOUTH = 0,
	SOUTH_EAST = 1,
	EAST = 2,
	NORTH_EAST = 3,
	NORTH = 4,
	NORTH_WEST = 5,
	WEST = 6,
	SOUTH_WEST = 7,
}

enum State {
	WANDER,
	CHASE,
	WINDUP,
	SLASH,
	RECOVER,
	HURT,
	DEAD,
}

## ลำดับเฟรมตาม tools/gen_ink_shade_sheet.gd (คอลัมน์ในแต่ละแถว)
const ANIMS: Dictionary = {
	&"idle": {"frames": [0, 1, 2, 3], "fps": 6.0, "loop": true},
	&"walk": {"frames": [4, 5, 6, 7, 8, 9], "fps": 8.0, "loop": true},
	&"windup": {"frames": [10, 11, 12], "fps": 5.0, "loop": false},
	&"slash": {"frames": [13, 14, 15], "fps": 12.0, "loop": false},
	&"hurt": {"frames": [16, 17], "fps": 8.0, "loop": false},
	&"dead": {"frames": [18, 19, 20, 21, 22, 23], "fps": 7.0, "loop": false},
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
@export var chase_speed: float = 75.0
@export var detect_range: float = 150.0
@export var knockback_friction: float = 800.0

@export_group("Combat")
@export var attack_range: float = 48.0
## เวลา telegraph ค้างง้าง + กระพริบทอง ก่อนฟัน
@export var windup_time: float = 0.6
@export var slash_time: float = 0.25
@export var slash_dash_speed: float = 120.0
@export var slash_reach: float = 20.0
## เวลาเปิดช่องให้ผู้เล่นสวนกลับหลังฟันเสร็จ
@export var recover_time: float = 0.7
@export var hurt_time: float = 0.25
@export var corpse_time: float = 1.0

var state: State = State.WANDER
var target: Node2D = null
var facing_dir: int = Dir.SOUTH:
	set(val):
		facing_dir = val
		_update_sprite_frame()
var spawn_position: Vector2 = Vector2.ZERO

var _state_t: float = 0.0
var _anim: StringName = &""
var _anim_t: float = 0.0
var _current_frame_col: int = 0
var _flash_t: float = 0.0
var _died_emitted: bool = false
var _attack_dir: Vector2 = Vector2.DOWN
var _wander_target: Vector2 = Vector2.ZERO
var _wander_pause_t: float = 0.0
var _poise_damage: float = 0.0

var sprite: Sprite2D
var health: Health
var hurtbox: Hurtbox
var hitbox: Hitbox
var detect: Area2D


func _ready() -> void:
	setup()


## ผูก node ลูก + signal แยกจาก _ready ให้เทสต์เรียกได้โดยไม่ต้องอยู่ใน tree
func setup() -> void:
	sprite = $Sprite
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

	detect.collision_layer = 0
	detect.collision_mask = Combat.LAYER_PLAYER
	detect.body_entered.connect(_on_body_entered)
	detect.body_exited.connect(_on_body_exited)

	spawn_position = global_position
	_wander_target = spawn_position
	facing_dir = Dir.SOUTH
	_enter(State.WANDER)


## แปลงเวกเตอร์ความเร็ว/ทิศ (screen-space) เป็นทิศ 8 ทิศ (0..7)
## 0=S, 1=SE, 2=E, 3=NE, 4=N, 5=NW, 6=W, 7=SW
static func vector_to_dir(v: Vector2) -> int:
	if v.length_squared() < 0.0001:
		return Dir.SOUTH
	return posmod(int(round(rad_to_deg(atan2(v.x, v.y)) / 45.0)), 8)


## ดาเมจหลังหัก defense — ขั้นต่ำ 1 ตาม contract damage
static func compute_damage(amount: int, def: int) -> int:
	return maxi(1, amount - def)


## เช็คการเซเทียบ poise
static func should_stagger(stagger: float, poise_threshold: float) -> bool:
	return stagger >= poise_threshold


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
			if _state_t >= windup_time:
				_enter(State.SLASH)
		State.SLASH:
			velocity = _attack_dir * slash_dash_speed
			if _state_t >= slash_time:
				_enter(State.RECOVER)
		State.RECOVER:
			velocity = Vector2.ZERO
			if _state_t >= recover_time:
				_enter(State.CHASE if _has_target() else State.WANDER)
		State.HURT:
			velocity = velocity.move_toward(Vector2.ZERO, knockback_friction * delta)
			if _state_t >= hurt_time:
				_enter(State.CHASE if _has_target() else State.WANDER)
		State.DEAD:
			velocity = velocity.move_toward(Vector2.ZERO, knockback_friction * delta)
			if _state_t >= corpse_time:
				queue_free()


func _process(delta: float) -> void:
	_tick_anim(delta)
	_tick_flash(delta)
	queue_redraw()


func _draw() -> void:
	# เงาบนพื้น
	var alpha: float = 0.35
	if state == State.DEAD:
		alpha *= clampf(1.0 - _state_t / corpse_time, 0.0, 1.0)
	draw_set_transform(Vector2(0, 0), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 10.0, Color(0, 0, 0, alpha))


func _tick_wander(delta: float) -> void:
	if _has_target():
		_enter(State.CHASE)
		return

	if _wander_pause_t > 0.0:
		_wander_pause_t -= delta
		velocity = Vector2.ZERO
		_play(&"idle")
		if _wander_pause_t <= 0.0:
			_pick_wander_target()
		return

	var to_dest: Vector2 = _wander_target - global_position
	if to_dest.length() <= 4.0:
		velocity = Vector2.ZERO
		_wander_pause_t = wander_pause_time
		_play(&"idle")
	else:
		facing_dir = vector_to_dir(to_dest)
		velocity = to_dest.normalized() * wander_speed
		_play(&"walk")


func _pick_wander_target() -> void:
	var angle: float = randf() * TAU
	var dist: float = randf() * wander_radius
	_wander_target = spawn_position + Vector2(cos(angle), sin(angle)) * dist


func _tick_chase() -> void:
	if not _has_target():
		_enter(State.WANDER)
		return

	var to_target: Vector2 = target.global_position - global_position
	var dist: float = to_target.length()
	facing_dir = vector_to_dir(to_target)

	if dist <= attack_range:
		_enter(State.WINDUP)
		return

	velocity = to_target.normalized() * chase_speed
	_play(&"walk")


func _enter(next: State) -> void:
	var prev: State = state
	if prev == State.DEAD:
		return

	if prev == State.SLASH:
		hitbox.deactivate()
		hitbox.position = Vector2.ZERO
	if prev == State.WINDUP:
		sprite.self_modulate = Color.WHITE

	state = next
	_state_t = 0.0

	match next:
		State.WANDER:
			_wander_pause_t = 0.5
			_play(&"idle")
		State.CHASE:
			_play(&"walk")
		State.WINDUP:
			velocity = Vector2.ZERO
			hitbox.deactivate()
			if _has_target():
				_attack_dir = (target.global_position - global_position).normalized()
				if _attack_dir.length_squared() < 0.01:
					_attack_dir = Vector2.DOWN
				facing_dir = vector_to_dir(_attack_dir)
			_play(&"windup")
		State.SLASH:
			hitbox.position = _attack_dir * slash_reach
			hitbox.activate()
			_play(&"slash")
		State.RECOVER:
			velocity = Vector2.ZERO
			hitbox.deactivate()
			hitbox.position = Vector2.ZERO
			_play(&"idle")
		State.HURT:
			hitbox.deactivate()
			_play(&"hurt")
		State.DEAD:
			velocity = Vector2.ZERO
			hitbox.deactivate()
			_play(&"dead")


func _on_hurt(info: DamageInfo) -> void:
	if state == State.DEAD:
		return

	var dealt: int = health.take_damage(compute_damage(info.amount, defense))
	EventBus.damage_dealt.emit(self, info, dealt)
	_flash_t = 0.08
	velocity = info.knockback
	if info.knockback.length_squared() > 0.01:
		facing_dir = vector_to_dir(-info.knockback)

	if not health.is_dead:
		_poise_damage += info.stagger
		if should_stagger(_poise_damage, poise):
			_poise_damage = 0.0
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


func _play(anim: StringName) -> void:
	if _anim != anim:
		_anim = anim
		_anim_t = 0.0
		if ANIMS.has(anim):
			_current_frame_col = ANIMS[anim]["frames"][0]
		_update_sprite_frame()


func _tick_anim(delta: float) -> void:
	if not ANIMS.has(_anim):
		return
	var a: Dictionary = ANIMS[_anim]
	var frames: Array = a["frames"]
	_anim_t += delta
	var loop_len: float = frames.size() / float(a["fps"])
	if a["loop"] and _anim_t >= loop_len:
		_anim_t = fmod(_anim_t, loop_len)
	var i: int = int(_anim_t * a["fps"])
	i = i % frames.size() if a["loop"] else mini(i, frames.size() - 1)
	_current_frame_col = frames[i]
	_update_sprite_frame()


func _update_sprite_frame() -> void:
	if sprite != null and sprite.texture != null:
		sprite.frame_coords = Vector2i(_current_frame_col, facing_dir)


func _tick_flash(delta: float) -> void:
	if _flash_t > 0.0:
		_flash_t -= delta
		sprite.self_modulate = FLASH_HURT
	elif state == State.WINDUP:
		var k: float = _state_t / windup_time
		var pulse: float = 0.5 + 0.5 * sin(_state_t * lerpf(12.0, 32.0, k))
		sprite.self_modulate = Color.WHITE.lerp(FLASH_GOLD, pulse)
	elif state == State.DEAD:
		var fade: float = clampf((_state_t - corpse_time * 0.3) / (corpse_time * 0.7), 0.0, 1.0)
		sprite.self_modulate = Color(1, 1, 1, 1.0 - fade)
	else:
		sprite.self_modulate = Color.WHITE
