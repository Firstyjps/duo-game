extends RefCounted
## ดันเจี้ยนและห้อง isometric — game/systems/dungeon/ · issue #39 & contract #52

const ROOM_SCENE: PackedScene = preload("res://systems/dungeon/room/room.tscn")
const DUNGEON_SCENE: PackedScene = preload("res://systems/dungeon/dungeon.tscn")
const TILESET: TileSet = preload("res://systems/dungeon/dungeon_tileset.tres")
const DOOR_SCENE: PackedScene = preload("res://systems/dungeon/room/door.tscn")


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
	
	var bus_started: Array = []
	var bus_cleared: Array = []
	var on_started := func(r: Node, rect: Rect2) -> void:
		bus_started.append([r, rect])
	var on_cleared := func(r: Node) -> void:
		bus_cleared.append(r)
	
	EventBus.room_started.connect(on_started)
	EventBus.room_cleared.connect(on_cleared)
	
	room.start_room()
	
	var both_emitted: bool = bus_started.size() == 1 and bus_cleared.size() == 1
	var order_ok: bool = bus_started[0][0] == room and bus_cleared[0] == room
	var state_ok: bool = room.state == Room.State.CLEARED and door.is_open
	
	EventBus.room_started.disconnect(on_started)
	EventBus.room_cleared.disconnect(on_cleared)
	
	_safe_free(room)
	return both_emitted and order_ok and state_ok


func test_spawn_enemies_in_offset_room_matches_marker_position() -> bool:
	var room: Room = ROOM_SCENE.instantiate()
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
	
	for e: Node in room.spawned_enemies.duplicate():
		if is_instance_valid(e):
			e.free()
	room.spawned_enemies.clear()
	_safe_free(room)
	return has_markers and count_ok and pos_ok


func test_door_has_exact_children_count_no_duplicates() -> bool:
	var door: Door = DOOR_SCENE.instantiate()
	door.setup()
	var standalone_ok: bool = door.get_child_count() == 3
	_safe_free(door)
	
	var room: Room = ROOM_SCENE.instantiate()
	room.setup()
	var room_door_ok: bool = room.doors.size() == 1 and room.doors[0].get_child_count() == 3
	_safe_free(room)
	
	var dungeon: Dungeon = DUNGEON_SCENE.instantiate()
	dungeon.setup()
	var dungeon_door_ok: bool = true
	for r: Room in dungeon.rooms:
		if r.doors.is_empty():
			dungeon_door_ok = false
			break
		for d: Door in r.doors:
			if d.get_child_count() != 3:
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
	
	# ประมวลผล deferred check
	room._check_clear_deferred()
	
	var cleared_ok: bool = room.get_remaining_enemies_count() == 0 and room.state == Room.State.CLEARED
	
	_safe_free(room)
	return waiting_ok and cleared_ok


func test_teardown_locked_room_does_not_emit_room_cleared() -> bool:
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
	
	var cleared_emitted: Array[bool] = [false]
	var on_cleared := func(_r: Variant = null) -> void:
		cleared_emitted[0] = true
	
	room.room_cleared.connect(on_cleared)
	EventBus.room_cleared.connect(on_cleared)
	
	# Free ห้องขณะ LOCKED มีศัตรูค้างอยู่
	room.free()
	if is_instance_valid(dummy):
		dummy.free()
	
	EventBus.room_cleared.disconnect(on_cleared)
	
	# ต้องไม่มีการ emit room_cleared ปลอมตอน teardown
	return cleared_emitted[0] == false


func test_room_started_and_cleared_event_bus_rect() -> bool:
	var room: Room = ROOM_SCENE.instantiate()
	room.setup()
	
	var started_args: Array = []
	var cleared_args: Array = []
	
	var on_started := func(r: Node, rect: Rect2) -> void:
		started_args.append([r, rect])
	var on_cleared := func(r: Node) -> void:
		cleared_args.append(r)
	
	EventBus.room_started.connect(on_started)
	EventBus.room_cleared.connect(on_cleared)
	
	room.start_room()
	
	var started_ok: bool = started_args.size() == 1 and started_args[0][0] == room
	var rect: Rect2 = started_args[0][1] if started_ok else Rect2()
	var rect_ok: bool = rect.size.x > 0.0 and rect.size.y > 0.0 and rect == room.get_room_rect()
	
	var enemies: Array[Node] = room.spawned_enemies.duplicate()
	for e: Node in enemies:
		EventBus.enemy_died.emit(e, &"slime", Vector2.ZERO)
	
	var cleared_ok: bool = cleared_args.size() == 1 and cleared_args[0] == room and room.state == Room.State.CLEARED
	
	EventBus.room_started.disconnect(on_started)
	EventBus.room_cleared.disconnect(on_cleared)
	
	_safe_free(room)
	return started_ok and rect_ok and cleared_ok


