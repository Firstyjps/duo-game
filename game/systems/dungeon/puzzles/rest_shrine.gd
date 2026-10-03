class_name RestShrine
extends StaticBody2D
## ศาลเจ้าพักผ่อนและจุดเกิดใหม่ isometric (issue #57)
## ใช้ได้เมื่อไม่มีศัตรูในรัศมี rest_safe_radius และพ้น cooldown rest_cooldown
## กด interact ใกล้ๆ → แสงทอง + EventBus.player_respawn_requested + checkpoint_set(pos)

signal checkpoint_set(position: Vector2)
signal rested

const ART_TEXTURE: Texture2D = preload("res://systems/dungeon/puzzles/art/shrine.png")

@export var rest_safe_radius: float = 240.0
@export var rest_cooldown: float = 3.0
@export var spawn_marker: Marker2D = null

var is_active: bool = false
var collision_shape: CollisionShape2D
var interact_area: Area2D
var safe_area: Area2D
var point_light: PointLight2D
var sprite: Sprite2D

var _cooldown_timer: float = 0.0
var _player_in_range: bool = false
var _enemies_in_range: Array[Node2D] = []
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

	sprite = get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = "Sprite2D"
		sprite.texture = ART_TEXTURE
		sprite.centered = false
		sprite.offset = Vector2(-64, -100)
		add_child(sprite)
	else:
		sprite.texture = ART_TEXTURE
		sprite.centered = false
		sprite.offset = Vector2(-64, -100)

	collision_shape = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null:
		collision_shape = CollisionShape2D.new()
		collision_shape.name = "CollisionShape2D"
		var circle := CircleShape2D.new()
		circle.radius = 16.0
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

	safe_area = get_node_or_null("SafeArea") as Area2D
	if safe_area == null:
		safe_area = Area2D.new()
		safe_area.name = "SafeArea"
		safe_area.collision_layer = 0
		safe_area.collision_mask = Combat.LAYER_ENEMY
		var scol := CollisionShape2D.new()
		var scircle := CircleShape2D.new()
		scircle.radius = rest_safe_radius
		scol.shape = scircle
		safe_area.add_child(scol)
		add_child(safe_area)
	else:
		safe_area.collision_layer = 0
		safe_area.collision_mask = Combat.LAYER_ENEMY

	if not safe_area.body_entered.is_connected(_on_enemy_entered):
		safe_area.body_entered.connect(_on_enemy_entered)
	if not safe_area.body_exited.is_connected(_on_enemy_exited):
		safe_area.body_exited.connect(_on_enemy_exited)

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
		point_light.position = Vector2(0, -48)
		point_light.color = Color(1.0, 0.85, 0.3)
		point_light.energy = 1.6
		point_light.enabled = is_active
		point_light.texture = _create_light_texture()
		point_light.texture_scale = 1.8
		add_child(point_light)
	else:
		point_light.position = Vector2(0, -48)
		point_light.enabled = is_active


func _process(delta: float) -> void:
	tick(delta)


func _unhandled_input(event: InputEvent) -> void:
	if _player_in_range and event.is_action_pressed(&"interact"):
		rest()


func tick(delta: float) -> void:
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta


func has_enemies_nearby() -> bool:
	_enemies_in_range = _enemies_in_range.filter(func(b: Node2D) -> bool: return is_instance_valid(b))
	if not _enemies_in_range.is_empty():
		return true
	if safe_area != null and safe_area.is_inside_tree():
		for b in safe_area.get_overlapping_bodies():
			if is_instance_valid(b) and (b.is_in_group(&"enemy") or ("team" in b and b.team == Combat.Team.ENEMY)):
				return true
	return false


func can_rest() -> bool:
	return _cooldown_timer <= 0.0 and not has_enemies_nearby()


func rest() -> bool:
	if not can_rest():
		return false
	_cooldown_timer = rest_cooldown
	var spawn_pos: Vector2 = spawn_marker.global_position if spawn_marker != null else global_position
	EventBus.player_respawn_requested.emit(spawn_pos)
	checkpoint_set.emit(spawn_pos)
	is_active = true
	if point_light != null:
		point_light.enabled = true
	queue_redraw()
	rested.emit()
	return true


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group(&"player") or body.name == "Player" or body is Player:
		_player_in_range = true
		queue_redraw()


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group(&"player") or body.name == "Player" or body is Player:
		_player_in_range = false
		queue_redraw()


func _on_enemy_entered(body: Node2D) -> void:
	if body != null and not _enemies_in_range.has(body):
		_enemies_in_range.append(body)
		queue_redraw()


func _on_enemy_exited(body: Node2D) -> void:
	if body != null:
		_enemies_in_range.erase(body)
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
	# Center holy relic / golden glow overlay
	if is_active:
		draw_circle(Vector2(0, -48), 6.0, Color(1.0, 0.88, 0.3, 0.95))
		draw_circle(Vector2(0, -48), 12.0, Color(1.0, 0.95, 0.6, 0.45))

	# Prompt hint
	if _player_in_range:
		var text := "[E] Commune"
		var col := Color(1, 0.95, 0.6)
		if has_enemies_nearby():
			text = "Cannot rest (Enemies nearby!)"
			col = Color(1.0, 0.4, 0.4)
		elif _cooldown_timer > 0.0:
			text = "Resting... (%.1fs)" % _cooldown_timer
			col = Color(0.7, 0.7, 0.7)
		draw_string(ThemeDB.fallback_font, Vector2(-60, -85), text, HORIZONTAL_ALIGNMENT_CENTER, -1, 10, col)
