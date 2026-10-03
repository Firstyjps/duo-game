class_name KintsugiCrack
extends StaticBody2D
## สะพาน/ประตูแตกสไตล์คินสึงิ (issue #57)
## สถานะแตก = กันทาง (layer world) · ผู้เล่นยืนใกล้ + กด interact ค้าง repair_time → ซ่อมด้วยทอง → ผ่านได้

signal repaired
signal progress_changed(progress: float)

@export var cost: int = 3
@export var repair_time: float = 1.0
@export var targets: Array[NodePath] = []

var is_repaired: bool = false
var repair_progress: float = 0.0

var collision_shape: CollisionShape2D
var interact_area: Area2D
var point_light: PointLight2D

var _repair_timer: float = 0.0
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
		var poly := ConvexPolygonShape2D.new()
		poly.points = PackedVector2Array([
			Vector2(0, -12),
			Vector2(24, 0),
			Vector2(0, 12),
			Vector2(-24, 0),
		])
		collision_shape.shape = poly
		add_child(collision_shape)

	interact_area = get_node_or_null("InteractArea") as Area2D
	if interact_area == null:
		interact_area = Area2D.new()
		interact_area.name = "InteractArea"
		interact_area.collision_layer = 0
		interact_area.collision_mask = Combat.LAYER_PLAYER
		var icol := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 28.0
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

	point_light = get_node_or_null("PointLight2D") as PointLight2D
	if point_light == null:
		point_light = PointLight2D.new()
		point_light.name = "PointLight2D"
		point_light.color = Color(1.0, 0.85, 0.25)
		point_light.energy = 0.0
		point_light.enabled = false
		add_child(point_light)


func _process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	if is_repaired:
		return

	if _player_in_range:
		if Input.is_action_pressed(&"interact"):
			if GoldShards.count >= cost:
				_repair_timer += delta
				repair_progress = clampf(_repair_timer / repair_time, 0.0, 1.0)
				progress_changed.emit(repair_progress)
				queue_redraw()
				if _repair_timer >= repair_time:
					try_repair()
			else:
				# Not enough shards
				_repair_timer = 0.0
				repair_progress = 0.0
				progress_changed.emit(0.0)
				queue_redraw()
		else:
			if _repair_timer > 0.0:
				_repair_timer = 0.0
				repair_progress = 0.0
				progress_changed.emit(0.0)
				queue_redraw()


func try_repair() -> bool:
	if is_repaired:
		return false
	if GoldShards.spend(cost):
		is_repaired = true
		repair_progress = 1.0
		if collision_shape != null:
			collision_shape.set_deferred(&"disabled", true)
		if point_light != null:
			point_light.enabled = true
			point_light.energy = 1.0
		queue_redraw()
		repaired.emit()
		_notify_targets(true)
		return true
	return false


func _notify_targets(on: bool) -> void:
	for path in targets:
		var target := get_node_or_null(path)
		if target == null:
			continue
		if on and target.has_method("activate"):
			target.call("activate", self)
		elif not on and target.has_method("deactivate"):
			target.call("deactivate", self)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group(&"player") or body.name == "Player" or body is Player:
		_player_in_range = true
		queue_redraw()


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group(&"player") or body.name == "Player" or body is Player:
		_player_in_range = false
		_repair_timer = 0.0
		repair_progress = 0.0
		queue_redraw()


func _draw() -> void:
	# Isometric floor crack diamond outline
	var pts := PackedVector2Array([
		Vector2(0, -12),
		Vector2(24, 0),
		Vector2(0, 12),
		Vector2(-24, 0),
	])

	# Draw chasm / crack background
	if not is_repaired:
		draw_colored_polygon(pts, Color(0.08, 0.07, 0.06, 0.9))
		# Jagged crack lines
		var crack1 := PackedVector2Array([
			Vector2(-20, 2),
			Vector2(-8, -4),
			Vector2(2, 4),
			Vector2(12, -2),
			Vector2(22, 1),
		])
		var crack2 := PackedVector2Array([
			Vector2(-4, -10),
			Vector2(2, 4),
			Vector2(5, 10),
		])
		draw_polyline(crack1, Color(0.02, 0.02, 0.02), 3.0)
		draw_polyline(crack2, Color(0.02, 0.02, 0.02), 2.5)

		# If repairing, show golden filling progress
		if repair_progress > 0.0:
			var fill_color := Color(1.0, 0.85, 0.2, 0.6 + repair_progress * 0.4)
			draw_polyline(crack1, fill_color, 2.0 * repair_progress + 1.0)
			draw_polyline(crack2, fill_color, 1.5 * repair_progress + 1.0)

		# Prompt hint if player in range
		if _player_in_range:
			var prompt_text := "Hold [E] to Repair (%d/%d shards)" % [GoldShards.count, cost]
			draw_string(ThemeDB.fallback_font, Vector2(-60, -18), prompt_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color(1, 0.9, 0.4))
	else:
		# Repaired: glowing Kintsugi golden veins
		draw_colored_polygon(pts, Color(0.25, 0.23, 0.20, 0.95))
		var gold_vein1 := PackedVector2Array([
			Vector2(-20, 2),
			Vector2(-8, -4),
			Vector2(2, 4),
			Vector2(12, -2),
			Vector2(22, 1),
		])
		var gold_vein2 := PackedVector2Array([
			Vector2(-4, -10),
			Vector2(2, 4),
			Vector2(5, 10),
		])
		draw_polyline(gold_vein1, Color(1.0, 0.88, 0.25, 1.0), 2.5)
		draw_polyline(gold_vein2, Color(1.0, 0.88, 0.25, 1.0), 2.0)
		# Golden glow aura
		draw_circle(Vector2(2, 4), 6.0, Color(1.0, 0.9, 0.3, 0.35))
