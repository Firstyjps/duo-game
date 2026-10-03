class_name Hurtbox
extends Area2D
## ตัวรับดาเมจ — ติดที่ผู้เล่น (A) / ศัตรู (B)
## owner ฟัง `hurt` → หัก defense → Health.take_damage() → EventBus.damage_dealt

signal hurt(info: DamageInfo)
## ปัดการโจมตีได้ (parry) — ไม่ emit hurt, ผู้ตีได้ Hitbox.deflected แทน hit_landed
signal deflected(info: DamageInfo)

enum Result { REJECTED, HIT, DEFLECTED }

@export var team: Combat.Team = Combat.Team.NEUTRAL
## i-frames (เช่นตอน dodge) — owner เปิด/ปิดเอง
var invulnerable: bool = false
## หน้าต่าง parry — owner เปิด/ปิดเอง (ฝั่งเดียวกัน/i-frames ยังปฏิเสธก่อนเสมอ)
var deflecting: bool = false


func _init() -> void:
	collision_layer = Combat.LAYER_HURTBOX
	collision_mask = 0
	monitoring = false
	monitorable = true


## คืน true = โดนจริง (Hitbox จะ emit hit_landed สำหรับ hitstop/VFX)
func receive(info: DamageInfo) -> bool:
	return receive_result(info) == Result.HIT


## REJECTED = ไม่นับ (ฝั่งเดียวกัน/i-frames — โดนซ้ำได้เมื่อหมด) · HIT = emit hurt · DEFLECTED = emit deflected
func receive_result(info: DamageInfo) -> Result:
	if invulnerable or not Combat.can_hit(info.team, team):
		return Result.REJECTED
	if deflecting:
		deflected.emit(info)
		return Result.DEFLECTED
	hurt.emit(info)
	return Result.HIT
