extends SceneTree
## สร้าง sprite sheet บอสสไลม์ (placeholder art แบบ procedural) — แก้สี/ทรงแล้วรันใหม่ได้
## สไตล์ตาม ref ที่ Few ส่ง (บอส Monstrous Droop ใน Dimraeth — วาดเองใหม่ ไม่ใช้ภาพเขา): ก้อนเมือกฟ้าใส ขอบเรืองแสง (ไม่มีเส้นขอบดำ) · ด้านบนเป็นฟองเล็กเป็นกระจุก
## หน้าเป็นโพรงตา 2 ช่อง + โพรงปาก มืดลึกแบบหัวกะโหลก · ฐานไหลเยิ้มแผ่บนพื้น ขอบเป็นคลื่น
## godot --headless --path game --script res://systems/enemy/boss_slime/tools/gen_boss_slime_sheet.gd
## ได้: boss_slime_sheet.png (เฟรม 128×128 เรียงแนวนอน) + tools/boss_slime_preview.png (ขยาย ×3 ไว้ดู)

const SIZE: int = 128
const OUT_DIR: String = "res://systems/enemy/boss_slime/"
const BASE_Y: float = 120.0

const C_GLOW := Color("b8f6ff")   # ขอบเรืองแสงด้านบน
const C_RIM := Color("74dcff")
const C_LIGHT := Color("4cc4ff")
const C_BODY := Color("2fa2f2")
const C_MID := Color("2581dc")
const C_DEEP := Color("1b5fbf")
const C_SEAM := Color("1a4fa6")   # ร่องระหว่างฟอง
const C_SKIRT_EDGE := Color("3fb4fa")
const C_HOLE_RIM := Color("123f8f")
const C_HOLE := Color("0b2766")
const C_HOLE_DEEP := Color("061a4a")
const C_SHINE := Color("eafcff")
const C_ABYSS := Color("163a82")      # ล่างสุดของตัว (เงาหนักกดพื้น)
const C_CRYSTAL_DARK := Color("1f86c9")
const C_CRYSTAL_EDGE := Color("0f3f86")
const C_EYE_HALO := Color("4a1450")   # แสงแดงจางรอบลูกตาในโพรงมืด
const C_EYE_GLOW := Color("ff3b6b")   # ตาเรืองแสงแดง — สีตรงข้ามตัว ดูอันตราย
const C_EYE_CORE := Color("ffd6e0")
const C_THROAT := Color("b0204f")     # คอเรืองแดงจากข้างใน
const C_THROAT_DEEP := Color("4d0d38")
const C_T_LIGHT := Color("7af5e6")  # ฟองด้านบนโทน teal
const C_T_BODY := Color("3ad3dc")
const C_T_MID := Color("2aa7d6")
const C_DEBRIS_LIGHT := Color("5c9fe6")
const C_STEEL := Color("c9d6e3")      # ใบดาบส่วนที่โผล่นอกตัว
const C_STEEL_DARK := Color("7c8ea3")
const C_STEEL_IN := Color("8fd0f0")   # ใบดาบที่จมอยู่ในเนื้อ (ติดสีเมือก)
const C_HILT := Color("6b3b22")
const C_HILT_LIGHT := Color("c58a3e")
const C_DEBRIS := Color("1c56b4")  # ของจมในเมือก (กระดูก/หัวกะโหลก) — เข้มกว่าเนื้อนิดเดียว ให้ดูอยู่ข้างใน
const C_GEM := Color("6fe9ff")     # คริสตัลในตัว (เข้ากับคริสตัลในถ้ำ)
const C_GEM_LIGHT := Color("e6feff")

const LIGHT := Vector2(-0.6, -0.8)

