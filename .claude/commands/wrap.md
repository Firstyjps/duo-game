---
description: จบ session — เทสต์, commit, เปิด/อัปเดต PR, เขียน handoff ให้อีกคน
---
1. รันเทสต์ `godot --headless --path game --script res://tests/run_tests.gd` — ไม่ผ่าน → แก้ก่อน หรือถาม user ว่าจะ push เป็น draft PR ไหม
2. `git diff origin/main --stat` ตรวจขอบเขต:
   - แตะ `game/core/`, `project.godot`, `docs/contracts/`, `CLAUDE.md` หรือ folder ของเพื่อน → แจ้ง user และ PR ต้องมี label `core`/`contract` + request review เพื่อน
3. commit งานที่ค้าง (`[<ระบบ>] <ทำอะไร> (#<issue>)`) → `git push -u origin HEAD`
4. PR:
   - ยังไม่มี → `gh pr create` ตาม `.github/pull_request_template.md` (ลิงก์ `Closes #<issue>`, ใส่ label, `--reviewer <เพื่อน>`; งานยังไม่เสร็จ → `--draft`)
   - มีแล้ว → อัปเดตคำอธิบายถ้าขอบเขตเปลี่ยน
5. Handoff: `gh issue comment <Handoff issue ของฉัน> --body ...` ตาม format ใน `docs/WORKFLOW.md` ส่วน "Handoff" (สั้น อ่านจบใน 30 วินาที)
6. **ความรู้ถาวร** — ทบทวน session นี้แล้วถามตัวเองว่า "ถ้า AI ของเพื่อนมาทำต่อพรุ่งนี้ ต้องรู้อะไรที่ยังไม่อยู่ในไฟล์?" แล้วลงไฟล์ใน PR นี้ตามตาราง "ความรู้เก็บไว้ที่ไหน" ใน `CLAUDE.md`:
   - วิธีทำงาน / กับดักของระบบเรา → `game/systems/<ระบบ>/CLAUDE.md` (ยังไม่มี → copy `docs/templates/system-CLAUDE.md`)
   - signal / data ที่อีกระบบพึ่ง → `docs/contracts/` (label `contract`)
   - ตัดสินใจเรื่องที่กระทบทั้งเกม → `docs/DECISIONS.md`
   - คำเรียกใหม่ในเกม → `docs/GLOSSARY.md`
   - เกมเปลี่ยนเรื่องใหญ่ → `docs/DESIGN.md` + สรุปใน `CLAUDE.md` ส่วน "เกมนี้คืออะไร"
   - ไม่มี → บอก user ว่า "ไม่มีความรู้ถาวรใหม่" (อย่าข้ามข้อนี้เงียบ ๆ)
7. สรุปให้ user: ลิงก์ PR · สถานะ CI (`gh pr checks`) · สิ่งที่เพื่อนต้องรู้ · ไฟล์ความรู้ที่อัปเดต

$ARGUMENTS
