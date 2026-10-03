class_name QaBot
extends Node2D
## QA Bot (เฟส 7 · #66) — บอททดสอบอัตโนมัติ ควบคุม Player ผ่าน Player.set_intent()
## พฤติกรรม:
## 1. หาศัตรูใกล้สุดผ่าน Area2D (mask LAYER_ENEMY / LAYER_HURTBOX) หรือ EventBus
## 2. เดินเข้าหา เล็ง ล็อคเป้า และโจมตีเมื่อเข้าระยะ
## 3. สุ่ม Dodge หรือ Parry เมื่อศัตรูอยู่ในระยะอันตราย (จำลองการรับมือท่าเตรียม/windup)
## 4. ดื่มขวดฟื้นพลังเมื่อ HP < 40% และมีขวดเหลือ
## 5. หากไม่มีศัตรู ให้เดินสุ่มสำรวจ
## 6. หากติดกำแพงนานผิดปกติ ให้สลับทิศทางเดิน

@export var detection_radius: float = 800.0
@export var attack_reach: float = 38.0
@export var danger_distance: float = 75.0
@export var react_min_time: float = 1.0
@export var react_max_time: float = 2.2
@export var dodge_chance: float = 0.5
@export var heal_threshold_pct: float = 0.4
@export var stuck_time_threshold: float = 0.4
@export var stuck_distance_threshold: float = 3.0
@export var wander_min_time: float = 1.5
@export var wander_max_time: float = 3.0

var player: Player
var detection_area: Area2D
var detection_shape: CollisionShape2D

var _current_target: Node2D = null
var _tracked_enemies: Array[Node2D] = []
var _react_timer: float = 1.0
var _wander_timer: float = 2.0
var _wander_dir: Vector2 = Vector2.RIGHT
var _stuck_timer: float = 0.0
var _last_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	if player == null:
		setup()


func _enter_tree() -> void:
	_connect_event_bus()


func _exit_tree() -> void:
	_disconnect_event_bus()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_disconnect_event_bus()


## กำหนด Player เป้าหมายและเตรียมคอมโพเนนต์ — แยกจาก _ready ให้เทสต์เรียกได้นอก tree
func setup(target_player: Player = null) -> void:
	if target_player != null:
		player = target_player
	elif get_parent() != null and "player" in get_parent() and get_parent().get("player") is Player:
		player = get_parent().get("player") as Player

	if player != null:
		player.manual_control = true
		_last_pos = player.global_position

	_ensure_detection_area()
	_react_timer = randf_range(react_min_time, react_max_time)
	_wander_timer = randf_range(wander_min_time, wander_max_time)
	_wander_dir = Vector2.from_angle(randf() * TAU)
	_connect_event_bus()


func _ensure_detection_area() -> void:
	if detection_area != null:
		return
	detection_area = Area2D.new()
	detection_area.name = "BotDetectionArea"
	detection_area.collision_layer = 0
	detection_area.collision_mask = Combat.LAYER_ENEMY | Combat.LAYER_HURTBOX
	detection_area.monitoring = true
	detection_area.monitorable = false

	detection_shape = CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = detection_radius
	detection_shape.shape = circle
	detection_area.add_child(detection_shape)
	add_child(detection_area)


func _connect_event_bus() -> void:
	if EventBus == null:
		return
	if not EventBus.enemy_died.is_connected(_on_enemy_died):
		EventBus.enemy_died.connect(_on_enemy_died)
	if not EventBus.boss_engaged.is_connected(_on_boss_engaged):
		EventBus.boss_engaged.connect(_on_boss_engaged)


func _disconnect_event_bus() -> void:
	if EventBus == null:
		return
	if EventBus.enemy_died.is_connected(_on_enemy_died):
		EventBus.enemy_died.disconnect(_on_enemy_died)
	if EventBus.boss_engaged.is_connected(_on_boss_engaged):
		EventBus.boss_engaged.disconnect(_on_boss_engaged)


func _on_enemy_died(enemy: Node, _enemy_id: StringName, _pos: Vector2) -> void:
	if enemy is Node2D:
		_tracked_enemies.erase(enemy as Node2D)
	if enemy == _current_target:
		_current_target = null


func _on_boss_engaged(boss: Node, _health: Health, _display_name: String) -> void:
	if boss is Node2D and not _tracked_enemies.has(boss as Node2D):
		_tracked_enemies.append(boss as Node2D)


func _physics_process(delta: float) -> void:
	tick(delta)


