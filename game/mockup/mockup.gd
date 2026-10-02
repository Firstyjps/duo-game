extends Node2D
## ⚠️ MOCKUP — ทิ้งได้ · ไม่ใช่โค้ดจริงของระบบ A/B (ห้ามโค้ดใน game/systems/ อ้างถึง)
## เล่น:    godot --path game res://mockup/mockup.tscn
## อัดคลิป:  godot --path game --windowed --resolution 960x540 --fixed-fps 30 res://mockup/mockup.tscn -- --autoplay --frames=<โฟลเดอร์>
##          (--write-movie ไม่อัด CanvasLayer/HUD เลยเก็บภาพจาก viewport เองทีละเฟรม → ffmpeg)

const PlayerScript := preload("res://mockup/mockup_player.gd")
const EnemyScript := preload("res://mockup/mockup_enemy.gd")
const HudScript := preload("res://mockup/mockup_hud.gd")
## ศัตรูจริงของระบบ enemy (Few) — instance ตรง ไม่ copy · Few แก้แล้ว mockup เปลี่ยนตาม
const SlimeScene := preload("res://systems/enemy/slime/slime.tscn")
const Fx := preload("res://mockup/mockup_fx.gd")
## ด่าน: grass = สนามหญ้าทดสอบ (Kling) · stone = ดันเจี้ยน (Higgsfield) · Tab สลับ
const ARENAS: Dictionary = {
	&"grass": {"tex": "res://mockup/assets/arena_grass.png", "floor": Rect2(80, 102, 804, 350), "ambient": Color(0.96, 0.96, 0.92), "lights": [], "light": 0.0},
	&"stone": {"tex": "res://mockup/assets/arena.png", "floor": Rect2(72, 108, 818, 372), "ambient": Color(0.5, 0.55, 0.7), "lights": [Vector2(332, 78), Vector2(627, 78)], "light": 1.35},
}
## รอบศัตรู: หมดรอบหนึ่งแล้วรอบถัดไปออก → สุดท้ายโกเลมตื่น
const WAVES: Array = [
	[[&"slime", Vector2(420, 230)], [&"slime", Vector2(450, 430)], [&"slime", Vector2(600, 300)]],
	[[&"skeleton", Vector2(560, 330)], [&"skeleton", Vector2(690, 430)]],
]
const AUTOPLAY_SECONDS: float = 35.0

var player: CharacterBody2D
var enemies: Array[Node2D] = []
var golem: Node2D
var actors: Node2D
var fx_layer: CanvasLayer
var hud: CanvasLayer
var camera: Camera2D
var torches: Array[PointLight2D] = []
var coins: Array[Node2D] = []
var shake: float = 0.0
var gold: int = 0
var autoplay: bool = false
var clock: float = 0.0
var frames_dir: String = ""
## นับรวมข้าม reload_current_scene (ตายแล้วเริ่มใหม่) — ใช้จบคลิป autoplay
static var autoplay_clock: float = 0.0
static var arena_id: StringName = &"grass"
var wave: int = 0
var light_energy: float = 0.0


class Coin extends Node2D:
	var t: float = randf() * TAU

	func _process(delta: float) -> void:
		t += delta * 5.0
		queue_redraw()

	func _draw() -> void:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.4))
		draw_circle(Vector2.ZERO, 4.0, Color(0, 0, 0, 0.4))
		draw_set_transform(Vector2.ZERO)
		var y: float = roundf(-6.0 - absf(sin(t)) * 3.0)
		draw_circle(Vector2(0, y), 3.5, Color(1.0, 0.8, 0.2))
		draw_circle(Vector2(-1, y - 1), 1.2, Color(1.0, 1.0, 0.8))


