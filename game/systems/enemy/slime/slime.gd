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
	## ลอยใช้ตัวกลม (เฟรม 0) แล้วยืดเป็นวงรีด้วยโค้ด (leap_pose) · เฟรม 12 วาดไว้ ยังไม่ใช้
	&"leap": {"frames": [0], "fps": 1.0, "loop": false},
	&"land": {"frames": [13, 0], "fps": 8.0, "loop": false},
	&"death": {"frames": [14, 15, 16], "fps": 8.0, "loop": false},
	## โดนตี: ตาหยี 0.2 วิ แล้วลืมตา · ตัวสั่นแบบเยลลี่ด้วยโค้ด (hurt_pose)
	&"hurt": {"frames": [17, 17, 0], "fps": 10.0, "loop": false},
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
@export var leap_time: float = 0.28
@export var leap_height: float = 14.0
## พักหลังเด้งต่อจบ (ช่วงเด้งต่อ ~0.2 วิ ผู้เล่นก็สวนได้อยู่แล้ว)
@export var recover_time: float = 0.6
@export var hurt_time: float = 0.25
@export var corpse_time: float = 1.2
@export_group("Leap Shape")
## ยืดเป็นวงรีชี้ไปทางที่พุ่งตลอดทาง (0.35 = ยาวขึ้น 35% บางลงให้พื้นที่เท่าเดิม) · ไม่หมุนตัว ตาตั้งตรง
@export var stretch_amount: float = 0.35
## ยืดเพิ่มตอนออกตัว/ใกล้ตก (เร็วสุด)
@export var stretch_speed_bonus: float = 0.15
## แบนตอนตกพื้น — เด้งต่อแบนน้อยลงตามความสูง
@export var squash_amount: float = 0.5
@export var squash_time: float = 0.05
## เด้งต่อ 1 ครั้งหลังตกพื้น (Hitbox ปิดแล้ว)
@export var rebound_height: float = 5.0
@export var rebound_time: float = 0.12
@export var rebound_distance: float = 8.0
@export_group("Hop & Hurt Shape")
## เดิน: ยืดตอนลอย · แบนตอนลง · ย่อเตรียมก่อนเด้ง (เบากว่าท่าโจมตี)
@export var hop_stretch: float = 0.2
@export var hop_squash: float = 0.25
## โดนตี: บี้ตามทิศที่โดน แล้วสั่นกลับแบบเยลลี่ (แรง, ความถี่ rad/s, หายเร็วแค่ไหน)
@export var hurt_wobble: float = 0.35
@export var hurt_wobble_freq: float = 30.0
@export var hurt_wobble_decay: float = 9.0
@export_group("VFX")
@export var vfx_enabled: bool = true
## ระยะห่างระหว่างเงาตามตัว (after-image) ตอนพุ่ง
@export var afterimage_interval: float = 0.05
@export var afterimage_life: float = 0.22
@export var afterimage_color: Color = Color(0.45, 0.8, 1.0, 0.55)
## รัศมีคลื่นกระแทกตอนตกพื้น (ประมาณขนาด Hitbox)
@export var impact_ring_radius: float = 18.0
@export var impact_droplets: int = 10
@export var takeoff_dust: int = 6

var state: State = State.IDLE
var target: Node2D = null

var _state_t: float = 0.0
var _leap_from: Vector2 = Vector2.ZERO
var _leap_to: Vector2 = Vector2.ZERO
var _anim: StringName = &""
var _anim_t: float = 0.0
var _flash_t: float = 0.0
var _died_emitted: bool = false
var _afterimage_t: float = 0.0
## ความสูงจากพื้นตอนนี้ (เงาใช้)
var _lift: float = 0.0
var _landings: int = 0
var _hurt_dir: Vector2 = Vector2.RIGHT

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
			_tick_leap(delta)
		State.RECOVER:
			velocity = Vector2.ZERO
			if _state_t >= recover_time:
				_enter(State.CHASE if _has_target() else State.IDLE)
		State.HURT:
			velocity = velocity.move_toward(Vector2.ZERO, knockback_friction * delta)
			_apply_pose(hurt_pose(_state_t, _hurt_dir))
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
	var lift: float = clampf(_lift / maxf(leap_height, 1.0), 0.0, 1.0)
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
	var pose: Dictionary = hop_pose(phase, to_target.normalized())
	_lift = pose["lift"]
	_apply_pose(pose["basis"])
	if not airborne and to_target.length() <= attack_range:
		_enter(State.WINDUP)
		return
	velocity = to_target.normalized() * hop_speed if airborne else Vector2.ZERO