func test_player_died_deferred_respawn_after_delay_and_reset() -> bool:
	var dungeon: Dungeon = DUNGEON_SCENE.instantiate()
	dungeon.setup()
	
	dungeon.rooms[0].state = Room.State.LOCKED
	var dummy: Node = Node.new()
	dungeon.rooms[0].register_enemy(dummy)
	
	var respawn_events: Array[Vector2] = []
	var on_respawn := func(pos: Vector2) -> void:
		respawn_events.append(pos)
	EventBus.player_respawn_requested.connect(on_respawn)
	
	var reset_signal_fired: Array[bool] = [false]
	dungeon.dungeon_reset.connect(func() -> void:
		reset_signal_fired[0] = true
	)
	
	# delay ~1.2s ตาม contract
	dungeon.respawn_delay = 1.2
	
	# ผู้เล่นตาย
	EventBus.player_died.emit()
	
	# ต้องไม่ยิง respawn ทันที (deferred timer กำลังนับ)
	var deferred_ok: bool = respawn_events.is_empty() and dungeon.is_respawn_timer_running() and dungeon._respawn_timer.wait_time == 1.2
	
	# จำลอง timer หมดเวลา
	dungeon._on_respawn_timer_timeout()
	
	var expected_spawn: Vector2 = dungeon.rooms[0].player_spawn_point.global_position
	var respawn_ok: bool = respawn_events.size() == 1 and respawn_events[0] == expected_spawn
	var reset_ok: bool = reset_signal_fired[0] and dungeon.current_room_index == 0
	
	var rooms_idle: bool = true
	for r: Room in dungeon.rooms:
		if r.state != Room.State.IDLE or not r.spawned_enemies.is_empty():
			rooms_idle = false
			break
	
	EventBus.player_respawn_requested.disconnect(on_respawn)
	if is_instance_valid(dummy):
		dummy.free()
	_safe_free(dungeon)
	return deferred_ok and respawn_ok and reset_ok and rooms_idle


func test_door_entered_signal_chain_real_objects() -> bool:
	var dungeon: Dungeon = DUNGEON_SCENE.instantiate()
	dungeon.setup()
	
	var r0: Room = dungeon.rooms[0]
	var r_last: Room = dungeon.rooms.back()
	
	var r0_door: Door = null
	for d: Door in r0.doors:
		if d.door_name == &"exit":
			r0_door = d
			break
	var r0_door_entered_fired: Array[bool] = [false]
	r0.door_entered.connect(func(_room: Room, _door: Door) -> void:
		r0_door_entered_fired[0] = true
	)
	
	var dungeon_completed_fired: Array[bool] = [false]
	var run_completed_fired: Array[bool] = [false]
	dungeon.dungeon_completed.connect(func() -> void:
		dungeon_completed_fired[0] = true
	)
	dungeon.run_completed.connect(func() -> void:
		run_completed_fired[0] = true
	)
	
	# ห้องแรก: ยิงผ่าน Door.entered จริง
	r0_door.open_door()
	r0_door.entered.emit(r0_door)
	var r0_chain_ok: bool = r0_door_entered_fired[0]
	
	# ห้องสุดท้าย: trigger จบด่าน (RunCompleteTrigger) ยิงสัญญาณ run_completed และ dungeon_completed
	var dummy_p: CharacterBody2D = CharacterBody2D.new()
	dummy_p.add_to_group(&"player")
	dummy_p.collision_layer = Combat.LAYER_PLAYER
	r_last.add_child(dummy_p)
	r_last._on_run_complete_trigger_body_entered(dummy_p)
	dummy_p.free()
	
	var completed_ok: bool = dungeon_completed_fired[0] and run_completed_fired[0]
	
	_safe_free(dungeon)
	return r0_chain_ok and completed_ok


