class_name IsoTallBlock
extends StaticBody2D
## บล็อกทรงสูงมุมมอง Isometric 2.5D สำหรับทดสอบระบบกล้องและการบัง (Occlusion)
## มี origin อยู่ที่ฐานเท้า (y-sort) และมี Area2D ตรวจจับการบังสไปรต์ตัวละคร

@export var block_height: float = 64.0
@export var base_width: float = 64.0
@export var base_depth: float = 32.0

var occlusion_area: Area2D
var base_shape: CollisionShape2D


func _ready() -> void:
	collision_layer = 1 # layer world
	collision_mask = 0

	# 1. Collision ฐานสำหรับการชนทางกายภาพของผู้เล่น (ไม่ให้เดินทะลุฐานบล็อก)
	base_shape = get_node_or_null("BaseShape") as CollisionShape2D
	if base_shape == null:
		base_shape = CollisionShape2D.new()
		base_shape.name = "BaseShape"
		add_child(base_shape)
		var shape := RectangleShape2D.new()
		shape.size = Vector2(base_width * 0.75, base_depth * 0.75)
		base_shape.shape = shape
		base_shape.position = Vector2(0, 0)

	# 2. Area2D ครอบคลุมความสูงของบล็อกเพื่อตรวจจับการบังตัวละครที่อยู่ข้างหลัง
	occlusion_area = get_node_or_null("OcclusionArea") as Area2D
	if occlusion_area == null:
		occlusion_area = Area2D.new()
		occlusion_area.name = "OcclusionArea"
		add_child(occlusion_area)
		occlusion_area.collision_layer = 1
		occlusion_area.collision_mask = 0
		var occ_shape := CollisionShape2D.new()
		occ_shape.name = "CollisionShape2D"
		var rect_shape := RectangleShape2D.new()
		rect_shape.size = Vector2(base_width * 0.9, block_height)
		occ_shape.shape = rect_shape
		occ_shape.position = Vector2(0, -block_height * 0.5)
		occlusion_area.add_child(occ_shape)

	queue_redraw()


func _draw() -> void:
	var hw: float = base_width * 0.5
	var hh: float = base_depth * 0.5
	var h: float = block_height

	# จุดยอดบนระนาบพื้น (origin = 0,0)
	var b_top := Vector2(0, -hh)
	var b_right := Vector2(hw, 0)
	var b_bottom := Vector2(0, hh)
	var b_left := Vector2(-hw, 0)

	# จุดยอดบนหลังคาบล็อก (ลอยขึ้นไปตามแกน y = -h)
	var t_top := b_top + Vector2(0, -h)
	var t_right := b_right + Vector2(0, -h)
	var t_bottom := b_bottom + Vector2(0, -h)
	var t_left := b_left + Vector2(0, -h)

	# 1. หน้าซ้าย (Medium shadow)
	var left_poly := PackedVector2Array([t_left, t_bottom, b_bottom, b_left])
	draw_colored_polygon(left_poly, Color(0.26, 0.30, 0.38))
	draw_polyline(left_poly, Color(0.18, 0.20, 0.26), 1.0)

	# 2. หน้าขวา (Darker shadow)
	var right_poly := PackedVector2Array([t_bottom, t_right, b_right, b_bottom])
	draw_colored_polygon(right_poly, Color(0.18, 0.22, 0.28))
	draw_polyline(right_poly, Color(0.12, 0.15, 0.20), 1.0)

	# 3. หน้าบน (Top light face)
	var top_poly := PackedVector2Array([t_top, t_right, t_bottom, t_left])
	draw_colored_polygon(top_poly, Color(0.42, 0.48, 0.58))
	draw_polyline(top_poly, Color(0.55, 0.62, 0.72), 1.0)
