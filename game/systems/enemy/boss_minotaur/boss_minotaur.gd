class_name BossMinotaur
extends CharacterBody2D
## บอสมิโนทอร์ (The Horned Warden) — บอสเฟส 4: AI 8 ทิศ + 6 ท่าโจมตี + 2 Phase + Poise
## docs/contracts/damage.md · EventBus.boss_engaged · EventBus.enemy_died

enum State { IDLE, CHASE, WINDUP, ACTIVE, RECOVER, HURT, DEAD }

enum AttackType {
	CLEAVE,  # ฟาดเหนือหัว (ระยะใกล้)
	SWEEP,   # กวาดขวาน (ระยะใกล้)
	RISING,  # เสยขวานขึ้น (ระยะใกล้)
	CHARGE,  # พุ่งชนด้วยเขา (ระยะไกล)
	STOMP,   # กระทืบกีบ (ระยะกลาง AoE)
	LEAP,    # กระโดดทุบ (ระยะไกล)
}

const COLS_PER_ROW: int = 60

const COL_IDLE_START: int = 0
const COL_IDLE_COUNT: int = 4

const COL_WALK_START: int = 4
const COL_WALK_COUNT: int = 8

const ATTACK_COLS: Dictionary = {
	AttackType.CLEAVE: {"start": 12, "tele": 13, "hit": 16, "recover": 17},
	AttackType.SWEEP: {"start": 18, "tele": 19, "hit": 21, "recover": 23},
	AttackType.RISING: {"start": 24, "tele": 25, "hit": 27, "recover": 29},
	AttackType.CHARGE: {"start": 30, "tele": 31, "hit": 34, "recover": 35},
	AttackType.STOMP: {"start": 36, "tele": 37, "hit": 38, "recover": 41},
	AttackType.LEAP: {"start": 42, "tele": 42, "hit": 46, "recover": 47},
}

const COL_HURT_START: int = 48
const COL_HURT_COUNT: int = 4

const COL_DEATH_START: int = 52
const COL_DEATH_COUNT: int = 8
const COL_DEATH_FINAL: int = 59

const FLASH_HURT := Color(3.0, 3.0, 3.0)
const FLASH_WINDUP := Color(1.8, 0.65, 0.6)

@export var enemy_id: StringName = &"boss_minotaur"
@export var display_name: String = "มิโนทอร์"
@export var defense: int = 2
@export var poise: float = 60.0

@export_group("Movement")
@export var walk_speed: float = 58.0
@export var knockback_friction: float = 900.0

@export_group("Ranges")
@export var near_attack_range: float = 70.0
@export var mid_attack_range: float = 110.0
@export var far_attack_range: float = 240.0

@export_group("Attack Windup Times")
@export var cleave_windup: float = 0.65
@export var sweep_windup: float = 0.60
@export var rising_windup: float = 0.55
@export var charge_windup: float = 0.75
@export var stomp_windup: float = 0.65
@export var leap_windup: float = 0.80

@export_group("Attack Active Times")
@export var melee_active_time: float = 0.22
@export var charge_duration: float = 0.60
@export var stomp_active_time: float = 0.25
@export var leap_time: float = 0.35
@export var leap_active_time: float = 0.25

@export_group("Attack Recover Times")
@export var recover_time: float = 0.45
@export var charge_recover: float = 0.50
@export var leap_recover: float = 0.50

@export_group("Cleave Attack")
@export var cleave_damage: int = 15
@export var cleave_knockback: float = 240.0
@export var cleave_stagger: float = 30.0

@export_group("Sweep Attack")
@export var sweep_damage: int = 12
@export var sweep_knockback: float = 280.0
@export var sweep_stagger: float = 25.0

@export_group("Rising Attack")
@export var rising_damage: int = 14
@export var rising_knockback: float = 220.0
@export var rising_stagger: float = 35.0

@export_group("Charge Attack")
@export var charge_speed: float = 340.0
@export var charge_damage: int = 18
@export var charge_knockback: float = 360.0
@export var charge_stagger: float = 50.0

@export_group("Stomp Attack")
@export var stomp_damage: int = 16
@export var stomp_knockback: float = 300.0
@export var stomp_stagger: float = 45.0
@export var stomp_radius: float = 120.0

