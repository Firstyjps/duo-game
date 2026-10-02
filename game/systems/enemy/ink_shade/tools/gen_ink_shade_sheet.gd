extends SceneTree
## สร้าง sprite sheet ศัตรู "เงาหมึก" Ink Shade 8 ทิศ (placeholder art วาดด้วยโค้ด)
## วิญญาณหมึกดำม่วง ขอบเรืองแสงทอง ถือดาบสั้น ตัวสูง ~48 px
## 8 แถว = ทิศ (S, SE, E, NE, N, NW, W, SW)
## เฟรม 64×64: idle 4 · เดิน 6 · ง้าง (telegraph) 3 · ฟัน 3 · โดนตี 2 · ตาย 6 (รวม 24 คอลัมน์)
## รัน: godot --headless --path game --script res://systems/enemy/ink_shade/tools/gen_ink_shade_sheet.gd

const SIZE: int = 64
const CX: float = 32.0
const FEET: float = 56.0
const OUT_DIR: String = "res://systems/enemy/ink_shade/"
const LIGHT := Vector2(-0.55, -0.83)

const DIRS: Array[Dictionary] = [
	{"name": "S", "deg": 0.0},
	{"name": "SE", "deg": 45.0},
	{"name": "E", "deg": 90.0},
	{"name": "NE", "deg": 135.0},
	{"name": "N", "deg": 180.0},
	{"name": "NW", "deg": 225.0},
	{"name": "W", "deg": 270.0},
	{"name": "SW", "deg": 315.0},
]

const IDLE_FRAMES: int = 4
const WALK_FRAMES: int = 6
const WINDUP_FRAMES: int = 3
const SLASH_FRAMES: int = 3
const HURT_FRAMES: int = 2
const DEAD_FRAMES: int = 6
const TOTAL_COLS: int = IDLE_FRAMES + WALK_FRAMES + WINDUP_FRAMES + SLASH_FRAMES + HURT_FRAMES + DEAD_FRAMES

# จานสีหมึกดำม่วง
const INK_CORE: Color = Color("0d0716")
const INK_DEEP: Color = Color("190d2e")
const INK_DARK: Color = Color("281545")
const INK_MID: Color = Color("3e1f68")
const INK_LIGHT: Color = Color("5c3094")
const INK_PAL: Array[Color] = [INK_LIGHT, INK_MID, INK_DARK, INK_DEEP]

# จานสีทองเรืองแสง
const GOLD_HOT: Color = Color("fff5c0")
const GOLD_BRIGHT: Color = Color("ffd700")
const GOLD_MID: Color = Color("e0a526")
const GOLD_DARK: Color = Color("8c6010")
const GOLD_PAL: Array[Color] = [GOLD_HOT, GOLD_BRIGHT, GOLD_MID, GOLD_DARK]

# จานสีดาบ
const STEEL_EDGE: Color = Color("f4f6fa")
const STEEL_BRIGHT: Color = Color("cdd4e0")
const STEEL_MID: Color = Color("7b8599")
const STEEL_DARK: Color = Color("404857")
const STEEL_PAL: Array[Color] = [STEEL_EDGE, STEEL_BRIGHT, STEEL_MID, STEEL_DARK]

var img: Image
var _R := Vector2.ZERO
var _F := Vector2.ZERO
var _parts: Array[Dictionary] = []
var _lift: float = 0.0
var _facing_cam: float = 0.0