func test_dungeon_room_sequence_via_detectors_and_doors() -> bool:
	var dungeon: Dungeon = DUNGEON_SCENE.instantiate()
	dungeon.setup()
	
	var ok: bool = dungeon.rooms.size() == 3
	ok = ok and dungeon.rooms[0].room_id == &"room_1"
	ok = ok and dungeon.rooms[1].room_id == &"room_2"
	ok = ok and dungeon.rooms[2].room_id == &"room_3"
	
	ok = ok and dungeon.rooms[0].get_spawn_points().size() == 2
	ok = ok and dungeon.rooms[1].get_spawn_points().size() == 4
	ok = ok and dungeon.rooms[2].get_spawn_points().size() == 0
	ok = ok and dungeon.current_room_index == 0
	
	var room_changed_events: Array = []
	dungeon.room_changed.connect(func(from_idx: int, to_idx: int, r: Room) -> void:
		room_changed_events.append([from_idx, to_idx, r])
	)
	
	# ห้อง 1 เริ่มทำงาน
	dungeon.rooms[0].start_room()
	ok = ok and dungeon.rooms[0].state == Room.State.LOCKED
	
	# เคลียร์ห้อง 1
	for e: Node in dungeon.rooms[0].spawned_enemies.duplicate():
		EventBus.enemy_died.emit(e, &"slime", Vector2.ZERO)
	ok = ok and dungeon.rooms[0].state == Room.State.CLEARED
	
	# ผู้เล่นเดินไปห้อง 2 -> ห้อง 2 เริ่มทำงาน
	dungeon.rooms[1].start_room()
	ok = ok and dungeon.rooms[1].state == Room.State.LOCKED
	ok = ok and dungeon.current_room_index == 1 and dungeon.get_current_room() == dungeon.rooms[1]
	
	# เคลียร์ห้อง 2
	for e: Node in dungeon.rooms[1].spawned_enemies.duplicate():
		EventBus.enemy_died.emit(e, &"slime", Vector2.ZERO)
	ok = ok and dungeon.rooms[1].state == Room.State.CLEARED
	
	# ผู้เล่นเดินไปห้อง 3 (บอส 0 ศัตรู) -> เริ่มและเคลียร์ทันที
	dungeon.rooms[2].start_room()
	ok = ok and dungeon.rooms[2].state == Room.State.CLEARED
	ok = ok and dungeon.current_room_index == 2 and dungeon.get_current_room() == dungeon.rooms[2]
	
	ok = ok and room_changed_events.size() == 2
	ok = ok and room_changed_events[0][0] == 0 and room_changed_events[0][1] == 1
	ok = ok and room_changed_events[1][0] == 1 and room_changed_events[1][1] == 2
	
	_safe_free(dungeon)
	return ok


func test_dungeon_connected_rooms_layout() -> bool:
	var dungeon: Dungeon = DUNGEON_SCENE.instantiate()
	dungeon.setup()
	
	var ok: bool = dungeon.rooms.size() == 3
	var r1: Room = dungeon.rooms[0]
	var r2: Room = dungeon.rooms[1]
	var r3: Room = dungeon.rooms[2]
	
	# ห้องต่อกันจริงในโลก
	ok = ok and r1.position == Vector2(0, 0)
	ok = ok and r2.position == Vector2(416, 208)
	ok = ok and r3.position == Vector2(832, 416)
	
	var r2_has_entrance: bool = false
	for d: Door in r2.doors:
		if d.door_name == &"entrance":
			r2_has_entrance = true
			break
	var r3_has_entrance: bool = false
	for d: Door in r3.doors:
		if d.door_name == &"entrance":
			r3_has_entrance = true
			break
	
	ok = ok and r2_has_entrance and r3_has_entrance
	
	_safe_free(dungeon)
	return ok


func test_respawn_detects_player_in_detector_and_starts_room() -> bool:
	var dungeon: Dungeon = DUNGEON_SCENE.instantiate()
	dungeon.setup()
	
	var dummy_player: CharacterBody2D = CharacterBody2D.new()
	dummy_player.name = "Player"
	dummy_player.add_to_group(&"player")
	dummy_player.collision_layer = Combat.LAYER_PLAYER
	dungeon.add_child(dummy_player)
	dummy_player.global_position = dungeon.rooms[0].player_spawn_point.global_position
	
	# ตรวจจับผู้เล่นที่อยู่ใน detector
	dungeon.rooms[0].check_player_inside(dummy_player)
	
	var started_ok: bool = dungeon.rooms[0].state == Room.State.LOCKED
	
	for e: Node in dungeon.rooms[0].spawned_enemies.duplicate():
		if is_instance_valid(e):
			e.free()
	dungeon.rooms[0].spawned_enemies.clear()
	dummy_player.free()
	_safe_free(dungeon)
	return started_ok


