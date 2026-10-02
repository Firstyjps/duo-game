extends SceneTree
## สร้าง scene ของ dungeon: room.tscn, dungeon.tscn

func _initialize() -> void:
	var ts: TileSet = load("res://systems/dungeon/dungeon_tileset.tres")
	if ts == null:
		printerr("Failed to load dungeon_tileset.tres")
		quit(1)
		return
	
	var door_scene: PackedScene = load("res://systems/dungeon/room/door.tscn")
	if door_scene == null:
		printerr("Failed to load door.tscn")
		quit(1)
		return
	
	var room_script: GDScript = load("res://systems/dungeon/room/room.gd")
	var dungeon_script: GDScript = load("res://systems/dungeon/dungeon.gd")
	
	# 1. สร้าง room.tscn (Standalone base room)
	var base_room: Node2D = _build_room("Room", &"base_room", 2, Vector2i(10, 5), ts, door_scene, room_script)
	var packed_room: PackedScene = PackedScene.new()
	var err: Error = packed_room.pack(base_room)
	if err == OK:
		ResourceSaver.save(packed_room, "res://systems/dungeon/room/room.tscn")
		print("Saved res://systems/dungeon/room/room.tscn")
	else:
		printerr("Failed to pack room.tscn: ", err)
	base_room.free()
	
	# 2. สร้าง dungeon.tscn (3 ห้อง)
	var dungeon: Node2D = dungeon_script.new()
	dungeon.name = "Dungeon"
	dungeon.y_sort_enabled = true
	
	# CanvasModulate ตัวเดียวที่ Dungeon
	var modulate: CanvasModulate = CanvasModulate.new()
	modulate.name = "CanvasModulate"
	modulate.color = Color(0.32, 0.32, 0.44, 1.0)
	dungeon.add_child(modulate)
	modulate.owner = dungeon
	
	var r1: Node2D = _build_room("Room1", &"room_1", 2, Vector2i(10, 5), ts, door_scene, room_script)
	r1.position = Vector2(0, 0)
	dungeon.add_child(r1)
	_set_owner_recursive(r1, dungeon)
	
	var r2: Node2D = _build_room("Room2", &"room_2", 4, Vector2i(10, 5), ts, door_scene, room_script)
	r2.position = Vector2(1400, 0)
	dungeon.add_child(r2)
	_set_owner_recursive(r2, dungeon)
	
	var r3: Node2D = _build_room("Room3", &"room_3", 0, Vector2i(10, 5), ts, door_scene, room_script)
	r3.position = Vector2(2800, 0)
	dungeon.add_child(r3)
	_set_owner_recursive(r3, dungeon)
	
	dungeon.set("rooms", [r1, r2, r3])
	
	var packed_dungeon: PackedScene = PackedScene.new()
	err = packed_dungeon.pack(dungeon)
	if err == OK:
		ResourceSaver.save(packed_dungeon, "res://systems/dungeon/dungeon.tscn")
		print("Saved res://systems/dungeon/dungeon.tscn")
	else:
		printerr("Failed to pack dungeon.tscn: ", err)
	dungeon.free()
	
	quit(0)


