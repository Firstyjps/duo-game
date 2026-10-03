extends Node2D
## Sandbox ทดสอบปริศนา isometric + ศาลเจ้า (issue #57)
## ปริศนา: เหยียบสวิตช์ 2 อัน (อันหนึ่งดันบล็อกทับ) + จุดโคม → ประตูเปิด → สะพานแตกซ่อมด้วยเศษทอง 3 ชิ้น → ศาลเจ้า

const TILES: Texture2D = preload("res://systems/player/debug/iso/iso_tiles.png")
const PLAYER_SCENE: PackedScene = preload("res://systems/player/player.tscn")
const SWITCH_SCENE: PackedScene = preload("res://systems/dungeon/puzzles/pressure_switch.tscn")
const BLOCK_SCENE: PackedScene = preload("res://systems/dungeon/puzzles/push_block.tscn")
const LANTERN_SCENE: PackedScene = preload("res://systems/dungeon/puzzles/stone_lantern.tscn")
const GATE_SCENE: PackedScene = preload("res://systems/dungeon/puzzles/puzzle_gate.tscn")
const CRACK_SCENE: PackedScene = preload("res://systems/dungeon/puzzles/kintsugi_crack.tscn")
const SHRINE_SCENE: PackedScene = preload("res://systems/dungeon/puzzles/rest_shrine.tscn")
const SHARD_SCENE: PackedScene = preload("res://systems/dungeon/puzzles/pickup_shard.tscn")

var floor_layer: TileMapLayer
var walls_layer: TileMapLayer
var world: Node2D

var player: Player
var switch_1: PressureSwitch
var switch_2: PressureSwitch
var push_block: PushBlock
var lantern: StoneLantern
var gate: PuzzleGate
var crack: KintsugiCrack
var shrine: RestShrine

var hud_label: Label
var status_label: Label


func _ready() -> void:
	InteractAction.ensure_registered()
	GoldShards.reset()

	var ts: TileSet = _make_tileset()

	floor_layer = TileMapLayer.new()
	floor_layer.name = "FloorLayer"
	floor_layer.tile_set = ts
	add_child(floor_layer)

	world = Node2D.new()
	world.name = "World"
	world.y_sort_enabled = true
	add_child(world)

	walls_layer = TileMapLayer.new()
	walls_layer.name = "WallsLayer"
	walls_layer.tile_set = ts
	walls_layer.y_sort_enabled = true
	world.add_child(walls_layer)

	_build_map()
	_spawn_puzzle_elements()
	_spawn_player()
	_build_ui()


func _make_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	ts.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	ts.tile_size = Vector2i(64, 32)
	ts.add_physics_layer()
	var src := TileSetAtlasSource.new()
	src.texture = TILES
	src.texture_region_size = Vector2i(64, 32)
	ts.add_source(src, 0)
	for i: int in 4:
		src.create_tile(Vector2i(i, 0), Vector2i(1, 2))
		var td: TileData = src.get_tile_data(Vector2i(i, 0), 0)
		td.texture_origin = Vector2i(0, 16 if i == 3 else 6)
	var block: TileData = src.get_tile_data(Vector2i(3, 0), 0)
	block.add_collision_polygon(0)
	block.set_collision_polygon_points(0, 0, PackedVector2Array([
		Vector2(0, -16), Vector2(32, 0), Vector2(0, 16), Vector2(-32, 0)]))
	return ts


func _build_map() -> void:
	# Chamber 1: x 1..8, y 1..8
	# Hallway / Bridge: y = 5, x = 9..14
	# Chamber 2 (Sanctuary): x 15..19, y 3..7
	var rng := RandomNumberGenerator.new()
	rng.seed = 57

	# Build floors
	for y: int in range(1, 9):
		for x: int in range(1, 9):
			var kind: int = 1 if rng.randf() < 0.1 else (2 if rng.randf() < 0.2 else 0)
			floor_layer.set_cell(Vector2i(x, y), 0, Vector2i(kind, 0))

	# Bridge floor
	for x: int in range(9, 15):
		floor_layer.set_cell(Vector2i(x, 5), 0, Vector2i(0, 0))

	# Sanctuary floor
	for y: int in range(3, 8):
		for x: int in range(15, 20):
			var kind: int = 1 if rng.randf() < 0.1 else 0
			floor_layer.set_cell(Vector2i(x, y), 0, Vector2i(kind, 0))

	# Build perimeter walls
	# Chamber 1 outer walls
	for x: int in range(0, 10):
		walls_layer.set_cell(Vector2i(x, 0), 0, Vector2i(3, 0))
		walls_layer.set_cell(Vector2i(x, 9), 0, Vector2i(3, 0))
	for y: int in range(0, 10):
		walls_layer.set_cell(Vector2i(0, y), 0, Vector2i(3, 0))
		if y != 5: # Leave opening for gate at (9, 5)
			walls_layer.set_cell(Vector2i(9, y), 0, Vector2i(3, 0))

	# Bridge rails / walls
	for x: int in range(9, 15):
		walls_layer.set_cell(Vector2i(x, 4), 0, Vector2i(3, 0))
		walls_layer.set_cell(Vector2i(x, 6), 0, Vector2i(3, 0))

	# Sanctuary walls
	for x: int in range(14, 21):
		walls_layer.set_cell(Vector2i(x, 2), 0, Vector2i(3, 0))
		walls_layer.set_cell(Vector2i(x, 8), 0, Vector2i(3, 0))
	for y: int in range(2, 9):
		walls_layer.set_cell(Vector2i(20, y), 0, Vector2i(3, 0))
		if y < 4 or y > 6:
			walls_layer.set_cell(Vector2i(14, y), 0, Vector2i(3, 0))