@export_group("Leap Attack")
@export var leap_damage: int = 22
@export var leap_knockback: float = 340.0
@export var leap_stagger: float = 60.0
@export var leap_radius: float = 52.0
@export var leap_height: float = 24.0

@export_group("Phases & Timing")
@export var phase_2_windup_multiplier: float = 0.75
@export var attack_cooldown: float = 0.4
@export var hurt_time: float = 0.35
@export var corpse_time: float = 2.0

var state: State = State.IDLE
var target: Node2D = null
var current_attack: AttackType = AttackType.CLEAVE
var is_attack_active: bool = false
var facing_dir: int = Dir8.SOUTH

var last_attack: AttackType = AttackType.CLEAVE
var consecutive_attack_count: int = 0
var accumulated_stagger: float = 0.0

var _state_t: float = 0.0
var _attack_cooldown_t: float = 0.0
var _flash_t: float = 0.0
var _engaged_emitted: bool = false
var _died_emitted: bool = false
var _combo_pending: bool = false

var _charge_dir: Vector2 = Vector2.DOWN
var _leap_from: Vector2 = Vector2.ZERO
var _leap_to: Vector2 = Vector2.ZERO
var _attack_facing_vec: Vector2 = Vector2.DOWN

var sprite: Sprite2D
var health: Health
var hurtbox: Hurtbox
var hitbox: Hitbox
var hitbox_shape: CollisionShape2D
var detect: Area2D
var telegraph_marker: TelegraphMarker
var _hit_circle: CircleShape2D
var _hit_poly: ConvexPolygonShape2D


func _ready() -> void:
	setup()


func setup() -> void:
	sprite = $Sprite
	health = $Health
	hurtbox = $Hurtbox
	hitbox = $Hitbox
	hitbox_shape = $Hitbox/Shape
	detect = $Detect
	if has_node("TelegraphMarker"):
		telegraph_marker = $TelegraphMarker as TelegraphMarker
	elif telegraph_marker == null:
		telegraph_marker = TelegraphMarker.new()
		telegraph_marker.name = "TelegraphMarker"
		telegraph_marker.top_level = true
		telegraph_marker.z_index = -1
		telegraph_marker.visible = false
		add_child(telegraph_marker)

	if not is_inside_tree():
		health.reset()

	hitbox.source = self
	hitbox.team = Combat.Team.ENEMY
	hurtbox.team = Combat.Team.ENEMY

	_hit_circle = CircleShape2D.new()
	_hit_poly = ConvexPolygonShape2D.new()
	hitbox_shape.shape = _hit_circle

	if stomp_radius < mid_attack_range + 10.0:
		stomp_radius = mid_attack_range + 10.0
	var charge_hit_reach: float = 18.0 + 26.0
	if charge_speed * charge_duration + charge_hit_reach < far_attack_range:
		charge_speed = (far_attack_range - charge_hit_reach) / maxf(charge_duration, 0.01)

	hurtbox.hurt.connect(_on_hurt)
	health.died.connect(_on_died)

	detect.collision_layer = 0
	detect.collision_mask = Combat.LAYER_PLAYER
	detect.body_entered.connect(_on_body_entered)
	detect.body_exited.connect(_on_body_exited)

	_update_sprite_frame(COL_IDLE_START)


func is_phase_2() -> bool:
	if health == null:
		return false
	return float(health.hp) < float(health.max_hp) * 0.5


func get_windup_time(atk: AttackType) -> float:
	var base_w: float = 0.65
	match atk:
		AttackType.CLEAVE: base_w = cleave_windup
		AttackType.SWEEP: base_w = sweep_windup
		AttackType.RISING: base_w = rising_windup
		AttackType.CHARGE: base_w = charge_windup
		AttackType.STOMP: base_w = stomp_windup
		AttackType.LEAP: base_w = leap_windup
	if is_phase_2():
		return base_w * phase_2_windup_multiplier
	return base_w


func get_recover_time(atk: AttackType) -> float:
	match atk:
		AttackType.CHARGE: return charge_recover
		AttackType.LEAP: return leap_recover
		_: return recover_time


func get_attack_candidates(dist: float) -> Array[AttackType]:
	if dist <= near_attack_range:
		return [AttackType.CLEAVE, AttackType.SWEEP, AttackType.RISING]
	elif dist <= mid_attack_range:
		return [AttackType.STOMP]
	elif dist <= far_attack_range:
		return [AttackType.CHARGE, AttackType.LEAP]
	return []