## w = ครึ่งความกว้างตัว, h = ความสูงตัว (ไม่รวมฐาน) · skirt = ฐานแผ่กว้างกี่เท่าของตัว · spiky = ขอบฐานเป็นแฉก (ตอนทุบ)
## face = open / half / closed / squint / wide / tall / flat / melt / none · bumps = จำนวนฟองด้านบน (ตอนตายแตกหาย)
## wob = เฟสกระเพื่อม · glow = แอ่งเรืองแสง (ตอนตาย) · ขนาดคิดในเฟรม 96 (บอสสูง ~3 เท่าผู้เล่น)
const FRAME_DEFS: Array[Dictionary] = [
	# 0–7 idle: หายใจหนัก ๆ ฟองกระเพื่อม ขอบฐานไหลเป็นคลื่น
	{"w": 31.0, "h": 60.0, "skirt": 1.35, "face": "open", "bumps": 24, "wob": 0.0},    # 0
	{"w": 30.5, "h": 61.5, "skirt": 1.33, "face": "open", "bumps": 24, "wob": 0.8},    # 1
	{"w": 30.0, "h": 63.0, "skirt": 1.3, "face": "open", "bumps": 24, "wob": 1.6},     # 2 ยืดสุด
	{"w": 30.5, "h": 61.5, "skirt": 1.33, "face": "open", "bumps": 24, "wob": 2.4},    # 3
	{"w": 31.0, "h": 60.0, "skirt": 1.35, "face": "open", "bumps": 24, "wob": 3.1},    # 4
	{"w": 32.0, "h": 58.5, "skirt": 1.38, "face": "open", "bumps": 24, "wob": 3.9},    # 5
	{"w": 33.0, "h": 57.0, "skirt": 1.4, "face": "open", "bumps": 24, "wob": 4.7},     # 6 ย่อสุด
	{"w": 32.0, "h": 58.5, "skirt": 1.38, "face": "open", "bumps": 24, "wob": 5.5},    # 7
	# 8–9 กระพริบ (โพรงตาหรี่ลง)
	{"w": 31.0, "h": 60.0, "skirt": 1.35, "face": "half", "bumps": 24, "wob": 3.1},    # 8
	{"w": 32.0, "h": 58.5, "skirt": 1.38, "face": "closed", "bumps": 24, "wob": 3.9},  # 9
	# 10–11 windup: ย่อตัวแผ่ออก (ก่อนกระโดด / ก่อนยืดเสา)
	{"w": 35.0, "h": 51.0, "skirt": 1.3, "face": "wide", "bumps": 24, "wob": 0.4},     # 10
	{"w": 38.0, "h": 44.0, "skirt": 1.25, "face": "wide", "bumps": 24, "wob": 0.8},    # 11 ย่อสุด
	# 12–13 rise: ยืดขึ้นเป็นเสา โพรงหน้ายืดยาว ฐานยังแผ่บนพื้น (telegraph ก่อนทุบ)
	{"w": 25.0, "h": 74.0, "skirt": 1.75, "face": "tall", "bumps": 24, "wob": 1.2},    # 12
	{"w": 22.0, "h": 84.0, "skirt": 2.0, "face": "tall", "bumps": 24, "wob": 1.8},     # 13 สูงสุด
	# 14–15 slam: ทุบลงแผ่แบน ขอบฐานเป็นแฉก
	{"w": 42.0, "h": 26.0, "skirt": 1.12, "face": "flat", "bumps": 18, "wob": 0.5, "spiky": 1.0, "sk_h": 9.0},  # 14 กระแทก
	{"w": 38.0, "h": 38.0, "skirt": 1.2, "face": "wide", "bumps": 24, "wob": 1.0, "spiky": 0.5, "sk_h": 7.0},   # 15 เด้งกลับ
	# 16 hurt: โพรงตาบีบเป็นขีด
	{"w": 31.0, "h": 60.0, "skirt": 1.35, "face": "squint", "bumps": 24, "wob": 2.0},  # 16
	# 17–19 death: ฟองแตก หน้าเบี้ยว → แผ่เป็นแอ่งใหญ่เรืองแสง มีเมือกกระเซ็นกลางแอ่ง
	{"w": 35.0, "h": 40.0, "skirt": 1.35, "face": "melt", "bumps": 12, "wob": 1.0},    # 17
	{"w": 40.0, "h": 16.0, "skirt": 1.15, "face": "none", "bumps": 4, "wob": 2.0, "glow": true, "spiky": 0.3},   # 18
	{"w": 44.0, "h": 6.0, "skirt": 1.05, "face": "none", "bumps": 0, "wob": 3.0, "glow": true, "splash": true},  # 19
]
## ขนาดฟอง/ฐาน อ้างอิงเฟรม 64 เดิม → คูณ 1.5
const S: float = 1.5 * K
## ขยายทั้งตัวจาก FRAME_DEFS (เขียนไว้ที่สเกลเฟรม 96) → บอสสูง ~4 เท่าผู้เล่น
const K: float = 1.3


func _init() -> void:
	var sheet := Image.create_empty(SIZE * FRAME_DEFS.size(), SIZE, false, Image.FORMAT_RGBA8)
	for i: int in FRAME_DEFS.size():
		var frame := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
		_draw_frame(frame, FRAME_DEFS[i])
		sheet.blit_rect(frame, Rect2i(0, 0, SIZE, SIZE), Vector2i(i * SIZE, 0))
	sheet.save_png(ProjectSettings.globalize_path(OUT_DIR + "boss_slime_sheet.png"))
	_save_preview(sheet)
	print("boss slime sheet: %d frames" % FRAME_DEFS.size())
	quit()


## ฟองด้านบน: (x, y) ตามสัดส่วนตัว (x -1..1, y 0 = ยอด .. 1 = ฐาน) · z = รัศมี — ฟองแถวบนสุดทำให้ขอบบนเป็นปุ่ม
func _bumps() -> Array[Vector3]:
	var out: Array[Vector3] = []
	# แถวขอบบน (เป็นส่วนของ silhouette)
	for a: float in [-0.92, -0.72, -0.5, -0.26, 0.0, 0.26, 0.5, 0.72, 0.92]:
		out.append(Vector3(a, 0.12 + absf(a) * absf(a) * 0.3, 4.5 if absf(a) < 0.8 else 3.5))
	# ฟองบนผิวด้านบน (ไม่ทับโพรงหน้า)
	for p: Vector3 in [Vector3(-0.8, 0.42, 3.5), Vector3(-0.55, 0.28, 4), Vector3(-0.3, 0.2, 3.5), Vector3(-0.05, 0.26, 4),
			Vector3(0.2, 0.18, 3.5), Vector3(0.45, 0.27, 4), Vector3(0.7, 0.38, 3.5), Vector3(0.9, 0.55, 3),
			Vector3(-0.92, 0.6, 3), Vector3(0.05, 0.4, 3), Vector3(-0.4, 0.38, 3), Vector3(0.55, 0.45, 3),
			Vector3(-0.15, 0.08, 3), Vector3(0.35, 0.06, 3), Vector3(-0.62, 0.12, 3)]:
		out.append(p)
	# ฟองเล็กกระจายเต็มด้านบน (สุ่มแบบตายตัว ทุกเฟรมตำแหน่งเดิม)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i: int in 12:
		var y: float = rng.randf_range(0.08, 0.5)
		var span: float = 0.95 - absf(y - 0.3) * 0.3
		out.append(Vector3(rng.randf_range(-span, span), y, rng.randf_range(2.2, 3.0)))
	return out


