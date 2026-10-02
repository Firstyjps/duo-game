# Mockup (ทิ้งได้)

ฉากทดลองเพื่อดู movement / feel — **ไม่ใช่โค้ดจริงของระบบ A/B** โค้ดใน `game/systems/` ห้ามอ้างถึงไฟล์ในนี้
ใช้ contract damage จริง (`game/core/combat/`) · ภาพจาก Higgsfield (Nano Banana 2) ต้นฉบับอยู่ `art/concept/`

```bash
godot --path game res://mockup/mockup.tscn                       # เล่นเอง
godot --path game res://mockup/mockup.tscn -- --autoplay          # ดูบอทเล่น
```

| ปุ่ม | ทำอะไร |
|---|---|
| WASD / ลูกศร | เดิน |
| เมาส์ | เล็ง |
| คลิกซ้าย / J | ฟันดาบ (15 stamina) |
| Space / Shift | dodge — i-frames 0.24 วิ (25 stamina) · กดตอน recover หลังฟันได้ |
| R | เริ่มใหม่ |

สิ่งที่มี: โครงกระดูก 2 ตัว (telegraph 0.55 วิ + วงแดงบนพื้น, เซได้เมื่อโดน 2 ที) → ตายแล้วดรอปเหรียญ (`EventBus.enemy_died`) → โกเลมตื่น (`EventBus.boss_engaged` → หลอด HP บอส) · ทุบพื้น telegraph 1 วิ · hitstop, กล้องสั่น, ตัวเลขดาเมจ (`EventBus.damage_dealt`) · แสงคบเพลิง

ค่าที่ลองจูน: `mockup_player.gd` (SPEED, DODGE_*, STAMINA_*, WINDUP/ACTIVE/RECOVER) · `mockup_enemy.gd` (`KINDS`)
คลิป: `art/mockup/mockup-autoplay.mp4` · แปลงภาพใหม่: `godot --headless --path game --script res://mockup/tools/import_concept.gd`
