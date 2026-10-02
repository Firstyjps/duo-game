class_name Dungeon
extends Node2D
## ระบบจัดการดันเจี้ยน isometric — ต่อห้อง, ย้ายผู้เล่นเมื่อผ่านประตู, รีเซ็ตเมื่อตาย
## ฟัง EventBus.player_died เพื่อรีเซ็ตกลับห้องแรก

signal room_changed(from_index: int, to_index: int, new_room: Room)
signal dungeon_reset
signal dungeon_completed

@export var rooms: Array[Room] = []
@export var player: Node2D = null
@export var camera: GameCamera = null

var current_room_index: int = 0


func _ready() -> void:
	setup()


func _exit_tree() -> void:
	_cleanup_event_bus()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_cleanup_event_bus()


func _cleanup_event_bus() -> void:
	if EventBus != null and is_instance_valid(EventBus) and EventBus.player_died.is_connected(_on_player_died):
		EventBus.player_died.disconnect(_on_player_died)


func setup() -> void:
	if rooms.is_empty():
		for child: Node in get_children():
			if child is Room:
				rooms.append(child)
	
	for i in range(rooms.size()):
		var r: Room = rooms[i]
		r.setup()
		if not r.door_entered.is_connected(_on_room_door_entered):
			r.door_entered.connect(_on_room_door_entered)
	
	if EventBus != null and is_instance_valid(EventBus):
		if not EventBus.player_died.is_connected(_on_player_died):
			EventBus.player_died.connect(_on_player_died)
	
	current_room_index = 0
	if player != null:
		teleport_player_to_room(0)


func get_current_room() -> Room:
	if current_room_index >= 0 and current_room_index < rooms.size():
		return rooms[current_room_index]
	return null


func transition_to_room(target_index: int) -> void:
	if target_index < 0 or target_index >= rooms.size():
		return
	
	var prev_index: int = current_room_index
	current_room_index = target_index
	var new_room: Room = rooms[current_room_index]
	
	teleport_player_to_room(current_room_index)
	
	if camera != null and new_room != null:
		# กล้องตัดภาพ/เลื่อนไปตำแหน่งห้องใหม่
		var room_center: Vector2 = new_room.global_position + Vector2(32, 176)
		camera.global_position = room_center
	
	room_changed.emit(prev_index, current_room_index, new_room)


func teleport_player_to_room(room_idx: int) -> void:
	if player == null or room_idx < 0 or room_idx >= rooms.size():
		return
	var target_room: Room = rooms[room_idx]
	if target_room != null and target_room.player_spawn_point != null:
		player.global_position = target_room.player_spawn_point.global_position
		if player is CharacterBody2D:
			(player as CharacterBody2D).velocity = Vector2.ZERO


func reset_dungeon() -> void:
	for r: Room in rooms:
		r.reset_room()
	current_room_index = 0
	teleport_player_to_room(0)
	
	var first_room: Room = get_current_room()
	if camera != null and first_room != null:
		camera.global_position = first_room.global_position + Vector2(32, 176)
	
	dungeon_reset.emit()


func _on_player_died() -> void:
	reset_dungeon()


func _on_room_door_entered(room: Room, _door: Door) -> void:
	if room != get_current_room():
		return
	
	if current_room_index < rooms.size() - 1:
		transition_to_room(current_room_index + 1)
	else:
		dungeon_completed.emit()


func tick(_delta: float) -> void:
	pass
