class_name Combat
extends RefCounted
## ค่าคงที่ของการต่อสู้ที่ทุกระบบใช้ร่วมกัน — contract: docs/contracts/damage.md

enum Team { PLAYER, ENEMY, NEUTRAL }

## physics layer (bit) — ชื่อตั้งไว้ใน project.godot [layer_names]
const LAYER_WORLD: int = 1 << 0
const LAYER_PLAYER: int = 1 << 1
const LAYER_ENEMY: int = 1 << 2
const LAYER_HURTBOX: int = 1 << 3

## NEUTRAL (กับดัก) โดนทุกฝั่ง · ฝั่งเดียวกันไม่โดนกันเอง
static func can_hit(attacker: Team, target: Team) -> bool:
	return attacker == Team.NEUTRAL or attacker != target
