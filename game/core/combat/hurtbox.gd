class_name Hurtbox
extends Area2D
## ตัวรับดาเมจ — ติดที่ผู้เล่น (A) / ศัตรู (B)
## owner ฟัง `hurt` → หัก defense → Health.take_damage() → EventBus.damage_dealt

signal hurt(info: DamageInfo)

@export var team: Combat.Team = Combat.Team.NEUTRAL
## i-frames (เช่นตอน dodge) — owner เปิด/ปิดเอง
var invulnerable: bool = false


func _init() -> void:
	collision_layer = Combat.LAYER_HURTBOX
	collision_mask = 0
	monitoring = false
	monitorable = true


## คืน true = โดนจริง (Hitbox จะ emit hit_landed สำหรับ hitstop/VFX)
func receive(info: DamageInfo) -> bool:
	if invulnerable or not Combat.can_hit(info.team, team):
		return false
	hurt.emit(info)
	return true
