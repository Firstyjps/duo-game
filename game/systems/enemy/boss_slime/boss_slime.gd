class_name BossSlime
extends CharacterBody2D
## บอสสไลม์ (Boss Slime AI) — Abyssal Maw (issue #67)
## ท่า 3 ท่า: ทุบพื้น (Slam), กระโดดทับ (Leap), แตกลูก (Split)
## Phase 2 (HP < 50%): ท่าเร็วขึ้น x0.8, poise สูง สะสม stagger, แตกลูกได้
## ดาเมจผ่าน Hitbox/Hurtbox ตาม docs/contracts/damage.md, feedback.md

enum State {
	IDLE,
	CHASE,
	SLAM_WINDUP,
	SLAM_ACTIVE,
	SLAM_RECOVER,
	LEAP_WINDUP,
	LEAP_AIRBORNE,
	LEAP_IMPACT,
	LEAP_RECOVER,
	SPLIT_WINDUP,
	HURT,
	DEAD
}

## ลำดับเฟรมใน boss_slime_sheet.png (128x128, 20 เฟรม):
## 0–7 idle, 8–9 blink, 10–11 windup, 12–13 rise, 14–15 slam, 16 hurt, 17–19 death
const ANIMS: Dictionary = {
	&"idle": {"frames": [0, 1, 2, 3, 4, 5, 6, 7], "fps": 6.0, "loop": true},
	&"idle_blink": {"frames": [0, 1, 2, 3, 8, 9, 6, 7], "fps": 6.0, "loop": true},
	&"windup": {"frames": [10, 11], "fps": 4.0, "loop": false},
	&"rise": {"frames": [12, 13], "fps": 3.0, "loop": false},
	&"slam": {"frames": [14, 15], "fps": 8.0, "loop": false},
	&"hurt": {"frames": [16, 16, 0], "fps": 10.0, "loop": false},
	&"death": {"frames": [17, 18, 19], "fps": 3.0, "loop": false},
	&"split": {"frames": [8, 9], "fps": 5.0, "loop": true},
}

const FLASH_HURT := Color(3.0, 3.0, 3.0)
const FLASH_WINDUP := Color(1.8, 0.75, 0.7)
const SLIME_SCENE: PackedScene = preload("res://systems/enemy/slime/slime.tscn")

@export var enemy_id: StringName = &"boss_slime"
@export var display_name: String = "Abyssal Maw"
@export var defense: int = 2
@export_range(0.0, 1.0) var blink_chance: float = 0.3

@export_group("Phase & Poise")
@export var base_max_poise: float = 40.0
@export var phase2_max_poise: float = 60.0
@export var poise_regen_rate: float = 20.0
@export var poise_regen_delay_time: float = 2.0
@export var phase2_speed_multiplier: float = 0.8

@export_group("Movement")
@export var hop_speed: float = 45.0
@export var hop_interval: float = 1.0
@export var hop_height: float = 7.0
@export var knockback_friction: float = 900.0

@export_group("Slam Attack")
@export var slam_range: float = 95.0
@export var slam_windup_time: float = 0.9
@export var slam_active_time: float = 0.16
@export var slam_recover_time: float = 0.6
@export var slam_radius: float = 65.0
@export var slam_damage: int = 4
@export var slam_stagger: float = 25.0
@export var slam_shake: float = 0.5

@export_group("Leap Attack")
@export var leap_range: float = 230.0
@export var leap_distance: float = 140.0
@export var leap_windup_time: float = 0.8
@export var leap_air_time: float = 0.5
@export var leap_impact_time: float = 0.16
@export var leap_recover_time: float = 0.6
@export var leap_height: float = 34.0
@export var leap_radius: float = 55.0
@export var leap_damage: int = 5
@export var leap_stagger: float = 30.0
@export var leap_shake: float = 0.6

@export_group("Split Move")
@export var split_windup_time: float = 0.8
@export var split_cooldown: float = 7.0
@export var max_living_minions: int = 4

