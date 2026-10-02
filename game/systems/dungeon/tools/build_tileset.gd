extends SceneTree

func _init() -> void:
	var ts: TileSet = TileSet.new()
	ts.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	ts.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	ts.tile_size = Vector2i(64, 32)
	
	# Physics layer 0: LAYER_WORLD
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, Combat.LAYER_WORLD)
	ts.set_physics_layer_collision_mask(0, 0)
	
	var src: TileSetAtlasSource = TileSetAtlasSource.new()
	var tex: Texture2D = load("res://systems/dungeon/art/iso_tiles.png")
	if tex == null:
		printerr("Failed to load iso_tiles.png!")
		quit(1)
		return
	src.texture = tex
	src.texture_region_size = Vector2i(64, 32)
	ts.add_source(src, 0)
	
	var diamond_collision: PackedVector2Array = [
		Vector2(0, -16),
		Vector2(32, 0),
		Vector2(0, 16),
		Vector2(-32, 0)
	]
	
	# Floor tiles: Row 0 (cols 0..7, size 1x1)
	for col in range(8):
		src.create_tile(Vector2i(col, 0), Vector2i(1, 1))
	
	# Wall blocks & doors: Rows 1-2 (cols 0..7, size 1x2, texture_origin (0, 16))
	# Cols with full collision: 0, 1, 2, 3, 4 (door closed), 6 (lantern), 7 (altar)
	for col in [0, 1, 2, 3, 4, 6, 7]:
		src.create_tile(Vector2i(col, 1), Vector2i(1, 2))
		var td: TileData = src.get_tile_data(Vector2i(col, 1), 0)
		td.texture_origin = Vector2i(0, 16)
		td.add_collision_polygon(0)
		td.set_collision_polygon_points(0, 0, diamond_collision)
	
	# Col 5: Door Open (size 1x2, texture_origin (0, 16), passable without collision)
	src.create_tile(Vector2i(5, 1), Vector2i(1, 2))
	var td_door_open: TileData = src.get_tile_data(Vector2i(5, 1), 0)
	td_door_open.texture_origin = Vector2i(0, 16)
	
	# Special / accent floor tiles: Row 3 (cols 0..7, size 1x1)
	for col in range(8):
		src.create_tile(Vector2i(col, 3), Vector2i(1, 1))
	
	var err: Error = ResourceSaver.save(ts, "res://systems/dungeon/dungeon_tileset.tres")
	if err != OK:
		printerr("Failed to save dungeon_tileset.tres: ", err)
		quit(1)
		return
	
	print("Successfully saved res://systems/dungeon/dungeon_tileset.tres")
	quit(0)
