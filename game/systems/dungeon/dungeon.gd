class_name Dungeon
extends Node2D
## ระบบจัดการดันเจี้ยน isometric — ต่อห้อง, ผู้เล่นเดินข้ามเองเมื่อประตูเปิด, รีเซ็ตเมื่อตาย
## contract: docs/contracts/dungeon-flow.md

signal room_changed(from_index: int, to_index: int, new_room: Room)
signal dungeon_reset
signal dungeon_completed
signal run_completed

@export var rooms: Array[Room] = []
@export var respawn_delay: float = 1.2

var current_room_index: int = 0
var _respawn_timer: Timer = null
var _timer_running: bool = false
var _respawning: bool = false


func _ready() -> void:
	setup()


func _exit_tree() -> void:
	_cleanup_event_bus()
	_timer_running = false
	if _respawn_timer != null and is_instance_valid(_respawn_timer):
		_respawn_timer.stop()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_cleanup_event_bus()
		_timer_running = false
		if _respawn_timer != null and is_instance_valid(_respawn_timer):
			_respawn_timer.stop()


func _cleanup_event_bus() -> void:
	if EventBus != null and is_instance_valid(EventBus):
		if EventBus.player_died.is_connected(_on_player_died):
			EventBus.player_died.disconnect(_on_player_died)
		if EventBus.player_respawn_requested.is_connected(_on_player_respawn_requested):
			EventBus.player_respawn_requested.disconnect(_on_player_respawn_requested)


func setup() -> void:
	add_to_group(&"respawn_handler")
	
	if rooms.is_empty():
		for child: Node in get_children():
			if child is Room:
				rooms.append(child)
	
	for i in range(rooms.size()):
		var r: Room = rooms[i]
		r.setup()
		if not r.door_entered.is_connected(_on_room_door_entered):
			r.door_entered.connect(_on_room_door_entered)
		if not r.room_started.is_connected(_on_room_started):
			r.room_started.connect(_on_room_started)
		if not r.run_completed.is_connected(_on_room_run_completed):
			r.run_completed.connect(_on_room_run_completed)
	
	if EventBus != null and is_instance_valid(EventBus):
		if not EventBus.player_died.is_connected(_on_player_died):
			EventBus.player_died.connect(_on_player_died)
		if not EventBus.player_respawn_requested.is_connected(_on_player_respawn_requested):
			EventBus.player_respawn_requested.connect(_on_player_respawn_requested)
	
	if _respawn_timer == null:
		_respawn_timer = get_node_or_null("RespawnTimer") as Timer
		if _respawn_timer == null:
			_respawn_timer = Timer.new()
			_respawn_timer.name = "RespawnTimer"
			_respawn_timer.one_shot = true
			add_child(_respawn_timer)
		if not _respawn_timer.timeout.is_connected(_on_respawn_timer_timeout):
			_respawn_timer.timeout.connect(_on_respawn_timer_timeout)
	
	current_room_index = 0


func get_current_room() -> Room:
	if current_room_index >= 0 and current_room_index < rooms.size():
		return rooms[current_room_index]
	return null


func is_respawn_timer_running() -> bool:
	if _respawn_timer != null and not _respawn_timer.is_stopped():
		return true
	return _timer_running


func reset_dungeon() -> void:
	_timer_running = false
	if _respawn_timer != null and is_instance_valid(_respawn_timer) and not _respawn_timer.is_stopped():
		_respawn_timer.stop()
	for r: Room in rooms:
		r.reset_room()
	current_room_index = 0
	dungeon_reset.emit()


func _on_player_died() -> void:
	if respawn_delay > 0.0 and _respawn_timer != null:
		_timer_running = true
		_respawn_timer.wait_time = respawn_delay
		if is_inside_tree():
			_respawn_timer.start(respawn_delay)
	else:
		_do_respawn.call_deferred()


func _on_respawn_timer_timeout() -> void:
	_timer_running = false
	_do_respawn()


func _do_respawn() -> void:
	reset_dungeon()
	var spawn_pos: Vector2 = Vector2.ZERO
	if not rooms.is_empty() and rooms[0].player_spawn_point != null:
		spawn_pos = rooms[0].player_spawn_point.global_position
	_respawning = true
	EventBus.player_respawn_requested.emit(spawn_pos)
	_respawning = false
	_start_room_at.call_deferred(spawn_pos)


## หลังฟื้น: เริ่มเฉพาะห้องที่มีจุดฟื้น (เช็คจากตำแหน่ง ไม่ใช้ overlap cache ที่ยังเป็นของห้องเดิม) — ห้องอื่นห้ามเริ่มเอง
func _start_room_at(world_pos: Vector2) -> void:
	var r: Room = room_at(world_pos)
	if r != null and r.state == Room.State.IDLE:
		r.start_room()


func room_at(world_pos: Vector2) -> Room:
	for r: Room in rooms:
		if r.is_point_inside_detector(world_pos):
			return r
	return null


## ฟื้นที่ไม่ได้มาจากความตาย (พักศาลเจ้า) → ส่ง room_started ของห้องปัจจุบันซ้ำให้กล้องได้ขอบคืน (ไม่ reset ห้อง)
func _on_player_respawn_requested(world_pos: Vector2) -> void:
	if _respawning:
		return
	var r: Room = room_at(world_pos)
	if r != null and rooms.find(r) == current_room_index and r.state != Room.State.IDLE:
		EventBus.room_started.emit(r, r.get_room_rect())


func _on_room_started(room: Room) -> void:
	var idx: int = rooms.find(room)
	if idx != -1 and idx != current_room_index:
		var prev_index: int = current_room_index
		current_room_index = idx
		room_changed.emit(prev_index, current_room_index, room)


func _on_room_door_entered(room: Room, door: Door) -> void:
	if rooms.is_empty():
		return
	if room == rooms.back() and door != null and door.door_name == &"exit":
		run_completed.emit()
		dungeon_completed.emit()


func _on_room_run_completed(_room: Room) -> void:
	run_completed.emit()
	dungeon_completed.emit()


func tick(_delta: float) -> void:
	pass
