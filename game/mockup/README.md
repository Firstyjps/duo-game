# Mockup (ทิ้งได้)

ฉากทดลองเพื่อดู movement / feel — **ไม่ใช่โค้ดจริงของระบบ A/B** โค้ดใน `game/systems/` ห้ามอ้างถึงไฟล์ในนี้
ใช้ contract damage จริง (`game/core/combat/`) · **สไลม์ = ของจริงจากระบบ enemy ของ Few** (instance `systems/enemy/slime/slime.tscn` ไม่ได้ copy — Few แก้แล้ว mockup เปลี่ยนตาม)
ภาพ: ดันเจี้ยน/อัศวิน/โครงกระดูก/โกเลมจาก Higgsfield · สนามหญ้าจาก Kling (ทั้งคู่ใช้ Nano Banana 2) ต้นฉบับอยู่ `art/concept/`

```bash
godot --path game res://mockup/mockup.tscn                       # เล่นเอง
godot --path game res://mockup/mockup.tscn -- --autoplay          # ดูบอทเล่น
godot --path game res://mockup/mockup.tscn -- --arena=stone       # เริ่มที่ดันเจี้ยน (ค่าเริ่ม = สนามหญ้า)
```

| ปุ่ม | ทำอะไร |
|---|---|
| WASD / ลูกศร | เดิน |
| เมาส์ | เล็ง |
| คลิกซ้าย / J | ฟันดาบ (15 stamina) |
| Space / Shift | dodge — i-frames 0.24 วิ (25 stamina) · กดตอน recover หลังฟันได้ |
| R | เริ่มใหม่ |
| Tab | สลับด่าน สนามหญ้า ↔ ดันเจี้ยน |

สิ่งที่มี: **รอบ 1** สไลม์ ×3 (ของ Few) → **รอบ 2** โครงกระดูก ×2 (telegraph 0.55 วิ + วงแดงบนพื้น, เซได้เมื่อโดน 2 ที) → **บอส** โกเลมตื่น · ขึ้นรอบใหม่ HP เต็ม · ศัตรูตายดรอปเหรียญ (`EventBus.enemy_died`) · โกเลม (`EventBus.boss_engaged` → หลอด HP บอส) · ทุบพื้น telegraph 1 วิ · hitstop, กล้องสั่น, ตัวเลขดาเมจ (`EventBus.damage_dealt`) · แสงคบเพลิง

ค่าที่ลองจูน: `mockup_player.gd` (SPEED, DODGE_*, STAMINA_*, WINDUP/ACTIVE/RECOVER) · `mockup_enemy.gd` (`KINDS`)
คลิป: `art/mockup/mockup-autoplay.mp4` · แปลงภาพใหม่: `godot --headless --path game --script res://mockup/tools/import_concept.gd`