## ยืดตามแกน u (unit) ให้พื้นที่เท่าเดิม — matrix สมมาตร ไม่มีการหมุน ตาจึงไม่เอียง
## แบนลงกว้างออก (ยึดเท้า) ให้พื้นที่เท่าเดิม
static func squash_basis(amount: float) -> Transform2D:
	return Transform2D(Vector2(1.0 + amount, 0), Vector2(0, 1.0 / (1.0 + amount)), Vector2.ZERO)


## เดิน 1 รอบเด้ง (phase 0–1): 0–0.5 ลอย (ยืดตามทิศ) · 0.5–0.6 ลงพื้นแบน · 0.85–1 ย่อเตรียมเด้ง
func hop_pose(phase: float, dir: Vector2) -> Dictionary:
	var pose: Dictionary = {"lift": 0.0, "basis": Transform2D.IDENTITY}
	if phase < 0.5:
		var k: float = phase / 0.5
		pose["lift"] = sin(k * PI) * hop_height
		var v: Vector2 = dir * hop_speed + Vector2(0, -hop_height * PI * cos(k * PI) / (hop_interval * 0.5))
		if v.length() > 0.01:
			pose["basis"] = stretch_basis(v.normalized(), hop_stretch * (0.5 + 0.5 * absf(cos(k * PI))))
	elif phase < 0.6:
		pose["basis"] = squash_basis(hop_squash * (1.0 - (phase - 0.5) / 0.1))
	elif phase > 0.85:
		pose["basis"] = squash_basis(hop_squash * 0.8 * (phase - 0.85) / 0.15)
	return pose


## โดนตี t วินาที: บี้ตามทิศที่โดน (u) แล้วสั่นกลับไปมาจนนิ่ง
func hurt_pose(t: float, u: Vector2) -> Transform2D:
	var a: float = hurt_wobble * exp(-hurt_wobble_decay * t) * cos(hurt_wobble_freq * t)
	return stretch_basis(u, -a)


static func stretch_basis(u: Vector2, amount: float) -> Transform2D:
	var along: float = 1.0 + amount
	var across: float = 1.0 / along
	var x_axis := Vector2(across + (along - across) * u.x * u.x, (along - across) * u.x * u.y)
	var y_axis := Vector2((along - across) * u.x * u.y, across + (along - across) * u.y * u.y)
	return Transform2D(x_axis, y_axis, Vector2.ZERO)


## ท่าพุ่ง ณ เวลา t: โค้งหลัก (วงรีชี้ไปข้างหน้า) → แบน → เด้งต่อ 1 ครั้ง → แบน → จบ
## คืน lift, travel (ระยะตามทิศพุ่ง), basis (Transform2D ยืด/แบน), landings (แตะพื้นกี่ครั้ง), done
func leap_pose(t: float, distance: float, dir: Vector2) -> Dictionary:
	var arcs: Array[Vector3] = [Vector3(leap_time, leap_height, distance),
		Vector3(rebound_time, rebound_height, rebound_distance)]
	var pose: Dictionary = {"lift": 0.0, "travel": 0.0, "basis": Transform2D.IDENTITY, "landings": 0, "done": false}
	var tt: float = t
	for i: int in arcs.size():
		var dur: float = arcs[i].x
		var h: float = arcs[i].y
		var d: float = arcs[i].z
		var power: float = h / maxf(leap_height, 1.0)
		if tt < dur:
			var k: float = tt / dur
			pose["lift"] = sin(k * PI) * h
			pose["travel"] += d * k
			# ทิศที่ลอยบนจอ = ไปข้างหน้า + ขึ้น/ลง → ยอดโค้งชี้ไปข้างหน้าตรงๆ
			var v: Vector2 = dir * (d / dur) + Vector2(0, -h * PI * cos(k * PI) / dur)
			if v.length() > 0.01:
				var st: float = (stretch_amount + stretch_speed_bonus * absf(cos(k * PI))) * power
				pose["basis"] = stretch_basis(v.normalized(), st)
			return pose
		tt -= dur
		pose["travel"] += d
		pose["landings"] = i + 1
		if tt < squash_time:
			pose["basis"] = squash_basis(squash_amount * power * (1.0 - tt / squash_time))
			return pose
		tt -= squash_time
	pose["done"] = true
	return pose


