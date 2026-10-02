extends SceneTree
## สร้าง sprite sheet บอส Minotaur 8 ทิศ (placeholder art วาดด้วยโค้ด) — แก้สี/ท่าแล้วรันใหม่ได้
## หุ่นโครง 3D ง่าย ๆ: ข้อต่อมีความลึก (x ขวาของตัว, y ขึ้น, z หน้าของตัว) → หมุนตามทิศ → ฉายลงจอ top-down 3/4
## แต่ละชิ้น (แคปซูล/วงรี) เรียงวาดตามความลึก (ใกล้กล้อง = วาดทีหลัง) · เข่า/ศอกคำนวณด้วย IK
## หน้าตาอ้างอิงภาพที่ Few ส่ง (สไตล์ Minotaur ใน Mobile Legends — วาดเองใหม่ ก่อนขายจริงควรปรับให้เป็นของเรา):
##   ผิวแดง · แผงคอ/เคราถักสีส้มแดง · เขาโค้งสีเข้ม · เกราะบ่าเหล็กใหญ่ขอบเรืองส้ม + เขากระดูก
##   มือซ้ายเป็นค้อนเหล็กหนาม · มือขวาเล็บ · สร้อยเชือกลูกปัด · ผ้าเตี่ยวหนัง · ขนส้มข้อเท้า · กีบเข้ม
## godot --headless --path game --script res://systems/enemy/boss_minotaur/tools/gen_minotaur_sheet.gd
## ได้: minotaur_sheet.png — แถว = ทิศ (DIRS), คอลัมน์ = เฟรม (idle 0–3, walk 4–9), เฟรม 128×128
##      tools/minotaur_preview.png (ขยาย ×2)

const SIZE: int = 128
const CX: float = 64.0
const FEET: float = 110.0  # เว้นที่ล่าง 18 px ให้หัวขวานที่ห้อยต่ำ
const OUT_DIR: String = "res://systems/enemy/boss_minotaur/"
const LIGHT := Vector2(-0.6, -0.8)
## ทิศที่หัน (องศา, 0 = หันลงล่าง/เข้ากล้อง) — ลำดับแถวใน sheet
const DIRS: Array[Dictionary] = [
	{"name": "S", "deg": 0.0}, {"name": "SE", "deg": 45.0}, {"name": "E", "deg": 90.0}, {"name": "NE", "deg": 135.0},
	{"name": "N", "deg": 180.0}, {"name": "NW", "deg": 225.0}, {"name": "W", "deg": 270.0}, {"name": "SW", "deg": 315.0},
]
const IDLE_FRAMES: int = 4
## ทิศที่คมขวานหัน (local: x = ข้างตัว, z = หน้า)
const AXE_OUT := Vector3(0.6, 0, 1.0)  # เฉียงไปหน้า (Few เลือก)
const WALK_FRAMES: int = 8

# จานสี: [ไฮไลต์, สว่าง, กลาง, มืด]
## ตัว = ขนน้ำตาลแบบวัว · ขาท่อนล่างเข้มกว่า · ปาก/จมูกสีอ่อน
const SKIN: Array[Color] = [Color("c08a5a"), Color("94643a"), Color("6c4524"), Color("452a14")]
const FUR_LEG: Array[Color] = [Color("845a38"), Color("5e3e24"), Color("422a16"), Color("29190c")]
const MUZZLE: Array[Color] = [Color("c89a86"), Color("a27464"), Color("7c5448"), Color("523630")]
const C_NOSTRIL := Color("2a1814")
const C_EAR_IN := Color("c88a7a")
const HAIR: Array[Color] = [Color("d27a3c"), Color("a8521f"), Color("7a3614"), Color("4a1e08")]  # แผงคอน้ำตาลแดงเข้ม
const HORN: Array[Color] = [Color("8a7aa0"), Color("5a4c70"), Color("3a3050"), Color("221b30")]
const BONE: Array[Color] = [Color("f4e8cc"), Color("d8c6a0"), Color("a8946c"), Color("6c5c42")]
const STEEL: Array[Color] = [Color("98a2b4"), Color("646e82"), Color("444c5e"), Color("282d3a")]
const WOOD_DARK: Array[Color] = [Color("6a4a32"), Color("4a3222"), Color("33221a"), Color("1e140e")]  # ด้ามไม้ดำ
const BLADE: Array[Color] = [Color("8a909c"), Color("5a606c"), Color("3c4048"), Color("22252b")]  # เหล็กดำใบขวาน
const C_EDGE := Color("dfe5ec")
const C_RUNE := Color("ff3a2a")
const C_RUNE_HOT := Color("ffb08a")
const C_BLOOD := Color("6a0e10")
const WOOD: Array[Color] = [Color("a0703f"), Color("7a5230"), Color("5a3a22"), Color("3a2414")]  # ด้ามขวาน
const LEATHER: Array[Color] = [Color("8a6446"), Color("664630"), Color("4a3222"), Color("2e1e14")]
const HOOF: Array[Color] = [Color("6a7088"), Color("484e64"), Color("30344a"), Color("1c1e2c")]
const ROPE: Array[Color] = [Color("e8d2a0"), Color("c4a874"), Color("947a50"), Color("5e4c30")]
const C_GLOW := Color("ff9a2a")
const C_GLOW_HOT := Color("ffd27a")
const C_EYE := Color("fff2b0")
const C_BROW := Color("4a1a14")
const C_GEM := Color("8fe8ff")
const C_OUTLINE := Color("170d0a")
const C_TATTOO := Color("5a1e22")   # รอยสักลายชนเผ่าบนต้นแขน
const C_GLOW_DIM := Color("e06a3a")  # แสงเรืองรอบดวงตา
const GOLD_RING: Array[Color] = [Color("ffe08a"), Color("c08a28")]  # ห่วงทองบนเคราถัก

var img: Image
var _R := Vector2.ZERO  # แกนขวาของตัวในโลก (X, Z)
var _F := Vector2.ZERO  # แกนหน้าของตัวในโลก (X, Z)
var _parts: Array[Dictionary] = []
var _hip_y: float = 36.0
var _lean_f: float = 0.0
var _sway: float = 0.0
var _yaw: float = 0.0   # บิดลำตัวรอบแกนตั้ง (เรเดียน, + = หมุนไปทางขวาของตัว)
var _lift: float = 0.0  # ลอยทั้งตัว (กระโดด)
var _eyes: String = "glow"  # glow / closed (เจ็บ) / off (ตาย)


## จุดของส่วนบนตัว → เลื่อนตามการก้ม/โยก (งอที่สะโพก: สูงจากสะโพก 45 px = เอนเต็มค่า)
## ก้มไปหน้าแล้วความสูงลดลงเล็กน้อยด้วย (ไม่ให้ตัวยืดยาว)
func _u(v: Vector3) -> Vector3:
	var k: float = clampf((v.y - _hip_y) / 45.0, 0.0, 1.2)
	var a: float = _yaw * minf(k, 1.0)
	var r := Vector3(v.x * cos(a) + v.z * sin(a), v.y, -v.x * sin(a) + v.z * cos(a))
	return r + Vector3(_sway * k, -absf(_lean_f) * 0.35 * k * k, _lean_f * k)


