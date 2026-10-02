class_name Slime
extends CharacterBody2D
## สไลม์ — ศัตรูตัวแรก: เด้งเข้าหาผู้เล่น → windup + วงเตือนจุดตก → พุ่ง (Hitbox) → พัก
## ดาเมจผ่าน Hitbox/Hurtbox ตาม docs/contracts/damage.md · หาผู้เล่นจาก physics layer `player` เท่านั้น

enum State { IDLE, CHASE, WINDUP, LEAP, RECOVER, HURT, DEAD }

## เฟรมใน slime_sheet.png (ลำดับตาม tools/gen_slime_sheet.gd)
const ANIMS: Dictionary = {
	&"idle": {"frames": [0, 1, 2, 3, 4, 5, 6, 7], "fps": 8.0, "loop": true},
	## idle รอบที่กระพริบตา (เฟรม 8–9 = ทรงเดียวกับ 4–5 แต่หลับตา)
	&"idle_blink": {"frames": [0, 1, 2, 3, 8, 9, 6, 7], "fps": 8.0, "loop": true},
	&"windup": {"frames": [10, 11], "fps": 5.0, "loop": false},
	&"leap": {"frames": [12], "fps": 1.0, "loop": false},
	&"land": {"frames": [13, 0], "fps": 8.0, "loop": false},
	&"death": {"frames": [14, 15, 16], "fps": 8.0, "loop": false},
}
const FLASH_HURT := Color(3.0, 3.0, 3.0)
const FLASH_WINDUP := Color(1.8, 0.75, 0.7)

@export var enemy_id: StringName = &"slime"
@export var defense: int = 0
## โอกาสกระพริบตาต่อ 1 รอบหายใจ (1 วิ)
@export_range(0.0, 1.0) var blink_chance: float = 0.3
@export_group("Movement")
@export var hop_speed: float = 55.0
## เวลา 1 รอบเด้ง (ครึ่งแรกลอย/เคลื่อนที่ ครึ่งหลังหยุด)
@export var hop_interval: float = 0.7
@export var hop_height: float = 4.0
@export var knockback_friction: float = 900.0
@export_group("Attack")
## เข้าใกล้เท่านี้แล้วเริ่ม windup
@export var attack_range: float = 70.0
## เวลา telegraph ก่อนพุ่ง — ยาวพอให้ผู้เล่น dodge ทัน
@export var windup_time: float = 0.6
@export var leap_distance: float = 80.0
@export var leap_time: float = 0.35
@export var leap_height: float = 14.0
@export var recover_time: float = 0.8
@export var hurt_time: float = 0.25
@export var corpse_time: float = 1.2

var state: State = State.IDLE
var target: Node2D = null

var _state_t: float = 0.0
var _leap_from: Vector2 = Vector2.ZERO
var _leap_to: Vector2 = Vector2.ZERO
var _anim: StringName = &""
var _anim_t: float = 0.0
var _flash_t: float = 0.0
var _died_emitted: bool = false

var sprite: Sprite2D
var health: Health
var hurtbox: Hurtbox
var hitbox: Hitbox
var detect: Area2D


func _ready() -> void:
	setup()


## ผูก node ลูก + signal — แยกจาก _ready ให้เทสต์เรียกได้โดยไม่ต้องอยู่ใน scene tree
func setup() -> void:
	sprite = $Sprite
	health = $Health
	hurtbox = $Hurtbox
	hitbox = $Hitbox
	detect = $Detect
	if not is_inside_tree():
		health.reset()
	hitbox.source = self
	hurtbox.hurt.connect(_on_hurt)
	health.died.connect(_on_died)
	detect.collision_layer = 0
	detect.collision_mask = Combat.LAYER_PLAYER
	detect.body_entered.connect(_on_body_entered)
	detect.body_exited.connect(_on_body_exited)
	_play(&"idle")
	# สุ่มจังหวะหายใจ สไลม์หลายตัวจะได้ไม่เด้งพร้อมกัน
	_anim_t = randf() * ANIMS[&"idle"]["frames"].size() / float(ANIMS[&"idle"]["fps"])


## ดาเมจหลังหัก defense — โดนแล้วขั้นต่ำ 1 (contract damage)
static func compute_damage(amount: int, def: int) -> int:
	return maxi(1, amount - def)


## จุดตกของท่าพุ่ง — ล็อกตอนเริ่ม windup (ผู้เล่นหลบได้) และไม่เกิน max_dist
static func leap_target(from: Vector2, toward: Vector2, max_dist: float) -> Vector2:
	var offset: Vector2 = toward - from
	if offset.length() > max_dist:
		offset = offset.normalized() * max_dist
	return from + offset


func set_target(node: Node2D) -> void:
	target = node
	if state == State.IDLE and node != null:
		_enter(State.CHASE)


func _physics_process(delta: float) -> void:
	tick(delta)
	move_and_slide()