func test_cleared_room_reentry_emits_started_and_cleared_without_locking() -> bool:
	var room: Room = ROOM_SCENE.instantiate()
	room.setup()
	room.state = Room.State.CLEARED
	
	var started_events: Array[Rect2] = []
	var cleared_events: Array[Node] = []
	
	var on_started := func(r: Node, rect: Rect2) -> void:
		if r == room:
			started_events.append(rect)
	var on_cleared := func(r: Node) -> void:
		if r == room:
			cleared_events.append(r)
	
	EventBus.room_started.connect(on_started)
	EventBus.room_cleared.connect(on_cleared)
	
	# ผู้เล่นเดินเข้าห้องที่เคลียร์แล้ว (contract v1.1: ส่ง room_started แล้ว room_cleared ทันที ไม่ปิดประตู)
	room.start_room()
	
	var ok: bool = started_events.size() == 1 and cleared_events.size() == 1
	ok = ok and room.state == Room.State.CLEARED
	for d: Door in room.doors:
		ok = ok and d.is_open
	
	EventBus.room_started.disconnect(on_started)
	EventBus.room_cleared.disconnect(on_cleared)
	_safe_free(room)
	return ok


func test_wall_hugging_body_overlaps_detector_and_door_notches() -> bool:
	var dungeon: Dungeon = DUNGEON_SCENE.instantiate()
	dungeon.setup()
	
	var r2: Room = dungeon.rooms[1]
	var det: Area2D = r2.player_detector
	var poly_node: CollisionPolygon2D = det.get_node("CollisionPolygon2D") as CollisionPolygon2D
	var poly: PackedVector2Array = poly_node.polygon
	
	var check_circle_overlap := func(center: Vector2, radius: float) -> bool:
		if Geometry2D.is_point_in_polygon(center, poly):
			return true
		for angle_deg in range(0, 360, 30):
			var rad: float = deg_to_rad(angle_deg)
			var pt: Vector2 = center + Vector2(cos(rad), sin(rad)) * radius
			if Geometry2D.is_point_in_polygon(pt, poly):
				return true
		return false
	
	var l: TileMapLayer = r2.floor_layer
	var p_0_5: Vector2 = l.map_to_local(Vector2i(0, 5))
	var p_1_5: Vector2 = l.map_to_local(Vector2i(1, 5))
	var p_1_1: Vector2 = l.map_to_local(Vector2i(1, 1))
	var p_9_1: Vector2 = l.map_to_local(Vector2i(9, 1))
	var p_9_5: Vector2 = l.map_to_local(Vector2i(9, 5))
	var p_10_5: Vector2 = l.map_to_local(Vector2i(10, 5))
	
	# ประตูไม่ปิดทับ: ยืนใน cell ประตู (0, 5) และ (10, 5) ต้องไม่ overlap detector
	var door_in_no_overlap: bool = not check_circle_overlap.call(p_0_5, 8.0)
	var door_out_no_overlap: bool = not check_circle_overlap.call(p_10_5, 8.0)
	
	# เดินเลียบกำแพงตามทาง (0,5)→(1,5)→(1,1)→(9,1)→(9,5)→(10,5) ต้อง overlap detector
	var path_overlap_1_5: bool = check_circle_overlap.call(p_1_5, 8.0)
	var path_overlap_1_1: bool = check_circle_overlap.call(p_1_1, 8.0)
	var path_overlap_9_1: bool = check_circle_overlap.call(p_9_1, 8.0)
	var path_overlap_9_5: bool = check_circle_overlap.call(p_9_5, 8.0)
	
	# ช่องว่างถึงกำแพง < 8 px
	var top_vertex: Vector2 = l.map_to_local(Vector2i(1, 1)) + Vector2(0, -16)
	var right_vertex: Vector2 = l.map_to_local(Vector2i(9, 1)) + Vector2(32, 0)
	var bottom_vertex: Vector2 = l.map_to_local(Vector2i(9, 9)) + Vector2(0, 16)
	var left_vertex: Vector2 = l.map_to_local(Vector2i(1, 9)) + Vector2(-32, 0)
	
	var gap_ok: bool = poly.has(top_vertex) and poly.has(right_vertex) and poly.has(bottom_vertex) and poly.has(left_vertex)
	
	var ok: bool = door_in_no_overlap and door_out_no_overlap and path_overlap_1_5 and path_overlap_1_1 and path_overlap_9_1 and path_overlap_9_5 and gap_ok
	
	_safe_free(dungeon)
	return ok


