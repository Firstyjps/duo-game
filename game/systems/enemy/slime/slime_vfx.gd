class_name SlimeVfx
extends Node2D
## เอฟเฟกต์ท่าพุ่งของสไลม์ (วาดเองแบบ pixel ไม่ใช้ texture) — ฝุ่นตอนกระโดด · คลื่นกระแทก + เมือกกระเด็นตอนตกพื้น
## spawn ลง parent ของสไลม์ (ไม่ขยับตามตัว) แล้วลบตัวเองเมื่อจบ · แยก tick() ให้เทสต์เรียกได้

const GRAVITY: float = 260.0
const C_SPLASH: Array[Color] = [Color("2f86e8"), Color("43b8f0"), Color("5fe3e6")]
const C_RING := Color("eafaff")
const C_DUST := Color("cfc6b4")

## อนุภาค: pos (บนพื้น), z (ความสูง), vel, vz, life, max_life, size, color
var particles: Array[Dictionary] = []
var ring_radius: float = 0.0
var ring_time: float = 0.0
var _ring_t: float = 0.0


## คลื่นกระแทก + เมือกกระเด็น ตอนสไลม์ตกพื้น
static func spawn_impact(parent: Node, at: Vector2, radius: float, droplets: int) -> SlimeVfx:
	var vfx := SlimeVfx.new()
	vfx.ring_radius = radius
	vfx.ring_time = 0.28
	for i: int in droplets:
		var dir: Vector2 = Vector2.from_angle(TAU * (i + randf() * 0.6) / droplets)
		vfx._add(dir * randf_range(3.0, 6.0), dir * randf_range(40.0, 85.0), randf_range(50.0, 90.0),
			randf_range(0.7, 1.0), 1 + (randi() % 2), C_SPLASH[randi() % C_SPLASH.size()])
	vfx._attach(parent, at)
	return vfx


## ฝุ่นฟุ้งตอนกระโดดขึ้น
static func spawn_dust(parent: Node, at: Vector2, count: int) -> SlimeVfx:
	var vfx := SlimeVfx.new()
	for i: int in count:
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var vel := Vector2(side * randf_range(15.0, 35.0), randf_range(-4.0, 4.0))
		vfx._add(Vector2(side * randf_range(3.0, 7.0), 0.0), vel, randf_range(8.0, 20.0),
			randf_range(0.3, 0.45), 2, C_DUST)
	vfx._attach(parent, at)
	return vfx


func _add(pos: Vector2, vel: Vector2, vz: float, life: float, size: int, color: Color) -> void:
	particles.append({"pos": pos, "z": 0.0, "vel": vel, "vz": vz,
		"life": life, "max_life": life, "size": size, "color": color})


func _attach(parent: Node, at: Vector2) -> void:
	if parent == null:
		return
	parent.add_child(self)
	# y น้อยกว่าสไลม์ 1 px → y-sort วาดไว้หลังตัว (เป็นของบนพื้น)
	global_position = at + Vector2(0, -1)


func is_done() -> bool:
	return particles.is_empty() and _ring_t >= ring_time


func tick(delta: float) -> void:
	_ring_t += delta
	for p: Dictionary in particles:
		p["life"] -= delta
		if p["z"] > 0.0 or p["vz"] > 0.0:
			p["pos"] += p["vel"] * delta
			p["vz"] -= GRAVITY * delta
			p["z"] = maxf(0.0, p["z"] + p["vz"] * delta)
			if p["z"] == 0.0:
				p["vz"] = 0.0  # ตกพื้นแล้วค้างเป็นจุดเมือก จางหายไป
		else:
			p["vel"] *= 0.85
			p["pos"] += p["vel"] * delta
	particles.assign(particles.filter(func(p: Dictionary) -> bool: return p["life"] > 0.0))


func _process(delta: float) -> void:
	tick(delta)
	queue_redraw()
	if is_done():
		queue_free()


func _draw() -> void:
	if _ring_t < ring_time:
		var k: float = _ring_t / ring_time
		var r: float = lerpf(4.0, ring_radius, 1.0 - pow(1.0 - k, 3.0))
		var c: Color = C_RING.lerp(C_SPLASH[1], k)
		c.a = 1.0 - k
		_draw_pixel_ellipse(r, c)
	for p: Dictionary in particles:
		var c: Color = p["color"]
		c.a = clampf(p["life"] / p["max_life"] * 1.5, 0.0, 1.0)
		var at: Vector2 = (p["pos"] + Vector2(0, -p["z"])).round()
		var s: float = p["size"]
		draw_rect(Rect2(at, Vector2(s, s)), c)


## วงรีบนพื้น (สูง 0.45 ของกว้าง) จุดละ 1 px — คม ไม่ blur แบบ draw_arc
func _draw_pixel_ellipse(r: float, c: Color) -> void:
	var steps: int = maxi(12, int(r * 3.0))
	var seen: Dictionary = {}
	for i: int in steps:
		var a: float = TAU * i / steps
		var at: Vector2 = Vector2(cos(a) * r, sin(a) * r * 0.45).round()
		if seen.has(at):
			continue
		seen[at] = true
		draw_rect(Rect2(at, Vector2.ONE), c)