@export_group("Shape & Isometric")
@export var squash: float = 0.55
@export var aoe_hurt_offset_y: float = -22.0
@export var aoe_hurt_radius_margin: float = 16.0
@export var body_radius: float = 16.0
@export var hurt_time: float = 0.35
@export var corpse_time: float = 1.8

var state: State = State.IDLE
var target: Node2D = null
var is_attack_active: bool = false
var current_poise: float = 40.0

var _state_t: float = 0.0
var _anim: StringName = &"idle"
var _anim_t: float = 0.0
var _flash_t: float = 0.0
var _lift: float = 0.0
var _leap_from: Vector2 = Vector2.ZERO
var _leap_to: Vector2 = Vector2.ZERO
var _poise_regen_delay: float = 0.0
var _split_cd: float = 0.0
var _boss_engaged_emitted: bool = false
var _died_emitted: bool = false
var _minions: Array[Node] = []
var _last_attack_was_slam: bool = false

var sprite: Sprite2D
var health: Health
var hurtbox: Hurtbox
var hitbox: Hitbox
var hitbox_shape: CollisionShape2D
var detect: Area2D
var telegraph_marker: TelegraphMarker


func _ready() -> void:
	setup()


## ผูก node ลูก + signal — แยกจาก _ready ให้เทสต์เรียกได้ก่อนอยู่ใน scene tree
func setup() -> void:
	if has_node("Sprite"):
		sprite = $Sprite
	if has_node("Health"):
		health = $Health
	if has_node("Hurtbox"):
		hurtbox = $Hurtbox
	if has_node("Hitbox"):
		hitbox = $Hitbox
		if hitbox.has_node("Shape"):
			hitbox_shape = hitbox.get_node("Shape")
	if has_node("Detect"):
		detect = $Detect
	if has_node("TelegraphMarker"):
		telegraph_marker = $TelegraphMarker
	else:
		telegraph_marker = TelegraphMarker.new()
		add_child(telegraph_marker)

	if health != null:
		if not is_inside_tree():
			health.reset()
		if not health.died.is_connected(_on_died):
			health.died.connect(_on_died)

	current_poise = get_max_poise()

	if hurtbox != null:
		hurtbox.team = Combat.Team.ENEMY
		if not hurtbox.hurt.is_connected(_on_hurt):
			hurtbox.hurt.connect(_on_hurt)

	if hitbox != null:
		hitbox.source = self
		hitbox.team = Combat.Team.ENEMY
		hitbox.deactivate()

	if detect != null:
		detect.collision_layer = 0
		detect.collision_mask = Combat.LAYER_PLAYER
		if not detect.body_entered.is_connected(_on_body_entered):
			detect.body_entered.connect(_on_body_entered)
		if not detect.body_exited.is_connected(_on_body_exited):
			detect.body_exited.connect(_on_body_exited)

	if has_node("Body"):
		var b_node: Node = get_node("Body")
		if b_node is CollisionShape2D and (b_node as CollisionShape2D).shape is CircleShape2D:
			body_radius = ((b_node as CollisionShape2D).shape as CircleShape2D).radius

	if telegraph_marker != null:
		telegraph_marker.top_level = true
		telegraph_marker.z_index = -1
		telegraph_marker.squash = squash
		telegraph_marker.visible = false

	if hitbox_shape != null:
		if hitbox_shape.shape != null:
			hitbox_shape.shape = hitbox_shape.shape.duplicate()
		hitbox_shape.position = Vector2(0, aoe_hurt_offset_y)
		hitbox_shape.scale = Vector2(1.0, squash)

	_play(&"idle")


## ดาเมจหลังหัก defense — โดนแล้วขั้นต่ำ 1 (contract damage)
static func compute_damage(amount: int, def: int) -> int:
	return maxi(1, amount - def)


