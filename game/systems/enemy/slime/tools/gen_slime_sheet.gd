extends SceneTree
## สร้าง sprite sheet สไลม์ (placeholder art แบบ procedural) — แก้สี/ทรงแล้วรันใหม่ได้
## godot --headless --path game --script res://systems/enemy/slime/tools/gen_slime_sheet.gd
## ได้: slime_sheet.png (เฟรม 32×32 เรียงแนวนอน ตาม Slime.FRAMES) + slime_preview.png (ขยาย ×8 ไว้ดู)

const SIZE: int = 32
const OUT_DIR: String = "res://systems/enemy/slime/"

const C_OUTLINE := Color("101a45")
const C_DEEP := Color("1b3a8c")
const C_DARK := Color("2257c4")
const C_MID := Color("2f86e8")
const C_LIGHT := Color("43b8f0")
const C_RIM := Color("5fe3e6")
const C_SHINE := Color("eafaff")
const C_EYE := Color("effdff")
const C_EYE_EDGE := Color("9fe9ff")
const C_EYE_RING := Color("14306e")

## ลำดับต้องตรงกับ Slime.FRAMES — w = ครึ่งความกว้าง, h = ความสูง (px), eye = ความสูงตา (0 = ไม่มีตา)
const FRAME_DEFS: Array[Dictionary] = [
	{"w": 11.0, "h": 17.0, "eye": 4},  # 0 idle
	{"w": 11.5, "h": 16.0, "eye": 4},  # 1 idle
	{"w": 12.0, "h": 15.0, "eye": 3},  # 2 idle
	{"w": 11.5, "h": 16.0, "eye": 4},  # 3 idle
	{"w": 13.0, "h": 13.0, "eye": 3},  # 4 windup
	{"w": 14.0, "h": 11.0, "eye": 2},  # 5 windup (ย่อสุด = ใกล้พุ่ง)
	{"w": 9.0, "h": 21.0, "eye": 5},   # 6 leap
	{"w": 13.5, "h": 12.5, "eye": 3},  # 7 land
	{"w": 14.0, "h": 9.0, "eye": 2},   # 8 death
	{"w": 15.0, "h": 6.0, "eye": 0},   # 9 death
	{"w": 15.0, "h": 3.0, "eye": 0},   # 10 death (แอ่ง)
]
const BASE_Y: float = 30.0


func _init() -> void:
	var sheet := Image.create_empty(SIZE * FRAME_DEFS.size(), SIZE, false, Image.FORMAT_RGBA8)
	for i: int in FRAME_DEFS.size():
		_draw_frame(sheet, i * SIZE, FRAME_DEFS[i])
	# หยดน้ำกระเด็นตอนตายเฟรมสุดท้าย
	var last: int = (FRAME_DEFS.size() - 1) * SIZE
	for p: Vector2i in [Vector2i(5, 22), Vector2i(27, 21), Vector2i(9, 19)]:
		sheet.set_pixel(last + p.x, p.y, C_MID)
		sheet.set_pixel(last + p.x, p.y + 1, C_OUTLINE)
	sheet.save_png(ProjectSettings.globalize_path(OUT_DIR + "slime_sheet.png"))
	_save_preview(sheet)
	print("slime sheet: %d frames" % FRAME_DEFS.size())
	quit()


func _inside(px: float, py: float, cx: float, cy: float, w: float, h: float) -> bool:
	var dx: float = (px - cx) / w
	if py < cy:
		var dy: float = (py - cy) / (h * 0.55)
		return dx * dx + dy * dy <= 1.0
	var dyb: float = (py - cy) / (h * 0.45)
	return pow(absf(dx), 4.0) + pow(absf(dyb), 4.0) <= 1.0


