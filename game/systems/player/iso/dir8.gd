class_name Dir8
extends RefCounted
## 8 ทิศของสไปรต์ (ชื่อตรงกับ PixelLab) — เลือกจากเวกเตอร์ "บนจอ" (x ขวา, y ลง = south)
## ลำดับทวนเข็มบนจอเริ่มที่ south: index ตรงกับแถวใน atlas ที่ tools/build_dir_atlas.py สร้าง

enum { SOUTH, SOUTH_EAST, EAST, NORTH_EAST, NORTH, NORTH_WEST, WEST, SOUTH_WEST }

const COUNT: int = 8
const NAMES: Array[String] = [
	"south", "south-east", "east", "north-east",
	"north", "north-west", "west", "south-west",
]
const SECTOR: float = TAU / COUNT


## มุมกลางของทิศ (เรเดียนแบบ Vector2.angle(): east = 0, south = +PI/2)
static func center_angle(dir: int) -> float:
	return PI * 0.5 - float(posmod(dir, COUNT)) * SECTOR


static func to_vector(dir: int) -> Vector2:
	return Vector2.from_angle(center_angle(dir))


## เวกเตอร์ยาว ~0 → คืน fallback (ยืนนิ่งให้หันทางเดิม)
static func from_vector(v: Vector2, fallback: int = SOUTH) -> int:
	if v.length_squared() < 0.0001:
		return fallback
	return posmod(roundi((PI * 0.5 - v.angle()) / SECTOR), COUNT)


## เหมือน from_vector แต่ไม่เปลี่ยนทิศถ้ายังอยู่ใกล้ขอบทิศเดิม (กันสไปรต์กระพริบตอนก้าน analog อยู่ตรงรอยต่อ)
static func from_vector_sticky(v: Vector2, current: int, margin_deg: float = 8.0) -> int:
	if v.length_squared() < 0.0001:
		return current
	var diff: float = absf(angle_difference(v.angle(), center_angle(current)))
	if diff <= SECTOR * 0.5 + deg_to_rad(margin_deg):
		return current
	return from_vector(v, current)


static func name_of(dir: int) -> String:
	return NAMES[posmod(dir, COUNT)]