## ท่าโจมตี 6 ท่า × 6 เฟรม (ต่อจาก idle + walk ในแต่ละแถว) — แต่ละเฟรมแก้จากท่ายืนพื้นฐาน
## ทุกท่ามี telegraph: เฟรม 1 (ค้างท่าง้าง) · เฟรมกระแทกดูที่ "hit" ใน ATTACK_NAMES
## ทิศ local: x = ขวาของตัว, y = ขึ้น, z = หน้า · axe_dir = ด้ามชี้ไปทางหัวขวาน · axe_out = ทิศคม
const ATTACK_NAMES: Array[Dictionary] = [
	{"id": "cleave", "th": "ฟาดเหนือหัว", "hit": 4},
	{"id": "sweep", "th": "กวาดขวาน", "hit": 3},
	{"id": "rising", "th": "เสยขวานขึ้น", "hit": 3},
	{"id": "charge", "th": "พุ่งชนด้วยเขา", "hit": 4},
	{"id": "stomp", "th": "กระทืบกีบ", "hit": 2},
	{"id": "leap", "th": "กระโดดทุบ", "hit": 4},
]
const WIDE_L := Vector3(-14, 0, 5)
const WIDE_R := Vector3(14, 0, -4)
const ATTACKS: Array = [
	# 1 ฟาดเหนือหัว: ย่อ → ชูขวานไปหลังหัว (ค้าง) → ฟาดผ่านหน้า → หัวขวานจมพื้น → ฟื้น
	[
		{"two_hand": true, "bob": 4.0, "lean_fwd": 2.0, "hand_r": Vector3(6, 58, 16), "axe_dir": Vector3(0.1, 1, -0.2), "foot_l": WIDE_L, "foot_r": WIDE_R},
		{"two_hand": true, "bob": -1.0, "lean_fwd": -5.0, "breath": 3.0, "hand_r": Vector3(4, 84, 2), "axe_dir": Vector3(0, 0.35, -1), "axe_out": Vector3(0, 1, 0.2), "foot_l": WIDE_L, "foot_r": WIDE_R, "head_dip": -2.0},
		{"two_hand": true, "bob": -2.0, "lean_fwd": -6.0, "breath": 3.0, "hand_r": Vector3(3, 85, -1), "axe_dir": Vector3(0, 0.1, -1), "axe_out": Vector3(0, 1, 0), "foot_l": WIDE_L, "foot_r": WIDE_R, "head_dip": -2.0},
		{"two_hand": true, "bob": 3.0, "lean_fwd": 6.0, "hand_r": Vector3(3, 66, 22), "axe_dir": Vector3(0, 0.9, 0.5), "axe_out": Vector3(0, 0, 1), "foot_l": WIDE_L, "foot_r": WIDE_R},
		{"two_hand": true, "bob": 9.0, "lean_fwd": 11.0, "head_dip": 4.0, "hand_r": Vector3(2, 38, 26), "axe_dir": Vector3(0, -0.8, 0.6), "axe_out": Vector3(0, -1, 0), "foot_l": WIDE_L, "foot_r": WIDE_R},
		{"two_hand": true, "bob": 5.0, "lean_fwd": 6.0, "hand_r": Vector3(6, 46, 22), "axe_dir": Vector3(0.1, -0.3, 1), "axe_out": Vector3(0, -1, 0), "foot_l": WIDE_L, "foot_r": WIDE_R},
	],
	# 2 กวาดขวาน: บิดตัวง้างขวานไปหลังขวา (ค้าง) → กวาดผ่านหน้าเป็นวง → ตามแรงไปซ้าย → ฟื้น
	[
		{"two_hand": true, "bob": 4.0, "yaw": 0.7, "hand_r": Vector3(28, 52, -10), "axe_dir": Vector3(0.6, 0.3, -0.8), "axe_out": Vector3(0, 0, 1), "foot_l": WIDE_L, "foot_r": WIDE_R},
		{"two_hand": true, "bob": 5.0, "yaw": 1.0, "lean_fwd": 2.0, "hand_r": Vector3(30, 50, -16), "axe_dir": Vector3(0.5, 0.15, -1), "axe_out": Vector3(0, 0, 1), "foot_l": WIDE_L, "foot_r": WIDE_R},
		{"two_hand": true, "bob": 5.0, "yaw": 0.3, "lean_fwd": 4.0, "hand_r": Vector3(18, 50, 22), "axe_dir": Vector3(0.5, 0.05, 1), "axe_out": Vector3(-1, 0, 0), "foot_l": WIDE_L, "foot_r": WIDE_R},
		{"two_hand": true, "bob": 6.0, "yaw": -0.25, "lean_fwd": 5.0, "hand_r": Vector3(2, 50, 26), "axe_dir": Vector3(-0.35, 0, 1), "axe_out": Vector3(-1, 0, -0.3), "foot_l": WIDE_L, "foot_r": WIDE_R},
		{"two_hand": true, "bob": 5.0, "yaw": -0.9, "lean_fwd": 3.0, "hand_r": Vector3(-20, 50, 18), "axe_dir": Vector3(-1, 0.05, 0.25), "axe_out": Vector3(0, 0, -1), "foot_l": WIDE_L, "foot_r": WIDE_R},
		{"two_hand": true, "bob": 3.0, "yaw": -0.4, "hand_r": Vector3(-6, 48, 20), "axe_dir": Vector3(-0.3, 0.7, 0.5), "foot_l": WIDE_L, "foot_r": WIDE_R},
	],
	# 3 เสยขวานขึ้น: ย่อลดขวานต่ำแตะพื้น (ค้าง) → เสยขึ้นผ่านหน้า → ชูสุดเหนือหัว → ฟื้น
	[
		{"two_hand": true, "bob": 7.0, "lean_fwd": 6.0, "hand_r": Vector3(14, 28, 18), "axe_dir": Vector3(0.2, -0.7, 0.6), "axe_out": Vector3(0, 1, 0.3), "foot_l": WIDE_L, "foot_r": WIDE_R},
		{"two_hand": true, "bob": 9.0, "lean_fwd": 8.0, "head_dip": 3.0, "hand_r": Vector3(14, 24, 20), "axe_dir": Vector3(0.2, -0.8, 0.5), "axe_out": Vector3(0, 1, 0.3), "foot_l": WIDE_L, "foot_r": WIDE_R},
		{"two_hand": true, "bob": 3.0, "lean_fwd": 3.0, "hand_r": Vector3(10, 52, 24), "axe_dir": Vector3(0.1, 0.5, 0.9), "axe_out": Vector3(0, 1, -0.3), "foot_l": WIDE_L, "foot_r": WIDE_R},
		{"two_hand": true, "bob": -2.0, "lean_fwd": -3.0, "breath": 2.0, "hand_r": Vector3(6, 84, 10), "axe_dir": Vector3(0, 1, 0.2), "axe_out": Vector3(0, 0, 1), "foot_l": WIDE_L, "foot_r": WIDE_R, "head_dip": -2.0},
		{"two_hand": true, "bob": -1.0, "lean_fwd": -4.0, "breath": 2.0, "hand_r": Vector3(4, 88, 2), "axe_dir": Vector3(0, 0.7, -0.7), "axe_out": Vector3(0, 0.6, 1), "foot_l": WIDE_L, "foot_r": WIDE_R},
		{"two_hand": false, "bob": 2.0, "hand_r": Vector3(27, 50, 16), "axe_dir": Vector3(0.14, 1, -0.05), "foot_l": WIDE_L, "foot_r": WIDE_R},
	],
	# 4 พุ่งชนด้วยเขา: ก้มหัว ตะกุยกีบขวา (ค้าง) → ดีดตัว → พุ่ง → เขาชนเต็มแรง → ฟื้น
	[
		{"bob": 5.0, "lean_fwd": 10.0, "head_dip": 8.0, "foot_r": Vector3(13, 4, -10), "hand_l": Vector3(-28, 38, 8), "hand_r": Vector3(29, 38, -4), "axe_dir": Vector3(0.3, -0.5, -1)},
		{"bob": 6.0, "lean_fwd": 11.0, "head_dip": 10.0, "foot_r": Vector3(13, 0, -15), "hand_l": Vector3(-28, 36, 6), "hand_r": Vector3(29, 37, -6), "axe_dir": Vector3(0.3, -0.5, -1), "tail": 6.0},
		{"bob": 6.0, "lean_fwd": 14.0, "head_dip": 12.0, "foot_l": Vector3(-13, 0, 14), "foot_r": Vector3(13, 4, -16), "hand_l": Vector3(-28, 40, -8), "hand_r": Vector3(29, 40, -10), "axe_dir": Vector3(0.3, -0.2, -1), "tail": -6.0},
		{"bob": 5.0, "lean_fwd": 16.0, "head_dip": 12.0, "foot_l": Vector3(-13, 6, 2), "foot_r": Vector3(13, 0, 12), "hand_l": Vector3(-28, 42, 14), "hand_r": Vector3(29, 42, -12), "axe_dir": Vector3(0.3, -0.1, -1), "tail": 6.0},
		{"bob": 7.0, "lean_fwd": 18.0, "head_dip": 13.0, "foot_l": Vector3(-13, 0, 16), "foot_r": Vector3(13, 0, -8), "hand_l": Vector3(-30, 44, 4), "hand_r": Vector3(30, 44, -8), "axe_dir": Vector3(0.3, -0.1, -1), "tail": -4.0},
		{"bob": 3.0, "lean_fwd": 6.0, "head_dip": 3.0, "hand_r": Vector3(27, 46, 14), "axe_dir": Vector3(0.14, 1, -0.05)},
	],
	# 5 กระทืบกีบ: ยกเข่าขวาสูง ชูหมัด (ค้าง) → กระทืบลง → คลื่นกระแทก (ค้าง) → ฟื้น
	[
		{"bob": -1.0, "lean_fwd": -2.0, "sway": -3.0, "foot_r": Vector3(13, 20, 6), "hand_l": Vector3(-30, 60, 8), "hand_r": Vector3(27, 50, 15)},
		{"bob": -2.0, "lean_fwd": -3.0, "sway": -4.0, "breath": 3.0, "foot_r": Vector3(13, 27, 8), "hand_l": Vector3(-28, 72, 6), "hand_r": Vector3(27, 54, 15), "head_dip": -2.0},
		{"bob": 8.0, "lean_fwd": 7.0, "head_dip": 5.0, "foot_r": Vector3(13, 0, 8), "foot_l": Vector3(-14, 0, -2), "hand_l": Vector3(-32, 40, 14), "hand_r": Vector3(27, 42, 18)},
		{"bob": 9.0, "lean_fwd": 8.0, "head_dip": 5.0, "foot_r": Vector3(13, 0, 8), "foot_l": Vector3(-14, 0, -2), "hand_l": Vector3(-32, 38, 14), "hand_r": Vector3(27, 41, 18)},
		{"bob": 5.0, "lean_fwd": 4.0, "head_dip": 2.0, "foot_r": Vector3(13, 0, 6), "hand_l": Vector3(-31, 34, 10), "hand_r": Vector3(27, 44, 17)},
		{"bob": 2.0, "lean_fwd": 1.0, "foot_r": Vector3(12, 0, 3), "hand_r": Vector3(27, 44, 17)},
	],
	# 6 กระโดดทุบ: ย่อลึก (ค้าง) → กระโดดชูขวาน → จุดสูงสุด → พุ่งลงฟาด → ทุบพื้น → ฟื้น
	[
		{"two_hand": true, "bob": 11.0, "lean_fwd": 9.0, "head_dip": 3.0, "hand_r": Vector3(20, 30, -8), "axe_dir": Vector3(0.3, -0.3, -1), "axe_out": Vector3(0, -1, 0), "foot_l": WIDE_L, "foot_r": WIDE_R},
		{"two_hand": true, "lift": 9.0, "bob": -2.0, "lean_fwd": -4.0, "hand_r": Vector3(4, 82, 0), "axe_dir": Vector3(0, 0.2, -1), "axe_out": Vector3(0, 1, 0), "foot_l": Vector3(-12, 8, 4), "foot_r": Vector3(12, 10, -2), "head_dip": -2.0},
		{"two_hand": true, "lift": 14.0, "bob": -2.0, "lean_fwd": -5.0, "breath": 3.0, "hand_r": Vector3(3, 82, -2), "axe_dir": Vector3(0, 0.05, -1), "axe_out": Vector3(0, 1, 0), "foot_l": Vector3(-12, 12, 6), "foot_r": Vector3(12, 12, 0), "head_dip": -3.0},
		{"two_hand": true, "lift": 7.0, "bob": 1.0, "lean_fwd": 6.0, "hand_r": Vector3(3, 64, 22), "axe_dir": Vector3(0, 0.9, 0.5), "axe_out": Vector3(0, 0, 1), "foot_l": Vector3(-13, 4, 6), "foot_r": Vector3(13, 4, -2)},
		{"two_hand": true, "bob": 11.0, "lean_fwd": 12.0, "head_dip": 5.0, "hand_r": Vector3(2, 36, 26), "axe_dir": Vector3(0, -0.8, 0.6), "axe_out": Vector3(0, -1, 0), "foot_l": WIDE_L, "foot_r": WIDE_R},
		{"two_hand": true, "bob": 6.0, "lean_fwd": 6.0, "hand_r": Vector3(6, 46, 22), "axe_dir": Vector3(0.1, -0.3, 1), "axe_out": Vector3(0, -1, 0), "foot_l": WIDE_L, "foot_r": WIDE_R},
	],
]
const ATTACK_FRAMES: int = 6

