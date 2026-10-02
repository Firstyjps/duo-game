---
description: เริ่ม session — sync main, อ่าน handoff ของอีกคน, สรุปงานวันนี้
---
ทำตามลำดับ หยุดถาม user ถ้าเจอ conflict หรือหาตัวตนไม่เจอ:

1. `git fetch origin --prune` แล้วดู `git status`
   - อยู่ `main` → `git pull --rebase origin main`
   - อยู่ branch งาน → `git rebase origin/main` (conflict → หยุด อธิบาย ถาม user)
2. หาตัวตน: `git config user.name` → `docs/OWNERS.md` (ฉันคือใคร, เพื่อนคือใคร, folder ของใคร)
3. อ่าน Handoff ของ**เพื่อน**: `gh issue list --label handoff --state open` → `gh issue view <เลข> --comments` (ดู 3 comment ล่าสุด) และของตัวเองล่าสุด 1 comment
4. ดูงาน: `gh issue list --assignee @me --state open` · PR รอฉันรีวิว `gh pr list --search "review-requested:@me"` · PR ของเพื่อนที่เปิดอยู่ `gh pr list`
5. `git log --oneline -10 origin/main` — มีอะไร merge เข้ามาใหม่ที่แตะ `game/core/` หรือ `docs/contracts/` ไหม (ถ้ามี อ่าน diff นั้น)
6. สรุปให้ user ไม่เกิน 10 บรรทัด:
   - เพื่อนทำอะไรไปล่าสุด + อะไรที่กระทบระบบเรา
   - PR ที่รอเรารีวิว (แนะนำให้รีวิวก่อนเริ่มงานใหม่)
   - `blocked` ที่รอเรา
   - งานที่แนะนำทำต่อ 1–3 อัน
7. เมื่อ user เลือกงาน: ถ้ายังไม่มี issue ให้สร้าง (`gh issue create`, template งาน, label `system:*`, assign @me) → `git switch -c <ชื่อ>/<issue>-<slug> origin/main`

$ARGUMENTS