func get_attack_reach(atk: AttackType) -> float:
	match atk:
		AttackType.CLEAVE:
			return 38.0 + 32.0
		AttackType.SWEEP:
			return 72.0
		AttackType.RISING:
			return 36.0 + 34.0
		AttackType.STOMP:
			return stomp_radius
		AttackType.CHARGE:
			return charge_speed * charge_duration + 18.0 + 26.0
		AttackType.LEAP:
			return far_attack_range + leap_radius
		_:
			return 0.0


func choose_attack(dist: float, record: bool = false) -> AttackType:
	var candidates: Array[AttackType] = get_attack_candidates(dist)
	if candidates.is_empty():
		candidates = [AttackType.CHARGE, AttackType.LEAP]

	var valid: Array[AttackType] = []
	for atk: AttackType in candidates:
		if not (atk == last_attack and consecutive_attack_count >= 2):
			valid.append(atk)

	if valid.is_empty():
		var all_atks: Array[AttackType] = [
			AttackType.CLEAVE, AttackType.SWEEP, AttackType.RISING,
			AttackType.CHARGE, AttackType.STOMP, AttackType.LEAP
		]
		for atk: AttackType in all_atks:
			if atk != last_attack and get_attack_reach(atk) >= dist:
				valid.append(atk)

		if valid.is_empty():
			for atk: AttackType in all_atks:
				if atk != last_attack:
					valid.append(atk)

	var chosen: AttackType = valid[randi() % valid.size()]
	if record:
		record_attack_chosen(chosen)
	return chosen


func record_attack_chosen(chosen: AttackType) -> void:
	if chosen == last_attack:
		consecutive_attack_count += 1
	else:
		last_attack = chosen
		consecutive_attack_count = 1


func start_attack(atk: AttackType) -> void:
	if state == State.DEAD:
		return
	record_attack_chosen(atk)
	current_attack = atk
	_enter(State.WINDUP)


func set_target(node: Node2D) -> void:
	target = node
	if target != null and not _engaged_emitted:
		_engaged_emitted = true
		EventBus.boss_engaged.emit(self, health, display_name)
	if state == State.IDLE and target != null:
		_enter(State.CHASE)


func _physics_process(delta: float) -> void:
	tick(delta)
	move_and_slide()


func tick(delta: float) -> void:
	_state_t += delta
	if _attack_cooldown_t > 0.0:
		_attack_cooldown_t -= delta

	match state:
		State.IDLE:
			velocity = Vector2.ZERO
			var idle_col: int = COL_IDLE_START + int(fmod(_state_t * 4.0, float(COL_IDLE_COUNT)))
			_update_sprite_frame(idle_col)
			if _has_target():
				_enter(State.CHASE)

		State.CHASE:
			_tick_chase(delta)

		State.WINDUP:
			velocity = Vector2.ZERO
			var windup_dur: float = get_windup_time(current_attack)
			if (current_attack == AttackType.LEAP or current_attack == AttackType.STOMP) and telegraph_marker:
				telegraph_marker.progress = _state_t / maxf(windup_dur, 0.001)
			if _state_t >= windup_dur:
				_enter(State.ACTIVE)

		State.ACTIVE:
			_tick_active(delta)

		State.RECOVER:
			velocity = Vector2.ZERO
			var rec_dur: float = get_recover_time(current_attack)
			if _state_t >= rec_dur:
				_on_recover_finished()

		State.HURT:
			velocity = velocity.move_toward(Vector2.ZERO, knockback_friction * delta)
			var hurt_idx: int = mini(int(_state_t * 10.0), COL_HURT_COUNT - 1)
			_update_sprite_frame(COL_HURT_START + hurt_idx)
			if _state_t >= hurt_time:
				_enter(State.CHASE if _has_target() else State.IDLE)

		State.DEAD:
			velocity = velocity.move_toward(Vector2.ZERO, knockback_friction * delta)
			var death_idx: int = mini(int(_state_t * 8.0), COL_DEATH_COUNT - 1)
			_update_sprite_frame(COL_DEATH_START + death_idx)
			var fade_t: float = _state_t - 1.0
			if fade_t > 0.0:
				var a: float = clampf(1.0 - fade_t / corpse_time, 0.0, 1.0)
				sprite.self_modulate = Color(1.0, 1.0, 1.0, a)
			if _state_t >= 1.0 + corpse_time:
				queue_free()


