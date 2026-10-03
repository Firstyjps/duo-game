# Decisions

ใหม่สุดอยู่บน · 1 เรื่อง 3–5 บรรทัด · เปลี่ยนใจ = เพิ่มรายการใหม่อ้างอันเดิม (ไม่ลบของเก่า)

## 2026-10-03 · contract ใหม่: parry/deflect · สั่นจอ · ห้องเริ่ม/เคลียร์ · ฟื้นผู้เล่น (#51)
- ใครตัดสิน: Kron (user อนุมัติทั้ง 4) · Few: **รีวิวย้อนหลังใน #51**
- `damage.md` v2: `Hurtbox.deflecting`/`deflected` + `Hitbox.deflected` + `EventBus.attack_deflected` — parry ไม่ทำให้ผู้ตีได้ `hit_landed` อีกต่อไป
- `feedback.md`: `EventBus.screen_shake_requested(strength, position)` (บอสกระทืบ/ทุบ)
- `dungeon-flow.md`: `room_started(room, room_rect)` · `room_cleared(room)` · `player_respawn_requested(position)` → Player `revive()`

## 2026-10-02 · มุมมองเปลี่ยนเป็น isometric + art/feel Kintsugi (#37) — แทนบางส่วนของ #8
- ใครตัดสิน: Kron (user ตัดสินใจขั้นสุดท้าย) · Few: **ขอให้อ่านแล้ว comment ใน #37 ถ้าติดอะไร**
- มุม: **isometric** แทน top-down 3/4 · TileSet `TILE_SHAPE_ISOMETRIC` + `DIAMOND_DOWN` tile **64×32** · y-sort · เดินแบบ screen-space · ฐานจอ 960×540 integer + nearest เหมือนเดิม
- ตัวละคร/ศัตรู **8 ทิศ** (ลำดับ/ชื่อตาม PixelLab: `Dir8`) · ผู้เล่น 64 px (atlas ช่อง 96) · ศัตรู/บอส art จริงใช้ PixelLab 8 ทิศ (placeholder วาดด้วยโค้ดได้)
- ธีมภาพ/feel: Kintsugi (ลานวัดญี่ปุ่นยามค่ำ รอยร้าวทอง) จาก `kintsugi/` · ตัวเกมยังเป็น ARPG Souls-lite + loot ตาม #8 · ต้นแบบเว็บ Three.js ใน `kintsugi/prototypes/` = ข้อมูลอ้างอิงเท่านั้น
- ผลกระทบ: tile/ห้องของ dungeon และ sprite ศัตรูต้องเป็น iso · ของเดิม (slime 32 px) ยังใช้ได้ระหว่างเปลี่ยน

## 2026-10-02 · เปลี่ยนเป็น auto merge (ไม่ต้องรอรีวิวก่อน merge)
- ใครตัดสิน: Kron
- ทุก PR merge เข้า `main` เองเมื่อ CI ผ่าน (`/wrap` ทำให้) · ยังผ่าน PR เสมอเพื่อให้ CI กัน main พัง + มีประวัติให้อีกคนอ่าน
- รีวิวเปลี่ยนเป็น**ย้อนหลัง** — `/start` อ่าน PR ที่อีกคน merge เข้ามา · แตะ core/contract ต้องเขียน ⚠️ ใน handoff
- แทนกติกาเดิม "อีกคนรีวิวภายใน 24 ชม. / ห้าม merge เอง" ใน `docs/WORKFLOW.md`

## 2026-10-02 · Kron ยืนยัน #8/#9 + แบ่งระบบ + ความละเอียด (#12)
- ยืนยันรายการ "แนวเกม ARPG + art pixel 32 px" ด้านล่าง → ตกลงแล้วทั้งคู่
- แบ่งระบบ: Kron = A (ผู้เล่น + ต่อสู้ + สกิล/build + UI/HUD) · Few = B (ดันเจี้ยน/ห้อง + ศัตรู AI + loot) — แก้ OWNERS ใน PR แยก
- ความละเอียด: 960×540 + aspect `expand` + scale `integer` (1440p เห็นพื้นที่ 1280×720 แทนขอบดำ/เบลอ)

## 2026-10-02 · แนวเกม ARPG + art pixel 32 px top-down 3/4 (#8)
- ใครตัดสิน: Few · สถานะ: **รอ Kron ยืนยัน**
- ARPG real-time · single-player · PC (Steam) · MVP ตาม `DESIGN.md`
- art: pixel 32×32 px, มุม top-down 3/4 (ref Dimraeth / Romestead / Core Keeper), Godot 2D + แสง 2D, ฐาน 960×540 scale จำนวนเต็ม
- ผลกระทบ: ทุก asset ต้องตามสเปกนี้ · ศัตรูทุกตัวต้องมี telegraph · co-op ไม่ทำใน MVP

## 2026-10-02 · Few ยืนยัน engine = Godot 4.7 (#8)
- ยืนยันรายการ "engine = Godot 4.7 (ชั่วคราว)" ด้านล่าง → ตกลงแล้วทั้งคู่

## 2026-10-02 · engine = Godot 4.7 (ชั่วคราว)
- ใครตัดสิน: Kron · สถานะ: **รอเพื่อนยืนยัน**
- เหตุผล: ใช้ทำ Emberglade มาแล้ว, ไฟล์ scene เป็น text (diff/merge ได้), เทสต์ headless ใน CI ได้
- ถ้าเปลี่ยน engine: แก้ `game/`, CI, `CLAUDE.md` ส่วนคำสั่งเทสต์
