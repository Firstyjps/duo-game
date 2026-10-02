# Kitsune Project

2D pixel platformer จากสไปรต์ชุด sample ของ **Merakintsugi Platformer Character** มีเกม Kintsugi Run (2 ด่าน, 22 ท่า, เสียงสังเคราะห์) และ Studio สำหรับตรวจเฟรม ดูท่า คอนเซปต์ และเอกสาร

## เปิดใช้งาน

ทุกหน้าใช้ ES modules และ `fetch` จึงต้องเปิดผ่าน web server (ดับเบิลคลิก `index.html` ตรงๆ จะไม่ทำงาน)

```bash
python3 -m http.server 8088
```

แล้วเปิด http://localhost:8088/

| หน้า | URL |
| :--- | :--- |
| Hub | `/` |
| เกม | `/game/` (`?debug` เปิดบอททดสอบ) |
| Studio | `/studio/` (`#inspector`, `#moves`, `#concepts`, `#docs`) |

## ปุ่มในเกม

| ปุ่ม | ท่า |
| :--- | :--- |
| ← → | เดิน (กด Shift ค้าง = วิ่ง) |
| Space / Z | กระโดด · กลางอากาศ = ตีลังกา · ชิดกำแพง = ถีบกำแพง |
| ↓ | หมอบ · วิ่งแล้ว ↓ = สไลด์ |
| ↑ | ปีนบันได · ↑+X ในคอมโบ = แยกไปคอมโบ 5 จังหวะ |
| X / J | ฟัน: X X X = คอมโบ 3 · X X ↑X X X = คอมโบ 5 · กลางอากาศ ↓+X = ปักดาบ |
| C / L | พุ่ง (กลางอากาศได้ 1 ครั้ง) |
| V | V + ทิศทาง = กลิ้งหลบ (แล้วกด X ทันที = ฟันสวน) · กด V ค้างแล้วปล่อย = ชาร์จพลัง |
| R / N / M | เริ่มด่านใหม่ / ด่านถัดไป (หลังเข้าเส้นชัย) / เปิด-ปิดเสียง |

บนมือถือมีปุ่มสัมผัสครบ (ปุ่ม RUN เป็นแบบกดติด)

## โครงสร้าง

```text
Kitsune/
├── index.html               Hub
├── game/
│   ├── index.html, css/game.css
│   ├── assets/              sheet.png + sprites.json (สร้างจาก tools/build_sprites.py ห้ามแก้ด้วยมือ)
│   └── js/
│       ├── main.js          boot + loop
│       ├── config.js        ค่าคงที่ ฟิสิกส์ พาเลตต์
│       ├── player.js        state machine ของทุกท่า + pose()
│       ├── moves.js         ข้อมูลท่า (ATTACKS / MOVES) ใช้ร่วมกับ studio
│       ├── fx.js            VFX: วงดาบ ลำแสง เงา particle
│       ├── enemies.js, game.js, input.js, sprites.js, world.js, audio.js
│       ├── sfx.js           เสียงสังเคราะห์ Web Audio (ไม่มีไฟล์เสียง)
│       ├── level.js         ตัวโหลดด่าน + วาด tile + ฉากหลัง
│       ├── levels/          level1.js, level2.js
│       └── dev/playtest.js  บอททดสอบ (โหลดเฉพาะ ?debug)
├── studio/                  index.html, studio.css, studio.js
├── shared/kitsune.css       สไตล์ร่วม hub + studio
├── assets/
│   ├── sprites/             idle.aseprite, walk.aseprite, sheets/, sample_idle_walk.zip, exports/*.gif
│   ├── reference/           GIF + วิดีโอตัวอย่างของชุดเต็ม, gif_timing.json (ใช้อ้างอิงเท่านั้น)
│   ├── concepts/            ภาพคอนเซปต์ตัวละครใหม่ 6 ภาพ
│   └── tiny-swords/         ชุด asset ฉาก (ยังไม่ได้ใช้)
├── docs/                    character-design-guide.md, moveset.md, concepts.md
└── tools/build_sprites.py   .aseprite → atlas + manifest + GIF
```

## งานที่ทำบ่อย

**แก้หรือเพิ่มสไปรต์:** วางไฟล์ `.aseprite` ใน `assets/sprites/` เพิ่มรายการใน `ANIMATIONS` ของ `tools/build_sprites.py` แล้วรัน

```bash
python3 tools/build_sprites.py
```

**เพิ่มด่าน:** คัดลอก `game/js/levels/level2.js` เป็นไฟล์ใหม่ แล้วเพิ่มใน `LEVELS` ของ `game/js/level.js` พิกัดเป็น tile 16 px: `[col, row]` = เท้ายืนบนแถว `row`

**ปรับท่า:** จังหวะและดาเมจอยู่ใน `game/js/moves.js` ฟิสิกส์อยู่ใน `game/js/config.js` ท่าทางของตัวละครอยู่ใน `pose()` ของ `game/js/player.js` หลังแก้ให้รัน `await PT.runAll()` ใน `game/index.html?debug`

## ข้อควรรู้

- สไปรต์ต้นฉบับ**หันหน้าซ้าย** โค้ด (`drawBody` ใน `sprites.js`) จึงกลับภาพเสมอเพื่อให้ `face = 1` หันขวา
- ใช้ได้จริงแค่ idle / walk / from idle ท่าอื่นสร้างจากเฟรมพวกนี้ + VFX รายละเอียดอยู่ใน `docs/moveset.md`
- GIF ใน `assets/reference/` เป็นภาพตัวอย่างของชุดเต็มที่ต้องซื้อ ห้ามดึงพิกเซลไปใช้ในเกม
- `game/js/sfx.js` และ `game/js/levels/level2.js` มาจาก build v3 (`~/Downloads/Pixel-Assets/Merakintsugi_Platformer_Character/game/`) อุโมงค์ด่าน 2 ขยายเป็น 2 ช่องให้พอดี hitbox หมอบ
