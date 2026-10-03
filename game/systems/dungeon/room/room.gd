class_name Room
extends Node2D
## ห้องดันเจี้ยน isometric — จัดการสถานะห้อง IDLE -> LOCKED -> CLEARED
## ควบคุมประตู, spawn ศัตรู, และนับ EventBus.enemy_died เฉพาะตัวของห้องนี้

signal room_started(room: Room)
signal room_cleared(room: Room)
signal door_entered(room: Room, door: Door)
signal run_completed(room: Room)

enum State { IDLE, LOCKED, CLEARED }

@export var room_id: StringName = &"room"
@export var enemy_scene: PackedScene = preload("res://systems/enemy/slime/slime.tscn")
@export var auto_start_on_player_enter: bool = true

var state: State = State.IDLE
var spawned_enemies: Array[Node] = []
var total_enemies: int = 0
var enemies_killed: int = 0
var doors: Array[Door] = []

var floor_layer: TileMapLayer
var wall_layer: TileMapLayer
var _run_completed_emitted: bool = false
var player_detector: Area2D
var doors_container: Node2D
var spawn_points_container: Node2D
var enemy_container: Node2D
var player_spawn_point: Marker2D
var run_complete_trigger: Area2D


var _is_teardown: bool = false
var _was_in_tree: bool = false


func _enter_tree() -> void:
	_was_in_tree = true


func _ready() -> void:
	setup()


func _exit_tree() -> void:
	_is_teardown = true
	_cleanup_event_bus()
	_disconnect_enemies()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_is_teardown = true
		_cleanup_event_bus()
		_disconnect_enemies()


func _cleanup_event_bus() -> void:
	if EventBus != null and is_instance_valid(EventBus) and EventBus.enemy_died.is_connected(_on_enemy_died):
		EventBus.enemy_died.disconnect(_on_enemy_died)


func _disconnect_enemies() -> void:
	for enemy: Node in spawned_enemies:
		if is_instance_valid(enemy) and enemy.tree_exiting.is_connected(_on_enemy_tree_exiting):
			enemy.tree_exiting.disconnect(_on_enemy_tree_exiting)


func setup() -> void:
	floor_layer = get_node_or_null("FloorLayer") as TileMapLayer
	wall_layer = get_node_or_null("WallLayer") as TileMapLayer
	player_detector = get_node_or_null("PlayerDetector") as Area2D
	doors_container = get_node_or_null("Doors") as Node2D
	spawn_points_container = get_node_or_null("SpawnPoints") as Node2D
	enemy_container = get_node_or_null("EnemyContainer") as Node2D
	player_spawn_point = get_node_or_null("PlayerSpawnPoint") as Marker2D
	run_complete_trigger = get_node_or_null("RunCompleteTrigger") as Area2D
	if run_complete_trigger == null:
		run_complete_trigger = get_node_or_null("ExitTrigger") as Area2D
	if run_complete_trigger != null:
		run_complete_trigger.collision_layer = 0
		run_complete_trigger.collision_mask = Combat.LAYER_PLAYER
		if not run_complete_trigger.body_entered.is_connected(_on_run_complete_trigger_body_entered):
			run_complete_trigger.body_entered.connect(_on_run_complete_trigger_body_entered)
	
	if player_detector != null:
		player_detector.collision_layer = 0
		player_detector.collision_mask = Combat.LAYER_PLAYER
		if not player_detector.body_entered.is_connected(_on_player_detector_body_entered):
			player_detector.body_entered.connect(_on_player_detector_body_entered)
	
	_refresh_doors()
	
	if EventBus != null and is_instance_valid(EventBus):
		if not EventBus.enemy_died.is_connected(_on_enemy_died):
			EventBus.enemy_died.connect(_on_enemy_died)
	
	match state:
		State.IDLE:
			open_all_doors()
		State.LOCKED:
			close_all_doors()
		State.CLEARED:
			open_all_doors()


func _refresh_doors() -> void:
	doors.clear()
	if doors_container != null:
		for child: Node in doors_container.get_children():
			if child is Door:
				doors.append(child)
				child.setup()
				if not child.entered.is_connected(_on_door_entered):
					child.entered.connect(_on_door_entered)


func get_spawn_points() -> Array[Marker2D]:
	var result: Array[Marker2D] = []
	if spawn_points_container != null:
		for child: Node in spawn_points_container.get_children():
			if child is Marker2D:
				result.append(child)
	return result


