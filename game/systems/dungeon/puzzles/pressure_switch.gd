class_name PressureSwitch
extends Area2D
## สวิตช์เหยียบ isometric (issue #57)
## ผู้เล่น (layer 2) หรือ PushBlock (layer 1) เหยียบ → on · latch/ไม่ latch · toggled(on) → targets

signal toggled(on: bool)

@export var latch: bool = false
@export var targets: Array[NodePath] = []

var is_on: bool = false
var pressing_bodies: Array[Node2D] = []
var collision_shape: CollisionShape2D

var _ready_done: bool = false


func _init() -> void:
	collision_layer = 0
	collision_mask = Combat.LAYER_PLAYER | Combat.LAYER_WORLD


func _ready() -> void:
	setup()


func setup() -> void:
	if _ready_done:
		return
	_ready_done = true

	collision_layer = 0
	collision_mask = Combat.LAYER_PLAYER | Combat.LAYER_WORLD

	collision_shape = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null:
		collision_shape = CollisionShape2D.new()
		collision_shape.name = "CollisionShape2D"
		var poly := ConvexPolygonShape2D.new()
		poly.points = PackedVector2Array([
			Vector2(0, -12),
			Vector2(24, 0),
			Vector2(0, 12),
			Vector2(-24, 0),
		])
		collision_shape.shape = poly
		add_child(collision_shape)

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)


func tick(_delta: float) -> void:
	# Deterministic tick logic if needed
	pass


func press(body: Node2D = null) -> void:
	if body != null and not pressing_bodies.has(body):
		pressing_bodies.append(body)
	_set_on(true)


func release(body: Node2D = null) -> void:
	if body != null:
		pressing_bodies.erase(body)
	if pressing_bodies.is_empty():
		if not latch:
			_set_on(false)


func _set_on(value: bool) -> void:
	if is_on == value:
		return
	is_on = value
	queue_redraw()
	toggled.emit(is_on)
	_notify_targets(is_on)


func _notify_targets(on: bool) -> void:
	for path in targets:
		var target := get_node_or_null(path)
		if target == null:
			continue
		if on:
			if target.has_method("activate"):
				target.call("activate", self)
		else:
			if target.has_method("deactivate"):
				target.call("deactivate", self)


func _is_valid_body(body: Node2D) -> bool:
	if body == null:
		return false
	if body.is_in_group(&"player") or body.name == "Player" or body is Player:
		return true
	if body is PushBlock or body.has_method("is_push_block") or body.name.begins_with("PushBlock"):
		return true
	return false


func _on_body_entered(body: Node2D) -> void:
	if _is_valid_body(body):
		press(body)


func _on_body_exited(body: Node2D) -> void:
	if _is_valid_body(body):
		release(body)


func _draw() -> void:
	# Isometric diamond plate on ground (64x32 grid size)
	var pts := PackedVector2Array([
		Vector2(0, -12),
		Vector2(24, 0),
		Vector2(0, 12),
		Vector2(-24, 0),
	])
	var border_color := Color(0.25, 0.28, 0.32, 1.0)
	var base_color: Color
	var rune_color: Color
	if is_on:
		base_color = Color(0.18, 0.32, 0.28, 1.0)
		rune_color = Color(0.2, 0.9, 0.6, 0.9)
	else:
		base_color = Color(0.12, 0.14, 0.16, 1.0)
		rune_color = Color(0.3, 0.45, 0.55, 0.5)

	draw_colored_polygon(pts, base_color)
	draw_polyline(pts + PackedVector2Array([pts[0]]), border_color, 2.0)

	# Inner glowing rune
	var inner_pts := PackedVector2Array([
		Vector2(0, -6),
		Vector2(12, 0),
		Vector2(0, 6),
		Vector2(-12, 0),
	])
	draw_polyline(inner_pts + PackedVector2Array([inner_pts[0]]), rune_color, 1.5)