func _draw_frame(img: Image, d: Dictionary) -> void:
	var w: float = float(d["w"]) * K
	var h: float = float(d["h"]) * K
	var wob: float = d["wob"]
	var cx: float = SIZE / 2.0
	var top: float = BASE_Y - h
	var bumps: Array[Vector3] = _bumps()
	# bumps 24 = ครบทุกฟอง · น้อยกว่านั้น = ฟองแตกไปตามสัดส่วน (ตอนตาย)
	var n_bumps: int = bumps.size() if int(d["bumps"]) >= 24 else int(d["bumps"]) * bumps.size() / 24
	var sk_w: float = w * float(d["skirt"])
	var sk_h: float = float(d.get("sk_h", clampf(h / K * 0.12, 3.0, 7.5))) * K
	var spiky: float = float(d.get("spiky", 0.0))
	# 1) silhouette = ตัว (โดมก้นกว้าง) ∪ ฟองขอบบน ∪ ฐานแผ่ (ขอบเป็นคลื่น)
	var mask: Array[bool] = []
	mask.resize(SIZE * SIZE)
	for y: int in SIZE:
		for x: int in SIZE:
			var px: float = x + 0.5
			var py: float = y + 0.5
			var inside: bool = false
			# ตัว: ครึ่งบนวงรี ครึ่งล่างกว้างขึ้นเล็กน้อยเหมือนไหลลง
			var by: float = (py - (top + h * 0.55)) / (h * 0.55 if py < top + h * 0.55 else h * 0.45)
			var bw: float = w * (1.0 + maxf(0.0, by) * 0.12)
			var bx: float = (px - cx) / bw
			if py >= top + h * 0.15 and py <= BASE_Y:
				inside = bx * bx + by * by <= 1.0 if by < 0.0 else absf(bx) <= 1.0 and by <= 1.0
			# ฐานแผ่: วงรีแบนที่พื้น ขอบเป็นคลื่น
			var ang: float = atan2((py - (BASE_Y - sk_h * 0.4)) / sk_h, (px - cx) / sk_w)
			var wave: float = 1.0 + 0.07 * sin(ang * 7.0 + wob) + 0.04 * sin(ang * 13.0 - wob * 1.7)
			# แฉกตอนทุบ: คลื่นสามเหลี่ยม 11 แฉก
			wave += spiky * 0.22 * (absf(fposmod(ang * 11.0 / TAU + wob * 0.1, 1.0) - 0.5) * 2.0 - 0.5)
			var sx: float = (px - cx) / (sk_w * wave)
			var sy: float = (py - (BASE_Y - sk_h * 0.4)) / sk_h
			if sx * sx + sy * sy <= 1.0:
				inside = true
			mask[y * SIZE + x] = inside
	if h >= 18.0:
		for i: int in mini(9, n_bumps):
			var b: Vector3 = bumps[i]
			var c: Vector2 = _bump_pos(b, i, cx, top, w, h, wob)
			var r: float = b.z * S * 1.3 * clampf(minf(h / (60.0 * K), w / (31.0 * K)), 0.7, 1.1)
			for y: int in range(int(c.y - r) - 1, int(c.y + r) + 2):
				for x: int in range(int(c.x - r) - 1, int(c.x + r) + 2):
					if x >= 0 and y >= 0 and x < SIZE and y < SIZE and Vector2(x + 0.5, y + 0.5).distance_to(c) <= r:
						mask[y * SIZE + x] = true
	# 2) ระยะจากขอบ (0 = ติดขอบ) — ใช้ทำขอบเรืองแสงแบบเมือกใส
	var dist: Array[int] = _edge_dist(mask)
	# 3) สีพื้นตัว: บนสว่าง ล่างเข้ม · ขอบบนเรืองแสง · ขอบฐานสว่างแบบเมือกบาง
	for y: int in SIZE:
		for x: int in SIZE:
			if not mask[y * SIZE + x]:
				continue
			var t: float = clampf((y + 0.5 - top) / maxf(h, 1.0), 0.0, 1.0)
			var nx: float = (x + 0.5 - cx) / sk_w
			var v: float = 0.6 - t * 1.35 - nx * 0.25
			var c: Color = _band_dither(v, x, y)
			var dd: int = dist[y * SIZE + x]
			var on_skirt: bool = y + 0.5 > BASE_Y - sk_h * 0.9
			if dd == 0:
				c = C_SKIRT_EDGE if on_skirt else (C_GLOW if t < 0.55 else C_RIM)
			elif dd == 1 and not on_skirt and t < 0.75:
				c = C_RIM
			img.set_pixel(x, y, c)
	# 4) ฟองบนผิว (แรเงาแต่ละลูก + ร่องด้านล่างขวา + จุดแสง)
	if h >= 18.0:
		for i: int in n_bumps:
			var b: Vector3 = bumps[i]
			var bp: Vector2 = _bump_pos(b, i, cx, top, w, h, wob)
			_bump(img, mask, dist, bp, b.z * S * 1.3 * clampf(minf(h / (60.0 * K), w / (31.0 * K)), 0.7, 1.1), bp.y < top + h * 0.3)
	# 5) รายละเอียด: ของจมในตัว · ฟองอากาศ · เมือกไหลข้างตัว · แสงสะท้อน · วงกระเพื่อมบนฐาน · หยดรอบตัว
	_details(img, mask, dist, cx, top, w, h, wob, sk_w, sk_h, d)
	# 5.5) คริสตัลเรืองแสงที่กลืนไว้ จมอยู่ในตัว (ความยิ่งใหญ่ของบอส แต่ทรงยังเป็นสไลม์)
	if h >= 36.0 and d["face"] != "none":
		_crystals_inside(img, mask, dist, cx, top, w, h, wob, d["face"] == "melt")
	# 6) โพรงหน้า
	_face(img, mask, cx, top, w, h, d["face"], wob)
	# ตาย: แอ่งเรืองแสง (กลางแอ่งสว่างสุด) + เมือกกระเซ็นขึ้นกลางแอ่ง + หยดรอบ ๆ
	if d.get("glow", false):
		for y: int in SIZE:
			for x: int in SIZE:
				if mask[y * SIZE + x] and dist[y * SIZE + x] > 0:
					var k: float = absf(x + 0.5 - cx) / sk_w
					img.set_pixel(x, y, C_GLOW if k < 0.25 else (C_RIM if k < 0.55 else C_LIGHT))
	if d.get("splash", false):
		for p: Vector3 in [Vector3(0, -6, 2), Vector3(-3, -11, 1), Vector3(3, -13, 1), Vector3(-1, -17, 1), Vector3(5, -8, 1), Vector3(-6, -7, 1)]:
			var px: int = int(cx + p.x)
			var py: int = int(BASE_Y + p.y)
			for yy: int in int(p.z):
				for xx: int in int(p.z):
					img.set_pixel(px + xx, py + yy, C_GLOW)
			img.set_pixel(px, py + int(p.z), C_RIM)
		for p: Vector2i in [Vector2i(6, 114), Vector2i(121, 113), Vector2i(16, 108), Vector2i(111, 107)]:
			img.set_pixel(p.x, p.y, C_LIGHT)
			img.set_pixel(p.x, p.y + 1, C_MID)


