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
## ผู้ป้องกัน (ผู้เล่น parry) emit หลังปัดสำเร็จ → VFX/เสียง/hitstop · ผู้ตีใช้ `Hitbox.deflected` ของตัวเอง
signal attack_deflected(defender: Node, info: DamageInfo)

# ── feedback · docs/contracts/feedback.md ──
## ใครก็ emit ได้ (ศัตรูกระทืบ/ระเบิด/บอสทุบ) → กล้อง (A) เพิ่ม trauma · strength 0..1 · position ไว้ลดแรงตามระยะ (ไม่บังคับ)
signal screen_shake_requested(strength: float, position: Vector2)

# ── ดันเจี้ยน · docs/contracts/dungeon-flow.md ──
## dungeon (B) emit ตอนห้องปิดประตูเริ่มสู้ → กล้อง/HUD/เพลง (A)
signal room_started(room: Node, room_rect: Rect2)
## dungeon (B) emit ตอนศัตรูในห้องหมด ประตูเปิด
signal room_cleared(room: Node)
## dungeon (B) emit หลัง player_died + รีเซ็ตห้องแล้ว → ผู้เล่น (A) ฟื้นเต็มที่ตำแหน่งนี้
signal player_respawn_requested(position: Vector2)
