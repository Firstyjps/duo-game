class_name TelegraphMarker
extends Node2D
## วงเตือนบนพื้นตรงจุดที่ท่าโจมตีจะลง — ศัตรูทุกตัวใช้ร่วมกันได้ (กติกา: ทุกท่าต้อง telegraph)
## ตั้ง `top_level = true` ใน scene ไม่งั้นวงจะวิ่งตามตัวศัตรู

@export var radius: float = 18.0
@export var color: Color = Color(1.0, 0.35, 0.25)
## มุมกล้อง top-down 3/4 → วงบนพื้นเป็นวงรี
@export var squash: float = 0.55

## 0 = เพิ่งเริ่มเตือน · 1 = กำลังจะโจมตี (วงในขยายเต็มวงนอก)
var progress: float = 0.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		queue_redraw()


func show_at(pos: Vector2) -> void:
	global_position = pos
	progress = 0.0
	visible = true


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, squash))
	draw_circle(Vector2.ZERO, radius, Color(color, 0.12))
	draw_circle(Vector2.ZERO, radius * progress, Color(color, 0.32))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(color, 0.85), 1.0)