## โดนตี 4 เฟรม (คอลัมน์ 48–51): สะดุ้งถอยหลัง หัวสะบัดหงาย หลับตา → ถอยสุด → ก้มหัวจ้องกลับ → คืนท่า
const HURT: Array[Dictionary] = [
	{"bob": 2.0, "lean_fwd": -6.0, "yaw": -0.2, "head_dip": -4.0, "eyes": "closed", "hand_l": Vector3(-30, 46, -4), "hand_r": Vector3(28, 46, 8), "axe_dir": Vector3(0.3, 1, -0.4)},
	{"bob": 4.0, "lean_fwd": -8.0, "yaw": -0.3, "sway": 3.0, "head_dip": -5.0, "eyes": "closed", "hand_l": Vector3(-31, 44, -8), "hand_r": Vector3(28, 44, 6), "axe_dir": Vector3(0.35, 1, -0.5)},
	{"bob": 3.0, "lean_fwd": 4.0, "head_dip": 4.0, "breath": 2.0, "hand_l": Vector3(-30, 36, 10), "hand_r": Vector3(27, 43, 17)},
	{"bob": 1.0, "lean_fwd": 1.0, "breath": 1.0, "hand_r": Vector3(27, 43, 17)},
]
## ตาย 8 เฟรม (คอลัมน์ 52–59) คุกเข่าข้างเดียว: เซหลัง → โซเซหน้า → เข่าซ้ายลงพื้น ขาขวาชันเข่า
## มือขวาปักขวานลงพื้นค้ำตัว → ก้มหัว → ตาดับ → ทรุดนิ่งทั้งที่ยังคุกเข่า (ในเกมค่อยจางหาย)
const KNEEL_L := Vector3(-12, 0, -20)   # กีบซ้ายพับไปหลัง เข่าแตะพื้น
const KNEEL_R := Vector3(13, 0, 10)     # ขาขวาตั้งชันเข่าไว้ข้างหน้า
const DEATH: Array[Dictionary] = [
	{"bob": 3.0, "lean_fwd": -8.0, "head_dip": -5.0, "eyes": "closed", "yaw": -0.2, "hand_l": Vector3(-31, 46, -6), "hand_r": Vector3(28, 46, 6), "axe_dir": Vector3(0.3, 1, -0.4)},
	{"bob": 7.0, "lean_fwd": 7.0, "sway": -3.0, "head_dip": 4.0, "eyes": "closed", "foot_l": Vector3(-13, 0, 6), "hand_l": Vector3(-30, 34, 12), "hand_r": Vector3(25, 38, 18), "axe_dir": Vector3(0.25, 0.4, 0.9)},
	{"bob": 16.0, "lean_fwd": 8.0, "head_dip": 5.0, "eyes": "closed", "foot_l": KNEEL_L, "foot_r": KNEEL_R, "hand_l": Vector3(-22, 28, 10), "hand_r": Vector3(22, 38, 18), "axe_dir": Vector3(0.15, -1, 0.25), "axe_out": Vector3(0, 0, 1)},
	{"bob": 18.0, "lean_fwd": 9.0, "head_dip": 7.0, "foot_l": KNEEL_L, "foot_r": KNEEL_R, "hand_l": Vector3(-21, 26, 10), "hand_r": Vector3(22, 37, 18), "axe_dir": Vector3(0.15, -1, 0.25), "axe_out": Vector3(0, 0, 1)},
	{"bob": 18.0, "lean_fwd": 11.0, "head_dip": 11.0, "eyes": "closed", "foot_l": KNEEL_L, "foot_r": KNEEL_R, "hand_l": Vector3(-21, 25, 11), "hand_r": Vector3(22, 37, 18), "axe_dir": Vector3(0.15, -1, 0.25), "axe_out": Vector3(0, 0, 1)},
	{"bob": 19.0, "lean_fwd": 12.0, "head_dip": 12.0, "eyes": "off", "breath": 0.0, "foot_l": KNEEL_L, "foot_r": KNEEL_R, "hand_l": Vector3(-22, 23, 12), "hand_r": Vector3(22, 36, 18), "axe_dir": Vector3(0.15, -1, 0.25), "axe_out": Vector3(0, 0, 1)},
	{"bob": 20.0, "lean_fwd": 13.0, "head_dip": 13.0, "eyes": "off", "breath": 0.0, "sway": 1.5, "foot_l": KNEEL_L, "foot_r": KNEEL_R, "hand_l": Vector3(-23, 20, 13), "hand_r": Vector3(22, 35, 18), "axe_dir": Vector3(0.15, -1, 0.25), "axe_out": Vector3(0, 0, 1), "tail": -3.0},
	{"bob": 20.0, "lean_fwd": 13.0, "head_dip": 14.0, "eyes": "off", "breath": 0.0, "sway": 1.5, "foot_l": KNEEL_L, "foot_r": KNEEL_R, "hand_l": Vector3(-23, 19, 13), "hand_r": Vector3(22, 35, 18), "axe_dir": Vector3(0.15, -1, 0.25), "axe_out": Vector3(0, 0, 1), "tail": -4.0},
]


## โดนตี (0–3) แล้วต่อด้วยตาย (4–11)
func _extra_pose(i: int) -> Dictionary:
	var pose: Dictionary = _idle_pose(1)
	pose.merge(HURT[i] if i < HURT.size() else DEATH[i - HURT.size()], true)
	return pose


func _attack_pose(atk: int, i: int) -> Dictionary:
	var pose: Dictionary = _idle_pose(1)
	pose.merge(ATTACKS[atk][i], true)
	return pose


func _init() -> void:
	var atk_end: int = IDLE_FRAMES + WALK_FRAMES + ATTACKS.size() * ATTACK_FRAMES
	var cols: int = atk_end + HURT.size() + DEATH.size()
	var sheet := Image.create_empty(SIZE * cols, SIZE * DIRS.size(), false, Image.FORMAT_RGBA8)
	for row: int in DIRS.size():
		var th: float = deg_to_rad(float(DIRS[row]["deg"]))
		_F = Vector2(sin(th), cos(th))
		_R = Vector2(-cos(th), sin(th))
		for col: int in cols:
			var pose: Dictionary
			if col < IDLE_FRAMES:
				pose = _idle_pose(col)
			elif col < IDLE_FRAMES + WALK_FRAMES:
				pose = _walk_pose(col - IDLE_FRAMES)
			else:
				var k: int = col - IDLE_FRAMES - WALK_FRAMES
				pose = _attack_pose(k / ATTACK_FRAMES, k % ATTACK_FRAMES) if col < atk_end else _extra_pose(col - atk_end)
			img = Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
			_build(pose)
			_render()
			_outline()
			sheet.blit_rect(img, Rect2i(0, 0, SIZE, SIZE), Vector2i(col * SIZE, row * SIZE))
	sheet.save_png(ProjectSettings.globalize_path(OUT_DIR + "minotaur_sheet.png"))
	_save_preview(sheet)
	print("minotaur sheet: %d dirs × %d frames" % [DIRS.size(), cols])
	quit()