## ตรรกะบอท 1 เฟรม — แยกจาก _physics_process ให้เทสต์เรียกตรงได้แบบ deterministic
func tick(delta: float) -> void:
	if player == null or not is_instance_valid(player) or player.is_dead():
		return

	# บังคับ manual_control เพื่อไม่ให้อ่าน Input จริง
	player.manual_control = true

	if detection_area != null:
		detection_area.global_position = player.global_position

	var move_intent: Vector2 = Vector2.ZERO
	var aim_intent: Vector2 = player.aim
	var atk_intent: bool = false
	var ddg_intent: bool = false
	var pry_intent: bool = false
	var lck_intent: bool = false
	var hel_intent: bool = false

	# 1. ตรวจสอบเงื่อนไขดื่มขวด (HP < 40%)
	var hp_pct: float = 1.0
	if player.health != null and player.health.max_hp > 0:
		hp_pct = float(player.health.hp) / float(player.health.max_hp)

	if hp_pct < heal_threshold_pct and player.flasks > 0 and player.can_drink():
		hel_intent = true

	# 2. ค้นหาศัตรูที่ใกล้ที่สุด
	_current_target = find_closest_enemy()

	# 3. จัดการพฤติกรรมต่อสู้หรือเดินสุ่ม
	if _current_target != null:
		var to_enemy: Vector2 = _current_target.global_position - player.global_position
		var dist: float = to_enemy.length()
		var dir_to_enemy: Vector2 = to_enemy.normalized() if dist > 0.001 else Vector2.RIGHT

		aim_intent = dir_to_enemy

		# ล็อคเป้าหมายหากอยู่ในระยะ lock_range
		if not player.is_locked_on() or player.lock_target != _current_target:
			if dist <= player.lock_range:
				lck_intent = true

		# ตรวจสอบระยะอันตราย (จำลองการรับมือศัตรูง้างโจมตี)
		_react_timer -= delta
		if dist <= danger_distance and _react_timer <= 0.0:
			_react_timer = randf_range(react_min_time, react_max_time)
			if randf() < dodge_chance:
				ddg_intent = true
				var perp: Vector2 = Vector2(-dir_to_enemy.y, dir_to_enemy.x)
				if randf() < 0.5:
					perp = -perp
				move_intent = (perp * 0.6 - dir_to_enemy * 0.8).normalized()
			else:
				pry_intent = true

		# หากไม่ได้กำลัง dodge หรือ parry ให้เดินเข้าหาหรือฟัน
		if not ddg_intent and not pry_intent:
			if dist > attack_reach:
				move_intent = dir_to_enemy
			else:
				move_intent = Vector2.ZERO
				if player.state == Player.State.MOVE and player.stamina >= player.attack_cost:
					atk_intent = true
	else:
		# ไม่มีศัตรู → เดินสุ่ม
		_wander_timer -= delta
		if _wander_timer <= 0.0:
			_wander_timer = randf_range(wander_min_time, wander_max_time)
			_wander_dir = Vector2.from_angle(randf() * TAU)
		move_intent = _wander_dir
		aim_intent = _wander_dir

	# 4. ติดกำแพงนาน → เปลี่ยนทิศ
	if move_intent.length_squared() > 0.01:
		var moved_dist: float = player.global_position.distance_to(_last_pos)
		if moved_dist < stuck_distance_threshold:
			_stuck_timer += delta
			if _stuck_timer >= stuck_time_threshold:
				_stuck_timer = 0.0
				_wander_dir = Vector2.from_angle(randf() * TAU)
				_wander_timer = randf_range(wander_min_time, wander_max_time)
				move_intent = _wander_dir
				aim_intent = _wander_dir
		else:
			_stuck_timer = 0.0
	else:
		_stuck_timer = 0.0

	_last_pos = player.global_position

	# ส่ง intent ทั้งหมดเข้า Player
	player.set_intent(move_intent, aim_intent, atk_intent, ddg_intent, pry_intent, lck_intent, false, hel_intent)


## ค้นหาศัตรูที่ใกล้ที่สุดผ่าน Area2D / Group / Fallback
func find_closest_enemy() -> Node2D:
	if player == null or not is_instance_valid(player):
		return null

	var candidates: Array[Node2D] = []
	var seen: Dictionary = {}

	# 1. Physics Area2D ตรวจจับ bodies บน LAYER_ENEMY
	if detection_area != null and detection_area.is_inside_tree():
		for body: Node2D in detection_area.get_overlapping_bodies():
			if _is_valid_enemy(body) and not seen.has(body):
				seen[body] = true
				candidates.append(body)

		# ตรวจจับ Hurtbox บนฝั่ง ENEMY
		for area: Area2D in detection_area.get_overlapping_areas():
			if area is Hurtbox and (area as Hurtbox).team == Combat.Team.ENEMY and (area as Hurtbox).monitorable:
				var entity: Node2D = Player._resolve_target_entity(area)
				if _is_valid_enemy(entity) and not seen.has(entity):
					seen[entity] = true
					candidates.append(entity)

	# 2. ค้นหาจากกลุ่ม "enemy"
	if is_inside_tree():
		for node: Node in get_tree().get_nodes_in_group(&"enemy"):
			if node is Node2D and _is_valid_enemy(node as Node2D) and not seen.has(node):
				seen[node] = true
				candidates.append(node as Node2D)

	# 3. ศัตรูที่บันทึกไว้ผ่าน EventBus (เช่น บอส)
	for node: Node2D in _tracked_enemies:
		if _is_valid_enemy(node) and not seen.has(node):
			seen[node] = true
			candidates.append(node)

	# 4. Fallback สำหรับการเทสต์แบบ deterministic นอก SceneTree / จำลองเฟรมโดยตรง
	if candidates.is_empty() and get_parent() != null:
		var level_node: Node = null
		if "level" in get_parent() and get_parent().get("level") is Node:
			level_node = get_parent().get("level") as Node
		if level_node != null:
			for child: Node in level_node.get_children():
				if child is CollisionObject2D and ((child as CollisionObject2D).collision_layer & Combat.LAYER_ENEMY) != 0:
					if _is_valid_enemy(child as Node2D) and not seen.has(child):
						seen[child] = true
						candidates.append(child as Node2D)

	if candidates.is_empty():
		return null

	var closest: Node2D = null
	var min_dist_sq: float = INF
	var p_pos: Vector2 = player.global_position
	for c: Node2D in candidates:
		var d_sq: float = p_pos.distance_squared_to(c.global_position)
		if d_sq < min_dist_sq:
			min_dist_sq = d_sq
			closest = c

	return closest


static func _is_valid_enemy(node: Node2D) -> bool:
	if node == null or not is_instance_valid(node) or node.is_queued_for_deletion():
		return false
	if node.has_method("is_dead") and node.call("is_dead"):
		return false
	var health: Health = node.get_node_or_null("Health") as Health
	if health != null and health.hp <= 0:
		return false
	return true
