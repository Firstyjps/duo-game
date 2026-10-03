extends Node2D
## ลานวัดทดสอบ isometric (เฟส 1 · #37) — เดิน 8 ทิศ ดูว่าสไปรต์หันถูกทุกทิศ
## WASD/ลูกศร เดิน · Shift วิ่ง · Space กลิ้งหลบ · H โดนตี · K ตาย · R ฟื้น
## สร้าง TileSet ด้วยโค้ด (tile PixelLab จาก make_tiles.py) ไม่ใช่ระบบดันเจี้ยนจริง

const TILES: Texture2D = preload("res://systems/player/debug/iso/iso_tiles.png")
const FRAMES_PATH: String = "res://systems/player/art/kintsugi_hero/kintsugi_hero_frames.tres"
const SIZE: int = 16

@export var walk_speed: float = 70.0
@export var run_speed: float = 125.0
@export var roll_speed: float = 190.0
@export var roll_time: float = 0.42

var hero: CharacterBody2D
var sprite: DirSprite
var info: Label
var _roll_left: float = 0.0
var _roll_dir: Vector2 = Vector2.ZERO
var _lock_left: float = 0.0
var _dead: bool = false
var _keys_down: Dictionary = {}
var _demo: bool = false


func _ready() -> void:
	var ts := _make_tileset()
	var floor_layer := TileMapLayer.new()
	floor_layer.tile_set = ts
	add_child(floor_layer)
	var world := Node2D.new()  # กำแพง + ตัวละคร เรียงลึกด้วย y_sort
	world.y_sort_enabled = true
	add_child(world)
	var walls := TileMapLayer.new()
	walls.tile_set = ts
	walls.y_sort_enabled = true
	world.add_child(walls)

	var rng := RandomNumberGenerator.new()
	rng.seed = 37
	for y: int in SIZE:
		for x: int in SIZE:
			var edge: bool = x == 0 or y == 0 or x == SIZE - 1 or y == SIZE - 1
			var pillar: bool = (x == 4 or x == 11) and (y == 4 or y == 11)
			if edge or pillar:
				walls.set_cell(Vector2i(x, y), 0, Vector2i(3, 0))
			else:
				var r: float = rng.randf()
				var kind: int = 1 if r < 0.08 else (2 if r < 0.2 else 0)
				floor_layer.set_cell(Vector2i(x, y), 0, Vector2i(kind, 0))

	hero = CharacterBody2D.new()
	hero.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 6.0
	col.shape = shape
	hero.add_child(col)
	sprite = DirSprite.new()
	sprite.offset = Vector2(0, -32)  # ช่อง atlas 96 px เท้าอยู่ที่ y≈80 → ยกขึ้น 32 ให้เท้าอยู่ที่ origin
	if ResourceLoader.exists(FRAMES_PATH):
		sprite.sprite_frames = load(FRAMES_PATH)
	hero.add_child(sprite)
	hero.position = floor_layer.map_to_local(Vector2i(SIZE / 2, SIZE / 2))
	world.add_child(hero)
	sprite.play_action(&"idle")

	var cam := Camera2D.new()
	cam.zoom = Vector2(2, 2)
	cam.position_smoothing_enabled = true
	hero.add_child(cam)

	var ui := CanvasLayer.new()
	add_child(ui)
	info = Label.new()
	info.position = Vector2(8, 6)
	ui.add_child(info)
	if sprite.sprite_frames == null:
		info.text = "ยังไม่มี %s — รัน tools/build_dir_atlas.py ก่อน" % FRAMES_PATH
	if OS.get_cmdline_user_args().has("--shot"):
		_shoot.call_deferred()


## godot --path game res://systems/player/debug/iso/iso_courtyard.tscn -- --shot
## เดินครบ 8 ทิศ ถ่ายภาพทีละทิศ → user://iso_courtyard_<ทิศ>.png แล้วปิด (ใช้ตรวจว่าหันถูก)
func _shoot() -> void:
	_demo = true
	for d: int in Dir8.COUNT:
		sprite.set_facing(Dir8.to_vector(d))
		sprite.play_action(&"walk")
		for i: int in 12:
			await get_tree().process_frame
		var img: Image = get_viewport().get_texture().get_image()
		info.text = "%s · %s" % [sprite.action, Dir8.name_of(sprite.facing)]
		await get_tree().process_frame
		img = get_viewport().get_texture().get_image()
		img.save_png("user://iso_courtyard_%s.png" % Dir8.name_of(d))
	get_tree().quit()


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
	for i: int in 4:  # ทุก tile สูง 64 = 1×2 ช่อง atlas (ดู make_tiles.py)
		src.create_tile(Vector2i(i, 0), Vector2i(1, 2))
		var td: TileData = src.get_tile_data(Vector2i(i, 0), 0)
		td.texture_origin = Vector2i(0, 16 if i == 3 else 6)  # บล็อก: ฐานกลาง y=48 · พื้นบาง: หน้าบนกลาง y≈38
	var block: TileData = src.get_tile_data(Vector2i(3, 0), 0)
	block.add_collision_polygon(0)
	block.set_collision_polygon_points(0, 0, PackedVector2Array([
		Vector2(0, -16), Vector2(32, 0), Vector2(0, 16), Vector2(-32, 0)]))
	return ts


func _physics_process(delta: float) -> void:
	if hero == null or sprite == null or _demo:
		return
	if Input.is_physical_key_pressed(KEY_R) and _dead:
		_dead = false
		sprite.play_action(&"idle")
	if _dead:
		return
	var move := Vector2(
		_axis(KEY_D, KEY_RIGHT) - _axis(KEY_A, KEY_LEFT),
		_axis(KEY_S, KEY_DOWN) - _axis(KEY_W, KEY_UP)).normalized()

	if _roll_left > 0.0:
		_roll_left -= delta
		hero.velocity = _roll_dir * roll_speed
	elif _lock_left > 0.0:
		_lock_left -= delta
		hero.velocity = Vector2.ZERO
	else:
		var running: bool = Input.is_physical_key_pressed(KEY_SHIFT)
		hero.velocity = move * (run_speed if running else walk_speed)
		sprite.set_facing(move)
		if _pressed_now(KEY_SPACE):
			_roll_dir = move if move != Vector2.ZERO else Dir8.to_vector(sprite.facing)
			sprite.set_facing(_roll_dir)
			_roll_left = roll_time
			sprite.play_action(&"roll")
		elif Input.is_physical_key_pressed(KEY_H):
			_lock_left = 0.35
			sprite.play_action(&"hurt")
		elif Input.is_physical_key_pressed(KEY_K):
			_dead = true
			hero.velocity = Vector2.ZERO
			sprite.play_action(&"death")
		elif move == Vector2.ZERO:
			sprite.play_action(&"idle")
		else:
			sprite.play_action(&"run" if running else &"walk")
	hero.move_and_slide()
	if info != null and sprite.sprite_frames != null:
		info.text = "%s · %s" % [sprite.action, Dir8.name_of(sprite.facing)]


## กดครั้งใหม่ (ไม่นับกดค้าง)
func _pressed_now(k: Key) -> bool:
	var down: bool = Input.is_physical_key_pressed(k)
	var was: bool = _keys_down.get(k, false)
	_keys_down[k] = down
	return down and not was


func _axis(a: Key, b: Key) -> float:
	return 1.0 if Input.is_physical_key_pressed(a) or Input.is_physical_key_pressed(b) else 0.0
