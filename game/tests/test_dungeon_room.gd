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
	# Wall tile 1x2 at (0, 1) has texture_origin (0, -16)
	var td_wall: TileData = src.get_tile_data(Vector2i(0, 1), 0)
	ok = ok and td_wall != null and td_wall.texture_origin == Vector2i(0, -16)
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


func test_dungeon_room_sequence_and_order() -> bool:
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
	
	# เดินผ่านประตูย้ายไปห้อง 2
	dungeon.transition_to_room(1)
	ok = ok and dungeon.current_room_index == 1 and dungeon.get_current_room() == dungeon.rooms[1]
	
	# เดินผ่านประตูย้ายไปห้อง 3
	dungeon.transition_to_room(2)
	ok = ok and dungeon.current_room_index == 2 and dungeon.get_current_room() == dungeon.rooms[2]
	
	_safe_free(dungeon)
	return ok


func test_player_died_resets_dungeon_to_room_one() -> bool:
	var dungeon: Dungeon = DUNGEON_SCENE.instantiate()
	dungeon.setup()
	
	dungeon.transition_to_room(2) # อยู่ห้อง 3
	var in_room_3: bool = dungeon.current_room_index == 2
	
	EventBus.player_died.emit()
	var reset_to_1: bool = dungeon.current_room_index == 0 and dungeon.get_current_room() == dungeon.rooms[0]
	
	_safe_free(dungeon)
	return in_room_3 and reset_to_1


static func _safe_free(node: Node) -> void:
	if node != null:
		node.free()