## จุดตกของท่ากระโดดทับ — ล็อกตอนเริ่ม windup ไม่เกิน max_dist
static func leap_target(from: Vector2, toward: Vector2, max_dist: float) -> Vector2:
	var offset: Vector2 = toward - from
	if offset.length() > max_dist:
		offset = offset.normalized() * max_dist
	return from + offset


## คำนวณว่าจุด point อยู่ในวงรี AoE หรือไม่ (squash = 0.55)
static func is_point_in_aoe(point: Vector2, center: Vector2, radius: float, sq: float = 0.55) -> bool:
	var offset: Vector2 = point - center
	var nx: float = offset.x / radius
	var ny: float = offset.y / (radius * sq)
	return (nx * nx + ny * ny) <= 1.0


func is_phase_2() -> bool:
	if health == null:
		return false
	return health.hp < int(ceil(float(health.max_hp) * 0.5))


func get_speed_multiplier() -> float:
	return phase2_speed_multiplier if is_phase_2() else 1.0


func get_max_poise() -> float:
	return phase2_max_poise if is_phase_2() else base_max_poise


func can_split() -> bool:
	return is_phase_2() and get_alive_minions_count() < max_living_minions and _split_cd <= 0.0


func set_target(node: Node2D) -> void:
	target = node
	if node != null and not _boss_engaged_emitted:
		_boss_engaged_emitted = true
		EventBus.boss_engaged.emit(self, health, display_name)
	if state == State.IDLE and node != null:
		_enter(State.CHASE)


func _physics_process(delta: float) -> void:
	tick(delta)
	# ลอย/กระแทก: ไม่ให้ physics ดันออกจากจุดตก (AoE ต้องอยู่กลางวงเตือน แม้ลูกสไลม์ยืนตรงนั้น)
	if state != State.LEAP_AIRBORNE and state != State.LEAP_IMPACT:
		move_and_slide()


func _process(delta: float) -> void:
	_tick_anim(delta)
	_tick_flash(delta)
	queue_redraw()


## เงาบนพื้น — ปรับขนาดตามความสูงตอนลอย
func _draw() -> void:
	if state == State.DEAD and _state_t >= corpse_time:
		return
	var lift_ratio: float = clampf(_lift / maxf(leap_height, 1.0), 0.0, 1.0)
	var shadow_w: float = lerpf(46.0, 28.0, lift_ratio)
	var alpha: float = 0.35 - 0.15 * lift_ratio
	if state == State.DEAD:
		var fade: float = clampf((_state_t - corpse_time * 0.5) / (corpse_time * 0.5), 0.0, 1.0)
		alpha *= (1.0 - fade)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, squash))
	draw_circle(Vector2.ZERO, shadow_w, Color(0.0, 0.0, 0.0, alpha))