func _spawn_puzzle_elements() -> void:
	# 1. Switch 1 (latch)
	switch_1 = SWITCH_SCENE.instantiate()
	switch_1.name = "Switch1"
	switch_1.latch = true
	switch_1.position = floor_layer.map_to_local(Vector2i(2, 7))
	world.add_child(switch_1)

	# 2. Switch 2 (non-latch) & PushBlock
	switch_2 = SWITCH_SCENE.instantiate()
	switch_2.name = "Switch2"
	switch_2.latch = false
	switch_2.position = floor_layer.map_to_local(Vector2i(5, 6))
	world.add_child(switch_2)

	push_block = BLOCK_SCENE.instantiate()
	push_block.name = "PushBlock"
	push_block.grid_layer = floor_layer
	push_block.position = floor_layer.map_to_local(Vector2i(5, 3))
	world.add_child(push_block)

	# 3. StoneLantern (lit on player hit)
	lantern = LANTERN_SCENE.instantiate()
	lantern.name = "StoneLantern"
	lantern.lit_time = 0.0 # permanent once ignited
	lantern.position = floor_layer.map_to_local(Vector2i(7, 2))
	world.add_child(lantern)

	# 4. PuzzleGate at (9, 5) opening
	gate = GATE_SCENE.instantiate()
	gate.name = "PuzzleGate"
	gate.position = floor_layer.map_to_local(Vector2i(9, 5))
	world.add_child(gate)

	gate.required = [
		gate.get_path_to(switch_1),
		gate.get_path_to(switch_2),
		gate.get_path_to(lantern)
	]
	switch_1.targets = [switch_1.get_path_to(gate)]
	switch_2.targets = [switch_2.get_path_to(gate)]
	lantern.targets = [lantern.get_path_to(gate)]

	# 5. Shards on bridge (3 pieces)
	for i: int in range(3):
		var shard: PickupShard = SHARD_SCENE.instantiate()
		shard.name = "Shard_%d" % (i + 1)
		shard.position = floor_layer.map_to_local(Vector2i(10 + i, 5))
		world.add_child(shard)

	# 6. KintsugiCrack at (13, 5)
	crack = CRACK_SCENE.instantiate()
	crack.name = "KintsugiCrack"
	crack.cost = 3
	crack.repair_time = 1.0
	crack.position = floor_layer.map_to_local(Vector2i(13, 5))
	world.add_child(crack)

	# 7. RestShrine at (17, 5)
	shrine = SHRINE_SCENE.instantiate()
	shrine.name = "RestShrine"
	shrine.position = floor_layer.map_to_local(Vector2i(17, 5))
	world.add_child(shrine)


func _spawn_player() -> void:
	player = PLAYER_SCENE.instantiate()
	player.name = "Player"
	player.position = floor_layer.map_to_local(Vector2i(2, 2))
	world.add_child(player)

	var cam := Camera2D.new()
	cam.name = "Camera2D"
	cam.zoom = Vector2(2.0, 2.0)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 6.0
	player.add_child(cam)


func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "UI"
	add_child(canvas)

	var panel := PanelContainer.new()
	panel.position = Vector2(16, 16)
	panel.size = Vector2(340, 220)
	canvas.add_child(panel)

	var vbox := VBoxContainer.new()
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "=== ปริศนาดันเจี้ยน & ศาลเจ้า (Issue #57) ==="
	vbox.add_child(title)

	var controls := Label.new()
	controls.text = "เดิน: WASD | กลิ้ง: Space | โจมตี: J / คลิกซ้าย | คุย/ซ่อม: E"
	controls.modulate = Color(0.8, 0.9, 1.0)
	vbox.add_child(controls)

	hud_label = Label.new()
	vbox.add_child(hud_label)

	status_label = Label.new()
	status_label.modulate = Color(1.0, 0.9, 0.4)
	vbox.add_child(status_label)


func _process(_delta: float) -> void:
	if hud_label == null:
		return

	var s1_check := "[✓]" if switch_1.is_on else "[ ]"
	var s2_check := "[✓]" if switch_2.is_on else "[ ]"
	var lan_check := "[✓]" if lantern.is_lit else "[ ]"
	var gate_check := "เปิดแล้ว" if gate.is_open else "ปิดอยู่"
	var crack_check := "ซ่อมแล้ว" if crack.is_repaired else "ยังแตกอยู่"
	var shrine_check := "บันทึกแล้ว" if shrine.is_active else "ยังไม่ใช้"

	hud_label.text = """
1. สวิตช์ 1 (เหยียบค้าง): %s
2. สวิตช์ 2 (ดันบล็อกทับ): %s
3. โคมหิน (โจมตีเพื่อจุดไฟ): %s
4. ประตูหิน (เงื่อนไข AND): %s
5. สะพานแตกคินสึงิ: %s (ต้องการ 3 เศษ)
6. ศาลเจ้า: %s
""" % [s1_check, s2_check, lan_check, gate_check, crack_check, shrine_check]

	status_label.text = "เศษทองที่ถือ: %d ชิ้น" % GoldShards.count