func _ready() -> void:
	autoplay = "--autoplay" in OS.get_cmdline_user_args()
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--frames="):
			frames_dir = a.trim_prefix("--frames=")
		if a.begins_with("--arena=") and autoplay_clock == 0.0:
			arena_id = StringName(a.trim_prefix("--arena="))
	if autoplay:
		get_window().size = Vector2i(960, 540)
	Engine.time_scale = 1.0
	RenderingServer.set_default_clear_color(Color(0.035, 0.04, 0.06))
	_setup_input()
	_build_arena()
	actors = Node2D.new()
	actors.y_sort_enabled = true
	add_child(actors)
	fx_layer = CanvasLayer.new()
	fx_layer.layer = 1
	fx_layer.follow_viewport_enabled = true
	add_child(fx_layer)
	player = PlayerScript.new()
	player.position = Vector2(190, 380)
	player.autoplay = autoplay
	player.main = self
	actors.add_child(player)
	if light_energy == 0.0:  # ด่านกลางวัน: ไม่ใช้ไฟรอบตัว (สว่างเกิน)
		for c in player.get_children():
			if c is PointLight2D:
				c.visible = false
	golem = _spawn(&"golem", Vector2(760, 210))
	_spawn_wave(0)
	hud = HudScript.new()
	add_child(hud)
	hud.bind_player(player)
	camera = Camera2D.new()
	camera.position = Vector2(480, 268)
	add_child(camera)
	camera.make_current()
	EventBus.damage_dealt.connect(_on_damage_dealt)
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.player_died.connect(_on_player_died)


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _process(delta: float) -> void:
	clock += delta
	autoplay_clock += delta
	enemies = enemies.filter(func(e) -> bool: return is_instance_valid(e))
	if Input.is_action_just_pressed(&"restart"):
		get_tree().reload_current_scene()
		return
	if Input.is_action_just_pressed(&"switch_arena"):
		arena_id = &"stone" if arena_id == &"grass" else &"grass"
		get_tree().reload_current_scene()
		return
	if autoplay and autoplay_clock > AUTOPLAY_SECONDS:
		get_tree().quit()
	if autoplay and get_window().size != Vector2i(960, 540):
		get_window().mode = Window.MODE_WINDOWED
		get_window().size = Vector2i(960, 540)
	if frames_dir != "":
		_save_frame()
	for i: int in torches.size():
		torches[i].energy = light_energy + 0.12 * sin(clock * 9.0 + i * 2.0) + 0.06 * sin(clock * 23.0 + i)
	camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake
	shake = move_toward(shake, 0.0, 30.0 * delta)
	for c: Node2D in coins.duplicate():
		if player.global_position.distance_to(c.position) < 18.0:
			coins.erase(c)
			gold += 1
			hud.set_gold(gold)
			c.queue_free()


static var frame_no: int = 0


func _save_frame() -> void:
	await RenderingServer.frame_post_draw
	if not is_inside_tree():
		return
	var img: Image = get_viewport().get_texture().get_image()
	img.save_jpg(frames_dir.path_join("f_%05d.jpg" % frame_no), 0.92)
	frame_no += 1


func _spawn(kind: StringName, at: Vector2) -> Node2D:
	var e: CharacterBody2D = EnemyScript.new()
	e.kind = kind
	e.target = player
	e.main = self
	e.position = at
	actors.add_child(e)
	enemies.append(e)
	return e


func _spawn_slime(at: Vector2) -> void:
	var s: CharacterBody2D = SlimeScene.instantiate()
	s.position = at
	actors.add_child(s)
	enemies.append(s)


func _spawn_wave(i: int) -> void:
	wave = i
	for entry: Array in WAVES[i]:
		var kind: StringName = entry[0]
		if kind == &"slime":
			_spawn_slime(entry[1])
		else:
			_spawn(kind, entry[1])
	if i > 0:
		_float_text("WAVE %d  ·  HP FULL" % (i + 1), Vector2(420, 250), Color(0.9, 0.95, 1.0), 16)
		player.health.heal(player.health.max_hp)


## ยังมีชีวิตไหม — รองรับทั้งศัตรู mockup และศัตรูจริงจาก game/systems/enemy/
static func is_alive(e) -> bool:
	if not is_instance_valid(e):
		return false
	if e is Slime:
		return e.state != Slime.State.DEAD
	return e.is_targetable()


