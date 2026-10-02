# Workflow ทำเกม 2 คน

> เป้าหมาย: ต่างคนต่างทำได้เต็มที่ ไม่ต้องรอกัน ไม่ชนกัน และเปิดเครื่องมาเมื่อไหร่ก็รู้ทันทีว่าอีกคนทำอะไรไป

## หลักการ 4 ข้อ
1. **GitHub = ความจริงหนึ่งเดียว** — โค้ด งาน และข้อตัดสินใจอยู่บน GitHub คุยใน LINE ได้ แต่ข้อสรุปต้องลง Issue หรือ `docs/DECISIONS.md`
2. **แบ่งตามระบบ เจ้าของชัด** — แต่ละคนเป็นเจ้าของ folder ของตัวเอง (`docs/OWNERS.md`) แก้ของอีกคน = ถาม/บอกเจ้าของก่อน แล้วแจ้งใน handoff
3. **คุยกันผ่าน contract** — ระบบเรียกกันผ่าน signal บน `EventBus` หรือ interface ที่เขียนไว้ใน `docs/contracts/` ห้ามเอื้อมเข้าไปเรียก node ภายในระบบอีกฝั่งตรง ๆ
4. **ส่งต่องานผ่าน Handoff issue** — คนละ 1 issue (label `handoff`, ปักหมุดไว้ · `/start` ครั้งแรกสร้างให้เอง) จบ session ทุกครั้งเพิ่ม comment สั้น ๆ อีกคนได้แจ้งเตือนทันที และ Claude ของอีกฝั่งอ่านตอน `/start`

## โครงสร้าง
```
game/
  core/            ของร่วม (EventBus, autoload, utils, asset ที่ใช้ร่วม) — แก้แล้วต้องแจ้ง ⚠️ ใน handoff
  systems/<ระบบ>/   เจ้าของคนเดียว: script + scene + asset ของระบบนั้น
  tests/           เทสต์ (test_*.gd)
docs/contracts/    ข้อตกลงระหว่างระบบ — แก้แล้วต้องแจ้ง ⚠️ ใน handoff
```

## 1 รอบงาน
```
Issue ─▶ branch ─▶ /start ─▶ ทำ + เทสต์ ─▶ /wrap (PR ─▶ CI ผ่าน ─▶ auto squash merge เข้า main ─▶ handoff)
```
1. ทุกงานเริ่มจาก **Issue** (template "งาน") ใส่ label `system:*` และ assign ตัวเอง
2. branch จาก `main` ชื่อ `<ชื่อ>/<issue#>-<สั้น ๆ>` เช่น `kron/12-dash-attack`
3. ทำงานใน folder ตัวเอง · เทสต์ผ่านก่อน push
4. `/wrap` → เปิด PR (มี template) → รอ CI → **ผ่าน = squash merge เข้า `main` เองทันที** (ไม่ต้องรอรีวิว) → ลบ branch → comment ใน Handoff issue
5. CI ไม่ผ่าน = **ไม่ merge** — แก้จนผ่าน หรือทิ้งเป็น draft PR แล้วบอกใน handoff
6. **รีวิวย้อนหลัง:** `/start` ของอีกคนอ่าน PR ที่ merge เข้ามาตั้งแต่ครั้งก่อน เจอปัญหา → comment ใน PR นั้น หรือเปิด issue/PR แก้

## กติกา Git
- `main` ต้องเปิดเกมได้และเทสต์ผ่านเสมอ · ไม่ commit ตรงเข้า `main`
- PR เล็ก: ไม่เกิน ~1 วันงาน (~400 บรรทัด) — PR ใหญ่ = ชนง่าย รีวิวยาก
- sync กับ main ทุกครั้งที่เริ่มงาน: `git fetch && git rebase origin/main` (`/start` ทำให้)
- **Auto merge:** ทุก PR merge เองได้เมื่อ CI ผ่าน (`/wrap` ทำให้) — ยังผ่าน PR เสมอ เพื่อให้ CI กัน `main` พัง และอีกคนเห็นทุกการเปลี่ยนแปลง
- งานยังไม่เสร็จ → `--draft` (ไม่ merge)
- แตะ `game/core/`, `docs/contracts/`, `project.godot`, `CLAUDE.md` หรือ folder ของอีกคน → merge ได้ แต่ต้อง label `core`/`contract` + เขียนใน ⚠️ ของ handoff ว่ากระทบอะไร
- PR ของอีกคนที่ยังเปิดอยู่ → อย่า merge ให้เขา (เจ้าของ PR merge เอง)

## จุดชนประจำของ Godot
| ไฟล์ | กติกา |
|---|---|
| `project.godot` (autoload, input map, settings) | แก้เฉพาะใน PR label `core` · บอกอีกคนก่อน |
| `.tscn` / `.tres` | ห้ามแก้ scene ของอีกคน — **instance** scene เขามาใช้แทน |
| asset (ภาพ/เสียง) | อยู่ใน folder ระบบตัวเอง · ใช้ร่วม → `game/core/assets/` |
| `.godot/`, `*.import` cache | ไม่ commit (มีใน `.gitignore`) |
| conflict ใน `.tscn` | อย่าแก้มือ — เลือกฝั่งใดฝั่งหนึ่ง (`git checkout --theirs/--ours`) แล้วทำส่วนที่หายใหม่ใน editor |