# ─────────────────────────── ท่า ───────────────────────────
## ท่า = ตำแหน่งเท้า/มือ (local) + ทรุดตัว + อกพอง

func _idle_pose(i: int) -> Dictionary:
	var breath: float = [0.0, 1.0, 2.0, 1.0][i]
	return {
		"bob": 0.0, "breath": breath, "lean": 0.0, "tail": [0.0, 1.5, 2.5, 1.5][i],
		"foot_l": Vector3(-12, 0, 0), "foot_r": Vector3(12, 0, 1),
		"hand_l": Vector3(-31, 30 + breath * 0.5, 9), "hand_r": Vector3(27, 43 + breath * 0.5, 17),
	}


## เดิน 8 เฟรม แบบนักล่าตัวหนัก: ก้มตัว ก้มหัวให้เขาชี้หน้า ย่อตัวต่ำ
## เฟรม 0 = เท้าซ้ายกระแทกพื้น · เฟรม 4 = เท้าขวากระแทก → ตัวทรุดลง + หัวพยัก (จังหวะฝุ่น/จอสั่น)
## ระหว่างก้าว: ตัวยืดขึ้น · ลำตัวโยกไปทางขาที่ยืน · ไหล่บิดสวนขา · หมัดซ้ายแกว่งหนัก · ขวานนิ่ง
func _walk_pose(i: int) -> Dictionary:
	var ph: float = TAU * i / WALK_FRAMES
	var stride: float = 10.0
	var zl: float = cos(ph) * stride           # เท้าซ้ายอยู่หน้าสุดตอนกระแทก (เฟรม 0)
	var zr: float = -zl
	var lift_l: float = maxf(0.0, -sin(ph)) * 6.0   # ยกเท้าสูงตอนเหวี่ยงไปข้างหน้า
	var lift_r: float = maxf(0.0, sin(ph)) * 6.0
	var impact: float = pow((cos(2.0 * ph) + 1.0) * 0.5, 3.0)  # 1 ตอนเท้ากระแทก แหลม ๆ
	var bob: float = 3.0 + impact * 3.0                        # ย่อตัวตลอด + ทรุดหนักตอนกระแทก
	return {
		"bob": bob, "breath": 1.0, "lean": 0.0, "tail": sin(ph) * 6.0,
		"lean_fwd": 7.0 + impact * 1.5, "sway": -cos(ph) * 3.0, "twist": sin(ph) * 3.5,
		"head_dip": 3.0 + impact * 2.5,
		"foot_l": Vector3(-13, lift_l, zl), "foot_r": Vector3(13, lift_r, zr),
		"hand_l": Vector3(-30, 33 - bob, 10 - zl * 1.0), "hand_r": Vector3(27, 44 - bob, 19 - zr * 0.2),
	}


# ─────────────────────────── ประกอบชิ้น ───────────────────────────

func _build(p: Dictionary) -> void:
	_parts.clear()
	var bob: float = p["bob"]
	var br: float = p["breath"]
	var lean: float = p["lean"]
	var hip_y: float = 36.0 - bob
	var sh_y: float = 68.0 - bob + br * 0.6
	# ส่วนบนของตัวงอจากสะโพก: ก้มไปหน้า (lean_fwd) · โยกข้าง (sway) — ยิ่งสูงยิ่งเอนมาก
	_hip_y = hip_y
	_lean_f = p.get("lean_fwd", 0.0)
	_sway = p.get("sway", 0.0)
	_yaw = p.get("yaw", 0.0)
	_lift = p.get("lift", 0.0)
	_eyes = p.get("eyes", "glow")
	# ── ขาแบบวัว: ต้นขาขนน้ำตาล → เข่า (งอหน้า) → ข้อพับ (ย้อนหลัง) → ข้อเท้าเรียว → กีบแยกสองซีก ──
	for side: float in [-1.0, 1.0]:
		var foot: Vector3 = p["foot_l"] if side < 0.0 else p["foot_r"]
		var hip := Vector3(9.5 * side, hip_y, -1.0)
		var hock: Vector3 = foot + Vector3(0, 12, -5)       # ข้อพับอยู่หลัง/เหนือกีบ
		var fetlock: Vector3 = foot + Vector3(0, 3.5, 0.5)
		var knee: Vector3 = _ik3(hip, hock, 15.0, 14.0, 1.0)
		_ell(knee + Vector3(0, 0, 2.5), 5.5, 5.0, 4.0, STEEL, "plate", -1.0)  # สนับเข่า
		_cap(hip, knee, 8.5, 7.0, SKIN, "fur_thigh", -5.0)  # ขาอยู่หลังลำตัว (ไม่ทับท้อง)
		_cap(knee, hock, 7.0, 4.5, FUR_LEG, "fur_leg", -2.0)
		_cap(hock, fetlock, 3.6, 2.8, FUR_LEG)
		_ell(hock + Vector3(0, 0, -1), 4.5, 3.5, 4.5, FUR_LEG, "fur")    # ปอยขนที่ข้อพับ
		_ell(fetlock + Vector3(0, 0.5, -0.5), 4.5, 3.0, 4.5, FUR_LEG, "fur")  # ขนปุยเหนือกีบ
		# กีบแยกสองซีก + เดือยหลังกีบ
		for toe: float in [-1.0, 1.0]:
			_ell(foot + Vector3(2.3 * toe, 1.8, 2.0), 2.5, 2.2, 4.0, HOOF, "toe")
		_ell(foot + Vector3(0, 4.0, -3.0), 1.6, 1.4, 1.4, HOOF)
	# ── หาง: ห้อยจากก้น แกว่งตามจังหวะ · ปลายเป็นพู่ ──
	var sway: float = p.get("tail", 0.0)
	var t0 := Vector3(0, hip_y + 1, -10)
	var t1 := Vector3(sway * 0.4, hip_y - 10, -15)
	var t2 := Vector3(sway, hip_y - 21, -14)
	_cap(t0, t1, 2.4, 1.8, SKIN)
	_cap(t1, t2, 1.8, 1.4, SKIN)
	_ell(t2 + Vector3(0, -2.5, 0), 3.0, 4.5, 3.0, HAIR, "hair")
	# ── สะโพก + ผ้าเตี่ยวหนัง (หน้า/หลัง) + เข็มขัดเหล็ก ──
	# เข็มขัดเหล็กกว้าง + แผ่นเหล็กห้อยกันต้นขาสองข้าง (เกราะเรียบ ไม่มีลาย)
	_ell(Vector3(0, hip_y + 1, 0), 14.0, 5.0, 10.5, STEEL, "plate")
	for side: float in [-1.0, 1.0]:
		_cap(Vector3(9.5 * side, hip_y - 1, 9), Vector3(11.0 * side, hip_y - 12, 10), 5.5, 5.0, STEEL, "plate", 1.0)
		_cap(Vector3(9.5 * side, hip_y - 1, -8), Vector3(11.0 * side, hip_y - 11, -9), 5.0, 4.5, STEEL, "plate")
	_cap(Vector3(0, hip_y - 2, 9), Vector3(0, hip_y - 16, 10), 6.5, 5.5, LEATHER)
	_cap(Vector3(0, hip_y - 2, -9), Vector3(0, hip_y - 15, -10), 6.5, 5.0, LEATHER)
	_ell(Vector3(0, hip_y + 3, 10), 6.0, 5.0, 2.0, STEEL, "belt_plate")
	# ── ลำตัวทรง V: หลังกว้าง · หนอกหลังคอแบบวัว · ท้องซิกแพ็คเป็นก้อน · อกกว้างแยกสองข้าง · กล้ามข้างลำตัว ──
	_ell(_u(Vector3(0, 60 - bob, -5)), 17.0, 13.0, 11.0, SKIN, "back")
	_ell(_u(Vector3(0, 73 - bob + br * 0.3, -6)), 13.0, 8.0, 9.0, SKIN, "hump")
	_ell(_u(Vector3(0, 46 - bob, 3 + lean * 0.3)), 11.0, 12.0, 11.0, SKIN, "belly")
	for side: float in [-1.0, 1.0]:
		_ell(_u(Vector3(11.5 * side, 49 - bob, 1 + lean * 0.3)), 4.5, 9.0, 8.0, SKIN, "oblique")
	for side: float in [-1.0, 1.0]:
		_ell(_u(Vector3(9.5 * side, 61 - bob + br * 0.5, 5 + lean * 0.5)), 12.0, 8.0, 10.5, SKIN, "pec_r" if side > 0.0 else "pec_l", 0.3)
	_ell(_u(Vector3(0, 71 - bob + br * 0.4, 2 + lean)), 9.0, 6.0, 8.0, SKIN)  # คอหนา
	# ปลอกคอเหล็ก + สายหนังไขว้อก (หน้า/หลัง) + แผ่นเหล็กกลมกลางอก
	var cz: float = 5.0 + lean * 0.5
	_ell(_u(Vector3(0, 70 - bob + br * 0.4, 1 + lean)), 13.0, 4.0, 10.0, STEEL, "plate", 0.6)
	for side: float in [-1.0, 1.0]:
		_cap(_u(Vector3(15.0 * side, 68 - bob + br * 0.4, cz + 7.5)), _u(Vector3(-9.0 * side, 41 - bob, 3 + lean * 0.3 + 10.5)), 2.2, 2.2, LEATHER, "strap", 1.2)
		_cap(_u(Vector3(15.0 * side, 68 - bob + br * 0.4, -12)), _u(Vector3(-9.0 * side, 44 - bob, -11)), 2.2, 2.2, LEATHER, "strap", 1.2)
	_ell(_u(Vector3(0, 55 - bob + br * 0.4, cz + 9.5)), 5.0, 5.0, 2.0, STEEL, "plate", 1.6)
	# ── แขน: ไหล่กลม → ต้นแขน (ไบเซ็ป/ไตรเซ็ป) → แขนท่อนล่าง → มือ ──
	# ขวานอยู่มือขวาเสมอ · two_hand = มือซ้ายจับด้ามเหนือมือขวา 9 px (ท่าฟาด/กวาด/เสย/กระโดด)
	var up: Vector3 = (p.get("axe_dir", Vector3(0.14, 1.0, -0.05)) as Vector3).normalized()
	var two_hand: bool = p.get("two_hand", false)
	var hand_r: Vector3 = p["hand_r"]
	var hand_l: Vector3 = hand_r + up * 9.0 if two_hand else p["hand_l"]
	_parts.append({"d": _w(hand_r).z + 0.2, "fn": _draw_axe.bind(hand_r, up, p.get("axe_out", AXE_OUT) as Vector3)})
	for side: float in [-1.0, 1.0]:
		var sh := _u(Vector3(24.0 * side, sh_y, 1.0 + lean * 0.5) + Vector3(0, 0, p.get("twist", 0.0) * side))
		var hand: Vector3 = hand_l if side < 0.0 else hand_r
		var elbow: Vector3 = _ik3(sh, hand, 19.0, 18.0, -1.0) + Vector3(4.0 * side, 0, 0)
		_ell(sh + Vector3(1.5 * side, -1, 0), 9.0, 8.5, 9.0, SKIN, "delt")                 # กล้ามไหล่
		_cap(sh, elbow, 8.0, 6.5, SKIN, "tattoo")
		_ell(sh.lerp(elbow, 0.55) + Vector3(0, 0, 3.0), 6.0, 6.5, 5.0, SKIN, "muscle")     # ไบเซ็ป
		_ell(sh.lerp(elbow, 0.45) + Vector3(1.5 * side, 0, -3.0), 5.0, 6.5, 4.5, SKIN)     # ไตรเซ็ป
		_cap(elbow, hand, 7.5, 5.5, SKIN, "forearm")
		_cap(elbow.lerp(hand, 0.3), elbow.lerp(hand, 0.88), 7.4, 6.4, STEEL, "bracer")     # ถุงมือเกราะยาวถึงข้อศอก
		_ell(elbow + Vector3(0, 0, -1.5), 5.0, 5.0, 5.0, STEEL, "plate", 0.3)               # ปลอกศอก
		if side > 0.0 or two_hand:
			# กำด้ามจริง: อุ้งมือ (หลังด้าม) → ด้าม → นิ้วพันด้านหน้า + นิ้วโป้งบน
			_ell(hand, 5.0, 5.0, 5.0, SKIN, "palm", 0.0)
			_parts.append({"d": _w(hand).z + 0.6, "fn": _draw_fingers.bind(hand, up)})
		else:
			_ell(hand, 5.5, 5.0, 5.5, SKIN, "fist")
		# เกราะบ่าเรียบ: แผ่นเหล็กครอบบนหัวไหล่ (วาดหลังกล้ามไหล่เสมอ) + เขากระดูกอันเดียว
		_ell(sh + Vector3(2.5 * side, 5.5, -0.5), 10.0, 6.5, 10.0, STEEL, "pauldron", 1.5)
		_cap(sh + Vector3(6 * side, 11, -2), sh + Vector3(11 * side, 21, -4), 3.0, 0.8, BONE, "", 1.6)
	# ── หัว (ชิ้นรวม: แผงคอ · เขา · หน้า · เครา) ──
	var head := _u(Vector3(0, 85 - bob + br * 0.3 - p.get("head_dip", 0.0), 5 + lean))
	_parts.append({"d": _w(head).z + 0.5, "fn": _draw_head.bind(head)})