func _tick_leap(delta: float) -> void:
	var offset: Vector2 = _leap_to - _leap_from
	var dir: Vector2 = offset.normalized() if offset.length() > 0.01 else Vector2.ZERO
	var pose: Dictionary = leap_pose(_state_t, offset.length(), dir)
	_lift = pose["lift"]
	_apply_pose(pose["basis"])
	var desired: Vector2 = _leap_from + dir * float(pose["travel"])
	velocity = (desired - global_position) / delta if delta > 0.0 else Vector2.ZERO
	var landings: int = pose["landings"]
	if landings > _landings:
		_landings = landings
		if landings == 1:
			# ตกพื้นครั้งแรก = จังหวะโจมตี · เด้งต่อไม่ทำดาเมจ
			hitbox.deactivate()
			if _vfx_ok():
				SlimeVfx.spawn_impact(get_parent(), global_position, impact_ring_radius, impact_droplets)
		elif _vfx_ok():
			SlimeVfx.spawn_dust(get_parent(), global_position, 2)
	if _landings == 0:
		_afterimage_t += delta
		if _afterimage_t >= afterimage_interval:
			_afterimage_t = 0.0
			_spawn_afterimage()
	if pose["done"]:
		velocity = Vector2.ZERO
		_enter(State.RECOVER)


## ใส่รูปทรง — ลอย: ยืดรอบกลางตัว · อยู่พื้น: ยึดเท้า (แบนแล้วไม่จมดิน)
func _apply_pose(basis: Transform2D) -> void:
	var pivot: Vector2 = Vector2(0, -8) if _lift > 0.0 else Vector2.ZERO
	basis.origin = Vector2(0, -_lift) + pivot - basis.basis_xform(pivot)
	sprite.transform = basis


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
	_lift = 0.0
	_apply_pose(Transform2D.IDENTITY)
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
			_afterimage_t = 0.0
			_landings = 0
			if _vfx_ok():
				SlimeVfx.spawn_dust(get_parent(), global_position, takeoff_dust)
		State.RECOVER:
			_play(&"idle")
		State.HURT:
			_play(&"hurt")
		State.DEAD:
			_play(&"death")


func _on_hurt(info: DamageInfo) -> void:
	if state == State.DEAD:
		return
	var dealt: int = health.take_damage(compute_damage(info.amount, defense))
	EventBus.damage_dealt.emit(self, info, dealt)
	_flash_t = 0.08
	velocity = info.knockback
	if info.knockback.length() > 0.01:
		_hurt_dir = info.knockback.normalized()
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


func _vfx_ok() -> bool:
	return vfx_enabled and is_inside_tree() and get_parent() != null


## เงาตามตัวตอนพุ่ง — สำเนาเฟรมปัจจุบัน ค้างไว้ที่เดิมแล้วจางหาย
func _spawn_afterimage() -> void:
	if not _vfx_ok():
		return
	var ghost := Sprite2D.new()
	ghost.texture = sprite.texture
	ghost.hframes = sprite.hframes
	ghost.frame = sprite.frame
	ghost.offset = sprite.offset
	ghost.modulate = afterimage_color
	get_parent().add_child(ghost)
	# ทรงเดียวกับตัวตอนนั้น · y น้อยกว่าตัว (ลอยอยู่) → y-sort วาดไว้หลังสไลม์
	ghost.global_transform = global_transform * sprite.transform
	var tw: Tween = ghost.create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, afterimage_life)
	tw.tween_callback(ghost.queue_free)


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