func test_game_run_dungeon_level_and_spawn_point() -> bool:
	var run: GameRun = (load("res://systems/ui/run/game_run.tscn") as PackedScene).instantiate()
	run.level_scene = DUNGEON_SCENE
	run.setup()
	
	var d: Dungeon = run.level as Dungeon
	var handles_respawn: bool = GameRun.level_handles_respawn(run.level)
	
	var r1_spawn: Marker2D = d.get_node("Room1/PlayerSpawnPoint") as Marker2D
	var r2_spawn: Marker2D = d.get_node("Room2/PlayerSpawnPoint") as Marker2D
	var r3_spawn: Marker2D = d.get_node("Room3/PlayerSpawnPoint") as Marker2D
	
	var player_at_spawn1: bool = run.player != null and run.player.position == r1_spawn.position
	
	# เฉพาะ Room1/PlayerSpawnPoint เท่านั้นที่อยู่ในกลุ่ม player_spawn
	var r1_has_group: bool = r1_spawn != null and r1_spawn.is_in_group(&"player_spawn")
	var r2_no_group: bool = r2_spawn != null and not r2_spawn.is_in_group(&"player_spawn")
	var r3_no_group: bool = r3_spawn != null and not r3_spawn.is_in_group(&"player_spawn")
	
	# Dungeon.setup() -> add_to_group(&"respawn_handler")
	d.setup()
	var d_in_group: bool = d.is_in_group(&"respawn_handler")
	
	var ok: bool = handles_respawn and player_at_spawn1 and r1_has_group and r2_no_group and r3_no_group and d_in_group
	run.free()
	return ok


func test_teardown_locked_dungeon_no_fake_room_cleared() -> bool:
	var dungeon: Dungeon = DUNGEON_SCENE.instantiate()
	dungeon.setup()
	
	var r0: Room = dungeon.rooms[0]
	r0.start_room()
	var locked_ok: bool = r0.state == Room.State.LOCKED and r0.get_remaining_enemies_count() == 2
	
	var cleared_emitted: Array[bool] = [false]
	var on_cleared := func(_r: Variant = null) -> void:
		cleared_emitted[0] = true
	
	r0.room_cleared.connect(on_cleared)
	EventBus.room_cleared.connect(on_cleared)
	
	dungeon.free()
	
	EventBus.room_cleared.disconnect(on_cleared)
	return locked_ok and cleared_emitted[0] == false


func test_no_duplicate_room_started_cleared_in_same_room() -> bool:
	var dungeon: Dungeon = DUNGEON_SCENE.instantiate()
	dungeon.setup()
	
	var started_events: Array = []
	var cleared_events: Array = []
	var on_started := func(r: Node, rect: Rect2) -> void:
		started_events.append([r, rect])
	var on_cleared := func(r: Node) -> void:
		cleared_events.append(r)
	
	EventBus.room_started.connect(on_started)
	EventBus.room_cleared.connect(on_cleared)
	
	# เริ่มและเคลียร์ห้อง 1
	var r0: Room = dungeon.rooms[0]
	r0.start_room()
	for e: Node in r0.spawned_enemies.duplicate():
		EventBus.enemy_died.emit(e, &"slime", Vector2.ZERO)
	
	var r0_cleared_ok: bool = r0.state == Room.State.CLEARED
	started_events.clear()
	cleared_events.clear()
	
	# ผู้เล่นเดินไปมาในห้องเดิม (ห้อง 1 เคลียร์แล้ว) -> ต้องไม่ emit ซ้ำ
	var dummy_p: CharacterBody2D = CharacterBody2D.new()
	dummy_p.add_to_group(&"player")
	dummy_p.collision_layer = Combat.LAYER_PLAYER
	r0.add_child(dummy_p)
	dummy_p.position = r0.player_spawn_point.position
	
	r0._on_player_detector_body_entered(dummy_p)
	r0.check_player_inside(dummy_p)
	
	var no_duplicate_ok: bool = started_events.is_empty() and cleared_events.is_empty()
	
	# ผู้เล่นเปลี่ยนห้องไปห้อง 2 -> ส่ง room_started ของห้อง 2
	var r1: Room = dungeon.rooms[1]
	r1.start_room()
	var room2_started_ok: bool = started_events.size() == 1 and started_events[0][0] == r1
	started_events.clear()
	cleared_events.clear()
	
	# ผู้เล่นเดินกลับมาห้อง 1 (ซึ่งเคลียร์แล้ว) -> เปลี่ยนห้องจริง ส่ง room_started และ room_cleared ของห้อง 1 อีก 1 ครั้ง
	r0._on_player_detector_body_entered(dummy_p)
	r0.start_room()
	var reentered_ok: bool = started_events.size() == 1 and started_events[0][0] == r0 \
		and cleared_events.size() == 1 and cleared_events[0] == r0
	started_events.clear()
	cleared_events.clear()
	
	# เดินวนในห้อง 1 ต่อ -> ไม่ส่งซ้ำ
	r0._on_player_detector_body_entered(dummy_p)
	r0.check_player_inside(dummy_p)
	var no_reentry_dup_ok: bool = started_events.is_empty() and cleared_events.is_empty()
	
	EventBus.room_started.disconnect(on_started)
	EventBus.room_cleared.disconnect(on_cleared)
	dummy_p.free()
	_safe_free(dungeon)
	return r0_cleared_ok and no_duplicate_ok and room2_started_ok and reentered_ok and no_reentry_dup_ok