# ─────────────────────────── หัว ───────────────────────────

func _draw_head(c: Vector3) -> void:
	var facing_cam: float = _F.y  # 1 = หันเข้ากล้อง, -1 = หันหลัง
	var local: Array[Dictionary] = []
	# แผงคอ/ผมส้ม: ก้อนใหญ่หลังหัว + ปอยแหลมตั้งขึ้น
	_queue(local, c + Vector3(0, 7, -7), Vector3(12, 9, 9), HAIR, "hair")
	for k: Vector3 in [Vector3(0, 13, -2), Vector3(-5, 11, -4), Vector3(5, 11, -4), Vector3(0, 9, -9), Vector3(-8, 6, -7), Vector3(8, 6, -7)]:
		_queue_cap(local, c + k * 0.6, c + k * 1.15 + Vector3(0, 3, 0), 4.0, 1.0, HAIR, "hair")
	# หัววัว: กะโหลกกว้างแบน · หน้ายาวลงมาเป็นปากยื่น · จมูกกว้างสีอ่อน · คาง · หูกางข้างใต้เขา · ขนหยิกหน้าผาก
	_queue(local, c + Vector3(0, 2, 0), Vector3(12, 9, 10), SKIN, "skull")
	_queue(local, c + Vector3(0, -3, 7), Vector3(8.5, 8, 7), SKIN, "face")       # สันหน้ายาว
	_queue(local, c + Vector3(0, -9, 13), Vector3(9.5, 6.5, 6.5), MUZZLE, "muzzle")  # ปาก/จมูกยื่น
	_queue(local, c + Vector3(0, -13, 9), Vector3(6.5, 3.5, 5), SKIN)             # คาง
	for side: float in [-1.0, 1.0]:
		_queue(local, c + Vector3(15.0 * side, 1, 0), Vector3(6.5, 2.6, 3.8), SKIN, "ear_r" if side > 0.0 else "ear_l")
	_queue(local, c + Vector3(0, 8, 6), Vector3(7, 3.5, 4), HAIR, "curls")        # ขนหยิกหน้าผาก
	# เขาโค้งสีเข้ม: ออกข้าง → ขึ้น → ปลายชี้หน้า
	for side: float in [-1.0, 1.0]:
		var pts: Array[Vector3] = [Vector3(9, 5, 1), Vector3(17, 6, 3), Vector3(25, 10, 5), Vector3(28, 17, 7), Vector3(26, 24, 10)]
		var radii: Array[float] = [5.0, 4.4, 3.6, 2.4, 0.9]
		for i: int in pts.size() - 1:
			_queue_cap(local, c + Vector3(pts[i].x * side, pts[i].y, pts[i].z), c + Vector3(pts[i + 1].x * side, pts[i + 1].y, pts[i + 1].z),
				radii[i], radii[i + 1], HORN, "horn")
	# เคราถักยาวห้อยจากคาง
	var beard: Array[Vector3] = [Vector3(0, -15, 10), Vector3(0, -20, 11), Vector3(0, -25, 11), Vector3(0, -29, 10)]
	for i: int in beard.size() - 1:
		_queue_cap(local, c + beard[i], c + beard[i + 1], 4.0 - i * 0.8, 3.4 - i * 0.8, HAIR, "beard")
	# วาดเรียงความลึกในหัวเอง
	local.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["d"] < b["d"])
	for part: Dictionary in local:
		(part["fn"] as Callable).call()
	# หน้า (เห็นเมื่อหันเข้ากล้องหรือเฉียง): ตาเรือง · คิ้วขมวด · อัญมณีตาที่สามบนหน้าผาก · รูจมูก · ห่วงจมูก
	if facing_cam > -0.35:
		for side: float in [-1.0, 1.0]:
			var e: Vector2 = _scr(c + Vector3(6.5 * side, 1, 9))  # ตาวัวอยู่ค่อนไปข้างหัว
			if _F.y < 0.2 and _side_hidden(side):
				continue
			# ทิศเข้าหากลางหน้าบนจอ (คิ้วต่ำลงด้านใน = ดุ)
			var fc: Vector2 = _scr(c + Vector3(0, 2, 10))
			var inner: int = 1 if fc.x > e.x else -1
			var ex: int = int(e.x)
			var ey: int = int(e.y)
			match _eyes:
				"closed":
					# หลับตาปี๋ (เจ็บ): ขีดเข้มเฉียง
					for k: int in range(-2, 2):
						_px(ex + k * inner, ey + (1 if k * inner > 0 else 0), C_BROW)
				"off":
					# ตาดับ (ตาย): จุดเทาหม่น
					_px(ex, ey, Color("4a3a34"))
					_px(ex + inner, ey, Color("4a3a34"))
				_:
					# แสงเรืองจาง ๆ รอบดวงตา (dither)
					for oy: int in range(-2, 4):
						for ox: int in range(-3, 4):
							if (ox + oy) % 2 == 0 and absf(ox) + absf(oy) <= 4 and _over(ex + ox, ey + oy):
								_px(ex + ox, ey + oy, C_GLOW_DIM)
					# ตาเรือง 3×2: กลางขาวร้อน รอบส้ม
					for o: Vector2i in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1)]:
						_px(ex + o.x, ey + o.y, C_GLOW)
					_px(ex, ey, C_EYE)
					_px(ex + inner, ey, C_EYE)
			# คิ้วหนา 2 แถว: ด้านนอกสูง ด้านในต่ำ
			for k: int in range(-3, 3):
				var by: int = ey - 2 + (1 if k * inner > 0 else 0)
				_px(ex + k * inner, by, C_BROW)
				_px(ex + k * inner, by - 1, C_BROW)
		var gem: Vector2 = _scr(c + Vector3(0, 4, 9))
		_px(int(gem.x), int(gem.y), C_GEM)
		_px(int(gem.x), int(gem.y) + 1, Color("3a9cc8"))
		# จมูกวัว: รูจมูกใหญ่สองข้างรูปเม็ดถั่ว + ร่องกลาง · ห่วงจมูกทองห้อยใต้จมูก
		var nose: Vector2 = _scr(c + Vector3(0, -8, 19))
		var nx: int = int(nose.x)
		var ny: int = int(nose.y)
		# แผ่นจมูกเข้ม (ด้านหน้าปาก)
		for oy: int in range(-3, 3):
			for ox: int in range(-5, 6):
				if absf(ox) / 5.5 + absf(oy + 0.5) / 3.5 <= 1.0 and _over(nx + ox, ny + oy):
					_px(nx + ox, ny + oy, MUZZLE[2] if (ox + oy) % 2 == 0 or oy > 0 else MUZZLE[1])
		for side: int in [-1, 1]:
			for o: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(2, 0)]:
				_px(nx + side * 3 + (o.x if side > 0 else -o.x), ny + o.y, C_NOSTRIL)
			_px(nx + side * 3, ny - 2, MUZZLE[0])  # ขอบรูจมูกด้านบนรับแสง
		_px(nx, ny + 1, MUZZLE[3])
		_px(nx, ny + 2, MUZZLE[3])
		# ห่วงทอง: วงเล็ก ๆ ใต้จมูก
		for o: Vector2i in [Vector2i(-2, 3), Vector2i(-2, 4), Vector2i(-1, 5), Vector2i(0, 5), Vector2i(1, 5), Vector2i(2, 4), Vector2i(2, 3)]:
			_px(nx + o.x, ny + o.y, GOLD_RING[0] if o.x < 0 else GOLD_RING[1])
	elif facing_cam > -0.75:
		# หันข้าง/เฉียงหลัง: เห็นรูจมูกด้านข้างที่ปลายปาก
		var tip: Vector2 = _scr(c + Vector3(0, -8, 19))
		_px(int(tip.x), int(tip.y), C_NOSTRIL)