func _init() -> void:
	var total_w: int = TOTAL_COLS * SIZE
	var total_h: int = DIRS.size() * SIZE
	var sheet := Image.create_empty(total_w, total_h, false, Image.FORMAT_RGBA8)

	for row: int in DIRS.size():
		var th: float = deg_to_rad(float(DIRS[row]["deg"]))
		_F = Vector2(sin(th), cos(th))
		_R = Vector2(-cos(th), sin(th))
		_facing_cam = _F.y

		for col: int in TOTAL_COLS:
			var pose: Dictionary
			if col < IDLE_FRAMES:
				pose = _idle_pose(col)
			elif col < IDLE_FRAMES + WALK_FRAMES:
				pose = _walk_pose(col - IDLE_FRAMES)
			elif col < IDLE_FRAMES + WALK_FRAMES + WINDUP_FRAMES:
				pose = _windup_pose(col - IDLE_FRAMES - WALK_FRAMES)
			elif col < IDLE_FRAMES + WALK_FRAMES + WINDUP_FRAMES + SLASH_FRAMES:
				pose = _slash_pose(col - IDLE_FRAMES - WALK_FRAMES - WINDUP_FRAMES)
			elif col < IDLE_FRAMES + WALK_FRAMES + WINDUP_FRAMES + SLASH_FRAMES + HURT_FRAMES:
				pose = _hurt_pose(col - IDLE_FRAMES - WALK_FRAMES - WINDUP_FRAMES - SLASH_FRAMES)
			else:
				pose = _dead_pose(col - (TOTAL_COLS - DEAD_FRAMES))

			img = Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
			_build(pose)
			_render()
			_outline(pose.get("glow_power", 1.0))
			_post_effects(pose)

			sheet.blit_rect(img, Rect2i(0, 0, SIZE, SIZE), Vector2i(col * SIZE, row * SIZE))

	var out_path: String = ProjectSettings.globalize_path(OUT_DIR + "ink_shade_sheet.png")
	sheet.save_png(out_path)
	_save_preview(sheet)
	print("ink shade sheet generated: %d dirs × %d frames -> %s" % [DIRS.size(), TOTAL_COLS, out_path])
	quit()


# ─────────────────────────── ท่าทาง (Poses) ───────────────────────────

func _idle_pose(i: int) -> Dictionary:
	var ph: float = TAU * float(i) / float(IDLE_FRAMES)
	var bob: float = sin(ph) * 1.5
	var sway: float = cos(ph) * 1.0
	return {
		"bob": bob,
		"sway": sway,
		"lean_fwd": 0.0,
		"hand_r": Vector3(7.5, 24.0 + bob * 0.4, 2.5),
		"sword_dir": Vector3(0.3, -0.65, 0.7).normalized(),
		"hand_l": Vector3(-7.5, 23.0 + bob * 0.4, 2.0),
		"glow_power": 1.0,
		"wisps_spread": 1.0,
		"dead": false,
		"dissolve": 0.0,
		"slash_fx": 0,
	}


func _walk_pose(i: int) -> Dictionary:
	var ph: float = TAU * float(i) / float(WALK_FRAMES)
	var bob: float = absf(sin(ph)) * 1.8
	var sway: float = sin(ph) * 2.5
	return {
		"bob": bob,
		"sway": sway,
		"lean_fwd": 4.5,
		"hand_r": Vector3(7.5, 24.0 + sin(ph) * 2.0, 3.0 + cos(ph) * 2.0),
		"sword_dir": Vector3(0.35, -0.5, 0.8).normalized(),
		"hand_l": Vector3(-7.5, 23.0 - sin(ph) * 2.0, 2.0 - cos(ph) * 2.0),
		"glow_power": 1.1,
		"wisps_spread": 1.3,
		"dead": false,
		"dissolve": 0.0,
		"slash_fx": 0,
	}


func _windup_pose(i: int) -> Dictionary:
	# ค้างง้าง telegraph: ดาบชูขึ้นสูง-ไปข้างหลัง ลำตัวเอนกลับ แสงทองแผ่
	var k: float = float(i) / float(WINDUP_FRAMES - 1)
	var glow: float = lerpf(1.4, 2.2, k)
	var lean: float = lerpf(-2.0, -5.5, k)
	var bob: float = lerpf(0.5, 2.0, k)
	return {
		"bob": bob,
		"sway": 0.0,
		"lean_fwd": lean,
		"hand_r": Vector3(8.0 + k * 1.5, 34.0 + k * 5.0, -2.0 - k * 5.0),
		"sword_dir": Vector3(0.1, 0.75, -0.65).normalized(),
		"hand_l": Vector3(-8.0, 26.0, 4.0),
		"glow_power": glow,
		"wisps_spread": 0.8,
		"dead": false,
		"dissolve": 0.0,
		"slash_fx": 0,
	}


