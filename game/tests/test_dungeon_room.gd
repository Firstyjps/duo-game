extends RefCounted
## ดันเจี้ยนและห้อง isometric — game/systems/dungeon/ · issue #39

const ROOM_SCENE: PackedScene = preload("res://systems/dungeon/room/room.tscn")
const DUNGEON_SCENE: PackedScene = preload("res://systems/dungeon/dungeon.tscn")
const TILESET: TileSet = preload("res://systems/dungeon/dungeon_tileset.tres")


func test_tileset_isometric_specs() -> bool:
	var ok: bool = TILESET != null
	ok = ok and TILESET.tile_shape == TileSet.TILE_SHAPE_ISOMETRIC
	ok = ok and TILESET.tile_layout == TileSet.TILE_LAYOUT_DIAMOND_DOWN
	ok = ok and TILESET.tile_size == Vector2i(64, 32)
	ok = ok and TILESET.get_physics_layer_collision_layer(0) == Combat.LAYER_WORLD
	
	var src: TileSetAtlasSource = TILESET.get_source(0) as TileSetAtlasSource
	ok = ok and src != null
	# Wall tile 1x2 at (0, 1) has texture_origin (0, 16)
	var td_wall: TileData = src.get_tile_data(Vector2i(0, 1), 0)
	ok = ok and td_wall != null and td_wall.texture_origin == Vector2i(0, 16)
	ok = ok and td_wall.get_collision_polygons_count(0) > 0
	return ok


const DOOR_SCENE: PackedScene = preload("res://systems/dungeon/room/door.tscn")


func test_door_collision_and_trigger_toggles() -> bool:
	var door: Door = DOOR_SCENE.instantiate()
	door.setup()
	
	# Close door: blocker enabled, trigger disabled
	door.close_door()
	var closed_ok: bool = (not door.blocker_shape.disabled) and (not door.exit_trigger.monitoring) and door.exit_shape.disabled
	
	# Open door: blocker disabled, trigger enabled
	door.open_door()
	var open_ok: bool = door.blocker_shape.disabled and door.exit_trigger.monitoring and (not door.exit_shape.disabled)
	
	_safe_free(door)
	return closed_ok and open_ok


func test_enemy_died_counts_only_spawned_enemies() -> bool:
	var room: Room = ROOM_SCENE.instantiate()
	room.setup()
	room.state = Room.State.LOCKED
	
	var e1: Node = Node.new()
	var e2: Node = Node.new()
	room.register_enemy(e1)
	room.register_enemy(e2)
	
	var other_enemy: Node = Node.new()
	
	# ศัตรูห้องอื่นตาย -> ไม่ลดจำนวนในห้องนี้
	EventBus.enemy_died.emit(other_enemy, &"slime", Vector2.ZERO)
	var ignore_other: bool = room.get_remaining_enemies_count() == 2 and room.enemies_killed == 0 \
		and room.state == Room.State.LOCKED
	
	# ศัตรูของห้องนี้ตาย -> นับลด
	EventBus.enemy_died.emit(e1, &"slime", Vector2.ZERO)
	var counted_first: bool = room.get_remaining_enemies_count() == 1 and room.enemies_killed == 1 \
		and room.state == Room.State.LOCKED
	
	# ศัตรูตัวสุดท้ายตาย -> ห้องเคลียร์
	EventBus.enemy_died.emit(e2, &"slime", Vector2.ZERO)
	var cleared: bool = room.get_remaining_enemies_count() == 0 and room.enemies_killed == 2 \
		and room.state == Room.State.CLEARED
	
	e1.free()
	e2.free()
	other_enemy.free()
	_safe_free(room)
	return ignore_other and counted_first and cleared


func test_doors_open_when_room_cleared() -> bool:
	var room: Room = ROOM_SCENE.instantiate()
	room.enemy_scene = null
	room.setup()
	
	var dummy_enemy: Node = Node.new()
	room.register_enemy(dummy_enemy)
	room.start_room()
	
	var locked_doors: bool = room.state == Room.State.LOCKED
	for d: Door in room.doors:
		locked_doors = locked_doors and (not d.is_open)
	
	EventBus.enemy_died.emit(dummy_enemy, &"slime", Vector2.ZERO)
	
	var cleared_doors: bool = room.state == Room.State.CLEARED
	for d: Door in room.doors:
		cleared_doors = cleared_doors and d.is_open
	
	dummy_enemy.free()
	_safe_free(room)
	return locked_doors and cleared_doors


