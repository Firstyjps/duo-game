---
description: จบ session — เทสต์, commit, PR, CI ผ่านแล้ว auto merge เข้า main, เขียน handoff ให้อีกคน
---
1. รันเทสต์ `godot --headless --path game --script res://tests/run_tests.gd` — ไม่ผ่าน → แก้ก่อน หรือถาม user ว่าจะ push เป็น draft PR (ไม่ merge) ไหม
2. `git diff origin/main --stat` ตรวจขอบเขต:
   - แตะ `game/core/`, `project.godot`, `docs/contracts/`, `CLAUDE.md` หรือ folder ของเพื่อน → แจ้ง user · PR ต้องมี label `core`/`contract` · handoff ต้องเขียน ⚠️ ว่ากระทบอะไร
3. commit งานที่ค้าง (`[<ระบบ>] <ทำอะไร> (#<issue>)`) → `git fetch origin && git rebase origin/main` (conflict → หยุด ถาม user) → เทสต์อีกรอบถ้ามีของใหม่จาก main → `git push -u origin HEAD --force-with-lease`
4. PR:
   - ยังไม่มี → `gh pr create` ตาม `.github/pull_request_template.md` (ลิงก์ `Closes #<issue>`, ใส่ label; งานยังไม่เสร็จ → `--draft`)
   - มีแล้ว → อัปเดตคำอธิบายถ้าขอบเขตเปลี่ยน
   - **Auto merge** (ข้ามถ้าเป็น draft): `gh pr checks --watch` → ผ่าน → `gh pr merge --squash --delete-branch` → `git switch main && git pull --rebase origin main`
     - CI ไม่ผ่าน → อ่าน log (`gh run view --log-failed`) แก้แล้ว push ใหม่ · แก้ไม่ได้ → `gh pr ready --undo` (เป็น draft) แล้วบอก user · **ห้าม merge ทั้งที่ CI แดง**
5. Handoff: `gh issue comment <Handoff issue ของฉัน> --body ...` ตาม format ใน `docs/WORKFLOW.md` ส่วน "Handoff" (สั้น อ่านจบใน 30 วินาที)
6. **ความรู้ถาวร** — ทบทวน session นี้แล้วถามตัวเองว่า "ถ้า AI ของเพื่อนมาทำต่อพรุ่งนี้ ต้องรู้อะไรที่ยังไม่อยู่ในไฟล์?" แล้วลงไฟล์ใน PR นี้ตามตาราง "ความรู้เก็บไว้ที่ไหน" ใน `CLAUDE.md`:
   - วิธีทำงาน / กับดักของระบบเรา → `game/systems/<ระบบ>/CLAUDE.md` (ยังไม่มี → copy `docs/templates/system-CLAUDE.md`)
   - signal / data ที่อีกระบบพึ่ง → `docs/contracts/` (label `contract`)
   - ตัดสินใจเรื่องที่กระทบทั้งเกม → `docs/DECISIONS.md`
   - คำเรียกใหม่ในเกม → `docs/GLOSSARY.md`
   - เกมเปลี่ยนเรื่องใหญ่ → `docs/DESIGN.md` + สรุปใน `CLAUDE.md` ส่วน "เกมนี้คืออะไร"
   - ไม่มี → บอก user ว่า "ไม่มีความรู้ถาวรใหม่" (อย่าข้ามข้อนี้เงียบ ๆ)
7. สรุปให้ user: ลิงก์ PR · CI ผ่าน/ไม่ผ่าน · merge แล้วหรือยัง · สิ่งที่เพื่อนต้องรู้ · ไฟล์ความรู้ที่อัปเดต

$ARGUMENTS