func _slash_pose(i: int) -> Dictionary:
	# ฟัน: พุ่งไปข้างหน้า ดาบกวาดเฉียงลง
	if i == 0:
		# เริ่มกวาด
		return {
			"bob": -1.0,
			"sway": 0.0,
			"lean_fwd": 7.0,
			"hand_r": Vector3(4.0, 32.0, 6.0),
			"sword_dir": Vector3(0.5, 0.2, 0.8).normalized(),
			"hand_l": Vector3(-8.5, 20.0, -3.0),
			"glow_power": 1.6,
			"wisps_spread": 1.4,
			"dead": false,
			"dissolve": 0.0,
			"slash_fx": 1,
		}
	elif i == 1:
		# ฟันสุดทาง (Active Hitbox frame)
		return {
			"bob": -2.0,
			"sway": 0.0,
			"lean_fwd": 9.5,
			"hand_r": Vector3(-2.0, 22.0, 11.0),
			"sword_dir": Vector3(-0.7, -0.3, 0.65).normalized(),
			"hand_l": Vector3(-9.0, 18.0, -5.0),
			"glow_power": 1.8,
			"wisps_spread": 1.6,
			"dead": false,
			"dissolve": 0.0,
			"slash_fx": 2,
		}
	else:
		# Follow-through
		return {
			"bob": 0.0,
			"sway": 0.0,
			"lean_fwd": 5.0,
			"hand_r": Vector3(-5.0, 19.0, 8.0),
			"sword_dir": Vector3(-0.8, -0.4, 0.4).normalized(),
			"hand_l": Vector3(-8.0, 21.0, -2.0),
			"glow_power": 1.2,
			"wisps_spread": 1.2,
			"dead": false,
			"dissolve": 0.0,
			"slash_fx": 0,
		}


func _hurt_pose(i: int) -> Dictionary:
	var rec: float = 1.0 - float(i) * 0.4
	return {
		"bob": 1.0 * rec,
		"sway": -2.0 * rec,
		"lean_fwd": -7.0 * rec,
		"hand_r": Vector3(9.0, 28.0, -3.0),
		"sword_dir": Vector3(0.5, 0.3, -0.8).normalized(),
		"hand_l": Vector3(-9.0, 27.0, -2.0),
		"glow_power": 1.5,
		"wisps_spread": 1.8,
		"dead": false,
		"dissolve": 0.0,
		"slash_fx": 0,
	}


func _dead_pose(i: int) -> Dictionary:
	var dis: float = float(i) / float(DEAD_FRAMES - 1)
	return {
		"bob": -dis * 14.0,
		"sway": sin(dis * PI * 2.0) * 1.5,
		"lean_fwd": dis * 4.0,
		"hand_r": Vector3(7.0 + dis * 6.0, 20.0 - dis * 18.0, 4.0 + dis * 5.0),
		"sword_dir": Vector3(0.4, -0.8 + dis * 0.5, 0.5).normalized(),
		"hand_l": Vector3(-7.0 - dis * 4.0, 20.0 - dis * 16.0, 3.0),
		"glow_power": maxf(0.0, 1.3 - dis * 1.5),
		"wisps_spread": 1.0 + dis * 2.0,
		"dead": true,
		"dissolve": dis,
		"slash_fx": 0,
	}


# ─────────────────────────── โครงร่าง 3D ───────────────────────────