func test_room_with_no_enemies_clears_immediately() -> bool:
	var room: Room = Room.new()
	var spawn_cont: Node2D = Node2D.new()
	spawn_cont.name = "SpawnPoints"
	room.add_child(spawn_cont)
	
	var doors_cont: Node2D = Node2D.new()
	doors_cont.name = "Doors"
	var door: Door = Door.new()
	doors_cont.add_child(door)
	room.add_child(doors_cont)
	
	room.setup()
	
	var cleared_events: Array[Room] = []
	room.room_cleared.connect(func(r: Room) -> void:
		cleared_events.append(r)
	)
	
	room.start_room()
	
	var ok: bool = room.state == Room.State.CLEARED and cleared_events.size() == 1 and door.is_open
	_safe_free(room)
	return ok


func test_spawn_enemies_in_offset_room_matches_marker_position() -> bool:
	var room: Room = ROOM_SCENE.instantiate()
	# ตั้งห้องที่ตำแหน่งห่างจาก origin (เช่น 1400, 300)
	room.position = Vector2(1400.0, 300.0)
	room.setup()
	
	var markers: Array[Marker2D] = room.get_spawn_points()
	var has_markers: bool = markers.size() == 2
	
	room.start_room()
	
	var count_ok: bool = room.spawned_enemies.size() == markers.size()
	var pos_ok: bool = true
	for i in range(markers.size()):
		var enemy: Node2D = room.spawned_enemies[i] as Node2D
		if enemy == null or enemy.global_position != markers[i].global_position:
			pos_ok = false
			break
	
	# ทำความสะอาดศัตรูก่อน free ห้อง
	for e: Node in room.spawned_enemies.duplicate():
		if is_instance_valid(e):
			e.free()
	room.spawned_enemies.clear()
	_safe_free(room)
	return has_markers and count_ok and pos_ok


func test_door_has_exact_children_count_no_duplicates() -> bool:
	# ตรวจสอบว่า door standalone มี 3 ลูก: Sprite2D, Blocker, ExitTrigger
	var door: Door = DOOR_SCENE.instantiate()
	door.setup()
	var standalone_ok: bool = door.get_child_count() == 3
	_safe_free(door)
	
	# ตรวจสอบว่า door ใน room.tscn ไม่มีลูกซ้ำ
	var room: Room = ROOM_SCENE.instantiate()
	room.setup()
	var room_door_ok: bool = room.doors.size() == 1 and room.doors[0].get_child_count() == 3
	_safe_free(room)
	
	# ตรวจสอบว่า door ใน dungeon.tscn ไม่มีลูกซ้ำ
	var dungeon: Dungeon = DUNGEON_SCENE.instantiate()
	dungeon.setup()
	var dungeon_door_ok: bool = true
	for r: Room in dungeon.rooms:
		if r.doors.is_empty() or r.doors[0].get_child_count() != 3:
			dungeon_door_ok = false
			break
	_safe_free(dungeon)
	
	return standalone_ok and room_door_ok and dungeon_door_ok


func test_enemy_freed_without_signal_clears_from_waiting_list() -> bool:
	var room: Room = Room.new()
	var enemy_cont: Node2D = Node2D.new()
	enemy_cont.name = "EnemyContainer"
	room.add_child(enemy_cont)
	
	var doors_cont: Node2D = Node2D.new()
	doors_cont.name = "Doors"
	var door: Door = Door.new()
	doors_cont.add_child(door)
	room.add_child(doors_cont)
	
	room.setup()
	room.state = Room.State.LOCKED
	
	var dummy: Node = Node.new()
	enemy_cont.add_child(dummy)
	room.register_enemy(dummy)
	
	var waiting_ok: bool = room.get_remaining_enemies_count() == 1 and room.state == Room.State.LOCKED
	
	# จำลอง node ออกจาก tree / ถูก free โดยไม่ emit EventBus.enemy_died
	dummy.tree_exiting.emit()
	dummy.free()
	
	# tree_exiting ดักจับและลบออกจาก spawned_enemies -> ห้องเคลียร์
	var cleared_ok: bool = room.get_remaining_enemies_count() == 0 and room.state == Room.State.CLEARED
	
	_safe_free(room)
	return waiting_ok and cleared_ok


