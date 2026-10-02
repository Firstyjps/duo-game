extends Node
## signal ข้ามระบบทั้งหมดประกาศที่นี่ที่เดียว — แต่ละอันต้องมี contract ใน docs/contracts/
## เพิ่ม/แก้ = PR label `contract`

# ── ต่อสู้ · docs/contracts/damage.md ──
## ผู้รับ emit หลังหัก HP แล้ว (final_amount = ที่หักจริง) → ตัวเลขดาเมจ, hitstop, กล้องสั่น
signal damage_dealt(target: Node, info: DamageInfo, final_amount: int)
## ระบบ enemy (B) emit ครั้งเดียวต่อตัว → loot (B) ดรอปของ, ระบบอื่นนับ kill ได้
signal enemy_died(enemy: Node, enemy_id: StringName, position: Vector2)
## ระบบผู้เล่น (A) emit → dungeon (B) รีเซ็ต/กลับจุดเริ่ม
signal player_died
## ระบบ enemy/dungeon (B) emit ตอนเริ่มสู้บอส → HUD (A) แสดงหลอด HP จาก `health`
signal boss_engaged(boss: Node, health: Health, display_name: String)