func _build(p: Dictionary) -> void:
	_parts.clear()
	var bob: float = p["bob"]
	var lean: float = p["lean_fwd"]
	var sway: float = p["sway"]
	var dis: float = p["dissolve"]
	var dead: bool = p["dead"]

	_lift = bob

	if dis >= 0.8:
		# เฟรมสุดท้ายแทบจางหมด เหลือแอ่งหมึกจาง ๆ
		_parts.append({"d": 0.0, "fn": _draw_pool.bind(dis)})
		return

	# ส่วนฐาน: ลำตัวหมึกและริ้วหมึกที่พลิ้วไหว
	var waist_y: float = 18.0 + bob * 0.5
	var chest_y: float = 30.0 + bob * 0.7
	var head_y: float = 40.0 + bob * 0.9

	# ริ้วหมึกด้านล่าง (Tendrils) 4 เส้น
	var spread: float = p["wisps_spread"]
	for k: int in 4:
		var ang: float = TAU * float(k) / 4.0
		var r_base: float = 4.0 * spread
		var t_top := Vector3(cos(ang) * r_base, waist_y, sin(ang) * r_base)
		var t_mid := Vector3(cos(ang + 0.5) * (r_base + 3.0), waist_y * 0.5, sin(ang + 0.5) * (r_base + 3.0) - lean * 0.3)
		var t_bot := Vector3(cos(ang + 1.0) * (r_base + 5.0) + sway * 0.8, 1.0, sin(ang + 1.0) * (r_base + 4.0) - lean * 0.8)
		_cap(t_top, t_mid, 3.5 * (1.0 - dis * 0.5), 2.5 * (1.0 - dis * 0.5), INK_PAL, "ink_wisp")
		_cap(t_mid, t_bot, 2.5 * (1.0 - dis * 0.5), 1.0 * (1.0 - dis * 0.5), INK_PAL, "ink_wisp")

	# แกนกลางช่วงล่าง (Lower Cloak)
	_ell(Vector3(0, waist_y, lean * 0.2), 7.5 * (1.0 - dis * 0.4), 6.5, 6.5, INK_PAL, "mantle")

	# หน้าอก / เสื้อคลุม (Upper Mantle)
	var chest_pos := Vector3(0, chest_y, lean * 0.5)
	_ell(chest_pos, 8.5 * (1.0 - dis * 0.3), 7.5, 7.5, INK_PAL, "mantle")

	# ปลอกไหล่ / บ่าหมึก
	for side: float in [-1.0, 1.0]:
		var sh_pos := Vector3(8.5 * side, chest_y + 1.0, lean * 0.5)
		_ell(sh_pos, 4.0, 3.5, 4.0, INK_PAL, "mantle")

	# หัวและฮู้ด (Hood & Head)
	var head_pos := Vector3(0, head_y, lean * 0.8)
	_ell(head_pos, 6.8 * (1.0 - dis * 0.2), 7.8, 7.0, INK_PAL, "hood")

	# ตาเรืองแสงทอง (ถ้าหน้าไม่หันหลัง)
	if not dead and _facing_cam > -0.35:
		_parts.append({"d": _w(head_pos).z + 5.0, "fn": _draw_eyes.bind(head_pos, p.get("glow_power", 1.0))})

	# แขนซ้าย (มือเปล่าหมึก)
	var hand_l: Vector3 = p["hand_l"]
	var sh_l := Vector3(-8.5, chest_y + 1.0, lean * 0.5)
	var elbow_l: Vector3 = (sh_l + hand_l) * 0.5 + Vector3(-2.0, -1.0, 0.0)
	_cap(sh_l, elbow_l, 3.0, 2.4, INK_PAL, "arm")
	_cap(elbow_l, hand_l, 2.4, 2.0, INK_PAL, "arm")
	_ell(hand_l, 2.2, 2.0, 2.2, INK_PAL, "hand")

	# แขนขวาและดาบสั้น (Right Arm & Short Sword)
	var hand_r: Vector3 = p["hand_r"]
	var sh_r := Vector3(8.5, chest_y + 1.0, lean * 0.5)
	var elbow_r: Vector3 = (sh_r + hand_r) * 0.5 + Vector3(2.0, -1.0, 0.0)
	_cap(sh_r, elbow_r, 3.0, 2.4, INK_PAL, "arm")
	_cap(elbow_r, hand_r, 2.4, 2.0, INK_PAL, "arm")
	_ell(hand_r, 2.2, 2.0, 2.2, INK_PAL, "hand")

	# ดาบสั้น
	var s_dir: Vector3 = p["sword_dir"]
	_parts.append({"d": _w(hand_r).z + 2.0, "fn": _draw_sword.bind(hand_r, s_dir, p.get("glow_power", 1.0))})

	# แอ่งหมึกที่พื้นตอนใกล้ตาย
	if dis > 0.1:
		_parts.append({"d": -10.0, "fn": _draw_pool.bind(dis)})