func _build_arena() -> void:
	var arena: Dictionary = ARENAS[arena_id]
	var bg := Sprite2D.new()
	bg.texture = load(arena.tex)
	bg.centered = false
	bg.z_index = -2  # ต่ำกว่า TelegraphMarker (z -1) ของระบบ enemy
	add_child(bg)
	var dark := CanvasModulate.new()
	dark.color = arena.ambient
	add_child(dark)
	light_energy = arena.light
	for p: Vector2 in arena.lights:
		var l: PointLight2D = Fx.light(Color(1.0, 0.6, 0.3), light_energy, 2.4)
		l.position = p
		add_child(l)
		torches.append(l)
	var floor_rect: Rect2 = arena.floor
	var walls := StaticBody2D.new()
	walls.collision_layer = Combat.LAYER_WORLD
	add_child(walls)
	for r: Rect2 in [
		Rect2(0, 0, 960, floor_rect.position.y),
		Rect2(0, floor_rect.end.y, 960, 80),
		Rect2(0, 0, floor_rect.position.x, 540),
		Rect2(floor_rect.end.x, 0, 80, 540),
	]:
		var s := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = r.size
		s.shape = rect
		s.position = r.get_center()
		walls.add_child(s)


func _on_damage_dealt(target: Node, _info: DamageInfo, final_amount: int) -> void:
	var hit_player: bool = target == player
	var pos: Vector2 = (target as Node2D).global_position + Vector2(randf_range(-6, 6), -46)
	_float_text(str(final_amount), pos, Color(1.0, 0.35, 0.3) if hit_player else Color(1.0, 0.95, 0.75))
	shake = maxf(shake, 5.0 if hit_player else 2.5)
	_hitstop(0.08 if hit_player else 0.05)


func _on_enemy_died(_enemy: Node, enemy_id: StringName, position_: Vector2) -> void:
	if autoplay:
		print("[autoplay] %s died at %.1fs" % [enemy_id, autoplay_clock])
	var n: int = EnemyScript.KINDS[enemy_id].coins if EnemyScript.KINDS.has(enemy_id) else 2
	for i: int in n:
		var c := Coin.new()
		actors.add_child(c)
		c.position = position_
		var dest: Vector2 = position_ + Vector2.from_angle(randf() * TAU) * randf_range(10, 28)
		var tw: Tween = c.create_tween()
		tw.tween_property(c, "position", dest, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if light_energy > 0.0:
			var l: PointLight2D = Fx.light(Color(1.0, 0.8, 0.3), 0.5, 0.18)
			l.position = Vector2(0, -6)
			c.add_child(l)
		coins.append(c)
	var minions_left: int = 0
	for e in enemies:
		if e != golem and is_alive(e):
			minions_left += 1
	if minions_left == 0 and wave + 1 < WAVES.size():
		_spawn_wave.call_deferred(wave + 1)
	elif minions_left == 0 and is_instance_valid(golem):
		_float_text("THE GOLEM AWAKENS", golem.global_position + Vector2(-50, -130), Color(1.0, 0.6, 0.3), 14)
		player.health.heal(player.health.max_hp)
		golem.wake()
		if autoplay:
			print("[autoplay] golem awake at %.1fs" % autoplay_clock)


func _on_player_died() -> void:
	if autoplay:
		print("[autoplay] player died at %.1fs" % autoplay_clock)
	_float_text("YOU DIED", player.global_position + Vector2(-30, -60), Color(0.9, 0.2, 0.2), 16)
	await get_tree().create_timer(1.8).timeout
	get_tree().reload_current_scene()


func _float_text(text: String, at: Vector2, color: Color, size: int = 11) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", color)
	l.add_theme_constant_override(&"outline_size", 3)
	l.add_theme_color_override(&"font_outline_color", Color.BLACK)
	l.position = at
	fx_layer.add_child(l)
	var tw: Tween = l.create_tween()
	tw.tween_property(l, "position:y", at.y - 18.0, 0.7).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.7).set_delay(0.3)
	tw.tween_callback(l.queue_free)


func _hitstop(seconds: float) -> void:
	Engine.time_scale = 0.05
	await get_tree().create_timer(seconds, true, false, true).timeout
	Engine.time_scale = 1.0


func _setup_input() -> void:
	var keys: Dictionary = {
		&"move_left": [KEY_A, KEY_LEFT], &"move_right": [KEY_D, KEY_RIGHT],
		&"move_up": [KEY_W, KEY_UP], &"move_down": [KEY_S, KEY_DOWN],
		&"dodge": [KEY_SPACE, KEY_SHIFT], &"attack": [KEY_J], &"restart": [KEY_R], &"switch_arena": [KEY_TAB],
	}
	for action: StringName in keys:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for k: Key in keys[action]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(action, e)
	var m := InputEventMouseButton.new()
	m.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event(&"attack", m)