## AI 1 เฟรม (ไม่รวม physics) — เทสต์เรียกตรงได้
func tick(delta: float) -> void:
	_state_t += delta
	if _split_cd > 0.0:
		_split_cd -= delta
	if _poise_regen_delay > 0.0:
		_poise_regen_delay -= delta
	elif current_poise < get_max_poise():
		current_poise = minf(get_max_poise(), current_poise + poise_regen_rate * delta)

	match state:
		State.IDLE:
			velocity = Vector2.ZERO
			if _has_target():
				_enter(State.CHASE)
		State.CHASE:
			_tick_chase(delta)
		State.SLAM_WINDUP:
			velocity = Vector2.ZERO
			var windup_dur: float = slam_windup_time * get_speed_multiplier()
			if telegraph_marker != null:
				telegraph_marker.progress = clampf(_state_t / windup_dur, 0.0, 1.0)
			if _state_t >= windup_dur:
				_enter(State.SLAM_ACTIVE)
		State.SLAM_ACTIVE:
			velocity = Vector2.ZERO
			if _state_t >= slam_active_time:
				_enter(State.SLAM_RECOVER)
		State.SLAM_RECOVER:
			velocity = Vector2.ZERO
			var rec_dur: float = slam_recover_time * get_speed_multiplier()
			if _state_t >= rec_dur:
				_enter(State.CHASE if _has_target() else State.IDLE)
		State.LEAP_WINDUP:
			velocity = Vector2.ZERO
			var leap_windup_dur: float = leap_windup_time * get_speed_multiplier()
			if telegraph_marker != null:
				telegraph_marker.progress = clampf(_state_t / leap_windup_dur, 0.0, 1.0)
			if _state_t >= leap_windup_dur:
				_enter(State.LEAP_AIRBORNE)
		State.LEAP_AIRBORNE:
			_tick_leap_airborne(delta)
		State.LEAP_IMPACT:
			velocity = Vector2.ZERO
			if _state_t >= leap_impact_time:
				_enter(State.LEAP_RECOVER)
		State.LEAP_RECOVER:
			velocity = Vector2.ZERO
			var leap_rec_dur: float = leap_recover_time * get_speed_multiplier()
			if _state_t >= leap_rec_dur:
				_enter(State.CHASE if _has_target() else State.IDLE)
		State.SPLIT_WINDUP:
			velocity = Vector2.ZERO
			var split_dur: float = split_windup_time * get_speed_multiplier()
			if _state_t >= split_dur:
				_spawn_minions()
				_enter(State.CHASE if _has_target() else State.IDLE)
		State.HURT:
			velocity = velocity.move_toward(Vector2.ZERO, knockback_friction * delta)
			if _state_t >= hurt_time:
				_enter(State.CHASE if _has_target() else State.IDLE)
		State.DEAD:
			velocity = velocity.move_toward(Vector2.ZERO, knockback_friction * delta)
			if _state_t >= corpse_time:
				queue_free()


func _tick_chase(delta: float) -> void:
	if not _has_target():
		_enter(State.IDLE)
		return

	var to_target: Vector2 = target.global_position - global_position
	var dist: float = to_target.length()

	# ใน Phase 2 แตกลูกเป็นลำดับแรกถ้าเงื่อนไขพร้อม
	if can_split():
		_enter(State.SPLIT_WINDUP)
		return

	var hop_dur: float = hop_interval * get_speed_multiplier()
	var phase: float = fmod(_state_t, hop_dur) / hop_dur
	var airborne: bool = phase < 0.5
	var pose: Dictionary = hop_pose(phase, to_target.normalized())
	_lift = pose["lift"]
	_apply_pose(pose["basis"])

	# เลือกท่าโจมตีตอนอยู่บนพื้น
	if not airborne:
		if dist <= slam_range:
			if _last_attack_was_slam and dist > 40.0:
				_last_attack_was_slam = false
				_enter(State.LEAP_WINDUP)
			else:
				_last_attack_was_slam = true
				_enter(State.SLAM_WINDUP)
			return
		elif dist <= leap_range:
			_last_attack_was_slam = false
			_enter(State.LEAP_WINDUP)
			return

	velocity = to_target.normalized() * hop_speed if airborne else Vector2.ZERO


func _tick_leap_airborne(delta: float) -> void:
	var total_dur: float = leap_air_time * get_speed_multiplier()
	var k: float = clampf(_state_t / total_dur, 0.0, 1.0)
	_lift = sin(k * PI) * leap_height

	var dir: Vector2 = (_leap_to - _leap_from).normalized() if (_leap_to - _leap_from).length() > 0.01 else Vector2.ZERO
	var total_dist: float = _leap_from.distance_to(_leap_to)
	global_position = _leap_from + dir * (total_dist * k)
	velocity = Vector2.ZERO

	var v: Vector2 = dir * (total_dist / total_dur) + Vector2(0, -leap_height * PI * cos(k * PI) / total_dur)
	if v.length() > 0.01:
		var st: float = 0.22 + 0.12 * absf(cos(k * PI))
		_apply_pose(stretch_basis(v.normalized(), st))

	if _state_t >= total_dur:
		_enter(State.LEAP_IMPACT)