## คริสตัลที่บอสกลืนไว้ — จมอยู่ในเนื้อใส เห็นทะลุผิว (สีอ่อนกว่าคริสตัลจริง) · แท่งกลางโผล่ปลายพ้นหัวนิดเดียว
## ทรงตัวยังกลมแบบสไลม์ แต่มีของเรืองแสงข้างในให้ดูยิ่งใหญ่ · melt = เอียงล้ม
func _crystals_inside(img: Image, mask: Array[bool], dist: Array[int], cx: float, top: float, w: float, h: float,
		wob: float, melt: bool) -> void:
	# (มุม, ยาว (สัดส่วน h), กว้างโคน) · โคนอยู่กลางตัวด้านบน
	var shards: Array[Vector3] = [Vector3(-90, 0.42, 6.0), Vector3(-118, 0.3, 4.5), Vector3(-62, 0.32, 4.5),
		Vector3(-140, 0.18, 3.0), Vector3(-38, 0.2, 3.0)]
	var base := Vector2(cx, top + h * 0.55)
	var first: bool = true
	for sh: Vector3 in shards:
		var a: float = sh.x + sin(wob * 0.7 + sh.x) * 1.5 + (30.0 if melt else 0.0)
		var dir := Vector2.from_angle(deg_to_rad(a))
		var perp := Vector2(-dir.y, dir.x)
		var length: float = sh.y * minf(h, 70.0 * K)
		length = minf(length, (base.y - 3.0) / maxf(0.3, -dir.y))
		var half_w: float = sh.z * K * 0.5
		var start: Vector2 = base + dir * (h * 0.08)
		for y: int in range(int(start.y - length) - 3, int(start.y + 4)):
			for x: int in range(int(start.x - length) - 3, int(start.x + length) + 4):
				if x < 0 or y < 0 or x >= SIZE or y >= SIZE:
					continue
				var rel := Vector2(x + 0.5, y + 0.5) - start
				var t: float = rel.dot(dir)
				var s: float = rel.dot(perp)
				if t < 0.0 or t > length:
					continue
				var k: float = t / length
				var wid: float = half_w * (1.0 - pow(k, 1.8))
				if absf(s) > wid + 0.5:
					continue
				var inside: bool = mask[y * SIZE + x]
				# นอกตัวได้เฉพาะปลายแท่งกลาง
				if not inside and not (first and not melt):
					continue
				var col: Color
				if not inside:
					col = C_GEM_LIGHT if s < 0.0 else C_GEM
				elif dist[y * SIZE + x] == 0:
					continue  # ขอบเรืองแสงของตัวคงไว้ (คริสตัลอยู่ข้างใน)
				elif absf(s) > wid - 0.6:
					col = C_LIGHT
				elif absf(s) < 0.6 and k > 0.3:
					col = C_GLOW
				elif s < 0.0:
					col = C_T_LIGHT
				else:
					col = C_RIM if (x + y) % 2 == 0 else C_T_BODY  # dither = มองผ่านเนื้อใส
				img.set_pixel(x, y, col)
		first = false


## ไล่เฉด 5 ระดับ + dither ลายหมากรุกตรงรอยต่อ (ผิวดูเนียนแบบ pixel art) · ล่างสุดมืดมาก = ตัวหนักกดพื้น
func _band_dither(v: float, x: int, y: int) -> Color:
	var cuts: Array[float] = [0.25, -0.15, -0.45, -0.8]
	var cols: Array[Color] = [C_LIGHT, C_BODY, C_MID, C_DEEP, C_ABYSS]
	var checker: bool = (x + y) % 2 == 0
	for i: int in cuts.size():
		if v > cuts[i] + 0.05:
			return cols[i]
		if v > cuts[i] - 0.05:
			return cols[i] if checker else cols[i + 1]
	return cols[4]