func _process(delta: float) -> void:
	_tick_flash(delta)
	queue_redraw()


func _draw() -> void:
	if state == State.DEAD and _state_t >= 1.0 + corpse_time:
		return
	draw_set_transform(Vector2(0, -1), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 24.0, Color(0, 0, 0, 0.4))


func _tick_chase(delta: float) -> void:
	if not _has_target():
		_enter(State.IDLE)
		return

	var to_target: Vector2 = target.global_position - global_position
	var dist: float = to_target.length()
	facing_dir = Dir8.from_vector_sticky(to_target, facing_dir)

	var walk_col: int = COL_WALK_START + int(fmod(_state_t * 10.0, float(COL_WALK_COUNT)))
	_update_sprite_frame(walk_col)

	if _attack_cooldown_t <= 0.0 and dist <= far_attack_range:
		var atk: AttackType = choose_attack(dist)
		start_attack(atk)
		return

	velocity = to_target.normalized() * walk_speed


func _tick_active(delta: float) -> void:
	match current_attack:
		AttackType.CHARGE:
			_setup_hitbox_for_attack(AttackType.CHARGE, _charge_dir)
			velocity = _charge_dir * charge_speed
			var hit_col: int = ATTACK_COLS[AttackType.CHARGE]["hit"]
			_update_sprite_frame(hit_col)
			if _state_t >= charge_duration:
				_enter(State.RECOVER)

		AttackType.LEAP:
			if _state_t < leap_time:
				var k: float = clampf(_state_t / leap_time, 0.0, 1.0)
				global_position = _leap_from.lerp(_leap_to, k)
				var arc: float = sin(k * PI) * leap_height
				sprite.offset = Vector2(0, -46.0 - arc)
				_update_sprite_frame(44)
			else:
				if not is_attack_active:
					is_attack_active = true
					_setup_hitbox_for_attack(AttackType.LEAP, _attack_facing_vec)
					hitbox.activate()
				global_position = _leap_to
				sprite.offset = Vector2(0, -46.0)
				_update_sprite_frame(ATTACK_COLS[AttackType.LEAP]["hit"])
				if _state_t >= leap_time + leap_active_time:
					_enter(State.RECOVER)

		AttackType.STOMP:
			var hit_col: int = ATTACK_COLS[AttackType.STOMP]["hit"]
			_update_sprite_frame(hit_col)
			if _state_t >= stomp_active_time:
				_enter(State.RECOVER)

		AttackType.CLEAVE, AttackType.SWEEP, AttackType.RISING:
			var hit_col: int = ATTACK_COLS[current_attack]["hit"]
			_update_sprite_frame(hit_col)
			if _state_t >= melee_active_time:
				_enter(State.RECOVER)


func _on_recover_finished() -> void:
	if is_phase_2() and current_attack == AttackType.CLEAVE and not _combo_pending:
		_combo_pending = true
		start_attack(AttackType.SWEEP)
		return

	_combo_pending = false
	_attack_cooldown_t = attack_cooldown
	_enter(State.CHASE if _has_target() else State.IDLE)


func _clamp_leap_position(target_pos: Vector2, from_pos: Vector2) -> Vector2:
	if not is_inside_tree():
		return target_pos
	var world_2d: World2D = get_world_2d()
	if world_2d == null:
		return target_pos
	var space_state: PhysicsDirectSpaceState2D = world_2d.direct_space_state
	if space_state == null:
		return target_pos

	var curr_pos: Vector2 = target_pos
	var to_boss: Vector2 = from_pos - curr_pos
	var total_dist: float = to_boss.length()
	if total_dist < 0.001:
		return target_pos

	var step_dir: Vector2 = to_boss / total_dist
	var max_steps: int = int(total_dist / 8.0)

	var query := PhysicsPointQueryParameters2D.new()
	query.collision_mask = Combat.LAYER_WORLD
	query.collide_with_bodies = true
	query.collide_with_areas = false

	for _i: int in max_steps:
		query.position = curr_pos
		var hits: Array[Dictionary] = space_state.intersect_point(query, 1)
		if hits.is_empty():
			break
		curr_pos += step_dir * 8.0

	return curr_pos