func _cast_leap_destination(from: Vector2, to: Vector2) -> Vector2:
	var motion: Vector2 = to - from
	if motion.length_squared() < 0.01:
		return to
	if not is_inside_tree() or get_world_2d() == null:
		return to
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	if space_state == null:
		return to

	var query := PhysicsShapeQueryParameters2D.new()
	var circle := CircleShape2D.new()
	circle.radius = body_radius
	query.shape = circle
	var body_offset: Vector2 = Vector2(0, -8)
	if has_node("Body"):
		var b_node: Node = get_node("Body")
		if b_node is Node2D:
			body_offset = (b_node as Node2D).position
	query.transform = Transform2D(0.0, from + body_offset)
	query.motion = motion
	query.collision_mask = Combat.LAYER_WORLD
	query.exclude = [get_rid()]

	var res: PackedFloat32Array = space_state.cast_motion(query)
	if res.size() >= 1 and res[0] < 1.0:
		return from + motion * res[0]
	return to


func _enter(next: State) -> void:
	var prev: State = state
	if prev == State.DEAD:
		return

	# ล้างสถานะเดิม
	if prev == State.SLAM_WINDUP:
		if telegraph_marker != null:
			telegraph_marker.visible = false
	elif prev == State.LEAP_WINDUP:
		if next != State.LEAP_AIRBORNE and telegraph_marker != null:
			telegraph_marker.visible = false
	elif prev == State.LEAP_AIRBORNE:
		if next != State.LEAP_IMPACT and telegraph_marker != null:
			telegraph_marker.visible = false
	if prev == State.SLAM_ACTIVE or prev == State.LEAP_IMPACT:
		is_attack_active = false
		if hitbox != null:
			hitbox.deactivate()
	if prev == State.SPLIT_WINDUP:
		if sprite != null:
			sprite.self_modulate = Color.WHITE

	state = next
	_state_t = 0.0
	_lift = 0.0
	_apply_pose(Transform2D.IDENTITY)

	match next:
		State.IDLE, State.CHASE:
			_play(&"idle")
		State.SLAM_WINDUP:
			_play(&"rise")
			is_attack_active = false
			if telegraph_marker != null:
				telegraph_marker.radius = slam_radius
				telegraph_marker.squash = squash
				telegraph_marker.show_at(global_position)
		State.SLAM_ACTIVE:
			_play(&"slam")
			is_attack_active = true
			if telegraph_marker != null:
				telegraph_marker.visible = false
			if hitbox != null:
				hitbox.position = Vector2.ZERO
				hitbox.damage = slam_damage
				hitbox.knockback_force = 220.0
				hitbox.stagger = slam_stagger
				_configure_hitbox_shape(slam_radius)
				hitbox.activate()
			EventBus.screen_shake_requested.emit(slam_shake, global_position)
		State.SLAM_RECOVER:
			_play(&"idle")
		State.LEAP_WINDUP:
			_play(&"windup")
			is_attack_active = false
			_leap_from = global_position
			var t_pos: Vector2 = target.global_position if _has_target() else global_position + Vector2.RIGHT * 60.0
			_leap_to = leap_target(_leap_from, t_pos, leap_distance)
			_leap_to = _cast_leap_destination(_leap_from, _leap_to)
			if telegraph_marker != null:
				telegraph_marker.radius = leap_radius
				telegraph_marker.squash = squash
				telegraph_marker.show_at(_leap_to)
		State.LEAP_AIRBORNE:
			_play(&"idle")
			is_attack_active = false
		State.LEAP_IMPACT:
			_play(&"slam")
			is_attack_active = true
			velocity = Vector2.ZERO
			global_position = _leap_to
			if telegraph_marker != null:
				telegraph_marker.visible = false
			if hitbox != null:
				hitbox.position = Vector2.ZERO
				hitbox.damage = leap_damage
				hitbox.knockback_force = 260.0
				hitbox.stagger = leap_stagger
				_configure_hitbox_shape(leap_radius)
				hitbox.activate()
			EventBus.screen_shake_requested.emit(leap_shake, global_position)
		State.LEAP_RECOVER:
			_play(&"idle")
		State.SPLIT_WINDUP:
			_play(&"split")
			is_attack_active = false
			_split_cd = split_cooldown
		State.HURT:
			_play(&"hurt")
			is_attack_active = false
		State.DEAD:
			_play(&"death")
			is_attack_active = false
			if telegraph_marker != null:
				telegraph_marker.visible = false


