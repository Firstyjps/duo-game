class_name DamageInfo
extends RefCounted
## ข้อมูลการโจมตี 1 ครั้ง — Hitbox สร้าง → Hurtbox ส่งต่อให้ owner ของตัวที่โดน

## ดาเมจ**ก่อน**หัก defense — ผู้รับหัก defense ของตัวเองแล้วค่อยเรียก Health.take_damage()
var amount: int = 1
var type: StringName = &"physical"
## ฝั่งผู้โจมตี
var team: Combat.Team = Combat.Team.NEUTRAL
## ทิศ × แรง (px/s) — ผู้รับเป็นคนใส่ให้ตัวเอง
var knockback: Vector2 = Vector2.ZERO
## poise damage — ผู้รับตัดสินเองว่าเซ/ขัดท่าไหม
var stagger: float = 0.0
var is_crit: bool = false
## ผู้โจมตี — อาจถูก free ไปแล้ว ต้อง is_instance_valid() ก่อนใช้
var source: Node = null
var hit_position: Vector2 = Vector2.ZERO
