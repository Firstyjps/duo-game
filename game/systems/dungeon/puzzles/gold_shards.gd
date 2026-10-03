class_name GoldShards
extends RefCounted
## ตัวนับเศษทองชั่วคราวระหว่างรอ contract currency/loot (issue #57)
## ใช้ static var แทน autoload (ห้ามเพิ่ม autoload เอง)

static var count: int = 0


static func reset() -> void:
	count = 0


static func add(amount: int = 1) -> void:
	count += amount


static func spend(amount: int) -> bool:
	if count >= amount:
		count -= amount
		return true
	return false