func get_room_rect() -> Rect2:
	if floor_layer == null:
		return Rect2(global_position, Vector2.ZERO)
	var used_rect: Rect2i = floor_layer.get_used_rect()
	if used_rect.size == Vector2i.ZERO:
		return Rect2(global_position, Vector2.ZERO)
	
	var half_w: float = 32.0
	var half_h: float = 16.0
	if floor_layer.tile_set != null:
		half_w = floor_layer.tile_set.tile_size.x * 0.5
		half_h = floor_layer.tile_set.tile_size.y * 0.5
	
	var min_cell := used_rect.position
	var max_cell := used_rect.position + used_rect.size - Vector2i(1, 1)
	
	var corner_cells: Array[Vector2i] = [
		Vector2i(min_cell.x, min_cell.y),
		Vector2i(max_cell.x, min_cell.y),
		Vector2i(min_cell.x, max_cell.y),
		Vector2i(max_cell.x, max_cell.y),
	]
	
	var min_x: float = INF
	var max_x: float = -INF
	var min_y: float = INF
	var max_y: float = -INF
	
	for cell: Vector2i in corner_cells:
		var local_center: Vector2 = floor_layer.map_to_local(cell)
		var vertices: Array[Vector2] = [
			local_center + Vector2(0.0, -half_h),
			local_center + Vector2(half_w, 0.0),
			local_center + Vector2(0.0, half_h),
			local_center + Vector2(-half_w, 0.0),
		]
		for v: Vector2 in vertices:
			var g: Vector2 = floor_layer.to_global(v)
			min_x = minf(min_x, g.x)
			max_x = maxf(max_x, g.x)
			min_y = minf(min_y, g.y)
			max_y = maxf(max_y, g.y)
	
	return Rect2(min_x, min_y, max_x - min_x, max_y - min_y)


func start_room() -> void:
	if state == State.LOCKED:
		return
	
	var rect: Rect2 = get_room_rect()
	
	# ห้องที่เคลียร์แล้ว: ส่ง room_started แล้ว room_cleared ทันที ไม่ปิดประตู (ตาม contract v1.1)
	if state == State.CLEARED:
		room_started.emit(self)
		if EventBus != null and is_instance_valid(EventBus):
			EventBus.room_started.emit(self, rect)
			EventBus.room_cleared.emit(self)
		room_cleared.emit(self)
		return
	
	var spawns: Array[Marker2D] = get_spawn_points()
	if spawns.is_empty() and spawned_enemies.is_empty():
		# ห้องที่ไม่มีศัตรู = เริ่มแล้ว clear ทันที (emit ทั้งคู่ ไม่ปิดประตู)
		state = State.LOCKED
		room_started.emit(self)
		if EventBus != null and is_instance_valid(EventBus):
			EventBus.room_started.emit(self, rect)
		clear_room()
		return
	
	state = State.LOCKED
	close_all_doors()
	if not spawns.is_empty():
		spawn_enemies()
	else:
		total_enemies = spawned_enemies.size()
		enemies_killed = 0
	room_started.emit(self)
	if EventBus != null and is_instance_valid(EventBus):
		EventBus.room_started.emit(self, rect)


func spawn_enemies() -> void:
	var spawns: Array[Marker2D] = get_spawn_points()
	for marker: Marker2D in spawns:
		if enemy_scene == null:
			continue
		var enemy: Node = enemy_scene.instantiate()
		
		if enemy_container != null:
			enemy_container.add_child(enemy)
		else:
			add_child(enemy)
		
		if enemy is Node2D:
			(enemy as Node2D).global_position = marker.global_position
		
		register_enemy(enemy)
	
	total_enemies = spawned_enemies.size()
	enemies_killed = 0
	
	if spawned_enemies.is_empty():
		clear_room()


func register_enemy(enemy: Node) -> void:
	if not (enemy in spawned_enemies):
		spawned_enemies.append(enemy)
		total_enemies = spawned_enemies.size()
		if not enemy.tree_exiting.is_connected(_on_enemy_tree_exiting):
			enemy.tree_exiting.connect(_on_enemy_tree_exiting.bind(enemy))


