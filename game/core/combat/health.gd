class_name Health
extends Node
## HP ของผู้เล่น/ศัตรู/ของที่ทำลายได้ — HUD (ระบบ A) อ่านจาก signal นี้ ไม่ต้องรู้จักตัวศัตรู

signal changed(current: int, maximum: int)
signal died

@export var max_hp: int = 10
var hp: int = 0
var is_dead: bool:
	get:
		return hp <= 0


func _ready() -> void:
	reset()


func reset() -> void:
	hp = max_hp
	changed.emit(hp, max_hp)


## คืนดาเมจที่หักจริง · ตายแล้วไม่หักซ้ำ และ `died` emit ครั้งเดียว
func take_damage(amount: int) -> int:
	if is_dead or amount <= 0:
		return 0
	var dealt: int = mini(amount, hp)
	hp -= dealt
	changed.emit(hp, max_hp)
	if hp <= 0:
		died.emit()
	return dealt


func heal(amount: int) -> int:
	if is_dead or amount <= 0:
		return 0
	var healed: int = mini(amount, max_hp - hp)
	hp += healed
	changed.emit(hp, max_hp)
	return healed
