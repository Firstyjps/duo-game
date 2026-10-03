class_name PushBlock
extends CharacterBody2D
## บล็อกหินดันได้ isometric (issue #57)
## ผู้เล่นดันค้าง push_time ในทิศ iso 4 แนวแกน grid จากตำแหน่ง (บล็อก - ผู้เล่น)
## เลื่อนทีละ 1 cell ถ้าปลายทางว่าง (intersect_shape world และไม่ติด blocked_cells) · tween

signal pushed(dir: Vector2)
signal moved(new_position: Vector2)

const ART_TEXTURE: Texture2D = preload("res://systems/dungeon/puzzles/art/push_block.png")

@export var push_time: float = 0.35
@export var push_grace_time: float = 0.12
@export var move_duration: float = 0.25
@export var grid_layer: TileMapLayer = null
@export var blocked_cells: Array[Vector2i] = []

var is_moving: bool = false
var collision_shape: CollisionShape2D
var detect_area: Area2D
var sprite: Sprite2D
var current_cell: Vector2i = Vector2i.ZERO

var _push_timer: float = 0.0
var _grace_timer: float = 0.0
var _pushing_player: Node2D = null
var _last_player_pos: Vector2 = Vector2.ZERO
var _last_player_move_dir: Vector2 = Vector2.ZERO
var _has_last_player_pos: bool = false
var _ready_done: bool = false
var _move_tween: Tween = null


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

	sprite = get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = "Sprite2D"
		sprite.texture = ART_TEXTURE
		sprite.centered = false
		sprite.offset = Vector2(-32, -48)
		add_child(sprite)
	else:
		sprite.texture = ART_TEXTURE
		sprite.centered = false
		sprite.offset = Vector2(-32, -48)

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
			Vector2(0, -20),
			Vector2(36, 0),
			Vector2(0, 20),
			Vector2(-36, 0),
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


func reset_to(pos: Vector2) -> void:
	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()
		_move_tween = null
	is_moving = false
	_push_timer = 0.0
	_grace_timer = 0.0
	global_position = pos
	if grid_layer != null:
		current_cell = grid_layer.local_to_map(grid_layer.to_local(global_position))


func _physics_process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	if is_moving:
		_push_timer = 0.0
		_grace_timer = 0.0
		return

	if _pushing_player == null and detect_area != null and detect_area.is_inside_tree():
		for b in detect_area.get_overlapping_bodies():
			if b.is_in_group(&"player") or b.name == "Player":
				set_pushing_player(b)
				break

	if _pushing_player == null and is_inside_tree():
		var tree := get_tree()
		if tree != null:
			for p in tree.get_nodes_in_group(&"player"):
				if p is Node2D and is_in_detect_area((p as Node2D).global_position):
					set_pushing_player(p as Node2D)
					break

	if _pushing_player != null and is_instance_valid(_pushing_player):
		if not is_in_detect_area(_pushing_player.global_position):
			set_pushing_player(null)
			return

		var cur_pos: Vector2 = _pushing_player.global_position
		var p_delta: Vector2 = Vector2.ZERO
		if _has_last_player_pos:
			p_delta = cur_pos - _last_player_pos
		else:
			_has_last_player_pos = true
		_last_player_pos = cur_pos

		var to_block: Vector2 = global_position - cur_pos
		var is_pushing: bool = false

		# Input ผู้เล่นเป็นเกณฑ์หลัก: อ่าน move_dir ของ body ที่ชน
		# p_delta เป็น fallback เท่านั้น
		var input_dir: Vector2 = Vector2.ZERO
		if "move_dir" in _pushing_player and (_pushing_player.move_dir as Vector2).length_squared() > 0.01:
			input_dir = (_pushing_player.move_dir as Vector2).normalized()
		elif p_delta.length_squared() > 0.0001:
			input_dir = p_delta.normalized()
		elif "velocity" in _pushing_player and (_pushing_player.velocity as Vector2).length_squared() > 0.01:
			input_dir = (_pushing_player.velocity as Vector2).normalized()

		if input_dir != Vector2.ZERO:
			_last_player_move_dir = input_dir
			if to_block.length_squared() > 0.0001:
				var dot: float = input_dir.dot(to_block.normalized())
				if dot > 0.5:
					is_pushing = true

		if is_pushing:
			# ป้องกันการไถลตามผิวข้าวหลามตัดขณะผู้เล่นออกแรงดันบล็อก
			if p_delta.length_squared() > 0.0001:
				_pushing_player.global_position -= p_delta
				_last_player_pos = _pushing_player.global_position

			_grace_timer = 0.0
			_push_timer += delta
			if _push_timer >= push_time:
				var step: Vector2i = get_push_cell_step()
				if step != Vector2i.ZERO:
					try_push_step(step)
				_push_timer = 0.0
		else:
			if _push_timer > 0.0:
				_grace_timer += delta
				if _grace_timer >= push_grace_time:
					_push_timer = 0.0
					_grace_timer = 0.0
	else:
		_push_timer = 0.0
		_grace_timer = 0.0
		_has_last_player_pos = false


func get_push_cell_step() -> Vector2i:
	if _pushing_player == null or not is_instance_valid(_pushing_player):
		return Vector2i.ZERO
	var to_block: Vector2 = global_position - _pushing_player.global_position
	var push_vec: Vector2 = _last_player_move_dir
	if push_vec.length_squared() < 0.0001:
		push_vec = to_block
	return snap_to_cell_step(push_vec, to_block, grid_layer)


