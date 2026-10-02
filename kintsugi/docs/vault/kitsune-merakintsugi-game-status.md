# Kitsune / Merakintsugi platformer — status

อัปเดต: 2026-10-02 ~20:30 (Claude Desktop, session refactor)

## ตัวหลัก = `~/Desktop/Kitsune` (git repo, branch main)
user เลือกให้ Kitsune เป็นตัวหลัก และรวม v3 จาก Downloads เข้ามาแล้ว **แก้เกมที่นี่ที่เดียว**

- เปิดด้วย `python3 -m http.server 8088` ที่ root → hub `/`, เกม `/game/`, studio `/studio/` (ต้องผ่าน server เพราะใช้ ES modules + fetch)
- โครงสร้าง: `game/` (โมดูล), `studio/` (หน้าเว็บปกติ), `assets/{sprites,reference,concepts,tiny-swords}`, `docs/`, `tools/build_sprites.py`, `shared/kitsune.css`
- atlas: `tools/build_sprites.py` อ่าน `.aseprite` → `game/assets/sheet.png` + `sprites.json` (เกมกับ studio ใช้ร่วมกัน)
- เกม: 2 ด่าน (`game/js/levels/level1.js`, `level2.js`), 22 ท่า, เสียง `sfx.js` (จาก v3), HP 3, เช็กพอยต์ร่ายพลัง
- ทดสอบ: `game/index.html?debug` แล้ว `await PT.runAll()` (บอทเช็คคอมโบ 3/5, อุโมงค์, บันได, ปล่องกำแพง, เหว ทั้ง 2 ด่าน) ผ่านหมดตอน 20:30
- Artifact (private) v4 = build โมดูลนี้: https://claude.ai/artifact/6HDuvZf1jofPwP1pYeoJWx

## ปุ่ม
← → เดิน (Shift วิ่ง) · Space กระโดด/ตีลังกา/ถีบกำแพง · ↓ หมอบ, วิ่ง+↓ สไลด์ · ↑ บันได · X ฟัน: X X X = คอมโบ 3, X X ↑X X X = คอมโบ 5, กลางอากาศ ↓+X ปักดาบ · C พุ่ง · V+ทิศ กลิ้ง (แล้ว X = ฟันสวน), V ค้าง = ชาร์จเสาแสง · R/N/M

## ข้อค้นพบสำคัญ
- สไปรต์ต้นฉบับ idle/walk **หันหน้าซ้าย** (`drawBody` กลับภาพเสมอ)
- ใช้ได้จริงแค่ idle/walk/from idle ท่าอื่นเป็นรีมิกซ์ (เฟรมเดิม + transform + VFX) ไม่ดึงพิกเซลจาก GIF preview ของชุดเต็ม รายละเอียด `docs/moveset.md`
- ชื่อ GIF ตัวอย่างไม่ตรงเนื้อหา: `gallery_04_attacks` = ปีนบันได, `gallery_05_dodge_attacks` = เกาะกำแพง
- ด่าน 2 จาก v3: อุโมงค์ขยายเป็น 2 ช่อง (32px) เพราะ hitbox หมอบ = 22px

## ประวัติ / ของเก่า
- v1–v3 (`~/Downloads/.../Merakintsugi_Platformer_Character/game/`) **ลบแล้ว** 20:37 ตามที่ user สั่ง (ย้ายไป `~/.Trash/Kintsugi-v3-game-20261002-203736` กู้คืนได้) ฟีเจอร์ของ v3 รวมเข้า Kitsune ครบแล้ว
- `game/pixellab/` (ท่าฟัน hit1 9 เฟรม จาก PixelLab ที่อีก session gen ไว้ 20:17) ย้ายเก็บที่ `Kitsune/assets/sprites/pixellab/` ยังไม่ได้ใส่ในเกม
- `MOVESET_REFERENCE.md` (agy บัญชี 1) ยังอยู่ที่ root ของโฟลเดอร์ Downloads ไม่ได้ลบ
- Antigravity เคยทำ hub/studio เวอร์ชันแรกใน Kitsune (generate_viewer.py) ถูกแทนด้วย `studio/` แล้ว ดูประวัติใน git ได้ (`29cb818` = snapshot ก่อน refactor)
- ⚠️ มีหลาย session/agent ทำโปรเจกต์นี้พร้อมกันมาแล้ว 3 ครั้ง ก่อนแก้ให้เช็ค `git log` + mtime ก่อนเสมอ