## Contract (ข้อตกลงระหว่างระบบ)
- ตัวอย่าง: ระบบต่อสู้ emit `EventBus.enemy_died(enemy_id, position)` → ระบบดรอปของฟังแล้วสร้างของ ทั้งสองฝั่งไม่ต้องรู้จักกัน
- ก่อนเริ่มฟีเจอร์ที่ต้องคุยข้ามระบบ: เขียน contract ก่อน (copy `docs/contracts/_TEMPLATE.md`) → PR label `contract` → ทั้งคู่ approve → ค่อยลงมือแยกกันทำ
- เปลี่ยน contract เดิม = PR label `contract` + เพิ่มเวอร์ชันในไฟล์ + แก้ทั้งสองฝั่งใน PR เดียวกันหรือมี issue ตามแก้

## Handoff — เขียนอะไร
comment ใน Handoff issue ของตัวเอง (`/wrap` เขียนให้):
```
**YYYY-MM-DD** · branch/PR: ...
✅ เสร็จ: ...
🔨 ค้าง: ...
⚠️ เพื่อนต้องรู้: (อะไรที่กระทบระบบอีกฝั่ง / contract / core) — ไม่มีให้เขียน "ไม่มี"
🙋 ต้องการจากเพื่อน: ...
➡️ ถัดไป: ...
```

## จังหวะการคุย
- **ทุกวัน:** ไม่ต้องประชุม — อ่าน handoff ของอีกคน (`/start` สรุปให้)
- **ติด/รอ:** ใส่ label `blocked` ใน issue + @mention อีกคน (ไม่รอทั้งวันเงียบ ๆ)
- **สัปดาห์ละครั้ง 30–45 นาที:** เล่น build ล่าสุดด้วยกัน → คุยสิ่งที่รู้สึก → เลือก issue ของสัปดาห์หน้า (milestone) → ข้อตัดสินใจลง `DECISIONS.md`

## Labels
| label | ใช้เมื่อ |
|---|---|
| `system:<ชื่อ>` | งานของระบบนั้น (สร้างเพิ่มตอนแบ่งระบบ) |
| `core` | แตะ `game/core/` หรือ `project.godot` — อีกคนต้องรีวิวย้อนหลัง |
| `contract` | สร้าง/แก้ contract — อีกคนต้องรีวิวย้อนหลัง |
| `bug` · `design` · `art` | ตามชื่อ |
| `blocked` | รออีกคน/รอตัดสินใจ |
| `handoff` | Handoff issue ประจำตัว (มีคนละ 1 อัน) |

## ใช้ Claude Code ร่วมกัน
> **AI ของอีกคนรู้เฉพาะสิ่งที่อยู่ใน repo/GitHub** — คุยกับ AI ตัวเองแล้วไม่ลงไฟล์ = เพื่อนไม่รู้
- บริบทแบ่งเป็นชั้น (ตารางเต็มใน `CLAUDE.md` → "ความรู้เก็บไว้ที่ไหน"): กติกา → ความรู้รายระบบ → ตัวเกม/contract → handoff
- handoff = ข่าวรายวัน · ความรู้ที่ต้องใช้ต่อไปต้องอยู่ในไฟล์ (`/wrap` ข้อ 6 ถามให้ทุกครั้ง)
- ระบบใหม่ → copy `docs/templates/system-CLAUDE.md` ไปเป็น `game/systems/<ระบบ>/CLAUDE.md`
- อยากให้ AI เห็น "ความรู้สึก" ของเกม → แปะรูป/คลิปใน PR · ผลจากการเล่นประจำสัปดาห์ลง `docs/DESIGN.md`
- `CLAUDE.md` ใน repo = กติกาที่ Claude **ทั้งสองฝั่ง** เห็นเหมือนกัน → พฤติกรรมเหมือนกัน
- `/start` ตอนเริ่ม · `/wrap` ตอนจบ (อยู่ใน `.claude/commands/` มากับ repo)
- อยากเปลี่ยนกติกา → แก้ `CLAUDE.md` / ไฟล์นี้ ผ่าน PR (ทั้งคู่ approve)
- ข้อมูลส่วนตัว / ความชอบส่วนตัวของ Claude ใส่ `CLAUDE.local.md` (ไม่ขึ้น git)

## Day 1 checklist
- [ ] ตกลงชื่อเกม + pitch 1 ย่อหน้า + core loop → `docs/DESIGN.md`
- [ ] แบ่งระบบ → `docs/OWNERS.md` + `.github/CODEOWNERS` + สร้าง label `system:*`
- [ ] เขียน contract แรก (ของที่ 2 ระบบต้องคุยกันแน่ ๆ)
- [ ] เชิญเพื่อนเข้า repo · เพื่อน `/start` ครั้งแรก → Claude สร้าง Handoff issue + ปักหมุด + ผูกแจ้งเตือนทั้งสองฝั่งให้เอง
- [ ] ต่างคนต่าง `/start` ทำ issue แรก → ลองรอบ `/wrap` (PR → CI → auto merge) ให้ครบ 1 รอบ