# ─────────────────────────── การฉายภาพ 3D → 2D ───────────────────────────

func _w(l: Vector3) -> Vector3:
	return Vector3(l.x * _R.x + l.z * _F.x, l.y, l.x * _R.y + l.z * _F.y)


func _scr(l: Vector3) -> Vector2:
	var w: Vector3 = _w(l)
	# isometric / 3/4 top-down: y ขึ้นจอ, z เข้าหาผู้เล่นเฉียงลง
	return Vector2(CX + w.x, FEET - (w.y + _lift) * 0.85 + w.z * 0.42)


func _cap(a: Vector3, b: Vector3, ra: float, rb: float, pal: Array[Color], tag: String = "", bias: float = 0.0) -> void:
	var d: float = (_w(a).z + _w(b).z) * 0.5 + bias
	_parts.append({"d": d, "fn": _draw_cap.bind(_scr(a), _scr(b), ra, rb, pal, tag)})


func _ell(c: Vector3, a: float, b: float, cz: float, pal: Array[Color], tag: String = "", bias: float = 0.0) -> void:
	_parts.append({"d": _w(c).z + bias, "fn": _draw_ell.bind(c, a, b, cz, pal, tag)})


func _render() -> void:
	_parts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["d"] < b["d"])
	for part: Dictionary in _parts:
		(part["fn"] as Callable).call()


# ─────────────────────────── การวาด 2D พิกเซล ───────────────────────────

