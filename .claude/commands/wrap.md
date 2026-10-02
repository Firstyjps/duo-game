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
6. ถ้าวันนี้ตัดสินใจเรื่องที่กระทบทั้งเกม → เพิ่ม `docs/DECISIONS.md` ใน PR นี้
7. สรุปให้ user: ลิงก์ PR · สถานะ CI (`gh pr checks`) · สิ่งที่เพื่อนต้องรู้

$ARGUMENTS