func _setup_hitbox_for_attack(atk: AttackType, facing: Vector2) -> void:
	if hitbox == null or hitbox_shape == null:
		return
	var marker_squash: float = telegraph_marker.squash if telegraph_marker != null else 0.55
	match atk:
		AttackType.CLEAVE:
			hitbox_shape.shape = _hit_circle
			hitbox_shape.scale = Vector2.ONE
			hitbox.damage = cleave_damage
			hitbox.knockback_force = cleave_knockback
			hitbox.stagger = cleave_stagger
			hitbox_shape.position = facing * 38.0 + Vector2(0, -12)
			_hit_circle.radius = 32.0
		AttackType.SWEEP:
			hitbox_shape.shape = _hit_poly
			hitbox_shape.scale = Vector2.ONE
			hitbox.damage = sweep_damage
			hitbox.knockback_force = sweep_knockback
			hitbox.stagger = sweep_stagger
			hitbox_shape.position = Vector2(0, -12)
			var base_angle: float = facing.angle()
			var sweep_pts := PackedVector2Array()
			sweep_pts.append(Vector2.ZERO)
			const SEGMENTS: int = 12
			for i in range(SEGMENTS + 1):
				var a: float = base_angle - PI * 0.5 + (float(i) / float(SEGMENTS)) * PI
				sweep_pts.append(Vector2.from_angle(a) * 72.0)
			_hit_poly.points = Geometry2D.convex_hull(sweep_pts)
		AttackType.RISING:
			hitbox_shape.shape = _hit_circle
			hitbox_shape.scale = Vector2.ONE
			hitbox.damage = rising_damage
			hitbox.knockback_force = rising_knockback
			hitbox.stagger = rising_stagger
			hitbox_shape.position = facing * 36.0 + Vector2(0, -14)
			_hit_circle.radius = 34.0
		AttackType.CHARGE:
			hitbox_shape.shape = _hit_circle
			hitbox_shape.scale = Vector2.ONE
			hitbox.damage = charge_damage
			hitbox.knockback_force = charge_knockback
			hitbox.stagger = charge_stagger
			hitbox_shape.position = facing * 18.0 + Vector2(0, -14)
			_hit_circle.radius = 26.0
		AttackType.STOMP:
			hitbox_shape.shape = _hit_circle
			hitbox_shape.scale = Vector2(1.0, marker_squash)
			hitbox.damage = stomp_damage
			hitbox.knockback_force = stomp_knockback
			hitbox.stagger = stomp_stagger
			hitbox_shape.position = Vector2(0, -6)
			_hit_circle.radius = stomp_radius
		AttackType.LEAP:
			hitbox_shape.shape = _hit_circle
			hitbox_shape.scale = Vector2(1.0, marker_squash)
			hitbox.damage = leap_damage
			hitbox.knockback_force = leap_knockback
			hitbox.stagger = leap_stagger
			hitbox_shape.position = Vector2(0, -6)
			_hit_circle.radius = leap_radius