func _draw_frame(img: Image, ox: int, d: Dictionary) -> void:
	var w: float = d["w"]
	var h: float = d["h"]
	var cx: float = SIZE / 2.0
	var cy: float = BASE_Y - h * 0.45
	var mask: Array[bool] = []
	mask.resize(SIZE * SIZE)
	for y: int in SIZE:
		for x: int in SIZE:
			mask[y * SIZE + x] = _inside(x + 0.5, y + 0.5, cx, cy, w, h)
	for y: int in SIZE:
		for x: int in SIZE:
			if not mask[y * SIZE + x]:
				continue
			var edge: bool = x == 0 or y == 0 or x == SIZE - 1 or y == SIZE - 1 \
				or not mask[y * SIZE + x - 1] or not mask[y * SIZE + x + 1] \
				or not mask[(y - 1) * SIZE + x] or not mask[(y + 1) * SIZE + x]
			img.set_pixel(ox + x, y, C_OUTLINE if edge else _shade(x + 0.5, y + 0.5, cx, cy, w, h))
	# ขอบสะท้อนแสงสีฟ้าอมเขียวด้านบนซ้าย (ตาม ref)
	for y: int in SIZE:
		for x: int in range(1, SIZE - 1):
			if img.get_pixel(ox + x, y) == C_LIGHT and x < cx and y < cy \
					and (img.get_pixel(ox + x - 1, y) == C_OUTLINE or img.get_pixel(ox + x, y - 1) == C_OUTLINE):
				img.set_pixel(ox + x, y, C_RIM)
	if h >= 8.0:
		_shine(img, ox, int(cx - w * 0.45), int(cy - h * 0.25), w, h)
	if d["eye"] > 0:
		var ey: int = int(round(cy + h * 0.02 - d["eye"] / 2.0))
		var gap: int = 3 if w < 10.0 else 4
		_eye(img, ox + int(cx) - gap - 1, ey, d["eye"])
		_eye(img, ox + int(cx) + gap - 1, ey, d["eye"])


## แสงมาจากบนซ้าย · ล่างกลางมืดสุด (โพรงใสของเจลลี่)
func _shade(px: float, py: float, cx: float, cy: float, w: float, h: float) -> Color:
	var nx: float = (px - cx) / w
	var ny: float = (py - cy) / (h * 0.55)
	var t: float = (ny + 1.0) * 0.5 + nx * 0.18
	if ny > 0.35 and absf(nx) < 0.55:
		return C_DEEP
	if t < 0.3:
		return C_LIGHT
	if t < 0.55:
		return C_MID
	if t < 0.8:
		return C_DARK
	return C_DEEP


## ไฮไลต์รูปบวก + จุดเล็ก (ตาม ref)
func _shine(img: Image, ox: int, x: int, y: int, w: float, h: float) -> void:
	for p: Vector2i in [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
		_put(img, ox, x + p.x, y + p.y, C_SHINE)
	_put(img, ox, x + int(w * 0.55), y - 1 - int(h * 0.08), C_SHINE)


func _eye(img: Image, x: int, y: int, eh: int) -> void:
	for yy: int in range(y - 1, y + eh + 1):
		for xx: int in range(x - 1, x + 3):
			var corner: bool = (xx == x - 1 or xx == x + 2) and (yy == y - 1 or yy == y + eh)
			if not corner:
				img.set_pixel(xx, yy, C_EYE_RING)
	for yy: int in range(y, y + eh):
		img.set_pixel(x, yy, C_EYE_EDGE)
		img.set_pixel(x + 1, yy, C_EYE)


func _put(img: Image, ox: int, x: int, y: int, c: Color) -> void:
	if x >= 0 and x < SIZE and y >= 0 and y < SIZE and img.get_pixel(ox + x, y).a > 0.0 \
			and img.get_pixel(ox + x, y) != C_OUTLINE:
		img.set_pixel(ox + x, y, c)


func _save_preview(sheet: Image) -> void:
	const SCALE: int = 8
	var pv := Image.create_empty(sheet.get_width() * SCALE, sheet.get_height() * SCALE, false, Image.FORMAT_RGBA8)
	for y: int in pv.get_height():
		for x: int in pv.get_width():
			var checker: bool = ((x / 32) + (y / 32)) % 2 == 0
			pv.set_pixel(x, y, Color("2a2d36") if checker else Color("23252d"))
	pv.blend_rect(_scaled(sheet, SCALE), Rect2i(Vector2i.ZERO, pv.get_size()), Vector2i.ZERO)
	pv.save_png(ProjectSettings.globalize_path(OUT_DIR + "tools/slime_preview.png"))


func _scaled(src: Image, s: int) -> Image:
	var out: Image = src.duplicate()
	out.resize(src.get_width() * s, src.get_height() * s, Image.INTERPOLATE_NEAREST)
	return out