func _configure_hitbox_shape(r: float) -> void:
	if hitbox_shape != null:
		var circle := hitbox_shape.shape as CircleShape2D
		if circle != null:
			circle.radius = maxf(1.0, r - aoe_hurt_radius_margin)
		hitbox_shape.position = Vector2(0, aoe_hurt_offset_y)
		hitbox_shape.scale = Vector2(1.0, squash)


func _spawn_minions() -> void:
	if not is_phase_2():
		return
	var alive: int = get_alive_minions_count()
	var can_spawn: int = mini(randi_range(2, 3), max_living_minions - alive)
	if can_spawn <= 0:
		return

	var parent_node: Node = get_parent()
	if parent_node == null:
		var tree: SceneTree = Engine.get_main_loop() as SceneTree
		if tree != null and tree.root != null:
			parent_node = tree.root

	for i: int in can_spawn:
		var minion: Node = SLIME_SCENE.instantiate()
		var angle: float = randf() * TAU
		var dist: float = randf_range(35.0, 60.0)
		var spawn_pos: Vector2 = global_position + Vector2(cos(angle), sin(angle) * squash) * dist
		_minions.append(minion)
		if parent_node != null:
			parent_node.add_child(minion)
		if minion is Node2D:
			minion.global_position = spawn_pos
		if minion.has_method("setup") and minion.get("sprite") == null:
			minion.call("setup")
		if minion.has_method("set_target") and target != null:
			minion.call("set_target", target)


func get_alive_minions_count() -> int:
	var count: int = 0
	var still_alive: Array[Node] = []
	for m: Node in _minions:
		if is_instance_valid(m) and not m.is_queued_for_deletion():
			var is_dead_flag: bool = false
			if "health" in m and m.health != null and "is_dead" in m.health:
				is_dead_flag = m.health.is_dead
			if not is_dead_flag:
				count += 1
				still_alive.append(m)
	_minions = still_alive
	return count


func _on_hurt(info: DamageInfo) -> void:
	if state == State.DEAD:
		return
	var dealt: int = health.take_damage(compute_damage(info.amount, defense))
	EventBus.damage_dealt.emit(self, info, dealt)
	_flash_t = 0.08
	velocity = info.knockback * 0.4

	# สะสม stagger ลง poise
	current_poise -= info.stagger
	_poise_regen_delay = poise_regen_delay_time

	if health.is_dead:
		return

	# เซ (HURT) เฉพาะเมื่อ poise หมด
	if current_poise <= 0.0:
		current_poise = get_max_poise()
		if state != State.SLAM_ACTIVE and state != State.LEAP_IMPACT and state != State.LEAP_AIRBORNE:
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


func _play(anim: StringName) -> void:
	_anim = anim
	_anim_t = 0.0
	if sprite != null and ANIMS.has(anim):
		sprite.frame = ANIMS[anim]["frames"][0]


