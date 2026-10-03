class_name RestShrine
extends StaticBody2D
## ศาลเจ้าพักผ่อนและจุดเกิดใหม่ isometric (issue #57)
## กด interact ใกล้ๆ → แสงทอง + EventBus.player_respawn_requested + checkpoint_set(pos)

signal checkpoint_set(position: Vector2)
signal rested

@export var spawn_marker: Marker2D = null

var is_active: bool = false
var collision_shape: CollisionShape2D
var interact_area: Area2D
var point_light: PointLight2D

var _player_in_range: bool = false
var _ready_done: bool = false


func _init() -> void:
	collision_layer = Combat.LAYER_WORLD
	collision_mask = 0


func _ready() -> void:
	setup()


func setup() -> void:
	if _ready_done:
		return
	_ready_done = true

	InteractAction.ensure_registered()

	collision_layer = Combat.LAYER_WORLD
	collision_mask = 0

	collision_shape = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null:
		collision_shape = CollisionShape2D.new()
		collision_shape.name = "CollisionShape2D"
		var circle := CircleShape2D.new()
		circle.radius = 12.0
		collision_shape.shape = circle
		add_child(collision_shape)

	interact_area = get_node_or_null("InteractArea") as Area2D
	if interact_area == null:
		interact_area = Area2D.new()
		interact_area.name = "InteractArea"
		interact_area.collision_layer = 0
		interact_area.collision_mask = Combat.LAYER_PLAYER
		var icol := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 32.0
		icol.shape = circle
		interact_area.add_child(icol)
		add_child(interact_area)
	else:
		interact_area.collision_layer = 0
		interact_area.collision_mask = Combat.LAYER_PLAYER

	if not interact_area.body_entered.is_connected(_on_body_entered):
		interact_area.body_entered.connect(_on_body_entered)
	if not interact_area.body_exited.is_connected(_on_body_exited):
		interact_area.body_exited.connect(_on_body_exited)

	if spawn_marker == null:
		spawn_marker = get_node_or_null("SpawnMarker") as Marker2D
		if spawn_marker == null:
			spawn_marker = Marker2D.new()
			spawn_marker.name = "SpawnMarker"
			spawn_marker.position = Vector2(0, 18)
			add_child(spawn_marker)

	point_light = get_node_or_null("PointLight2D") as PointLight2D
	if point_light == null:
		point_light = PointLight2D.new()
		point_light.name = "PointLight2D"
		point_light.position = Vector2(0, -20)
		point_light.color = Color(1.0, 0.85, 0.3)
		point_light.energy = 1.6
		point_light.enabled = is_active
		point_light.texture = _create_light_texture()
		point_light.texture_scale = 1.8
		add_child(point_light)
	else:
		point_light.enabled = is_active


func _unhandled_input(event: InputEvent) -> void:
	if _player_in_range and event.is_action_pressed(&"interact"):
		rest()


func tick(_delta: float) -> void:
	# Deterministic tick
	pass


func rest() -> void:
	var spawn_pos: Vector2 = spawn_marker.global_position if spawn_marker != null else global_position
	EventBus.player_respawn_requested.emit(spawn_pos)
	checkpoint_set.emit(spawn_pos)
	is_active = true
	if point_light != null:
		point_light.enabled = true
	queue_redraw()
	rested.emit()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group(&"player") or body.name == "Player" or body is Player:
		_player_in_range = true
		queue_redraw()


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group(&"player") or body.name == "Player" or body is Player:
		_player_in_range = false
		queue_redraw()


func _create_light_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	return tex


func _draw() -> void:
	# Isometric Torii / Pagoda stone shrine
	var h: float = 38.0
	var base_pts := PackedVector2Array([
		Vector2(0, -8),
		Vector2(16, 0),
		Vector2(0, 8),
		Vector2(-16, 0),
	])
	draw_colored_polygon(base_pts, Color(0.32, 0.30, 0.33))

	# Left pillar
	draw_line(Vector2(-10, 0), Vector2(-10, -h), Color(0.65, 0.22, 0.18), 4.0)
	# Right pillar
	draw_line(Vector2(10, 0), Vector2(10, -h), Color(0.55, 0.18, 0.15), 4.0)

	# Crossbeam (Lintel)
	var lintel := PackedVector2Array([
		Vector2(-18, -h - 2),
		Vector2(18, -h - 2),
		Vector2(16, -h - 6),
		Vector2(-16, -h - 6),
	])
	draw_colored_polygon(lintel, Color(0.72, 0.25, 0.20))
	draw_line(Vector2(-14, -h + 6), Vector2(14, -h + 6), Color(0.72, 0.25, 0.20), 2.5)

	# Center holy relic / golden bell
	if is_active:
		draw_circle(Vector2(0, -h * 0.5), 5.5, Color(1.0, 0.88, 0.3, 0.95))
		draw_circle(Vector2(0, -h * 0.5), 8.5, Color(1.0, 0.95, 0.6, 0.45))
	else:
		draw_circle(Vector2(0, -h * 0.5), 4.0, Color(0.6, 0.5, 0.3, 0.8))

	# Prompt hint
	if _player_in_range:
		draw_string(ThemeDB.fallback_font, Vector2(-40, -h - 10), "[E] Commune", HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color(1, 0.95, 0.6))