func _build_room(node_name: String, r_id: StringName, spawn_count: int, exit_door_pos: Vector2i, ts: TileSet, door_scene: PackedScene, room_script: GDScript) -> Node2D:
	var room: Node2D = room_script.new()
	room.name = node_name
	room.set("room_id", r_id)
	room.y_sort_enabled = true
	
	# FloorLayer
	var floor_layer: TileMapLayer = TileMapLayer.new()
	floor_layer.name = "FloorLayer"
	floor_layer.tile_set = ts
	floor_layer.y_sort_enabled = false
	room.add_child(floor_layer)
	
	# Populate floor (11x11 grid)
	for x in range(11):
		for y in range(11):
			var tile_coord := Vector2i(0, 0) # plain stone
			if (x + y) % 5 == 0:
				tile_coord = Vector2i(1, 0) # worn stone
			if x == 5 and y == 5:
				tile_coord = Vector2i(4, 0) # ornate center
			elif (x == 4 and y == 5) or (x == 6 and y == 5):
				tile_coord = Vector2i(2, 0) # kintsugi crack
			elif (x == 5 and y == 4) or (x == 5 and y == 6):
				tile_coord = Vector2i(3, 0) # kintsugi crack 2
			floor_layer.set_cell(Vector2i(x, y), 0, tile_coord)
	
	# Door threshold tile
	floor_layer.set_cell(exit_door_pos, 0, Vector2i(6, 0))
	
	# WallLayer
	var wall_layer: TileMapLayer = TileMapLayer.new()
	wall_layer.name = "WallLayer"
	wall_layer.tile_set = ts
	wall_layer.y_sort_enabled = true
	room.add_child(wall_layer)
	
	# Perimeter walls
	for x in range(11):
		for y in range(11):
			var is_edge: bool = (x == 0 or x == 10 or y == 0 or y == 10)
			if not is_edge:
				continue
			# Skip exit doorway cell
			if x == exit_door_pos.x and y == exit_door_pos.y:
				continue
			
			var wall_tile := Vector2i(0, 1) # plain wall
			if (x == 5 and y == 0) or (x == 0 and y == 5):
				wall_tile = Vector2i(1, 1) # kintsugi gold wall
			elif (x == 2 and y == 0) or (x == 8 and y == 0) or (x == 0 and y == 2) or (x == 0 and y == 8):
				wall_tile = Vector2i(6, 1) # stone lantern pillar
			
			wall_layer.set_cell(Vector2i(x, y), 0, wall_tile)
	
	# Doors Container & Door instance
	var doors_container: Node2D = Node2D.new()
	doors_container.name = "Doors"
	doors_container.y_sort_enabled = true
	room.add_child(doors_container)
	
	var door_inst: Node2D = door_scene.instantiate()
	door_inst.name = "ExitDoor"
	door_inst.position = floor_layer.map_to_local(exit_door_pos)
	doors_container.add_child(door_inst)
	
	# Player Detector Area2D
	var detector: Area2D = Area2D.new()
	detector.name = "PlayerDetector"
	detector.collision_layer = 0
	detector.collision_mask = Combat.LAYER_PLAYER
	var det_shape: CollisionPolygon2D = CollisionPolygon2D.new()
	det_shape.name = "CollisionPolygon2D"
	# Diamond shape covering inner room
	det_shape.polygon = PackedVector2Array([
		Vector2(32, 64),
		Vector2(256, 176),
		Vector2(32, 288),
		Vector2(-192, 176)
	])
	detector.add_child(det_shape)
	room.add_child(detector)
	
	# Spawn Points
	var spawn_container: Node2D = Node2D.new()
	spawn_container.name = "SpawnPoints"
	room.add_child(spawn_container)
	
	if spawn_count == 2:
		var sp1: Marker2D = Marker2D.new()
		sp1.name = "Spawn1"
		sp1.position = floor_layer.map_to_local(Vector2i(4, 4))
		sp1.add_to_group(&"spawn_points")
		spawn_container.add_child(sp1)
		
		var sp2: Marker2D = Marker2D.new()
		sp2.name = "Spawn2"
		sp2.position = floor_layer.map_to_local(Vector2i(6, 6))
		sp2.add_to_group(&"spawn_points")
		spawn_container.add_child(sp2)
	elif spawn_count == 4:
		var coords: Array[Vector2i] = [Vector2i(3, 3), Vector2i(7, 3), Vector2i(3, 7), Vector2i(7, 7)]
		for i in range(coords.size()):
			var sp: Marker2D = Marker2D.new()
			sp.name = "Spawn%d" % (i + 1)
			sp.position = floor_layer.map_to_local(coords[i])
			sp.add_to_group(&"spawn_points")
			spawn_container.add_child(sp)
	
	# Enemy Container
	var enemy_cont: Node2D = Node2D.new()
	enemy_cont.name = "EnemyContainer"
	enemy_cont.y_sort_enabled = true
	room.add_child(enemy_cont)
	
	# Player Spawn Point
	var p_spawn: Marker2D = Marker2D.new()
	p_spawn.name = "PlayerSpawnPoint"
	p_spawn.position = floor_layer.map_to_local(Vector2i(2, 5))
	room.add_child(p_spawn)
	
	# Lighting: PointLight2D lanterns
	var lighting: Node2D = Node2D.new()
	lighting.name = "Lighting"
	room.add_child(lighting)
	
	var grad_tex: GradientTexture2D = _create_lantern_light_texture()
	var lantern_coords: Array[Vector2i] = [Vector2i(2, 0), Vector2i(0, 2), Vector2i(8, 0), Vector2i(0, 8)]
	for i in range(lantern_coords.size()):
		var light: PointLight2D = PointLight2D.new()
		light.name = "LanternLight%d" % (i + 1)
		light.position = floor_layer.map_to_local(lantern_coords[i]) + Vector2(0, -16)
		light.texture = grad_tex
		light.energy = 1.3
		light.texture_scale = 2.2
		light.color = Color(1.0, 0.85, 0.55, 1.0)
		lighting.add_child(light)
	
	_set_owner_recursive(room, room)
	return room


func _create_lantern_light_texture() -> GradientTexture2D:
	var grad: Gradient = Gradient.new()
	grad.colors = PackedColorArray([
		Color(1.0, 0.9, 0.6, 1.0),
		Color(1.0, 0.6, 0.2, 0.65),
		Color(0.8, 0.4, 0.1, 0.2),
		Color(0.0, 0.0, 0.0, 0.0)
	])
	grad.offsets = PackedFloat32Array([0.0, 0.35, 0.7, 1.0])
	
	var tex: GradientTexture2D = GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 128
	tex.height = 128
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	return tex


func _set_owner_recursive(node: Node, new_owner: Node) -> void:
	if node != new_owner:
		node.owner = new_owner
		# ไม่ตั้ง owner ให้ลูกของ node ที่มาจาก scene อื่น (เช่น Door ที่มี scene_file_path != "")
		if node.scene_file_path != "":
			return
	for child: Node in node.get_children():
		_set_owner_recursive(child, new_owner)
