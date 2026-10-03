class_name PuzzleGate
extends StaticBody2D
## ประตูหินปริศนา isometric (issue #57)
## เปิดเมื่อ input ทุกตัวใน required on (AND logic) · ปิดกลับถ้า input ใดตัวหนึ่ง off

signal opened
signal closed
signal toggled(on: bool)

@export var required: Array[NodePath] = []

var is_open: bool = false
var collision_shape: CollisionShape2D

var _active_sources: Dictionary = {}
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

	collision_layer = Combat.LAYER_WORLD
	collision_mask = 0

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

	for path in required:
		var node := get_node_or_null(path)
		if node != null:
			if node.has_signal(&"toggled"):
				var cb := Callable(self, &"_on_input_toggled").bind(node)
				if not node.is_connected(&"toggled", cb):
					node.connect(&"toggled", cb)


func activate(source: Node = null) -> void:
	if source != null:
		_active_sources[source.get_instance_id()] = true
	else:
		_active_sources[-1] = true
	_evaluate()


func deactivate(source: Node = null) -> void:
	if source != null:
		_active_sources.erase(source.get_instance_id())
	else:
		_active_sources.erase(-1)
	_evaluate()


func _on_input_toggled(on: bool, source: Node) -> void:
	if on:
		activate(source)
	else:
		deactivate(source)


func _evaluate() -> void:
	var all_on: bool = false
	if required.is_empty():
		all_on = not _active_sources.is_empty()
	else:
		all_on = true
		for path in required:
			var node := get_node_or_null(path)
			if node == null or not _active_sources.has(node.get_instance_id()):
				all_on = false
				break

	if all_on and not is_open:
		open_gate()
	elif not all_on and is_open:
		close_gate()


func open_gate() -> void:
	is_open = true
	if collision_shape != null:
		collision_shape.set_deferred(&"disabled", true)
		collision_shape.disabled = true
	queue_redraw()
	opened.emit()
	toggled.emit(true)


func close_gate() -> void:
	is_open = false
	if collision_shape != null:
		collision_shape.set_deferred(&"disabled", false)
		collision_shape.disabled = false
	queue_redraw()
	closed.emit()
	toggled.emit(false)


func _draw() -> void:
	# Isometric stone gate archway
	var h: float = 36.0
	var pillar_left := PackedVector2Array([
		Vector2(-24, 0),
		Vector2(-16, 4),
		Vector2(-16, 4 - h),
		Vector2(-24, 0 - h),
	])
	var pillar_right := PackedVector2Array([
		Vector2(16, 4),
		Vector2(24, 0),
		Vector2(24, 0 - h),
		Vector2(16, 4 - h),
	])
	var arch_top := PackedVector2Array([
		Vector2(-26, -h),
		Vector2(26, -h),
		Vector2(24, -h - 8),
		Vector2(-24, -h - 8),
	])

	var stone_color := Color(0.38, 0.35, 0.32)
	var shadow_color := Color(0.24, 0.22, 0.20)
	var edge_color := Color(0.16, 0.14, 0.12)

	draw_colored_polygon(pillar_left, stone_color)
	draw_polyline(pillar_left + PackedVector2Array([pillar_left[0]]), edge_color, 1.5)

	draw_colored_polygon(pillar_right, shadow_color)
	draw_polyline(pillar_right + PackedVector2Array([pillar_right[0]]), edge_color, 1.5)

	draw_colored_polygon(arch_top, stone_color)
	draw_polyline(arch_top + PackedVector2Array([arch_top[0]]), edge_color, 1.5)

	# Portcullis bars
	if not is_open:
		var bar_color := Color(0.2, 0.2, 0.22)
		for x in [-10.0, -3.0, 4.0, 11.0]:
			var y_bottom: float = x * 0.25 # diagonal offset
			draw_line(Vector2(x, -h + 2.0), Vector2(x, y_bottom), bar_color, 2.0)
		draw_line(Vector2(-12, -h * 0.5), Vector2(12, -h * 0.5), bar_color, 2.0)
	else:
		# Small indicator rune glows green when open
		draw_circle(Vector2(0, -h - 4.0), 3.0, Color(0.2, 0.9, 0.5, 0.9))
