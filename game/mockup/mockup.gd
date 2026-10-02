extends Node2D
## ⚠️ MOCKUP — ทิ้งได้ · ไม่ใช่โค้ดจริงของระบบ A/B (ห้ามโค้ดใน game/systems/ อ้างถึง)
## เล่น:    godot --path game res://mockup/mockup.tscn
## อัดคลิป:  godot --path game --windowed --resolution 960x540 --fixed-fps 30 res://mockup/mockup.tscn -- --autoplay --frames=<โฟลเดอร์>
##          (--write-movie ไม่อัด CanvasLayer/HUD เลยเก็บภาพจาก viewport เองทีละเฟรม → ffmpeg)

const PlayerScript := preload("res://mockup/mockup_player.gd")
const EnemyScript := preload("res://mockup/mockup_enemy.gd")
const HudScript := preload("res://mockup/mockup_hud.gd")
const Fx := preload("res://mockup/mockup_fx.gd")
const FLOOR := Rect2(72, 108, 818, 372)
const TORCHES: Array[Vector2] = [Vector2(332, 52), Vector2(627, 52)]
const AUTOPLAY_SECONDS: float = 20.5

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
	_spawn(&"skeleton", Vector2(560, 330))
	_spawn(&"skeleton", Vector2(690, 430))
	golem = _spawn(&"golem", Vector2(760, 210))
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
	if autoplay and autoplay_clock > AUTOPLAY_SECONDS:
		get_tree().quit()
	if frames_dir != "":
		_save_frame()
	for i: int in torches.size():
		torches[i].energy = 1.35 + 0.12 * sin(clock * 9.0 + i * 2.0) + 0.06 * sin(clock * 23.0 + i)
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


func _build_arena() -> void:
	var bg := Sprite2D.new()
	bg.texture = load("res://mockup/assets/arena.png")
	bg.centered = false
	add_child(bg)
	var dark := CanvasModulate.new()
	dark.color = Color(0.5, 0.55, 0.7)
	add_child(dark)
	for p: Vector2 in TORCHES:
		var l: PointLight2D = Fx.light(Color(1.0, 0.6, 0.3), 1.35, 2.4)
		l.position = p + Vector2(0, 26)
		add_child(l)
		torches.append(l)
	var walls := StaticBody2D.new()
	walls.collision_layer = Combat.LAYER_WORLD
	add_child(walls)
	for r: Rect2 in [
		Rect2(0, 0, 960, FLOOR.position.y),
		Rect2(0, FLOOR.end.y, 960, 80),
		Rect2(0, 0, FLOOR.position.x, 540),
		Rect2(FLOOR.end.x, 0, 80, 540),
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
	var n: int = EnemyScript.KINDS[enemy_id].coins
	for i: int in n:
		var c := Coin.new()
		actors.add_child(c)
		c.position = position_
		var dest: Vector2 = position_ + Vector2.from_angle(randf() * TAU) * randf_range(10, 28)
		var tw: Tween = c.create_tween()
		tw.tween_property(c, "position", dest, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		var l: PointLight2D = Fx.light(Color(1.0, 0.8, 0.3), 0.5, 0.18)
		l.position = Vector2(0, -6)
		c.add_child(l)
		coins.append(c)
	var skeletons_left: int = 0
	for e in enemies:
		if is_instance_valid(e) and e.kind == &"skeleton" and e.is_targetable():
			skeletons_left += 1
	if skeletons_left == 0 and is_instance_valid(golem):
		_float_text("THE GOLEM AWAKENS", golem.global_position + Vector2(-50, -130), Color(1.0, 0.6, 0.3), 14)
		golem.wake()


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
		&"dodge": [KEY_SPACE, KEY_SHIFT], &"attack": [KEY_J], &"restart": [KEY_R],
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
