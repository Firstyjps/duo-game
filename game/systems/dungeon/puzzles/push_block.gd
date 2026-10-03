class_name PushBlock
extends CharacterBody2D
## บล็อกหินดันได้ isometric (issue #57)
## ผู้เล่นดันค้าง push_time ในทิศ iso 4 แนวแกน grid → เลื่อนทีละ 1 cell ถ้าปลายทางว่าง (intersect_shape world) · tween

signal pushed(dir: Vector2)
signal moved(new_position: Vector2)

@export var push_time: float = 0.35
@export var move_duration: float = 0.25
@export var grid_layer: TileMapLayer = null

var is_moving: bool = false
var collision_shape: CollisionShape2D
var detect_area: Area2D

var _push_timer: float = 0.0
var _pushing_player: Node2D = null
var _ready_done: bool = false


func _init() -> void:
	collision_layer = Combat.LAYER_WORLD
	collision_mask = Combat.LAYER_WORLD


func _ready() -> void:
	setup()


func setup() -> void:
	if _ready_done:
		return
	_ready_done = true

	collision_layer = Combat.LAYER_WORLD
	collision_mask = Combat.LAYER_WORLD

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

	detect_area = get_node_or_null("DetectArea") as Area2D
	if detect_area == null:
		detect_area = Area2D.new()
		detect_area.name = "DetectArea"
		detect_area.collision_layer = 0
		detect_area.collision_mask = Combat.LAYER_PLAYER
		var dcol := CollisionShape2D.new()
		var dpoly := ConvexPolygonShape2D.new()
		dpoly.points = PackedVector2Array([
			Vector2(0, -16),
			Vector2(32, 0),
			Vector2(0, 16),
			Vector2(-32, 0),
		])
		dcol.shape = dpoly
		detect_area.add_child(dcol)
		add_child(detect_area)
	else:
		detect_area.collision_layer = 0
		detect_area.collision_mask = Combat.LAYER_PLAYER

	if not detect_area.body_entered.is_connected(_on_detect_body_entered):
		detect_area.body_entered.connect(_on_detect_body_entered)
	if not detect_area.body_exited.is_connected(_on_detect_body_exited):
		detect_area.body_exited.connect(_on_detect_body_exited)


func is_push_block() -> bool:
	return true


func _physics_process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	if is_moving:
		_push_timer = 0.0
		return

	if _pushing_player != null and is_instance_valid(_pushing_player):
		var p_vel: Vector2 = Vector2.ZERO
		if "velocity" in _pushing_player:
			p_vel = _pushing_player.velocity
		var to_block: Vector2 = (global_position - _pushing_player.global_position).normalized()
		# Player is pushing if moving towards block
		if p_vel.length_squared() > 100.0 and p_vel.normalized().dot(to_block) > 0.35:
			_push_timer += delta
			if _push_timer >= push_time:
				try_push_dir(p_vel.normalized())
				_push_timer = 0.0
		else:
			_push_timer = 0.0
	else:
		_push_timer = 0.0


static func direction_to_cell_step(dir: Vector2, layer: TileMapLayer = null) -> Vector2i:
	if dir.length_squared() < 0.0001:
		return Vector2i.ZERO
	var norm_dir: Vector2 = dir.normalized()
	# 4 isometric cell steps
	var candidates: Array[Vector2i] = [
		Vector2i(1, 0),   # down-right
		Vector2i(0, 1),   # down-left
		Vector2i(-1, 0),  # up-left
		Vector2i(0, -1),  # up-right
	]
	var best_step: Vector2i = candidates[0]
	var best_dot: float = -2.0
	for step in candidates:
		var step_vec: Vector2 = Vector2.ZERO
		if layer != null:
			step_vec = (layer.map_to_local(step) - layer.map_to_local(Vector2i.ZERO)).normalized()
		else:
			step_vec = Vector2(
				float(step.x - step.y) * 32.0,
				float(step.x + step.y) * 16.0
			).normalized()
		var d: float = norm_dir.dot(step_vec)
		if d > best_dot:
			best_dot = d
			best_step = step
	return best_step


func get_cell_step_for_dir(dir: Vector2) -> Vector2i:
	return direction_to_cell_step(dir, grid_layer)