static func snap_to_cell_step(push_dir: Vector2, fallback_dir: Vector2 = Vector2.ZERO, layer: TileMapLayer = null) -> Vector2i:
	if push_dir.length_squared() < 0.0001:
		if fallback_dir.length_squared() < 0.0001:
			return Vector2i.ZERO
		push_dir = fallback_dir
		fallback_dir = Vector2.ZERO
	var norm_dir: Vector2 = push_dir.normalized()
	var candidates: Array[Vector2i] = [
		Vector2i(1, 0),   # down-right
		Vector2i(0, 1),   # down-left
		Vector2i(-1, 0),  # up-left
		Vector2i(0, -1),  # up-right
	]

	var candidate_vectors: Array[Vector2] = []
	for step in candidates:
		var step_vec: Vector2 = Vector2.ZERO
		if layer != null:
			step_vec = (layer.map_to_local(step) - layer.map_to_local(Vector2i.ZERO)).normalized()
		else:
			step_vec = Vector2(
				float(step.x - step.y) * 32.0,
				float(step.x + step.y) * 16.0
			).normalized()
		candidate_vectors.append(step_vec)

	var max_dot: float = -2.0
	for i: int in range(candidates.size()):
		var d: float = norm_dir.dot(candidate_vectors[i])
		if d > max_dot:
			max_dot = d

	# Find candidates tied within tolerance (0.04)
	var tied_indices: Array[int] = []
	for i: int in range(candidates.size()):
		var d: float = norm_dir.dot(candidate_vectors[i])
		if absf(d - max_dot) <= 0.04:
			tied_indices.append(i)

	if tied_indices.size() == 1 or fallback_dir.length_squared() < 0.0001:
		return candidates[tied_indices[0]]

	# Break tie using fallback direction
	var best_idx: int = tied_indices[0]
	var best_fallback_dot: float = -2.0
	var norm_fallback: Vector2 = fallback_dir.normalized()
	for idx in tied_indices:
		var fd: float = norm_fallback.dot(candidate_vectors[idx])
		if fd > best_fallback_dot:
			best_fallback_dot = fd
			best_idx = idx

	return candidates[best_idx]



static func direction_to_cell_step(dir: Vector2, layer: TileMapLayer = null) -> Vector2i:
	return snap_to_cell_step(dir, Vector2.ZERO, layer)


func get_cell_step_for_dir(dir: Vector2) -> Vector2i:
	return snap_to_cell_step(dir, _last_player_move_dir, grid_layer)


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


func is_cell_blocked(step: Vector2i) -> bool:
	if grid_layer != null:
		var cur_map: Vector2i = grid_layer.local_to_map(grid_layer.to_local(global_position))
		var target_map: Vector2i = cur_map + step
		if target_map in blocked_cells:
			return true
	else:
		if (current_cell + step) in blocked_cells:
			return true
	var target_pos: Vector2 = get_target_position_for_step(step)
	return is_target_blocked(target_pos)


func try_push_dir(dir: Vector2) -> bool:
	var step: Vector2i = get_cell_step_for_dir(dir)
	return try_push_step(step)


func try_push_step(step: Vector2i) -> bool:
	if is_moving or step == Vector2i.ZERO:
		return false
	if is_cell_blocked(step):
		return false
	var target_pos: Vector2 = get_target_position_for_step(step)
	pushed.emit(Vector2(step))
	_start_move(target_pos, step)
	return true


func _start_move(target_pos: Vector2, step: Vector2i = Vector2i.ZERO) -> void:
	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()
		_move_tween = null
	is_moving = true
	if is_inside_tree():
		_move_tween = create_tween()
		if _move_tween != null:
			_move_tween.tween_property(self, "global_position", target_pos, move_duration)
			_move_tween.finished.connect(func() -> void:
				is_moving = false
				_move_tween = null
				current_cell += step
				moved.emit(global_position)
			)
			return
	global_position = target_pos
	is_moving = false
	current_cell += step
	moved.emit(global_position)


func is_in_detect_area(pos: Vector2) -> bool:
	if _pushing_player != null and is_instance_valid(_pushing_player):
		if detect_area != null and detect_area.is_inside_tree() and detect_area.overlaps_body(_pushing_player):
			return true
		if _pushing_player is CharacterBody2D:
			for i in range((_pushing_player as CharacterBody2D).get_slide_collision_count()):
				var col: KinematicCollision2D = (_pushing_player as CharacterBody2D).get_slide_collision(i)
				if col != null and col.get_collider() == self:
					return true
	var local_p: Vector2 = to_local(pos)
	return (absf(local_p.x) / 56.0 + absf(local_p.y) / 30.0) <= 1.0


func set_pushing_player(body: Node2D) -> void:
	if body != null:
		_pushing_player = body
		_last_player_pos = body.global_position
		_has_last_player_pos = true
	else:
		_pushing_player = null
		_has_last_player_pos = false
	_push_timer = 0.0
	_grace_timer = 0.0


func _on_detect_body_entered(body: Node2D) -> void:
	if body.is_in_group(&"player") or body.name == "Player":
		set_pushing_player(body)


func _on_detect_body_exited(body: Node2D) -> void:
	if body == _pushing_player:
		if not is_in_detect_area(body.global_position):
			set_pushing_player(null)

