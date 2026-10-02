class_name Room
extends Node2D
## ห้องดันเจี้ยน isometric — จัดการสถานะห้อง IDLE -> LOCKED -> CLEARED
## ควบคุมประตู, spawn ศัตรู, และนับ EventBus.enemy_died เฉพาะตัวของห้องนี้

signal room_started(room: Room)
signal room_cleared(room: Room)
signal door_entered(room: Room, door: Door)

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
var player_detector: Area2D
var doors_container: Node2D
var spawn_points_container: Node2D
var enemy_container: Node2D
var player_spawn_point: Marker2D


func _ready() -> void:
	setup()


func _exit_tree() -> void:
	_cleanup_event_bus()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_cleanup_event_bus()


func _cleanup_event_bus() -> void:
	if EventBus != null and is_instance_valid(EventBus) and EventBus.enemy_died.is_connected(_on_enemy_died):
		EventBus.enemy_died.disconnect(_on_enemy_died)


func setup() -> void:
	floor_layer = get_node_or_null("FloorLayer") as TileMapLayer
	wall_layer = get_node_or_null("WallLayer") as TileMapLayer
	player_detector = get_node_or_null("PlayerDetector") as Area2D
	doors_container = get_node_or_null("Doors") as Node2D
	spawn_points_container = get_node_or_null("SpawnPoints") as Node2D
	enemy_container = get_node_or_null("EnemyContainer") as Node2D
	player_spawn_point = get_node_or_null("PlayerSpawnPoint") as Marker2D
	
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


func start_room() -> void:
	if state != State.IDLE:
		return
	
	var spawns: Array[Marker2D] = get_spawn_points()
	if spawns.is_empty() and spawned_enemies.is_empty():
		# ห้องที่ไม่มีศัตรู clear ทันที
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
	if enemy in spawned_enemies:
		spawned_enemies.erase(enemy)
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
	state = State.CLEARED
	open_all_doors()
	room_cleared.emit(self)


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


func _on_player_detector_body_entered(body: Node2D) -> void:
	if not auto_start_on_player_enter:
		return
	if state == State.IDLE and (body.is_in_group(&"player") or (body.collision_layer & Combat.LAYER_PLAYER) != 0):
		start_room.call_deferred()


func _on_door_entered(door: Door) -> void:
	door_entered.emit(self, door)