## ขวานสงครามน่ากลัว: ใบเหล็กดำขนาดใหญ่ คมหยักฟันเลื่อย ตะขอบน-ล่าง · หนามแหลมบนหัว · หนามโค้งด้านหลัง
## รูนแดงเรืองตามร่องใบ · คราบเลือดตามคม · ด้ามไม้ดำรัดเหล็ก ปลายด้ามมีหนาม · up = ทิศด้ามชี้ขึ้น (local)
func _draw_axe(hand: Vector3, up: Vector3, blade_out: Vector3) -> void:
	var pommel: Vector3 = hand - up * 13.0
	var top: Vector3 = hand + up * 38.0
	_draw_cap(_scr(pommel), _scr(top), 2.0, 1.8, WOOD_DARK, "haft", pommel, top)
	# หนามปลายด้าม
	_draw_cap(_scr(pommel), _scr(pommel - up * 5.0), 1.8, 0.4, BLADE, "", pommel, pommel)
	# ระนาบใบขวาน
	var out: Vector3 = blade_out
	out = (out - up * out.dot(up)).normalized()
	var hc: Vector3 = top - up * 12.0
	var o2: Vector2 = _scr(hc)
	var eu: Vector2 = _scr(hc + up) - o2
	var ev: Vector2 = _scr(hc + out) - o2
	# ย่อหัวขวานให้อยู่ในเฟรม (u, v ยังเป็นหน่วยเดิม)
	eu *= 0.8
	ev *= 0.8
	var det: float = eu.x * ev.y - eu.y * ev.x
	# (u = ตามด้าม, v = ออกไปทางคม) · คมหยัก = จุดสลับเข้า-ออก
	var blade: Array[Vector2] = [Vector2(6, 2.4), Vector2(14, 10), Vector2(19.5, 14.5), Vector2(15.5, 17), Vector2(14, 21),
		Vector2(11, 21.5), Vector2(9.5, 23.5), Vector2(6.5, 22.5), Vector2(4.5, 24.5), Vector2(1.5, 23.5), Vector2(-0.5, 25.5),
		Vector2(-3.5, 24.5), Vector2(-5.5, 26.5), Vector2(-8.5, 25), Vector2(-11, 26.5), Vector2(-13.5, 24),
		Vector2(-21, 20), Vector2(-22.5, 15.5), Vector2(-16, 12), Vector2(-9, 6), Vector2(-5, 2.4)]
	var edge_from: int = 3   # ช่วงจุดที่เป็นคม (ขัดเงา)
	var edge_to: int = 16
	var spike_top: Array[Vector2] = [Vector2(11, 1.6), Vector2(21, 0), Vector2(11, -1.6)]
	var spike_back: Array[Vector2] = [Vector2(4, -2.4), Vector2(2.5, -8), Vector2(-1, -15), Vector2(-0.5, -8.5), Vector2(-3, -2.4)]
	for shape: Array[Vector2] in [spike_back, spike_top, blade]:
		var pts: Array[Vector2] = []
		for q: Vector2 in shape:
			pts.append(o2 + eu * q.x + ev * q.y)
		var poly := PackedVector2Array(pts)
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for q: Vector2 in pts:
			lo = lo.min(q)
			hi = hi.max(q)
		for y: int in range(int(lo.y) - 1, int(hi.y) + 2):
			for x: int in range(int(lo.x) - 1, int(hi.x) + 2):
				var p := Vector2(x + 0.5, y + 0.5)
				if not Geometry2D.is_point_in_polygon(p, poly):
					continue
				var col: Color = BLADE[1]
				var u: float = 0.0
				var v: float = 0.0
				if absf(det) > 0.15:
					var r: Vector2 = p - o2
					u = (r.x * ev.y - r.y * ev.x) / det
					v = (eu.x * r.y - eu.y * r.x) / det
					col = BLADE[1] if u > 1.0 else BLADE[2]
					if (x + y) % 2 == 0 and absf(u - 1.0) < 1.0:
						col = BLADE[1]
				if shape == blade:
					# ระยะถึงคม (บนจอ) → คมขัดเงาสว่าง + คราบเลือด
					var ed: float = INF
					for i: int in range(edge_from, edge_to):
						ed = minf(ed, p.distance_to(Geometry2D.get_closest_point_to_segment(p, pts[i], pts[i + 1])))
					if ed < 1.3:
						col = C_EDGE
						if int(u * 2.0 + v) % 5 == 0:
							col = C_BLOOD
					elif ed < 2.6 and int(u * 3.0 + v * 2.0) % 7 == 0:
						col = C_BLOOD  # เลือดซึมใกล้คม
					elif absf(det) > 0.15 and absf(v - 10.0) < 1.0 and u > -12.0 and u < 10.0:
						# รูนแดงเรืองตามร่องใบ (เว้นช่องเป็นอักษร)
						col = C_RUNE if int(u + 20.0) % 4 != 0 else BLADE[3]
						if int(u + 20.0) % 4 == 1:
							col = C_RUNE_HOT
					elif absf(det) > 0.15 and absf(v - 10.0) < 2.0 and u > -12.0 and u < 10.0:
						col = BLADE[3]  # ขอบร่อง
				else:
					col = BLADE[0] if u > 0.0 or v < 0.0 and (x + y) % 2 == 0 else BLADE[2]
				_px(x, y, col)
	# ปลอกยึดหัวขวาน + แถบเหล็กรัดด้าม
	_draw_cap(_scr(hc - up * 3.5), _scr(hc + up * 4.5), 2.6, 2.6, BLADE, "", hc, hc)
	for f: float in [0.06]:
		var b: Vector3 = pommel.lerp(top, f)
		_draw_cap(_scr(b - up * 1.0), _scr(b + up * 1.0), 2.5, 2.5, STEEL, "", b, b)