func _on_enemy_tree_exiting(enemy: Node) -> void:
	if _is_teardown or is_queued_for_deletion() or (_was_in_tree and not is_inside_tree()):
		return
	if enemy in spawned_enemies:
		spawned_enemies.erase(enemy)
	_check_clear_deferred.call_deferred()


func _check_clear_deferred() -> void:
	if _is_teardown or is_queued_for_deletion() or (_was_in_tree and not is_inside_tree()):
		return
	if state == State.LOCKED and spawned_enemies.is_empty():
		clear_room()


func _on_enemy_died(enemy: Node, _enemy_id: StringName, _pos: Vector2) -> void:
	if not (enemy in spawned_enemies):
		# ไม่นับศัตรูของห้องอื่น
		return
	
	spawned_enemies.erase(enemy)
	enemies_killed += 1
	
	if state == State.LOCKED and spawned_enemies.is_empty():
		clear_room()


func clear_room() -> void:
	if state == State.CLEARED:
		return
	state = State.CLEARED
	open_all_doors()
	room_cleared.emit(self)
	if EventBus != null and is_instance_valid(EventBus):
		EventBus.room_cleared.emit(self)


func reset_room() -> void:
	state = State.IDLE
	var to_free: Array[Node] = spawned_enemies.duplicate()
	spawned_enemies.clear()
	for enemy: Node in to_free:
		if is_instance_valid(enemy):
			enemy.queue_free()
	if enemy_container != null:
		for child: Node in enemy_container.get_children():
			if is_instance_valid(child):
				child.queue_free()
	enemies_killed = 0
	total_enemies = 0
	open_all_doors()


func open_all_doors() -> void:
	for door: Door in doors:
		door.open_door()


func close_all_doors() -> void:
	for door: Door in doors:
		door.close_door()


func is_cleared() -> bool:
	return state == State.CLEARED


func is_locked() -> bool:
	return state == State.LOCKED


func get_remaining_enemies_count() -> int:
	return spawned_enemies.size()


func tick(_delta: float) -> void:
	# Deterministic tick logic if needed
	pass


func _can_start_on_player_enter() -> bool:
	if not auto_start_on_player_enter:
		return false
	if state == State.IDLE:
		return true
	if state == State.CLEARED:
		var dungeon: Dungeon = get_parent() as Dungeon
		if dungeon != null:
			var idx: int = dungeon.rooms.find(self)
			return idx != -1 and idx != dungeon.current_room_index
	return false


func _on_player_detector_body_entered(body: Node2D) -> void:
	if not _can_start_on_player_enter():
		return
	if (body.is_in_group(&"player") or (body.collision_layer & Combat.LAYER_PLAYER) != 0):
		start_room.call_deferred()


## จบด่านครั้งเดียว และต้องเคลียร์ห้องนี้ก่อน (กันเดินแตะ trigger ตอนห้อง LOCKED)
func _on_run_complete_trigger_body_entered(body: Node2D) -> void:
	if _run_completed_emitted or state != State.CLEARED:
		return
	if body.is_in_group(&"player") or (body.collision_layer & Combat.LAYER_PLAYER) != 0:
		_run_completed_emitted = true
		run_completed.emit(self)


func _on_door_entered(door: Door) -> void:
	door_entered.emit(self, door)


func is_point_inside_detector(world_point: Vector2) -> bool:
	if player_detector == null:
		return false
	var col_poly: CollisionPolygon2D = player_detector.get_node_or_null("CollisionPolygon2D") as CollisionPolygon2D
	if col_poly == null:
		return false
	var local_pos: Vector2 = col_poly.to_local(world_point)
	return Geometry2D.is_point_in_polygon(local_pos, col_poly.polygon)


func check_player_inside(target: Node2D = null) -> void:
	if not _can_start_on_player_enter():
		return
	if player_detector != null:
		for body: Node2D in player_detector.get_overlapping_bodies():
			if body.is_in_group(&"player") or (body.collision_layer & Combat.LAYER_PLAYER) != 0:
				start_room()
				return
	if target != null and is_instance_valid(target):
		if (target.is_in_group(&"player") or (target.collision_layer & Combat.LAYER_PLAYER) != 0) and is_point_inside_detector(target.global_position):
			start_room()
			return
	if is_inside_tree():
		for p: Node in get_tree().get_nodes_in_group(&"player"):
			if p is Node2D and is_point_inside_detector((p as Node2D).global_position):
				start_room()
				return
