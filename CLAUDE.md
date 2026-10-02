# กติกาของ Claude ในโปรเจกต์นี้ (ใช้ร่วมกัน 2 คน)

repo นี้มีคน 2 คน แต่ละคนใช้ Claude Code ของตัวเอง ไฟล์นี้ทำให้ Claude ทั้งสองฝั่งทำงานแบบเดียวกัน
กติกาเต็มสำหรับคน: `docs/WORKFLOW.md`

## เกมนี้คืออะไร
<!-- สรุปไม่เกิน 5 บรรทัด อัปเดตเมื่อ docs/DESIGN.md เปลี่ยนเรื่องใหญ่ -->
- ชื่อ: _TBD_ · engine: Godot 4.7 · platform: PC (Steam) เมาส์+คีย์บอร์ด/จอย · single-player
- pitch: ARPG real-time pixel art top-down 3/4 — ต่อสู้ Souls-lite (อ่าน telegraph, dodge, stamina) + ล่าของ/สร้าง build แบบ Diablo ในดันเจี้ยนมืดที่มีแสงสวย
- core loop: สู้ → เคลียร์ห้อง เก็บดรอป → ปรับ build → ดันเจี้ยนยากขึ้น/บอส
- art: tile 32 px · ฐาน 960×540 integer scale + aspect expand · filter nearest — ห้ามเปลี่ยนโดยไม่ตกลง (`game/tests/test_core_display.gd` กันไว้)
- รายละเอียด: `docs/DESIGN.md` · ข้อตัดสินใจ: `docs/DECISIONS.md` (อ่านก่อนเสนออะไรที่ขัดกับของเดิม)

## ใครดูแลอะไร + คำศัพท์ในเกม
@docs/OWNERS.md
@docs/GLOSSARY.md

## ความรู้เก็บไว้ที่ไหน
AI ของอีกคนรู้**เฉพาะสิ่งที่อยู่ใน repo/GitHub** — ความจำส่วนตัวหรือแชทของเราเขาไม่เห็น
| ความรู้ | เก็บที่ |
|---|---|
| วิธีทำงานร่วมกัน | `CLAUDE.md` นี้ / `docs/WORKFLOW.md` |
| ระบบหนึ่งทำงานยังไง ข้อควรระวัง | `game/systems/<ระบบ>/CLAUDE.md` (โหลดเองเมื่อทำงานใน folder นั้น) |
| สิ่งที่ระบบสัญญาให้อีกระบบ | `docs/contracts/` |
| ตัวเกม / ข้อตัดสินใจ / คำศัพท์ | `docs/DESIGN.md` · `docs/DECISIONS.md` · `docs/GLOSSARY.md` |
| วันนี้ทำอะไร ค้างอะไร | Handoff issue (ชั่วคราว — ห้ามเป็นที่เดียวที่เก็บความรู้ถาวร) |
- ใช้คำตาม `docs/GLOSSARY.md` ทั้งในโค้ด เอกสาร และคำตอบ · เจอคำใหม่ → เพิ่มลง GLOSSARY ใน PR
- อย่าเก็บความรู้เรื่องเกมใน memory ส่วนตัวหรือ `CLAUDE.local.md`
- ไฟล์นี้ต้องสั้น (≤150 บรรทัด) — รายละเอียดไปไว้ใน `docs/` หรือ CLAUDE.md ของระบบ

## ตัวตน
- ฉันทำงานให้ใคร = `git config user.name` → จับคู่ใน `docs/OWNERS.md` (ถ้าไม่เจอ ถาม user ก่อนทำอะไร)
- ตอบภาษาไทย technical terms ใช้อังกฤษได้

## ขอบเขต
- แก้ได้เลย: folder ที่ user เป็นเจ้าของใน `docs/OWNERS.md` + `game/tests/` ของระบบนั้น
- **ถาม user ก่อน** ถ้าจะแตะ: `game/core/`, `game/project.godot`, `docs/contracts/`, `CLAUDE.md`, `docs/WORKFLOW.md` หรือ folder ของอีกคน — และถ้าแตะ PR ต้องมี label `core`/`contract` + request review อีกคน
- ข้ามระบบ = ผ่าน signal ใน `game/core/event_bus.gd` ตาม `docs/contracts/` เท่านั้น ห้าม `get_node()` เข้าไปในระบบอีกฝั่ง
- ห้ามแก้ `.tscn`/`.tres` ของอีกคน — instance แทน

## Git
- ไม่ commit/push ตรงเข้า `main` · branch = `<ชื่อเล่นตัวพิมพ์เล็ก>/<issue#>-<slug>`
- commit message: `[<ระบบ>] <ทำอะไร> (#<issue>)`
- PR ใช้ template · squash merge · ห้าม `push --force` บน branch ของอีกคน
- ห้าม merge PR เองถ้าเข้าเงื่อนไข "ห้าม merge เอง" ใน `docs/WORKFLOW.md`

## ก่อน push ทุกครั้ง
```bash
godot --headless --path game --script res://tests/run_tests.gd
```
ต้องผ่าน · ฟีเจอร์ใหม่มี logic → เพิ่ม `game/tests/test_<ระบบ>_*.gd`

## GDScript
- static typing ทุกที่ (`var hp: int = 10`, `func f(x: float) -> void`)
- 1 ระบบ = 1 folder; ชื่อไฟล์ `snake_case`, class `PascalCase`
- ค่าที่ต้องจูน → `@export` หรือ `.tres` ไม่ hardcode

## ข้อตัดสินใจ
- ตัดสินเรื่องที่กระทบทั้งเกมหรืออีกคน → เพิ่มลง `docs/DECISIONS.md` (ใน PR)
- ไม่แน่ใจว่ากระทบอีกคนไหม → ถือว่ากระทบ เขียนใน "เพื่อนต้องรู้" ของ handoff