## ถ้าจะทำต่อ
- ท่าฟันจริง (เหวี่ยงแขน) ต้องใช้ `.aseprite` ชุดเต็มที่ซื้อ → วางใน `assets/sprites/`, เพิ่มใน `ANIMATIONS` ของ build script, แก้ `pose()` ใน `game/js/player.js`
- Tiny Swords ยังไม่ได้ใช้ในเกม

## อัปเดต 22:05 — v4 ท่าจริงจาก PixelLab 23 แอนิเมชัน (โควต้า trial หมดแล้ว 40/40)
- สร้างจาก idle frame ด้วย `animate_image` (64x64, 8 เฟรม) → `game/pixellab/<prefix>_1..8.png` → รวมด้วย `game/pixellab/build_atk.py` เป็น `game/atk.png` + `game/atk.js`
  - `build_atk.py` มี: seq ต่อเฟส, align (none/bottom/feet), FLIP (เฟรมที่ PixelLab หันกลับด้าน → mirror กลับ)
  - ดึงเฟรม: `game/pixellab/fetch.sh <job_id> <prefix>`
- ท่าที่ได้: hit1, hit2, hit3, 2-1 (แทง), 2-2 (ฟันกวาดมีวงดาบในตัว), jump, run, turn, crouch, dj, air dash, slide, back dodge, wall, ledge, ladder (หันข้าง ไม่ใช่หันหลัง), jump atk 1/2, dodge atk 1/2, vertical (รอบ 2 ดีกว่า; v1 ใน pixellab/vatk_v1), hurt, heal
- กลไกใหม่ใน index.html: คอมโบแตกสาย (1→2→3 / 1→2→เว้น→2-1→2-2), jump atk 2 จังหวะ, back dodge (C) + dodge atk 2 จังหวะ, hurt เบา/หนัก, heal (Q ค้าง ใช้เศษทอง 3), ledge grab/climb, run stop/turn, dj ตั้ง/ตีลังกา, ควัน (smoke)
- **ระวัง cache**: preview ต้อง `fetch(...,{cache:'reload'})` + เปลี่ยน query ไม่งั้นได้ index.html เก่า
- Artifact เดิม 6HDuvZf1jofPwP1pYeoJWx ถูก session อื่น publish ทับเป็นเวอร์ชัน Kitsune แยกโมดูล (~21:43) → v4 อยู่ลิงก์ใหม่ https://claude.ai/artifact/DEox6jyuHDgcPBYmbd2hoX
- 20:37 มีบางอย่างย้าย `game/` ไปถังขยะ (`~/.Trash/Kintsugi-v3-game-20261002-203736`) + kill preview server + แก้ launch.json ให้ชี้ ~/Desktop/Kitsune — กู้กลับแล้ว, launch.json มีทั้ง `kitsune` และ `kintsugi-game`

## อัปเดต 21:55 — ใส่ v4 ใน Kitsune + เอาการหมุนตัวออก
- `~/Desktop/Kitsune/game-pixellab/` = สำเนา v4 (index.html, atk.*, sheet.png, sfx.js, level2.js, pixellab/) · studio แท็บ "เล่น" + hub ชี้มาที่นี่ · เกมโมดูลเดิม `game/` ยังอยู่ ลิงก์ไว้ใต้ iframe
- ยังไม่ได้ commit ใน repo Kitsune (index.html, studio/index.html แก้แล้ว, game-pixellab/ ใหม่)
- user ไม่ชอบการหมุนตัวเป็นวงกลม → ลบ rotation ใน double jump ไปข้างหน้า และท่า ↑+X (วงดาบเปลี่ยนเป็นพระจันทร์เสี้ยวตวัดขึ้น) — ห้ามใส่ท่าหมุนตัวทั้งตัวอีก
- Artifact v4: https://claude.ai/artifact/DEox6jyuHDgcPBYmbd2hoX (v2 = ไม่มีการหมุน)

## อัปเดต 22:35 — เลือกแนวทาง Isometric แล้ว
- ต่อจากนี้ดู **`kitsune-iso-plan.md` (HANDOFF)** — มีสถานะ ไฟล์ การตัดสินใจ แผน และรายการที่ต้องให้ user เลือก
- สำเนา handoff: `~/Desktop/Kitsune/prototypes/25d/HANDOFF.md`