func get_target_position_for_step(step: Vector2i) -> Vector2:
	if grid_layer != null:
		var cur_map: Vector2i = grid_layer.local_to_map(grid_layer.to_local(global_position))
		var target_map: Vector2i = cur_map + step
		return grid_layer.to_global(grid_layer.map_to_local(target_map))
	else:
		var offset := Vector2(
			float(step.x - step.y) * 32.0,
			float(step.x + step.y) * 16.0
		)
		return global_position + offset


func is_target_blocked(target_pos: Vector2) -> bool:
	var space_state: PhysicsDirectSpaceState2D = null
	if is_inside_tree():
		var w2d := get_world_2d()
		if w2d != null:
			space_state = w2d.direct_space_state
	if space_state == null:
		var tree := Engine.get_main_loop() as SceneTree
		if tree != null and tree.root != null and tree.root.get_world_2d() != null:
			space_state = tree.root.get_world_2d().direct_space_state
	if space_state == null:
		return false

	var query := PhysicsShapeQueryParameters2D.new()
	if collision_shape != null and collision_shape.shape != null:
		query.shape = collision_shape.shape
	else:
		var s := ConvexPolygonShape2D.new()
		s.points = PackedVector2Array([
			Vector2(0, -12),
			Vector2(24, 0),
			Vector2(0, 12),
			Vector2(-24, 0),
		])
		query.shape = s
	query.transform = Transform2D(0, target_pos)
	query.collision_mask = Combat.LAYER_WORLD
	query.exclude = [get_rid()]

	var hits: Array[Dictionary] = space_state.intersect_shape(query, 1)
	return not hits.is_empty()


func try_push_dir(dir: Vector2) -> bool:
	var step: Vector2i = get_cell_step_for_dir(dir)
	return try_push_step(step)


func try_push_step(step: Vector2i) -> bool:
	if is_moving or step == Vector2i.ZERO:
		return false
	var target_pos: Vector2 = get_target_position_for_step(step)
	if is_target_blocked(target_pos):
		return false
	pushed.emit(Vector2(step))
	_start_move(target_pos)
	return true


func _start_move(target_pos: Vector2) -> void:
	is_moving = true
	if is_inside_tree():
		var tween := create_tween()
		if tween != null:
			tween.tween_property(self, "global_position", target_pos, move_duration)
			tween.finished.connect(func() -> void:
				is_moving = false
				moved.emit(global_position)
			)
			return
	global_position = target_pos
	is_moving = false
	moved.emit(global_position)


func _on_detect_body_entered(body: Node2D) -> void:
	if body.is_in_group(&"player") or body.name == "Player" or body is Player:
		_pushing_player = body


func _on_detect_body_exited(body: Node2D) -> void:
	if body == _pushing_player:
		_pushing_player = null
		_push_timer = 0.0


func _draw() -> void:
	# Isometric block drawing: height = 28px, base 64x32 diamond
	var h: float = 24.0
	# Top diamond face
	var top_pts := PackedVector2Array([
		Vector2(0, -12 - h),
		Vector2(24, 0 - h),
		Vector2(0, 12 - h),
		Vector2(-24, 0 - h),
	])
	# Left face
	var left_pts := PackedVector2Array([
		Vector2(-24, 0 - h),
		Vector2(0, 12 - h),
		Vector2(0, 12),
		Vector2(-24, 0),
	])
	# Right face
	var right_pts := PackedVector2Array([
		Vector2(0, 12 - h),
		Vector2(24, 0 - h),
		Vector2(24, 0),
		Vector2(0, 12),
	])

	# Colors: shaded stone
	var top_color := Color(0.48, 0.44, 0.38, 1.0)
	var left_color := Color(0.32, 0.28, 0.24, 1.0)
	var right_color := Color(0.24, 0.20, 0.18, 1.0)
	var line_color := Color(0.15, 0.12, 0.10, 1.0)

	draw_colored_polygon(left_pts, left_color)
	draw_colored_polygon(right_pts, right_color)
	draw_colored_polygon(top_pts, top_color)

	draw_polyline(top_pts + PackedVector2Array([top_pts[0]]), line_color, 1.5)
	draw_polyline(left_pts + PackedVector2Array([left_pts[0]]), line_color, 1.5)
	draw_polyline(right_pts + PackedVector2Array([right_pts[0]]), line_color, 1.5)