func test_dungeon_room_sequence_via_door_entered() -> bool:
	var dungeon: Dungeon = DUNGEON_SCENE.instantiate()
	dungeon.setup()
	
	var ok: bool = dungeon.rooms.size() == 3
	ok = ok and dungeon.rooms[0].room_id == &"room_1"
	ok = ok and dungeon.rooms[1].room_id == &"room_2"
	ok = ok and dungeon.rooms[2].room_id == &"room_3"
	
	# ห้อง 1 มี 2 ตัว, ห้อง 2 มี 4 ตัว, ห้อง 3 ว่างไว้สำหรับบอส (0 ตัว)
	ok = ok and dungeon.rooms[0].get_spawn_points().size() == 2
	ok = ok and dungeon.rooms[1].get_spawn_points().size() == 4
	ok = ok and dungeon.rooms[2].get_spawn_points().size() == 0
	ok = ok and dungeon.current_room_index == 0
	
	var completed_called: Array[bool] = [false]
	dungeon.dungeon_completed.connect(func() -> void:
		completed_called[0] = true
	)
	
	# ห้อง 0 เข้าประตู -> ย้ายไปห้อง 1 ผ่าน signal door_entered
	var r0: Room = dungeon.rooms[0]
	r0.door_entered.emit(r0, r0.doors[0])
	ok = ok and dungeon.current_room_index == 1 and dungeon.get_current_room() == dungeon.rooms[1]
	
	# ห้อง 1 เข้าประตู -> ย้ายไปห้อง 2
	var r1: Room = dungeon.rooms[1]
	r1.door_entered.emit(r1, r1.doors[0])
	ok = ok and dungeon.current_room_index == 2 and dungeon.get_current_room() == dungeon.rooms[2]
	
	# ประตูจากห้องอื่นที่ไม่ใช่ current_room ต้องถูกเพิกเฉย
	r0.door_entered.emit(r0, r0.doors[0])
	ok = ok and dungeon.current_room_index == 2
	
	# ห้อง 2 (ห้องสุดท้าย) เข้าประตู -> dungeon_completed
	var r2: Room = dungeon.rooms[2]
	r2.door_entered.emit(r2, r2.doors[0])
	ok = ok and completed_called[0]
	
	_safe_free(dungeon)
	return ok


func test_player_died_resets_dungeon_and_rooms_to_idle() -> bool:
	var dungeon: Dungeon = DUNGEON_SCENE.instantiate()
	dungeon.setup()
	
	# ย้ายไปห้อง 2 และจำลองให้ห้อง 1 อยู่ในสถานะ LOCKED มีศัตรู
	dungeon.rooms[0].state = Room.State.LOCKED
	var dummy: Node = Node.new()
	dungeon.rooms[0].register_enemy(dummy)
	
	dungeon.transition_to_room(1)
	dungeon.rooms[1].state = Room.State.LOCKED
	
	var reset_signal_fired: Array[bool] = [false]
	var run_reset_requested_fired: Array[bool] = [false]
	dungeon.dungeon_reset.connect(func() -> void:
		reset_signal_fired[0] = true
	)
	dungeon.run_reset_requested.connect(func() -> void:
		run_reset_requested_fired[0] = true
	)
	
	# ผู้เล่นตาย
	EventBus.player_died.emit()
	
	var reset_idx: bool = dungeon.current_room_index == 0 and dungeon.get_current_room() == dungeon.rooms[0]
	var signals_ok: bool = reset_signal_fired[0] and run_reset_requested_fired[0]
	
	# ทุกห้องต้องกลับเป็น IDLE และศัตรูถูกลบ
	var rooms_idle: bool = true
	for r: Room in dungeon.rooms:
		if r.state != Room.State.IDLE or not r.spawned_enemies.is_empty():
			rooms_idle = false
			break
	
	if is_instance_valid(dummy):
		dummy.free()
	_safe_free(dungeon)
	return reset_idx and signals_ok and rooms_idle


static func _safe_free(node: Node) -> void:
	if node != null:
		node.free()