func _tick_anim(delta: float) -> void:
	if sprite == null:
		return
	if state == State.DEAD:
		if _state_t < 0.3:
			sprite.frame = 17
		elif _state_t < 0.6:
			sprite.frame = 18
		else:
			sprite.frame = 19
		return

	if not ANIMS.has(_anim):
		return
	var a: Dictionary = ANIMS[_anim]
	var frames: Array = a["frames"]
	_anim_t += delta
	var fps: float = float(a["fps"])
	var loop_len: float = frames.size() / fps
	if a["loop"] and _anim_t >= loop_len:
		_anim_t = fmod(_anim_t, loop_len)
		if _anim == &"idle" or _anim == &"idle_blink":
			_anim = &"idle_blink" if randf() < blink_chance else &"idle"
			a = ANIMS[_anim]
			frames = a["frames"]
	var i: int = int(_anim_t * fps)
	i = i % frames.size() if a["loop"] else mini(i, frames.size() - 1)
	sprite.frame = frames[i]


func _tick_flash(delta: float) -> void:
	if sprite == null:
		return
	if _flash_t > 0.0:
		_flash_t -= delta
		sprite.self_modulate = FLASH_HURT
	elif state == State.SLAM_WINDUP or state == State.LEAP_WINDUP:
		var cur_dur: float = slam_windup_time * get_speed_multiplier() if state == State.SLAM_WINDUP else leap_windup_time * get_speed_multiplier()
		var k: float = clampf(_state_t / maxf(0.01, cur_dur), 0.0, 1.0)
		var pulse: float = 0.5 + 0.5 * sin(_state_t * lerpf(10.0, 30.0, k))
		sprite.self_modulate = Color.WHITE.lerp(FLASH_WINDUP, pulse)
	elif state == State.SPLIT_WINDUP:
		var pulse: float = 0.5 + 0.5 * sin(_state_t * 25.0)
		sprite.self_modulate = Color.WHITE.lerp(Color(0.4, 0.9, 1.0), pulse)
	elif state == State.DEAD:
		var fade: float = clampf((_state_t - corpse_time * 0.5) / (corpse_time * 0.5), 0.0, 1.0)
		sprite.self_modulate = Color(1.0, 1.0, 1.0, 1.0 - fade)
	else:
		sprite.self_modulate = Color.WHITE


static func squash_basis(amount: float) -> Transform2D:
	return Transform2D(Vector2(1.0 + amount, 0.0), Vector2(0.0, 1.0 / (1.0 + amount)), Vector2.ZERO)


static func stretch_basis(u: Vector2, amount: float) -> Transform2D:
	var along: float = 1.0 + amount
	var across: float = 1.0 / along
	var x_axis := Vector2(across + (along - across) * u.x * u.x, (along - across) * u.x * u.y)
	var y_axis := Vector2((along - across) * u.x * u.y, across + (along - across) * u.y * u.y)
	return Transform2D(x_axis, y_axis, Vector2.ZERO)


func hop_pose(phase: float, dir: Vector2) -> Dictionary:
	var pose: Dictionary = {"lift": 0.0, "basis": Transform2D.IDENTITY}
	var hop_dur: float = hop_interval * get_speed_multiplier()
	if phase < 0.5:
		var k: float = phase / 0.5
		pose["lift"] = sin(k * PI) * hop_height
		var v: Vector2 = dir * hop_speed + Vector2(0, -hop_height * PI * cos(k * PI) / (hop_dur * 0.5))
		if v.length() > 0.01:
			pose["basis"] = stretch_basis(v.normalized(), 0.15 * (0.5 + 0.5 * absf(cos(k * PI))))
	elif phase < 0.6:
		pose["basis"] = squash_basis(0.22 * (1.0 - (phase - 0.5) / 0.1))
	elif phase > 0.85:
		pose["basis"] = squash_basis(0.22 * 0.8 * (phase - 0.85) / 0.15)
	return pose


func _apply_pose(basis: Transform2D) -> void:
	if sprite == null:
		return
	var pivot: Vector2 = Vector2(0, -40) if _lift > 0.0 else Vector2.ZERO
	basis.origin = Vector2(0, -_lift) + pivot - basis.basis_xform(pivot)
	sprite.transform = basis