## AI 1 เฟรม (ไม่รวม physics) — เทสต์เรียกตรงได้
func tick(delta: float) -> void:
	_state_t += delta
	match state:
		State.IDLE:
			velocity = Vector2.ZERO
		State.CHASE:
			_tick_chase()
		State.WINDUP:
			velocity = Vector2.ZERO
			if _state_t >= windup_time:
				_enter(State.LEAP)
		State.LEAP:
			_tick_leap()
		State.RECOVER:
			velocity = Vector2.ZERO
			if _state_t >= recover_time:
				_enter(State.CHASE if _has_target() else State.IDLE)
		State.HURT:
			velocity = velocity.move_toward(Vector2.ZERO, knockback_friction * delta)
			if _state_t >= hurt_time:
				_enter(State.CHASE if _has_target() else State.IDLE)
		State.DEAD:
			velocity = velocity.move_toward(Vector2.ZERO, knockback_friction * delta)
			if _state_t >= corpse_time:
				queue_free()


func _process(delta: float) -> void:
	_tick_anim(delta)
	_tick_flash(delta)
	queue_redraw()


## เงาบนพื้น — เล็กลงตอนตัวลอย
func _draw() -> void:
	var lift: float = clampf(-sprite.position.y / maxf(leap_height, 1.0), 0.0, 1.0)
	var w: float = lerpf(11.0, 7.0, lift)
	draw_set_transform(Vector2(0, -1), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, w, Color(0, 0, 0, 0.35 - 0.15 * lift))


func _tick_chase() -> void:
	if not _has_target():
		_enter(State.IDLE)
		return
	var to_target: Vector2 = target.global_position - global_position
	var phase: float = fmod(_state_t, hop_interval) / hop_interval
	var airborne: bool = phase < 0.5
	sprite.position.y = -sin(phase * 2.0 * PI) * hop_height if airborne else 0.0
	if not airborne and to_target.length() <= attack_range:
		_enter(State.WINDUP)
		return
	velocity = to_target.normalized() * hop_speed if airborne else Vector2.ZERO


func _tick_leap() -> void:
	var k: float = clampf(_state_t / leap_time, 0.0, 1.0)
	sprite.position.y = -sin(k * PI) * leap_height
	velocity = (_leap_to - _leap_from) / leap_time
	if k >= 1.0:
		velocity = Vector2.ZERO
		_enter(State.RECOVER)


func _enter(next: State) -> void:
	var prev: State = state
	if prev == State.DEAD:
		return
	if prev == State.LEAP:
		hitbox.deactivate()
	if prev == State.WINDUP:
		sprite.self_modulate = Color.WHITE
	state = next
	_state_t = 0.0
	sprite.position.y = 0.0
	match next:
		State.IDLE, State.CHASE:
			_play(&"idle")
		State.WINDUP:
			_leap_from = global_position
			_leap_to = leap_target(global_position, target.global_position, leap_distance)
			_play(&"windup")
		State.LEAP:
			_leap_from = global_position
			hitbox.activate()
			_play(&"leap")
		State.RECOVER:
			_play(&"land")
		State.HURT:
			_play(&"land")
		State.DEAD:
			_play(&"death")


func _on_hurt(info: DamageInfo) -> void:
	if state == State.DEAD:
		return
	var dealt: int = health.take_damage(compute_damage(info.amount, defense))
	EventBus.damage_dealt.emit(self, info, dealt)
	_flash_t = 0.08
	velocity = info.knockback
	# ตอนพุ่งอยู่ไม่ถูกขัดท่า (super armor) · ท่าอื่นถูกขัด
	if not health.is_dead and state != State.LEAP:
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
	_anim = anim
	_anim_t = 0.0
	sprite.frame = ANIMS[anim]["frames"][0]


func _tick_anim(delta: float) -> void:
	var a: Dictionary = ANIMS[_anim]
	var frames: Array = a["frames"]
	_anim_t += delta
	var loop_len: float = frames.size() / float(a["fps"])
	if a["loop"] and _anim_t >= loop_len:
		_anim_t = fmod(_anim_t, loop_len)
		# จบ 1 รอบหายใจ → สุ่มว่ารอบหน้ากระพริบตาไหม
		if _anim == &"idle" or _anim == &"idle_blink":
			_anim = &"idle_blink" if randf() < blink_chance else &"idle"
			a = ANIMS[_anim]
			frames = a["frames"]
	var i: int = int(_anim_t * a["fps"])
	i = i % frames.size() if a["loop"] else mini(i, frames.size() - 1)
	sprite.frame = frames[i]


func _tick_flash(delta: float) -> void:
	if _flash_t > 0.0:
		_flash_t -= delta
		sprite.self_modulate = FLASH_HURT
	elif state == State.WINDUP:
		# กระพริบเร็วขึ้นเมื่อใกล้พุ่ง
		var k: float = _state_t / windup_time
		var pulse: float = 0.5 + 0.5 * sin(_state_t * lerpf(10.0, 30.0, k))
		sprite.self_modulate = Color.WHITE.lerp(FLASH_WINDUP, pulse)
	elif state == State.DEAD:
		var fade: float = clampf((_state_t - corpse_time * 0.5) / (corpse_time * 0.5), 0.0, 1.0)
		sprite.self_modulate = Color(1, 1, 1, 1.0 - fade)
	else:
		sprite.self_modulate = Color.WHITE