func _enter(next: State) -> void:
	var prev: State = state
	if prev == State.DEAD:
		return

	if prev == State.ACTIVE or next != State.ACTIVE:
		is_attack_active = false
		hitbox.deactivate()

	if prev == State.WINDUP:
		sprite.self_modulate = Color.WHITE

	state = next
	_state_t = 0.0

	match next:
		State.IDLE:
			velocity = Vector2.ZERO
			_update_sprite_frame(COL_IDLE_START)

		State.CHASE:
			_update_sprite_frame(COL_WALK_START)

		State.WINDUP:
			velocity = Vector2.ZERO
			is_attack_active = false
			hitbox.deactivate()
			if _has_target():
				var to_t: Vector2 = target.global_position - global_position
				if to_t.length_squared() > 0.01:
					_attack_facing_vec = to_t.normalized()
					facing_dir = Dir8.from_vector(_attack_facing_vec, facing_dir)
			else:
				_attack_facing_vec = Dir8.to_vector(facing_dir)

			if current_attack == AttackType.CHARGE:
				_charge_dir = _attack_facing_vec
			elif current_attack == AttackType.LEAP:
				_leap_from = global_position
				var max_leap_dist: float = far_attack_range
				if _has_target():
					var offset: Vector2 = target.global_position - global_position
					if offset.length() > max_leap_dist:
						offset = offset.normalized() * max_leap_dist
					_leap_to = global_position + offset
				else:
					_leap_to = global_position + _attack_facing_vec * (near_attack_range * 1.5)
				_leap_to = _clamp_leap_position(_leap_to, _leap_from)
				if telegraph_marker:
					telegraph_marker.radius = leap_radius
					telegraph_marker.show_at(_leap_to)
			elif current_attack == AttackType.STOMP:
				if telegraph_marker:
					telegraph_marker.radius = stomp_radius
					telegraph_marker.show_at(global_position)

			var tele_col: int = ATTACK_COLS[current_attack]["tele"]
			_update_sprite_frame(tele_col)

		State.ACTIVE:
			if current_attack != AttackType.LEAP:
				is_attack_active = true
				_setup_hitbox_for_attack(current_attack, _attack_facing_vec)
				hitbox.activate()
			else:
				is_attack_active = false
				hitbox.deactivate()

			if current_attack == AttackType.CHARGE:
				velocity = _charge_dir * charge_speed
			else:
				velocity = Vector2.ZERO

			var hit_col: int = 44 if current_attack == AttackType.LEAP else ATTACK_COLS[current_attack]["hit"]
			_update_sprite_frame(hit_col)

		State.RECOVER:
			velocity = Vector2.ZERO
			is_attack_active = false
			hitbox.deactivate()
			if telegraph_marker:
				telegraph_marker.visible = false
			sprite.offset = Vector2(0, -46)
			var rec_col: int = ATTACK_COLS[current_attack]["recover"]
			_update_sprite_frame(rec_col)

		State.HURT:
			velocity = Vector2.ZERO
			is_attack_active = false
			hitbox.deactivate()
			if telegraph_marker:
				telegraph_marker.visible = false
			sprite.offset = Vector2(0, -46)
			_combo_pending = false
			_update_sprite_frame(COL_HURT_START)

		State.DEAD:
			velocity = Vector2.ZERO
			is_attack_active = false
			hitbox.deactivate()
			if telegraph_marker:
				telegraph_marker.visible = false
			sprite.offset = Vector2(0, -46)
			_combo_pending = false
			hurtbox.set_deferred(&"monitorable", false)
			set_deferred(&"collision_layer", 0)
			if not _died_emitted:
				_died_emitted = true
				EventBus.enemy_died.emit(self, enemy_id, global_position)
			_update_sprite_frame(COL_DEATH_START)


func _on_hurt(info: DamageInfo) -> void:
	if state == State.DEAD:
		return

	var dealt: int = health.take_damage(maxi(1, info.amount - defense))
	EventBus.damage_dealt.emit(self, info, dealt)
	_flash_t = 0.08

	if health.is_dead:
		_on_died()
		return

	accumulated_stagger += info.stagger
	if accumulated_stagger >= poise:
		accumulated_stagger = 0.0
		_enter(State.HURT)
		velocity = info.knockback * 0.5


func _on_died() -> void:
	_enter(State.DEAD)


func _on_body_entered(body: Node2D) -> void:
	if target == null:
		set_target(body)


func _on_body_exited(body: Node2D) -> void:
	if body == target:
		target = null


func _has_target() -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if is_inside_tree() and not target.is_inside_tree():
		return false
	return true


func _update_sprite_frame(col: int) -> void:
	if sprite == null:
		return
	var dir: int = clampi(facing_dir, 0, Dir8.COUNT - 1)
	sprite.frame = dir * COLS_PER_ROW + col


func _tick_flash(delta: float) -> void:
	if sprite == null:
		return
	if _flash_t > 0.0:
		_flash_t -= delta
		sprite.self_modulate = FLASH_HURT
	elif state == State.WINDUP:
		var k: float = _state_t / maxf(get_windup_time(current_attack), 0.001)
		var pulse: float = 0.5 + 0.5 * sin(_state_t * lerpf(12.0, 28.0, k))
		sprite.self_modulate = Color.WHITE.lerp(FLASH_WINDUP, pulse)
	elif state != State.DEAD:
		sprite.self_modulate = Color.WHITE