## นิ้วที่โอบด้ามขวาน: 3 นิ้วพาดขวางด้ามด้านหน้า (ตั้งฉากกับด้ามบนจอ) + นิ้วโป้งพับทับด้านบน
func _draw_fingers(hand: Vector3, up: Vector3) -> void:
	var c: Vector2 = _scr(hand)
	var axis: Vector2 = (_scr(hand + up) - c).normalized()   # ทิศด้ามบนจอ
	var across := Vector2(-axis.y, axis.x)                    # ขวางด้าม
	for k: int in 3:
		var mid: Vector2 = c + axis * (1.5 - k * 2.2)
		var a: Vector2 = mid - across * 4.6
		var b: Vector2 = mid + across * 4.6
		_draw_cap(a, b, 1.35, 1.35, SKIN, "finger", hand, hand)
	# นิ้วโป้งพับข้ามด้านบนของกำ
	var t0: Vector2 = c + axis * 3.6 - across * 3.5
	_draw_cap(t0, t0 + across * 4.5 - axis * 0.5, 1.4, 1.2, SKIN, "finger", hand, hand)


## ตาข้างที่ถูกหัวบังตอนหันข้าง
func _side_hidden(side: float) -> bool:
	# side ของตา (ขวาตัว = +) → แกน X จอ = side * R.x ; หันข้าง: ตาข้างที่อยู่ไกลกล้อง (R.y*side < 0) ถูกบัง
	return _R.y * side < -0.5


# ─────────────────────────── ฉาย 3D → จอ ───────────────────────────

func _w(l: Vector3) -> Vector3:
	return Vector3(l.x * _R.x + l.z * _F.x, l.y, l.x * _R.y + l.z * _F.y)


func _scr(l: Vector3) -> Vector2:
	var w: Vector3 = _w(l)
	return Vector2(CX + w.x, FEET - (w.y + _lift) * 0.9 + w.z * 0.4)


func _cap(a: Vector3, b: Vector3, ra: float, rb: float, pal: Array, tag: String = "", bias: float = 0.0) -> void:
	var d: float = (_w(a).z + _w(b).z) * 0.5 + bias
	_parts.append({"d": d, "fn": _draw_cap.bind(_scr(a), _scr(b), ra, rb, pal, tag, a, b)})


func _ell(c: Vector3, a: float, b: float, cz: float, pal: Array, tag: String = "", bias: float = 0.0) -> void:
	_parts.append({"d": _w(c).z + bias, "fn": _draw_ell.bind(c, a, b, cz, pal, tag)})


func _queue(list: Array[Dictionary], c: Vector3, r: Vector3, pal: Array, tag: String = "") -> void:
	list.append({"d": _w(c).z, "fn": _draw_ell.bind(c, r.x, r.y, r.z, pal, tag)})


func _queue_cap(list: Array[Dictionary], a: Vector3, b: Vector3, ra: float, rb: float, pal: Array, tag: String = "") -> void:
	list.append({"d": (_w(a).z + _w(b).z) * 0.5, "fn": _draw_cap.bind(_scr(a), _scr(b), ra, rb, pal, tag, a, b)})


func _render() -> void:
	_parts.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["d"] < b["d"])
	for part: Dictionary in _parts:
		(part["fn"] as Callable).call()


## IK 3D แบบง่าย: แก้ในระนาบ (z, y) ของตัว · x เลื่อนเชิงเส้น · bend = +1 งอไปหน้า (เข่า), -1 งอไปหลัง (ศอก)
func _ik3(root: Vector3, target: Vector3, l1: float, l2: float, bend: float) -> Vector3:
	var to: Vector3 = target - root
	var dist: float = clampf(to.length(), 0.5, l1 + l2 - 0.01)
	var dir: Vector3 = to.normalized() if to.length() > 0.01 else Vector3.DOWN
	var a: float = (l1 * l1 - l2 * l2 + dist * dist) / (2.0 * dist)
	var h: float = sqrt(maxf(0.0, l1 * l1 - a * a))
	# ทิศตั้งฉากกับ dir ในระนาบ y-z ที่ชี้ไปหน้า (+z)
	var perp: Vector3 = Vector3(0, -dir.z, dir.y)
	if perp.length() < 0.01:
		perp = Vector3(0, 0, 1)
	perp = perp.normalized()
	if perp.z * bend < 0.0:
		perp = -perp
	return root + dir * a + perp * h


# ─────────────────────────── วาด 2D ───────────────────────────

## แรเงา 4 ระดับ + dither ลายหมากรุกตรงรอยต่อ · ขอบด้านมืดเข้มสุด
func _shade(n: Vector2, pal: Array, x: int, y: int) -> Color:
	var l: float = n.length()
	var lit: float = n.dot(LIGHT) * 0.85 + 0.15
	if l > 0.86 and lit < 0.3:
		return pal[3]
	var checker: bool = (x + y) % 2 == 0
	var cuts: Array[float] = [0.55, 0.15, -0.3]
	for i: int in 3:
		if lit > cuts[i] + 0.04:
			return pal[i]
		if lit > cuts[i] - 0.04:
			return pal[i] if checker else pal[i + 1]
	return pal[3]


## เส้นขอบตรงที่ชิ้นทับกัน: ต่างวัสดุ = เส้นเข้ม · กล้ามทับกล้าม (สีเดียวกัน) = เงานุ่ม ไม่ให้ตัวดูเป็นก้อน ๆ
func _rim(x: int, y: int, pal: Array, n: Vector2) -> Color:
	var under: Color = img.get_pixel(x, y)
	if pal.has(under):
		return pal[2] if n.dot(LIGHT) < -0.15 else _shade(n, pal, x, y)
	return pal[3]