func test_respawn_emits_room_started_once_for_revived_room() -> bool:
	var dungeon: Dungeon = DUNGEON_SCENE.instantiate()
	dungeon.setup()
	
	var started_events: Array = []
	var on_started := func(r: Node, rect: Rect2) -> void:
		started_events.append([r, rect])
	EventBus.room_started.connect(on_started)
	
	# ผู้เล่นตายและฟื้น
	dungeon._do_respawn()
	
	var dummy_p: CharacterBody2D = CharacterBody2D.new()
	dummy_p.add_to_group(&"player")
	dummy_p.collision_layer = Combat.LAYER_PLAYER
	dungeon.rooms[0].add_child(dummy_p)
	dummy_p.global_position = dungeon.rooms[0].player_spawn_point.global_position
	
	# ตรวจสอบผู้เล่นในห้องหลังฟื้น
	dungeon.rooms[0].check_player_inside(dummy_p)
	
	var once_ok: bool = started_events.size() == 1 and started_events[0][0] == dungeon.rooms[0]
	
	# ตรวจซ้ำในห้องเดิม -> ไม่ส่งเพิ่ม
	dungeon.rooms[0]._on_player_detector_body_entered(dummy_p)
	dungeon.rooms[0].check_player_inside(dummy_p)
	var still_once: bool = started_events.size() == 1
	
	EventBus.room_started.disconnect(on_started)
	dummy_p.free()
	_safe_free(dungeon)
	return once_ok and still_once


func test_room3_completion_trigger_and_solid_wall() -> bool:
	var dungeon: Dungeon = DUNGEON_SCENE.instantiate()
	dungeon.setup()
	
	var r3: Room = dungeon.rooms[2]
	
	# ไม่มี ExitDoor เปิดไปที่ว่าง
	var has_exit_door: bool = false
	for d: Door in r3.doors:
		if d.door_name == &"exit":
			has_exit_door = true
			break
	var no_exit_door: bool = not has_exit_door
	
	# ปิด cell ทางออก (10, 5) ด้วยกำแพง
	var wall_tile: Vector2i = r3.wall_layer.get_cell_atlas_coords(Vector2i(10, 5))
	var wall_closed: bool = wall_tile != Vector2i(-1, -1)
	
	# มี RunCompleteTrigger
	var trigger: Area2D = r3.get_node_or_null("RunCompleteTrigger") as Area2D
	var has_trigger: bool = trigger != null and (trigger.collision_mask & Combat.LAYER_PLAYER) != 0
	
	# เมื่อ trigger เข้าทำงาน emit signal run_completed และ dungeon_completed
	var run_completed_fired: Array[bool] = [false]
	var dungeon_completed_fired: Array[bool] = [false]
	dungeon.run_completed.connect(func() -> void:
		run_completed_fired[0] = true
	)
	dungeon.dungeon_completed.connect(func() -> void:
		dungeon_completed_fired[0] = true
	)
	
	var dummy_p: CharacterBody2D = CharacterBody2D.new()
	dummy_p.add_to_group(&"player")
	dummy_p.collision_layer = Combat.LAYER_PLAYER
	r3.add_child(dummy_p)
	r3._on_run_complete_trigger_body_entered(dummy_p)
	
	var signals_ok: bool = run_completed_fired[0] and dungeon_completed_fired[0]
	
	dummy_p.free()
	_safe_free(dungeon)
	return no_exit_door and wall_closed and has_trigger and signals_ok


static func _safe_free(node: Node) -> void:
	if node != null:
		node.free()