func _px(x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < SIZE and y < SIZE:
		img.set_pixel(x, y, c)


func _draw_cap(a: Vector2, b: Vector2, ra: float, rb: float, pal: Array[Color], tag: String) -> void:
	var r: float = maxf(ra, rb)
	var ab: Vector2 = b - a
	var len2: float = maxf(ab.length_squared(), 0.0001)
	for y: int in range(int(minf(a.y, b.y) - r) - 1, int(maxf(a.y, b.y) + r) + 2):
		for x: int in range(int(minf(a.x, b.x) - r) - 1, int(maxf(a.x, b.x) + r) + 2):
			var p := Vector2(x + 0.5, y + 0.5)
			var t: float = clampf((p - a).dot(ab) / len2, 0.0, 1.0)
			var rr: float = lerpf(ra, rb, t)
			var d: Vector2 = p - (a + ab * t)
			var l: float = d.length() / maxf(rr, 0.5)
			if l > 1.0:
				continue
			var n: Vector2 = d / maxf(rr, 0.5)
			var col: Color = _shade_color(n, pal, x, y)
			_px(x, y, col)


func _draw_ell(c: Vector3, a: float, b: float, cz: float, pal: Array[Color], tag: String) -> void:
	var sc: Vector2 = _scr(c)
	var rx: float = maxf(sqrt(pow(a * _R.x, 2.0) + pow(cz * _F.x, 2.0)), 1.0)
	var ry: float = maxf(sqrt(pow(b * 0.85, 2.0) + pow(a * _R.y * 0.42, 2.0) + pow(cz * _F.y * 0.42, 2.0)), 1.0)
	for y: int in range(int(sc.y - ry) - 1, int(sc.y + ry) + 2):
		for x: int in range(int(sc.x - rx) - 1, int(sc.x + rx) + 2):
			var n := Vector2((x + 0.5 - sc.x) / rx, (y + 0.5 - sc.y) / ry)
			var l: float = n.length()
			if l > 1.0:
				continue
			var col: Color = _shade_color(n, pal, x, y)
			if tag == "hood" and _facing_cam > 0.1:
				# โพรงหน้ามืดสนิทใต้ฮู้ด
				var inner: float = n.length()
				if inner < 0.65 and n.y > -0.2:
					col = INK_CORE
			_px(x, y, col)


func _shade_color(n: Vector2, pal: Array[Color], x: int, y: int) -> Color:
	var lit: float = n.dot(LIGHT) * 0.8 + 0.2
	var checker: bool = (x + y) % 2 == 0
	if lit > 0.45:
		return pal[0]
	elif lit > 0.15:
		return pal[0] if checker else pal[1]
	elif lit > -0.25:
		return pal[1] if checker else pal[2]
	elif lit > -0.55:
		return pal[2] if checker else pal[3]
	return pal[3]


func _draw_eyes(head_pos: Vector3, glow_p: float) -> void:
	var sc: Vector2 = _scr(head_pos)
	var cam_x: float = _R.x
	# ตาซ้ายและขวา
	var eye_col: Color = GOLD_HOT if glow_p > 1.4 else GOLD_BRIGHT
	var eye_y: int = int(sc.y - 0.5)

	# ระยะห่างของตาสองข้างตามมุมมอง
	var sep: float = 3.2 * absf(_facing_cam) + 1.2
	var center_x: float = sc.x + cam_x * 1.5

	for side: float in [-1.0, 1.0]:
		var ex: int = int(round(center_x + side * sep))
		# ตาสองพิกเซลเรืองแสง
		_px(ex, eye_y, eye_col)
		if glow_p > 1.3:
			_px(ex, eye_y - 1, GOLD_MID)
			_px(ex + int(side), eye_y, GOLD_HOT)


func _draw_sword(hand: Vector3, dir: Vector3, glow_p: float) -> void:
	var h_scr: Vector2 = _scr(hand)
	var tip_pos: Vector3 = hand + dir * 18.0
	var tip_scr: Vector2 = _scr(tip_pos)
	var pommel_pos: Vector3 = hand - dir * 4.0
	var pommel_scr: Vector2 = _scr(pommel_pos)

	# ด้ามและหัวด้ามทอง
	_cap_line(pommel_scr, h_scr, 1.4, GOLD_MID)
	_px(int(pommel_scr.x), int(pommel_scr.y), GOLD_BRIGHT)

	# โกร่งดาบ (Guard) ขวางทิศดาบ
	var s_axis: Vector2 = (tip_scr - h_scr).normalized()
	var s_perp := Vector2(-s_axis.y, s_axis.x)
	var g1: Vector2 = h_scr - s_perp * 3.5
	var g2: Vector2 = h_scr + s_perp * 3.5
	_cap_line(g1, g2, 1.5, GOLD_BRIGHT)

	# ใบดาบ (Blade) ค่อย ๆ เรียวลง
	_cap_line(h_scr, tip_scr, 2.0, STEEL_MID)
	# คมดาบขัดเงาสว่าง
	_cap_line(h_scr + s_perp * 0.8, tip_scr, 1.0, STEEL_EDGE if glow_p <= 1.3 else GOLD_HOT)

	if glow_p > 1.3:
		# แสงเรืองทองรอบดาบช่วง telegraph
		_px(int(tip_scr.x), int(tip_scr.y), GOLD_HOT)
		_px(int(tip_scr.x + s_perp.x), int(tip_scr.y + s_perp.y), GOLD_BRIGHT)


func _cap_line(a: Vector2, b: Vector2, r: float, c: Color) -> void:
	var ab: Vector2 = b - a
	var len2: float = maxf(ab.length_squared(), 0.0001)
	var r_int: int = int(ceil(r))
	for y: int in range(int(minf(a.y, b.y) - r_int), int(maxf(a.y, b.y) + r_int) + 1):
		for x: int in range(int(minf(a.x, b.x) - r_int), int(maxf(a.x, b.x) + r_int) + 1):
			var p := Vector2(x + 0.5, y + 0.5)
			var t: float = clampf((p - a).dot(ab) / len2, 0.0, 1.0)
			var d: Vector2 = p - (a + ab * t)
			if d.length() <= r:
				_px(x, y, c)


func _draw_pool(dis: float) -> void:
	var cx: int = int(CX)
	var cy: int = int(FEET)
	var rx: float = 14.0 * dis
	var ry: float = 6.0 * dis
	var alpha: float = clampf(1.0 - (dis - 0.2) / 0.8, 0.0, 1.0)
	var pool_col := Color(INK_DARK.r, INK_DARK.g, INK_DARK.b, alpha)
	var rim_col := Color(GOLD_MID.r, GOLD_MID.g, GOLD_MID.b, alpha * 0.7)

	for y: int in range(int(cy - ry) - 1, int(cy + ry) + 2):
		for x: int in range(int(cx - rx) - 1, int(cx + rx) + 2):
			var dx: float = (x + 0.5 - cx) / maxf(rx, 1.0)
			var dy: float = (y + 0.5 - cy) / maxf(ry, 1.0)
			var dist2: float = dx * dx + dy * dy
			if dist2 <= 1.0:
				if dist2 > 0.75:
					_px(x, y, rim_col)
				else:
					_px(x, y, pool_col)


# ─────────────────────────── ขอบเรืองแสงทอง (Golden Rim Outline) ───────────────────────────

func _outline(glow_p: float) -> void:
	var solid: Array[bool] = []
	solid.resize(SIZE * SIZE)
	for y: int in SIZE:
		for x: int in SIZE:
			solid[y * SIZE + x] = img.get_pixel(x, y).a > 0.05

	for y: int in SIZE:
		for x: int in SIZE:
			if solid[y * SIZE + x]:
				continue
			var has_neighbor: bool = false
			var min_dist_y: int = 0
			for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
								Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
				var q: Vector2i = Vector2i(x, y) + o
				if q.x >= 0 and q.y >= 0 and q.x < SIZE and q.y < SIZE and solid[q.y * SIZE + q.x]:
					has_neighbor = true
					min_dist_y = o.y
					break

			if has_neighbor:
				# ขอบทอง: ด้านบนสว่างกว่า ด้านล่างมืดกว่า (ตามแสง)
				var rim: Color
				if min_dist_y >= 0:
					rim = GOLD_BRIGHT if glow_p > 1.2 else GOLD_MID
				else:
					rim = GOLD_MID if glow_p > 1.2 else GOLD_DARK
				if glow_p > 1.5 and (x + y) % 2 == 0:
					rim = GOLD_HOT
				_px(x, y, rim)


func _post_effects(p: Dictionary) -> void:
	var fx: int = p.get("slash_fx", 0)
	if fx > 0:
		# เส้นประกายฟันโค้ง (Slash Arc Trail)
		var center := Vector2(CX, FEET - 22.0)
		var forward := Vector2(_F.x, _F.y * 0.5).normalized()
		var perp := Vector2(-forward.y, forward.x)
		var arc_p: Vector2 = center + forward * (14.0 if fx == 1 else 20.0)

		for t: int in range(-8, 9):
			var ft: float = float(t) / 8.0
			var pt: Vector2 = arc_p + perp * (ft * 16.0) - forward * (absf(ft) * 7.0)
			var col: Color = GOLD_HOT if absf(ft) < 0.3 else (GOLD_BRIGHT if absf(ft) < 0.7 else INK_LIGHT)
			_px(int(pt.x), int(pt.y), col)
			_px(int(pt.x + forward.x), int(pt.y + forward.y), GOLD_MID)


func _save_preview(sheet: Image) -> void:
	const SCALE: int = 2
	var pv := Image.create_empty(sheet.get_width() * SCALE, sheet.get_height() * SCALE, false, Image.FORMAT_RGBA8)
	pv.fill(Color("14161f"))
	var big: Image = sheet.duplicate()
	big.resize(sheet.get_width() * SCALE, sheet.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
	pv.blend_rect(big, Rect2i(Vector2i.ZERO, pv.get_size()), Vector2i.ZERO)
	var pv_path: String = ProjectSettings.globalize_path(OUT_DIR + "tools/ink_shade_preview.png")
	pv.save_png(pv_path)
