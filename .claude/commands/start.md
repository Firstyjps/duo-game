---
description: เริ่ม session — sync main, อ่าน handoff ของอีกคน, สรุปงานวันนี้
---
ทำตามลำดับ หยุดถาม user ถ้าเจอ conflict หรือหาตัวตนไม่เจอ:

1. `git fetch origin --prune` แล้วดู `git status`
   - อยู่ `main` → `git pull --rebase origin main`
   - อยู่ branch งาน → `git rebase origin/main` (conflict → หยุด อธิบาย ถาม user)
2. หาตัวตน: `git config user.name` → `docs/OWNERS.md` (ฉันคือใคร, เพื่อนคือใคร, folder ของใคร)
3. Handoff issue (ชื่อมาตรฐาน `📒 Handoff — <ชื่อใน OWNERS>`): `gh issue list --label handoff --state open --json number,title`
   - **ของฉันยังไม่มี → สร้างให้เลย** (ไม่ต้องถาม user):
     `gh issue create -t "📒 Handoff — <ชื่อฉัน>" -l handoff -a @me -b "Handoff ของ <ชื่อฉัน> — จบ session ทุกครั้ง /wrap เพิ่ม comment ที่นี่ (format ใน docs/WORKFLOW.md) · cc @<GitHub เพื่อน>"` แล้ว `gh issue pin <เลข>`
     (การ @mention ทำให้เพื่อนได้แจ้งเตือน issue นี้อัตโนมัติ)
   - ถ้าเพิ่งสร้าง และ**ของเพื่อนมีอยู่แล้ว** → `gh issue comment <issue เพื่อน> --body "📌 Handoff ของ <ชื่อฉัน> อยู่ที่ #<เลขของฉัน>"` (comment แล้วฉันจะได้แจ้งเตือน issue ของเพื่อนด้วย)
   - pin ไม่ได้ (สิทธิ์ไม่พอ) → ข้ามได้ บอก user
   - อ่าน Handoff ของ**เพื่อน**: `gh issue view <เลข> --comments` (3 comment ล่าสุด) และของตัวเองล่าสุด 1 comment · ของเพื่อนยังไม่มี → บอก user ว่า "เพื่อนยังไม่เคย /start"
4. ดูงาน: `gh issue list --assignee @me --state open` · PR รอฉันรีวิว `gh pr list --search "review-requested:@me"` · PR ของเพื่อนที่เปิดอยู่ `gh pr list`
5. **รีวิวย้อนหลัง** (PR auto merge ไม่มีใครรีวิวก่อน): `gh pr list --state merged --author <GitHub เพื่อน> -L 10` เทียบกับ handoff ล่าสุดของฉัน → PR ของเพื่อนที่ merge ตั้งแต่ session ก่อน อ่าน diff โดยเฉพาะที่ label `core`/`contract` หรือแตะ folder เรา · เจอปัญหา → เสนอ user ให้ comment ใน PR นั้นหรือเปิด issue
6. สรุปให้ user ไม่เกิน 10 บรรทัด:
   - เพื่อนทำอะไรไปล่าสุด + อะไรที่กระทบระบบเรา
   - PR ของเพื่อนที่ merge เข้ามา + ผลรีวิวย้อนหลัง (มีอะไรน่าห่วงไหม)
   - `blocked` ที่รอเรา
   - งานที่แนะนำทำต่อ 1–3 อัน
7. เมื่อ user เลือกงาน: ถ้ายังไม่มี issue ให้สร้าง (`gh issue create`, template งาน, label `system:*`, assign @me) → `git switch -c <ชื่อ>/<issue>-<slug> origin/main`

$ARGUMENTS