func _px(img: Image, mask: Array[bool], x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < SIZE and y < SIZE and mask[y * SIZE + x]:
		img.set_pixel(x, y, c)


func _details(img: Image, mask: Array[bool], dist: Array[int], cx: float, top: float, w: float, h: float,
		wob: float, sk_w: float, sk_h: float, d: Dictionary) -> void:
	var alive: bool = d["face"] != "none"
	# ของที่จมอยู่ในเมือกใส (เห็นจาง ๆ): กระดูก · หัวกะโหลก · คริสตัล
	if alive and h >= 30.0:
		var bone := Vector2i(int(cx + w * 0.42), int(top + h * 0.84))
		for k: int in range(-4, 5):
			_px(img, mask, bone.x + k, bone.y + k / 3, C_DEBRIS)
		for e: Vector2i in [Vector2i(-5, -2), Vector2i(-5, 0), Vector2i(5, 2), Vector2i(5, 4)]:
			_px(img, mask, bone.x + e.x, bone.y + e.y - 1, C_DEBRIS)
			_px(img, mask, bone.x + e.x, bone.y + e.y, C_DEBRIS)
		_px(img, mask, bone.x - 2, bone.y - 1, C_BODY)
		# หัวกะโหลกนักผจญภัยที่โดนกลืน (ใหญ่ขึ้น เห็นชัดผ่านเนื้อใส)
		var skull := Vector2i(int(cx - w * 0.6), int(top + h * 0.8))
		for y: int in range(-4, 5):
			for x: int in range(-4, 5):
				var inside_head: bool = (x * x) / 16.0 + ((y + 0.5) * (y + 0.5)) / 14.0 <= 1.0 and y <= 2
				var jaw: bool = y >= 2 and y <= 4 and absf(x) <= 2
				if inside_head or jaw:
					_px(img, mask, skull.x + x, skull.y + y, C_DEBRIS_LIGHT if x < 0 and y < 0 else C_DEBRIS)
		for e: Vector2i in [Vector2i(-2, 0), Vector2i(-1, 0), Vector2i(2, 0), Vector2i(1, 0), Vector2i(-2, 1), Vector2i(2, 1)]:
			_px(img, mask, skull.x + e.x, skull.y + e.y, C_HOLE)  # เบ้าตา
		_px(img, mask, skull.x, skull.y + 2, C_HOLE)
		for k: int in [-1, 1]:
			_px(img, mask, skull.x + k, skull.y + 4, C_HOLE)
		# ดาบปักคาในตัว: ด้ามโผล่ออกนอกตัวด้านขวาบน ใบดาบจมเฉียงลงในเนื้อ
		var hilt := Vector2(cx + w + 6.0, top + h * 0.5)
		var sdir := Vector2(-0.6, 0.8).normalized()
		var blade_len: float = h * 0.42
		for k: int in int(blade_len):
			var p: Vector2 = hilt + sdir * k
			var px := Vector2i(int(p.x), int(p.y))
			if px.x < 0 or px.y < 0 or px.x >= SIZE or px.y >= SIZE:
				continue
			var inside: bool = mask[px.y * SIZE + px.x]
			if k < 4:
				img.set_pixel(px.x, px.y, C_HILT_LIGHT if k == 0 else C_HILT)  # ด้ามจับ (นอกตัว)
			elif k < 6:
				for s: int in range(-2, 3):
					var g := Vector2i(int(p.x + s * 0.78), int(p.y + s * 0.62))
					if g.x >= 0 and g.y >= 0 and g.x < SIZE and g.y < SIZE:
						img.set_pixel(g.x, g.y, C_HILT if absf(s) < 2 else C_HILT_LIGHT)  # กระบังดาบ
			elif inside:
				_px(img, mask, px.x, px.y, C_STEEL_IN if k % 7 != 0 else C_RIM)  # ใบดาบเห็นผ่านเนื้อใส
				_px(img, mask, px.x + 1, px.y, C_DEBRIS)
			else:
				img.set_pixel(px.x, px.y, C_STEEL)
				if px.x + 1 < SIZE:
					img.set_pixel(px.x + 1, px.y, C_STEEL_DARK)
		var gem := Vector2i(int(cx + w * 0.7), int(top + h * 0.66))
		for k: int in 4:
			_px(img, mask, gem.x, gem.y - k, C_GEM if k < 3 else C_GEM_LIGHT)
			if k < 2:
				_px(img, mask, gem.x + 1, gem.y - k, C_DEBRIS)
	# ฟองอากาศลอยขึ้นข้างใน (ตำแหน่งตามเฟส wob → ขยับทีละเฟรม)
	if alive and h >= 24.0:
		for b: Vector3 in [Vector3(-0.3, 0.1, 1), Vector3(0.15, 0.55, 2), Vector3(0.6, 0.3, 1), Vector3(-0.75, 0.75, 1), Vector3(0.35, 0.9, 1)]:
			var rise: float = fposmod(b.y + wob * 0.06, 1.0)
			var bx: int = int(cx + b.x * w * 0.8 + sin(wob + b.y * 9.0))
			var by: int = int(BASE_Y - sk_h - rise * h * 0.45)
			if b.z > 1:
				for o: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
					_px(img, mask, bx + o.x, by + o.y, C_RIM)
				_px(img, mask, bx, by, C_BODY)
				_px(img, mask, bx - 1, by - 1, C_SHINE)
			else:
				_px(img, mask, bx, by, C_RIM)
	# เมือกไหลย้อยตามข้างตัว (ยาวสั้นตามเฟส)
	if h >= 24.0:
		var i: int = 0
		for fx: float in [-0.88, -0.62, -0.25, 0.3, 0.6, 0.86]:
			i += 1
			var x: int = int(cx + fx * w)
			var y0: int = int(top + h * (0.3 + absf(fx) * 0.2))
			var length: int = int(h * 0.12) + int(3.0 * (1.0 + sin(wob + i * 2.1)))
			for k: int in length:
				_px(img, mask, x, y0 + k, C_LIGHT)
				_px(img, mask, x + 1, y0 + k, C_BODY)
			# หยดปลายสาย
			_px(img, mask, x - 1, y0 + length, C_LIGHT)
			_px(img, mask, x, y0 + length, C_RIM)
			_px(img, mask, x + 1, y0 + length, C_BODY)
			_px(img, mask, x, y0 + length + 1, C_BODY)
			_px(img, mask, x, y0, C_SHINE)
	# แสงสะท้อนเป็นแถบโค้งบนซ้าย (ทับฟอง)
	if h >= 24.0 and not d.get("glow", false):
		var ecy: float = top + h * 0.55
		for k: int in 14:
			var a: float = deg_to_rad(lerpf(198.0, 250.0, k / 13.0))
			var p := Vector2(cx + cos(a) * (w - 5.0), ecy + sin(a) * (h * 0.55 - 5.0))
			_px(img, mask, int(p.x), int(p.y), C_SHINE if k % 5 != 4 else C_GLOW)
			_px(img, mask, int(p.x) + 1, int(p.y) + 1, C_GLOW)
	# วงกระเพื่อมบนฐาน (เส้นประด้านหน้า)
	if sk_h >= 3.0:
		var ry: float = BASE_Y - sk_h * 0.4
		for k: int in 90:
			var a: float = PI * k / 89.0
			if k % 4 == 3:
				continue
			_px(img, mask, int(cx + cos(a) * sk_w * 0.8), int(ry + sin(a) * sk_h * 0.65), C_LIGHT)
	# หยดเมือกบนพื้นรอบฐาน (นอกตัว)
	if not d.get("splash", false):
		for a: float in [15.0, 60.0, 115.0, 165.0]:
			var r: float = deg_to_rad(a)
			var gx: int = int(cx + cos(r) * (sk_w + 4.0))
			var gy: int = int(BASE_Y - sk_h * 0.4 + sin(r) * (sk_h + 2.0))
			if gx >= 1 and gx < SIZE - 2 and gy >= 1 and gy < SIZE - 1 and not mask[gy * SIZE + gx]:
				img.set_pixel(gx, gy, C_BODY)
				img.set_pixel(gx + 1, gy, C_MID)
				img.set_pixel(gx, gy - 1, C_RIM)


func _bump_pos(b: Vector3, i: int, cx: float, top: float, w: float, h: float, wob: float) -> Vector2:
	return Vector2(cx + b.x * w * 0.95 + sin(wob + i * 1.9) * 0.5, top + b.y * h + cos(wob * 1.2 + i) * 0.5)


func _edge_dist(mask: Array[bool]) -> Array[int]:
	var dist: Array[int] = []
	dist.resize(SIZE * SIZE)
	dist.fill(99)
	for y: int in SIZE:
		for x: int in SIZE:
			if not mask[y * SIZE + x]:
				continue
			for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = Vector2i(x, y) + o
				if q.x < 0 or q.y < 0 or q.x >= SIZE or q.y >= SIZE or not mask[q.y * SIZE + q.x]:
					dist[y * SIZE + x] = 0
					break
	for step: int in range(1, 4):
		for y: int in SIZE:
			for x: int in SIZE:
				if mask[y * SIZE + x] and dist[y * SIZE + x] == 99:
					for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
						var q: Vector2i = Vector2i(x, y) + o
						if dist[q.y * SIZE + q.x] == step - 1:
							dist[y * SIZE + x] = step
							break
	return dist


## ฟองบนผิว: ด้านบนของตัวเป็นโทน teal ด้านล่างน้ำเงิน (ไล่ตามความสูง)
func _bump(img: Image, mask: Array[bool], dist: Array[int], c: Vector2, r: float, teal: bool) -> void:
	_orb(img, mask, dist, c, r, teal)


## ลูกแก้วเมือกมันวาว: ขอบเข้มรอบลูก · แรเงาแสงบนซ้าย · แสงสะท้อนเสี้ยวล่างขวาด้านใน · แสงวิ้ง "+"
## dist = null → วาดได้ทุกที่ใน mask (ใช้กับลูกแก้วในโพรงหน้า)
func _orb(img: Image, mask: Array[bool], dist: Variant, c: Vector2, r: float, teal: bool) -> void:
	var pal: Array[Color] = [C_RIM, C_LIGHT, C_BODY, C_MID]
	if teal:
		pal = [C_T_LIGHT, C_T_BODY, C_T_MID, C_MID]
	for y: int in range(int(c.y - r) - 1, int(c.y + r) + 2):
		for x: int in range(int(c.x - r) - 1, int(c.x + r) + 2):
			if x < 0 or y < 0 or x >= SIZE or y >= SIZE or not mask[y * SIZE + x]:
				continue
			var n := (Vector2(x + 0.5, y + 0.5) - c) / r
			var l: float = n.length()
			if l > 1.0:
				continue
			if dist != null and dist[y * SIZE + x] == 0:
				continue  # ขอบเรืองแสงของตัวคงไว้
			var lit: float = n.dot(LIGHT)
			var col: Color
			if l > 0.78:
				# ขอบลูก: ด้านมืดเข้มมาก (แยกลูกออกจากกัน) ด้านสว่างเข้มน้อย
				col = C_SEAM if lit < 0.2 else pal[3]
			elif l > 0.5 and n.dot(-LIGHT) > 0.62:
				col = pal[0]  # แสงสะท้อนเสี้ยวล่างขวา (ลูกแก้วใส)
			elif lit > 0.4:
				col = pal[0]
			elif lit > -0.05:
				col = pal[1]
			elif lit > -0.45:
				col = pal[2]
			else:
				col = pal[3]
			img.set_pixel(x, y, col)
	# แสงวิ้ง: ลูกใหญ่เป็น "+" ลูกเล็กเป็นจุด
	var h := Vector2i(int(c.x - r * 0.4), int(c.y - r * 0.42))
	var pts: Array[Vector2i] = [Vector2i.ZERO]
	if r >= 4.5:
		pts = [Vector2i.ZERO, Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]
	elif r >= 3.0:
		pts = [Vector2i.ZERO, Vector2i(1, 0)]
	for p: Vector2i in pts:
		var q: Vector2i = h + p
		if q.x >= 0 and q.y >= 0 and q.x < SIZE and q.y < SIZE and mask[q.y * SIZE + q.x]:
			img.set_pixel(q.x, q.y, C_SHINE)


## โพรงหน้าแบบบอส: ตา 2 ข้างเอียงเป็นคิ้วขมวด (มุมในต่ำ = โกรธ) มีลูกตาแดงเรืองในโพรง
## ปากอ้ามีเขี้ยวเมือกแหลมบน-ล่าง คอเรืองแดงจากข้างใน
func _face(img: Image, mask: Array[bool], cx: float, top: float, w: float, h: float, face: String, wob: float) -> void:
	if face == "none" or h < 18.0:
		return
	var eye_h: float = 1.0
	var mouth: float = 1.0
	var tilt: float = 0.0
	var anger: float = 0.25   # ความเอียงของคิ้ว (เบา ๆ พอให้ดุ ไม่ให้เหลี่ยมจนไม่เหมือนสไลม์)
	var glow: float = 1.0     # ขนาดลูกตาเรืองแสง (0 = ไม่มี)
	match face:
		"half":
			eye_h = 0.45
			glow = 0.6
		"closed":
			eye_h = 0.15
			glow = 0.0
		"squint":
			eye_h = 0.25
			mouth = 0.6
			glow = 0.5
			anger = 0.35
		"wide":
			eye_h = 0.9
			mouth = 1.5
			anger = 0.35
			glow = 1.2
		"melt":
			eye_h = 0.8
			mouth = 0.8
			tilt = 0.25
			anger = 0.1
			glow = 0.4
		"tall":
			mouth = 1.3
			anger = 0.35
			glow = 1.2
		"flat":
			eye_h = 1.4
			mouth = 1.6
			anger = 0.3
	var ey: float = top + h * 0.5
	_hole(img, mask, Vector2(cx - w * 0.4, ey + h * 0.02), Vector2(w * 0.32, h * 0.18 * eye_h), 1.0 + wob, tilt, 1, anger, glow)
	_hole(img, mask, Vector2(cx + w * 0.38, ey - h * 0.01), Vector2(w * 0.34, h * 0.19 * eye_h), 2.3 + wob, -tilt, -1, anger, glow)
	_hole(img, mask, Vector2(cx - w * 0.02, top + h * 0.8), Vector2(w * 0.3 * mouth, h * 0.11 * mouth), 3.7 + wob, tilt, 0, 0.0, 0.0)


## โพรง 1 ช่อง · inner = ทิศด้านในของหน้า (+1 ตาซ้าย, -1 ตาขวา, 0 = ปาก)
func _hole(img: Image, mask: Array[bool], c: Vector2, rad: Vector2, seed_v: float, tilt: float,
		inner: int, anger: float, glow: float) -> void:
	if rad.y < 0.8:
		# ปิดสนิท = ขีดเข้มเอียงตามคิ้ว
		for x: int in range(int(c.x - rad.x), int(c.x + rad.x) + 1):
			var yy: int = int(c.y + (x - c.x) / rad.x * anger * 2.0 * inner)
			if x >= 0 and x < SIZE and yy >= 0 and yy < SIZE and mask[yy * SIZE + x]:
				img.set_pixel(x, yy, C_HOLE_RIM)
		return
	var is_mouth: bool = inner == 0
	for y: int in range(int(c.y - rad.y) - 2, int(c.y + rad.y) + 3):
		for x: int in range(int(c.x - rad.x) - 2, int(c.x + rad.x) + 3):
			if x < 0 or y < 0 or x >= SIZE or y >= SIZE or not mask[y * SIZE + x]:
				continue
			var p := Vector2(x + 0.5, y + 0.5) - c
			p.y -= p.x * tilt
			var a: float = atan2(p.y, p.x)
			var wob_r: float = 1.0 + 0.12 * sin(a * 3.0 + seed_v) + 0.06 * sin(a * 5.0 - seed_v * 2.0)
			var n := Vector2(p.x / rad.x, p.y / rad.y)
			var l: float = n.length() / wob_r
			if l > 1.15:
				continue
			# คิ้วขมวด: ตัดขอบบนเป็นเส้นเฉียง (ด้านในต่ำกว่า) → ตาดุ
			if not is_mouth:
				var brow: float = -0.7 + anger * (n.x * inner + 1.0)
				if n.y < brow:
					if n.y > brow - 0.22 and l < 1.1:
						img.set_pixel(x, y, C_ABYSS)  # สันคิ้วเป็นเงาเข้ม
					continue
			if l > 1.0:
				img.set_pixel(x, y, C_RIM if n.y > 0.2 else C_HOLE_RIM)
			elif is_mouth and n.y > -0.2:
				# คอเรืองแดงจากข้างใน: กลางล่างสว่างสุด
				var heat: float = (1.0 - absf(n.x)) * (n.y + 0.2)
				img.set_pixel(x, y, C_THROAT if heat > 0.45 else (C_THROAT_DEEP if heat > 0.12 else C_HOLE_DEEP))
			elif n.y > 0.55 and l > 0.6:
				img.set_pixel(x, y, C_HOLE_RIM)
			elif n.y < -0.35 or l > 0.8:
				img.set_pixel(x, y, C_HOLE_DEEP if n.y < 0.0 else C_HOLE)
			else:
				img.set_pixel(x, y, C_HOLE)
	if is_mouth:
		_fangs(img, mask, c, rad, tilt)
		return
	# เมือกย้อยจากคิ้วลงในโพรง
	if rad.y >= 3.0:
		var i: int = 0
		for fx: float in [-0.5, 0.45]:
			i += 1
			var x: int = int(c.x + fx * rad.x)
			var y0: int = int(c.y + rad.y * (-0.7 + anger * (fx * inner + 1.0)) + 1)
			var length: int = int(rad.y * (0.25 + 0.2 * (1.0 + sin(seed_v + i * 1.7)) * 0.5))
			for k: int in length:
				_px(img, mask, x, y0 + k, C_DEEP if k > 0 else C_MID)
			_px(img, mask, x, y0 + length, C_BODY)
			_px(img, mask, x + 1, y0 + length, C_DEEP)
			_px(img, mask, x, y0 + length + 1, C_DEEP)
	# ลูกตาเรืองแสงแดง: อยู่ค่อนไปด้านใน · แสงจางรอบ ๆ ในโพรงมืด
	if glow > 0.0 and rad.y >= 2.5:
		var gc := Vector2(c.x + inner * rad.x * 0.18, c.y + rad.y * 0.2)
		var gr := Vector2(maxf(1.6, rad.x * 0.24) * glow, maxf(1.4, rad.y * 0.3) * glow)
		for y: int in range(int(gc.y - gr.y * 2.2) - 1, int(gc.y + gr.y * 2.2) + 2):
			for x: int in range(int(gc.x - gr.x * 2.2) - 1, int(gc.x + gr.x * 2.2) + 2):
				if x < 0 or y < 0 or x >= SIZE or y >= SIZE or not mask[y * SIZE + x]:
					continue
				var cur: Color = img.get_pixel(x, y)
				var in_hole: bool = cur == C_HOLE or cur == C_HOLE_DEEP or cur == C_HOLE_RIM
				var e := Vector2((x + 0.5 - gc.x) / gr.x, (y + 0.5 - gc.y) / gr.y)
				var el: float = e.length()
				if el <= 0.55:
					img.set_pixel(x, y, C_EYE_CORE)
				elif el <= 1.0:
					img.set_pixel(x, y, C_EYE_GLOW)
				elif el <= 1.9 and in_hole and (x + y) % 2 == 0:
					img.set_pixel(x, y, C_EYE_HALO)  # แสงแดงจาง (dither)
		# ม่านตาแนวตั้งดำ ๆ กลางลูกตา
		if gr.y >= 2.0:
			for k: int in range(-int(gr.y * 0.6), int(gr.y * 0.6) + 1):
				_px(img, mask, int(gc.x), int(gc.y) + k, C_THROAT_DEEP)


## เมือกยืดในปาก: สายเมือกเหนียวเชื่อมปากบน-ล่าง (กลางสายคอดบาง) + หยดกลมย้อยจากปากบน — นุ่มแบบสไลม์ ไม่ใช่เขี้ยวแข็ง
func _fangs(img: Image, mask: Array[bool], c: Vector2, rad: Vector2, tilt: float) -> void:
	if rad.y < 3.0:
		return
	# สายเมือก 3 เส้น
	for fx: float in [-0.55, 0.1, 0.62]:
		var x0: float = c.x + fx * rad.x
		var span: float = rad.y * sqrt(maxf(0.0, 1.0 - fx * fx))
		var y_top: int = int(c.y - span + fx * rad.x * tilt)
		var y_bot: int = int(c.y + span + fx * rad.x * tilt)
		for y: int in range(y_top, y_bot + 1):
			var k: float = float(y - y_top) / maxf(1.0, float(y_bot - y_top))
			# หนาที่ปลายทั้งสองข้าง คอดตรงกลาง + โค้งย้อยนิด ๆ
			var thick: float = 0.6 + 1.6 * pow(absf(k - 0.5) * 2.0, 2.0)
			var xc: float = x0 + sin(k * PI) * 1.2
			for x: int in range(int(xc - thick), int(xc + thick) + 1):
				var col: Color = C_RIM if x == int(xc - thick) else C_LIGHT
				_px(img, mask, x, y, col)
			_px(img, mask, int(xc + thick), y, C_BODY)
	# หยดกลมย้อยจากปากบน
	for fx: float in [-0.25, 0.38]:
		var x: int = int(c.x + fx * rad.x)
		var y0: int = int(c.y - rad.y * sqrt(maxf(0.0, 1.0 - fx * fx)) + fx * rad.x * tilt)
		var length: int = int(rad.y * 0.45)
		for k: int in length:
			_px(img, mask, x, y0 + k, C_LIGHT)
		for o: Vector2i in [Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(1, 1)]:
			_px(img, mask, x + o.x, y0 + length + o.y, C_LIGHT)
		_px(img, mask, x - 1, y0 + length, C_SHINE)


func _save_preview(sheet: Image) -> void:
	const SCALE: int = 3
	var pv := Image.create_empty(sheet.get_width() * SCALE, sheet.get_height() * SCALE, false, Image.FORMAT_RGBA8)
	for y: int in pv.get_height():
		for x: int in pv.get_width():
			var checker: bool = ((x / 48) + (y / 48)) % 2 == 0
			pv.set_pixel(x, y, Color("1d2b3d") if checker else Color("182434"))
	var big: Image = sheet.duplicate()
	big.resize(sheet.get_width() * SCALE, sheet.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
	pv.blend_rect(big, Rect2i(Vector2i.ZERO, pv.get_size()), Vector2i.ZERO)
	pv.save_png(ProjectSettings.globalize_path(OUT_DIR + "tools/boss_slime_preview.png"))
