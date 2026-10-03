class_name PickupShard
extends Area2D
## เศษทองที่เก็บได้บนพื้น (issue #57)
## เก็บแล้วเพิ่มจำนวนใน GoldShards

signal collected(value: int)

@export var value: int = 1

var collision_shape: CollisionShape2D
var _ready_done: bool = false
var _time: float = 0.0


func _init() -> void:
	collision_layer = 0
	collision_mask = Combat.LAYER_PLAYER


func _ready() -> void:
	setup()


func setup() -> void:
	if _ready_done:
		return
	_ready_done = true

	collision_layer = 0
	collision_mask = Combat.LAYER_PLAYER

	collision_shape = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision_shape == null:
		collision_shape = CollisionShape2D.new()
		collision_shape.name = "CollisionShape2D"
		var circle := CircleShape2D.new()
		circle.radius = 12.0
		collision_shape.shape = circle
		add_child(collision_shape)

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	_time += delta
	queue_redraw()


func collect() -> void:
	GoldShards.add(value)
	collected.emit(value)
	queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group(&"player") or body.name == "Player" or body is Player:
		collect()


func _draw() -> void:
	var bob: float = sin(_time * 4.0) * 2.0
	var center := Vector2(0.0, -10.0 + bob)
	# Crystal polygon
	var pts := PackedVector2Array([
		center + Vector2(0, -8),
		center + Vector2(6, 0),
		center + Vector2(0, 8),
		center + Vector2(-6, 0),
	])
	var gold := Color(1.0, 0.85, 0.2, 0.95)
	var glow := Color(1.0, 0.95, 0.5, 0.4)
	draw_circle(center, 9.0, glow)
	draw_colored_polygon(pts, gold)
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color(1.0, 1.0, 0.8, 1.0), 1.0)