## ชิ้นที่วาดทับชิ้นอื่น → ขอบเป็นเส้นเข้ม (แยกหัวจากอก แขนจากตัว ฯลฯ)
func _over(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < SIZE and y < SIZE and img.get_pixel(x, y).a > 0.0


func _draw_cap(a: Vector2, b: Vector2, ra: float, rb: float, pal: Array, tag: String, la: Vector3, lb: Vector3) -> void:
	var r: float = maxf(ra, rb)
	var ab: Vector2 = b - a
	var len2: float = maxf(ab.length_squared(), 0.0001)
	var seg_len: float = sqrt(len2)
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
			var col: Color = _shade(n, pal, x, y)
			# เส้นตัดขอบเมื่อทับชิ้นอื่น (ชิ้นใหญ่เท่านั้น)
			if rr >= 3.5 and l > 0.84 and _over(x, y) and n.dot(LIGHT) < 0.5:
				col = _rim(x, y, pal, n)
			var along: float = t * seg_len
			match tag:
				"bracer":
					# สนับเรียบ: ขอบบน/ล่างเข้ม · เส้นส้มบาง ๆ เส้นเดียว
					if t < 0.08 or t > 0.92:
						col = STEEL[3]
					elif absf(t - 0.5) < 0.05:
						col = C_GLOW
				"haft":
					# ด้ามขวาน: พันหนังช่วงที่มือกำ + ลายไม้
					if t > 0.22 and t < 0.42 and int(along) % 3 != 0:
						col = LEATHER[1] if n.dot(LIGHT) > 0.0 else LEATHER[2]
					elif int(along * 0.5 + d.x) % 5 == 0:
						col = pal[2]
				"hammer":
					# แถบเหล็กรัด 3 เส้น + รอยร้าวเรืองส้มแนวทแยง
					if absf(t - 0.15) < 0.06 or absf(t - 0.85) < 0.06:
						col = STEEL[0] if n.dot(LIGHT) > 0.0 else STEEL[3]
					elif absf(t - 0.5) < 0.07:
						col = C_GLOW
					elif l < 0.7 and int(along + d.x * 1.3) % 6 == 0 and n.dot(LIGHT) < 0.3:
						col = C_GLOW if (x + y) % 3 != 0 else C_GLOW_HOT
				"horn":
					# วงหยักตามเขา (ทุก 3 px) — ด้านสว่างเป็นสันสว่าง
					if int(along) % 3 == 0 and l < 0.92:
						col = pal[2] if n.dot(LIGHT) < 0.3 else pal[1]
				"hair":
					# เส้นขนตามแนวปอย
					if int(along * 0.9 + d.x * 2.0) % 3 == 0 and l < 0.9:
						col = pal[2] if n.dot(LIGHT) > 0.0 else pal[3]
				"beard":
					# ห่วงทองคั่นเคราถัก
					if t < 0.18 and l < 0.95:
						col = GOLD_RING[0] if n.dot(LIGHT) > 0.2 else GOLD_RING[1]
					elif int(along + d.x * 1.5) % 3 == 0:
						col = pal[2]
				"tattoo":
					# รอยสักลายชนเผ่า: บั้งเข้มรอบต้นแขนช่วงกลาง
					if t > 0.35 and t < 0.65 and absf(fposmod(along - absf(d.x) * 0.8, 4.0) - 1.0) < 0.6 and l < 0.85:
						col = C_TATTOO
				"claw":
					if t > 0.6:
						col = BONE[0] if n.dot(LIGHT) > 0.0 else BONE[2]
				"fur_thigh", "fur_leg":
					# ขนสัตว์: เส้นขนตามแนวขา · ขอบนอกเป็นปอยขรุขระ (เว้นพิกเซลสลับ)
					if l > 0.82 and (x + y) % 2 == 0 and not _over(x, y):
						continue
					if int(along * 0.8 + d.x * 1.7 + 30.0) % 4 == 0 and l < 0.85:
						col = pal[2] if n.dot(LIGHT) > 0.1 else pal[3]
					elif tag == "fur_leg" and t > 0.75 and l < 0.6:
						col = pal[1]  # ขนยาวรวบที่ข้อพับ
				"finger":
					# ข้อนิ้ว: ขอบล่างเข้ม แยกนิ้วแต่ละนิ้ว · กลางนิ้วสว่าง
					col = SKIN[3] if n.y > 0.45 or l > 0.9 else (SKIN[0] if n.y < -0.3 else SKIN[1])
				"forearm":
					# กล้ามแขนท่อนล่างนูนช่วงใกล้ศอก
					if t < 0.4 and n.dot(LIGHT) > 0.35 and l > 0.35 and l < 0.6:
						col = pal[0]
			_px(x, y, col)


func _draw_ell(c: Vector3, a: float, b: float, cz: float, pal: Array, tag: String) -> void:
	var sc: Vector2 = _scr(c)
	# ขนาดบนจอของวงรี 3 แกนหลังหมุน
	var rx: float = sqrt(pow(a * _R.x, 2.0) + pow(cz * _F.x, 2.0))
	var ry: float = sqrt(pow(b * 0.9, 2.0) + pow(a * _R.y * 0.4, 2.0) + pow(cz * _F.y * 0.4, 2.0))
	rx = maxf(rx, 1.0)
	ry = maxf(ry, 1.0)
	var front: bool = _F.y > 0.3  # ด้านหน้าหันเข้ากล้อง
	for y: int in range(int(sc.y - ry) - 1, int(sc.y + ry) + 2):
		for x: int in range(int(sc.x - rx) - 1, int(sc.x + rx) + 2):
			var n := Vector2((x + 0.5 - sc.x) / rx, (y + 0.5 - sc.y) / ry)
			var l: float = n.length()
			if l > 1.0:
				continue
			var col: Color = _shade(n, pal, x, y)
			if minf(rx, ry) >= 3.5 and l > 0.86 and _over(x, y) and n.dot(LIGHT) < 0.5:
				col = _rim(x, y, pal, n)
			match tag:
				"pauldron":
					# เกราะเรียบ: ขอบล่างเข้ม · เส้นส้มเส้นเดียวใกล้ขอบ · เงาสะท้อนแถบเดียว
					if l > 0.86 and n.y > -0.2:
						col = STEEL[3]
					elif l > 0.72 and n.y > 0.1:
						col = C_GLOW
					elif absf(n.dot(Vector2(0.8, -0.6))) < 0.08 and n.dot(LIGHT) > 0.2:
						col = STEEL[0]
				"pec_l", "pec_r":
					# อกเป็นก้อนกล้ามกลม: ไฮไลต์ด้านบนนอก · เงาใต้อกเข้ม · ร่องกลางอก
					var side: float = 1.0 if tag == "pec_r" else -1.0
					var inner_x: float = -side * signf(_R.x) if absf(_R.x) > 0.3 else 0.0
					if n.y > 0.55 and l > 0.75:
						col = SKIN[3]
					elif n.y > 0.35 and l > 0.7:
						col = SKIN[2]
					elif inner_x != 0.0 and n.x * inner_x > 0.78:
						col = SKIN[3]  # ร่องกลางอก
					elif n.y < -0.1 and n.dot(LIGHT) > 0.35 and l > 0.3 and l < 0.75:
						col = SKIN[0]
				"delt":
					# กล้ามไหล่กลม: ไฮไลต์ด้านบน · ร่องล่าง
					if n.y < -0.3 and n.dot(LIGHT) > 0.3 and l < 0.7:
						col = SKIN[0]
					elif n.y > 0.65:
						col = SKIN[3]
				"fist":
					# ข้อนิ้ว: จุดสว่างแถวบน · ร่องนิ้วแนวตั้ง
					if n.y < -0.35 and n.y > -0.7 and (x % 2 == 0):
						col = pal[0]
					elif n.y > -0.3 and n.y < 0.5 and x % 2 == 1 and l < 0.8:
						col = pal[2]
				"belly":
					# ซิกแพ็ค 2×3 ก้อน (เห็นเมื่อหันหน้า): ร่องกลาง · ร่องขวาง · แต่ละก้อนสว่างมุมบนซ้าย
					if front and absf(n.x) < 0.6 and n.y > -0.8 and n.y < 0.75:
						var row: float = fposmod(n.y + 0.8, 0.5)
						var colx: float = absf(n.x)
						if colx < 0.08 or row < 0.07:
							col = SKIN[3]
						elif row < 0.18 and colx < 0.5:
							col = SKIN[0] if n.x < 0.0 or (x + y) % 2 == 0 else SKIN[1]
						elif row > 0.38:
							col = SKIN[2]
				"belt_plate":
					if l < 0.45:
						col = C_GLOW
					elif l > 0.75 and (x + y) % 3 == 0:
						col = STEEL[0]
				"necklace":
					if n.y < 0.1 or l < 0.55:
						continue
					col = BONE[1] if (x / 2) % 2 == 0 else ROPE[2]
					if (x / 2) % 4 == 0:
						col = BONE[0]
				"fur":
					# ขนปุยปลายแหลม: ขอบล่างเป็นซี่ ๆ · เส้นขน
					if n.y > 0.35 and l > 0.72 and (x % 2 == 0):
						continue
					if int(x + y * 0.5) % 3 == 0 and l < 0.85:
						col = pal[2]
				"hoof":
					if front and absf(n.x) < 0.1:
						col = pal[3]  # ร่องกลางกีบ
					elif n.y < -0.4 and l < 0.8:
						col = pal[0]
				"hair":
					if int(n.x * 9.0 + n.y * 4.0 + 20.0) % 2 == 0 and l < 0.9 and n.dot(LIGHT) < 0.45:
						col = pal[2]
				"toe":
					# กีบมันวาว: ไฮไลต์บนสุด · ขอบล่างเข้ม
					if n.y < -0.35 and n.x < 0.2 and l < 0.75:
						col = pal[0]
					elif n.y > 0.5:
						col = pal[3]
				"back", "hump":
					# ขนวัวหยาบบนหลัง/หนอก: เส้นขนโค้งตามตัว
					if int((n.x * n.x + n.y) * 10.0 + 40.0) % 3 == 0 and l < 0.88:
						col = pal[2] if n.dot(LIGHT) > 0.2 else pal[3]
				"oblique":
					# กล้ามซี่โครงข้างลำตัว (เส้นเฉียงสั้น ๆ)
					if absf(fposmod(n.y * 3.0 + n.x * 1.5, 1.0) - 0.5) < 0.12 and l < 0.8:
						col = pal[3]
				"muscle":
					# ไบเซ็ป: ไฮไลต์โค้งด้านแสง + เงาด้านล่าง
					if n.dot(LIGHT) > 0.4 and l > 0.4 and l < 0.7:
						col = pal[0]
					elif n.y > 0.6 and l > 0.7:
						col = pal[3]
				"muzzle":
					# จมูกเปียกมันวาวด้านบน · ขอบล่างเข้ม
					if n.y < -0.45 and absf(n.x) < 0.5 and l < 0.8 and (x + y) % 2 == 0:
						col = pal[0]
					elif n.y > 0.65:
						col = pal[3]
				"ear_l", "ear_r":
					# ด้านในหูสีชมพู (ฝั่งหน้า)
					if l < 0.55 and _F.y > -0.2:
						col = C_EAR_IN if n.dot(LIGHT) > -0.2 else MUZZLE[2]
				"curls":
					# ขนหยิกเป็นขด ๆ บนหน้าผาก
					if (x * 2 + y) % 4 == 0:
						col = pal[0]
					elif (x + y * 2) % 4 == 1:
						col = pal[3]
				"skull", "face":
					# ขนหน้าสั้น: เส้นแนวตั้งจาง ๆ
					if x % 3 == 0 and l < 0.8 and n.dot(LIGHT) < 0.3:
						col = pal[2]
			_px(x, y, col)


func _px(x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < SIZE and y < SIZE:
		img.set_pixel(x, y, c)


func _outline() -> void:
	var solid: Array[bool] = []
	solid.resize(SIZE * SIZE)
	for y: int in SIZE:
		for x: int in SIZE:
			solid[y * SIZE + x] = img.get_pixel(x, y).a > 0.0
	for y: int in SIZE:
		for x: int in SIZE:
			if solid[y * SIZE + x]:
				continue
			for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = Vector2i(x, y) + o
				if q.x >= 0 and q.y >= 0 and q.x < SIZE and q.y < SIZE and solid[q.y * SIZE + q.x]:
					img.set_pixel(x, y, C_OUTLINE)
					break


func _save_preview(sheet: Image) -> void:
	const SCALE: int = 2
	var pv := Image.create_empty(sheet.get_width() * SCALE, sheet.get_height() * SCALE, false, Image.FORMAT_RGBA8)
	pv.fill(Color("1b1f2b"))
	var big: Image = sheet.duplicate()
	big.resize(sheet.get_width() * SCALE, sheet.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
	pv.blend_rect(big, Rect2i(Vector2i.ZERO, pv.get_size()), Vector2i.ZERO)
	pv.save_png(ProjectSettings.globalize_path(OUT_DIR + "tools/minotaur_preview.png"))
