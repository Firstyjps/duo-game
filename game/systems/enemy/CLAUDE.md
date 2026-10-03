# ระบบ: enemy

- เจ้าของ: @kronkawin2549-create (Few) · contract ที่เกี่ยว: `docs/contracts/damage.md` (v1)

## ทำอะไร
- ผู้เล่น: ศัตรูที่อ่านท่าได้ — ทุกท่าโจมตีมี telegraph ก่อนเสมอ
- โค้ด: AI (state machine), ท่าโจมตี, HP ของศัตรู, ตายแล้วแจ้ง loot

## ไฟล์สำคัญ
| ไฟล์ | หน้าที่ |
|---|---|
| `slime/slime.tscn` + `slime.gd` | สไลม์: IDLE → CHASE (เด้ง) → WINDUP (ย่อตัว + กระพริบแดง) → LEAP (Hitbox เปิดถึงตกพื้นครั้งแรก แล้วเด้งต่อ 1 ครั้ง) → RECOVER · HURT · DEAD · ตอนลอยยืดเป็นวงรีชี้ไปทางที่พุ่งด้วยโค้ด (`leap_pose()`, กลุ่ม `Leap Shape`) ไม่หมุนตัว · เดินยืด/แบนทุกก้าว (`hop_pose()`) · โดนตีตาหยี + สั่นเยลลี่ตามทิศที่โดน (`hurt_pose()`) |
| `slime/slime_sheet.png` | sprite 18 เฟรม 32×32 (idle 0–7, กระพริบตา 8–9, windup 10–11, leap 12 (ยังไม่ใช้), land 13, death 14–16, hurt ตาหยี 17) — สร้างจาก `slime/tools/gen_slime_sheet.gd` (placeholder art, แก้สีแล้วรันใหม่) |
| `slime/slime_vfx.gd` | `SlimeVfx` เอฟเฟกต์ท่าพุ่ง วาดเองแบบ pixel: ฝุ่นตอนกระโดด · คลื่นกระแทก + เมือกกระเด็นตอนตกพื้น (after-image อยู่ใน `slime.gd`) · ค่าจูนอยู่ใน `@export_group("VFX")` ของ Slime |
| `slime/tools/slime_viewer.html` | ดู sprite + แอนิเมชัน + VFX ในเบราว์เซอร์ (idle · เดิน · โจมตี · โดนตี · ตาย) — ดูวิธีสร้างใหม่ที่ "sprite ที่วาดด้วยโค้ด + viewer" ด้านล่าง |
| `boss_slime/boss_slime_sheet.png` | บอสสไลม์ (ร่าง 8, ยังไม่มีโค้ด AI · เฟรม 128×128 ~4 เท่าผู้เล่น · ทรงสไลม์กลม · ตาแดงเรืองในโพรง คิ้วขมวดเบา ๆ · สายเมือกยืดในปาก คอเรืองแดง · คริสตัลเรืองจมในตัว · ของที่กลืน: ดาบปักคา หัวกะโหลก · ฟองลูกแก้ว teal→น้ำเงิน) อ้างอิง Monstrous Droop ใน Dimraeth (วาดเองใหม่ — ก่อนขายจริงควรปรับให้ต่างจากต้นฉบับ): เมือกฟ้าใส ขอบเรืองแสง · ฟองเป็นกระจุกด้านบน · โพรงตา 2 + ปาก · ฐานไหลเยิ้ม · sprite 20 เฟรม 128×128: idle 0–7, กระพริบ 8–9, windup 10–11, rise ยืดเสา 12–13 (telegraph ก่อนทุบ), slam ทุบแผ่แฉก 14–15, hurt 16, death 17–19 แอ่งเรืองแสง — สร้างจาก `boss_slime/tools/gen_boss_slime_sheet.gd` · ดูใน `boss_slime/tools/boss_slime_viewer.html` (ค่าเวลา/ท่าในนั้นเป็นค่าที่เสนอ) |
| `boss_minotaur/minotaur_sheet.png` | บอส Minotaur (ร่าง 7, ยังไม่มีโค้ด AI · เท้าอยู่ที่ y = 110 ในเฟรม → ตั้ง sprite offset ตามนี้) หน้าตาอ้างอิงภาพที่ Few ส่ง (สไตล์ Minotaur ใน Mobile Legends — ก่อนขายจริงควรปรับให้เป็นของเรา): ขนน้ำตาลแบบวัว หัววัว (ปากยื่น จมูกกว้าง รูจมูก ห่วงทอง หูกางใต้เขา ขนหยิกหน้าผาก) ลำตัวทรง V (อกแยก ซิกแพ็ค 2×3 กล้ามไหล่) + หนอกหลังคอ · ขวานสงครามน่ากลัวมือขวา ถือชี้ขึ้น: ศอกงอ แขนท่อนล่างยื่นหน้าระดับเอว ด้ามตั้งขึ้นเกือบตรง คมหันเฉียงไปหน้า (`AXE_OUT`) · กำจริง = วาดอุ้งมือ → ด้าม → นิ้วพันทับด้านหน้า (`_draw_fingers`) (ใบเหล็กดำ คมหยัก ตะขอบน-ล่าง หนาม รูนแดงเรือง คราบเลือด) · เกราะเยอะแต่เรียบ: เกราะบ่า ปลอกคอ สายหนังไขว้อก+แผ่นเหล็กกลาง เข็มขัดเหล็ก+แผ่นกันต้นขา ถุงมือเกราะ ปลอกศอก สนับเข่า (ลำดับวาดใช้ bias ความลึก) · ขาวัวข้อพับย้อนหลัง ขนปุย กีบแยกสองซีก หางพู่ · แผงคอ/เคราถักน้ำตาลแดง เขาโค้งสีเข้ม sheet 8 แถว = ทิศ (S SE E NE N NW W SW, มุม 0 = หันลง) × 60 คอลัมน์ เฟรม 128×128: idle 0–3 · walk 4–11 (8 เฟรมเดินหนักแบบนักล่า · คอลัมน์ 4 กับ 8 = เท้ากระแทกพื้น → ฝุ่น/จอสั่น) · ท่าโจมตี 6 ท่า × 6 เฟรม เริ่มคอลัมน์ 12: ฟาดเหนือหัว 12–17 · กวาด 18–23 · เสย 24–29 · พุ่งชน 30–35 · กระทืบ 36–41 · กระโดดทุบ 42–47 (เฟรม 2 ของทุกท่า = ค้างง้าง telegraph · เฟรมโดน = `hit` ใน `ATTACK_NAMES`) · โดนตี 48–51 (หลับตา สะดุ้งถอย) · ตาย 52–59 (คุกเข่าข้างเดียว ปักขวานค้ำ ก้มหัว ตาดับ · เฟรม 54 = เข่ากระแทกพื้น · ค้างเฟรม 59 แล้วจางหายในเกม) · วาดด้วยหุ่นโครง 3D ง่าย ๆ ใน `boss_minotaur/tools/gen_minotaur_sheet.gd` (ข้อต่อมีความลึก หมุนตามทิศแล้วฉายลงจอ เรียงชิ้นตามความลึก · ท่าใหม่ = เพิ่มฟังก์ชันท่าแบบ `_walk_pose`) · ดูใน `tools/minotaur_viewer.html` (คลิกพื้นให้เดิน · ช่องท่าโจมตีเลือกท่า/ทิศได้ · ไฟล์ใหญ่ ~2.2 MB เปิดผ่าน local server ถ้า preview เปิดตรงไม่ได้) |
| `ink_shade/ink_shade.tscn` + `ink_shade.gd` | เงาหมึก (Ink Shade): DirSprite 8 ทิศ · WANDER (วนรอบจุดเกิด) → CHASE (เห็นผู้เล่น) → WINDUP (attack ค้างเฟรม 3 ยกดาบสูง + กระพริบทอง) → SLASH (attack เฟรม 4–6, Hitbox active เฟรม 5 แสงทองฟันลง) → RECOVER (เฟรม 7–8) · HURT (stagger เทียบ poise หรือ parried_stagger_time เมื่อโดนปัด) · DEAD (death 9 เฟรม แล้วละลายด้วยโค้ด ยุบ scale.y → 0.2 + จาง alpha → 0) · emit enemy_died ครั้งเดียว |
| `ink_shade/art/` | `ink_shade.png` + `ink_shade_frames.tres` (SpriteFrames 8 ทิศ ช่อง 96 px เท้า y≈80 `offset.y = -32`) — ประกอบจากเฟรม PixelLab `kintsugi/assets/sprites/ink_shade_iso` ด้วย `build_dir_atlas.py` |
| `ink_shade/debug/ink_shade_sandbox.tscn` | scene ลองเงาหมึก (F6): หุ่น dummy เดิน/ฟัน, สู้กับเงาหมึก 2 ตัว |
| `common/telegraph_marker.gd` | `TelegraphMarker` วงเตือนบนพื้น — ยังไม่มีศัตรูตัวไหนใช้ (สไลม์เลิกใช้แล้ว) |
| `boss_minotaur/boss_minotaur.tscn` + `boss_minotaur.gd` | บอสมิโนทอร์ (`BossMinotaur`, `enemy_id = &"boss_minotaur"`): IDLE → CHASE (เดิน 8 ทิศ ตาม `Dir8`) → 6 ท่าตามระยะ (ใกล้: ฟาด/กวาด/เสย, กลาง: กระทืบ AoE, ไกล: พุ่งชน/กระโดดทุบ) · ทุกท่ามี WINDUP (telegraph + กระพริบแดง) → ACTIVE (Hitbox) → RECOVER · 2 Phase (HP < 50% windup สั้นลง ×0.75 + คอมโบฟาด→กวาด) · Poise สูง (เซเมื่อ stagger สะสมเกิน poise แล้วรีเซ็ต) · DEAD (คุกเข่าปักขวาน ค้างเฟรม 59 แล้วจางหาย) · emit `boss_engaged` / `enemy_died` ครั้งเดียว |
| `boss_minotaur/minotaur_sheet.png` | บอส Minotaur (ร่าง 7, ยังไม่มีโค้ด AI · เท้าอยู่ที่ y = 110 ในเฟรม → ตั้ง sprite offset ตามนี้) หน้าตาอ้างอิงภาพที่ Few ส่ง (สไตล์ Minotaur ใน Mobile Legends — ก่อนขายจริงควรปรับให้เป็นของเรา): ขนน้ำตาลแบบวัว หัววัว (ปากยื่น จมูกกว้าง รูจมูก ห่วงทอง หูกางใต้เขา ขนหยิกหน้าผาก) ลำตัวทรง V (อกแยก ซิกแพ็ค 2×3 กล้ามไหล่) + หนอกหลังคอ · ขวานสงครามน่ากลัวมือขวา ถือชี้ขึ้น: ศอกงอ แขนท่อนล่างยื่นหน้าระดับเอว ด้ามตั้งขึ้นเกือบตรง คมหันเฉียงไปหน้า (`AXE_OUT`) · กำจริง = วาดอุ้งมือ → ด้าม → นิ้วพันทับด้านหน้า (`_draw_fingers`) (ใบเหล็กดำ คมหยัก ตะขอบน-ล่าง หนาม รูนแดงเรือง คราบเลือด) · เกราะเยอะแต่เรียบ: เกราะบ่า ปลอกคอ สายหนังไขว้อก+แผ่นเหล็กกลาง เข็มขัดเหล็ก+แผ่นกันต้นขา ถุงมือเกราะ ปลอกศอก สนับเข่า (ลำดับวาดใช้ bias ความลึก) · ขาวัวข้อพับย้อนหลัง ขนปุย กีบแยกสองซีก หางพู่ · แผงคอ/เคราถักน้ำตาลแดง เขาโค้งสีเข้ม sheet 8 แถว = ทิศ (S SE E NE N NW W SW, มุม 0 = หันลง) × 60 คอลัมน์ เฟรม 128×128: idle 0–3 · walk 4–11 (8 เฟรมเดินหนักแบบนักล่า · คอลัมน์ 4 กับ 8 = เท้ากระแทกพื้น → ฝุ่น/จอสั่น) · ท่าโจมตี 6 ท่า × 6 เฟรม เริ่มคอลัมน์ 12: ฟาดเหนือหัว 12–17 · กวาด 18–23 · เสย 24–29 · พุ่งชน 30–35 · กระทืบ 36–41 · กระโดดทุบ 42–47 (เฟรม 2 ของทุกท่า = ค้างง้าง telegraph · เฟรมโดน = `hit` ใน `ATTACK_NAMES`) · โดนตี 48–51 (หลับตา สะดุ้งถอย) · ตาย 52–59 (คุกเข่าข้างเดียว ปักขวานค้ำ ก้มหัว ตาดับ · เฟรม 54 = เข่ากระแทกพื้น · ค้างเฟรม 59 แล้วจางหายในเกม) · วาดด้วยหุ่นโครง 3D ง่าย ๆ ใน `boss_minotaur/tools/gen_minotaur_sheet.gd` (ข้อต่อมีความลึก หมุนตามทิศแล้วฉายลงจอ เรียงชิ้นตามความลึก · ท่าใหม่ = เพิ่มฟังก์ชันท่าแบบ `_walk_pose`) · ดูใน `tools/minotaur_viewer.html` (คลิกพื้นให้เดิน · ช่องท่าโจมตีเลือกท่า/ทิศได้ · ไฟล์ใหญ่ ~2.2 MB เปิดผ่าน local server ถ้า preview เปิดตรงไม่ได้) · เฟส 4 มีโค้ด AI แล้วใน `boss_minotaur.gd` |
| `boss_minotaur/debug/minotaur_sandbox.tscn` | scene ลองสู้บอสมิโนทอร์ (F6): หุ่น Dummy ผู้เล่น (ลูกศร/WASD เดิน, Space ฟัน) สู้กับ Minotaur มี UI บอกสถานะ HP/Phase/State |
| `common/telegraph_marker.gd` | `TelegraphMarker` วงเตือนบนพื้น — Minotaur ใช้ในท่ากระโดดทุบ (Leap) แสดงจุดตก และกระทืบ (Stomp) แสดงรัศมี AoE (squash วงรี) |
| `debug/enemy_sandbox.tscn` | scene ลองศัตรู (F6) มีหุ่นแทนผู้เล่น: ลูกศรเดิน, Space ฟัน |

## ส่ง / รับ ข้ามระบบ
- emit: `EventBus.damage_dealt` — หลังหัก HP ศัตรูแล้ว
- emit: `EventBus.enemy_died(enemy, enemy_id, position)` — ครั้งเดียวต่อตัว → loot ดรอปของ
- หาผู้เล่น: Area2D `Detect` mask physics layer `player` เท่านั้น (ไม่ get_node เข้าระบบ A)

## กติกาเฉพาะระบบ / กับดักที่เคยเจอ
- art ตามสเปกใน `docs/DESIGN.md` (pixel 32 px, top-down 3/4) · sprite `offset.y = -14` ให้เท้าอยู่ที่ origin (y-sort ถูก)
- เงาหมึก (Ink Shade): ใช้ PixelLab 8 ทิศ ผ่าน `DirSprite` (AnimatedSprite2D) ช่อง 96 px เท้าอยู่ที่ y≈80 ในช่อง → sprite `offset = Vector2(0, -32)` ให้เท้าอยู่ที่ origin พอดีกับ y-sort · ทิศ 8 ทิศใช้ `Dir8` (`dir_sprite.set_facing()` + `play_action()`) · WINDUP ค้างเฟรม 3 (ยกดาบสูง), SLASH active เฉพาะเฟรม 5 (แสงทองฟันลง), RECOVER เฟรม 7–8 · contract damage v2: โดน parry (`hitbox.deflected`) เข้า HURT นาน `parried_stagger_time` (~0.8s) · DEAD จบท่า death 9 เฟรมแล้วละลายด้วยโค้ด: ยุบ scale.y → 0.2 + จาง alpha → 0 ตาม `corpse_time`
- ประกอบ atlas เงาหมึก (PixelLab 8 ทิศ):
  `python3 game/systems/player/tools/build_dir_atlas.py --raw kintsugi/assets/sprites/ink_shade_iso --out game/systems/enemy/ink_shade/art --name ink_shade --anim idle=idle:6:loop --anim walk=walk:9:loop --anim attack=attack_chop:12:once --anim hurt=hurt:12:once --anim death=death:9:once`
- art ตามสเปกใน `docs/DESIGN.md`: สไลม์ sprite `offset.y = -14` · Minotaur frame 128×128 `offset.y = -46` (center y=64, เท้า y=110) ให้เท้าอยู่ที่ origin (y-sort ถูก)
- ห้ามโจมตีโดยไม่มี telegraph — `Hitbox.activate()` หลัง windup เท่านั้น
- ถ้าใช้ `TelegraphMarker`: ต้อง `top_level = true` + `z_index = -1` → พื้น/TileMap ต้อง z ต่ำกว่า -1 ไม่งั้นบังวง
- เทสต์รันตอน root ยังไม่อยู่ใน tree → อย่าใช้ `@onready` กับ node ที่เทสต์ต้องใช้ · ผูก node ใน `setup()` และแยก AI ไว้ใน `tick()` (ไม่มี physics)
- การตรวจช่วง active ในเทสต์: ใช้ flag `is_attack_active` ของตัวศัตรู/บอส แทน `hitbox.monitoring` เพราะ `Hitbox.activate()`/`deactivate()` ใช้ `set_deferred`
- บอส Minotaur AI: ห้ามใช้ท่าเดิมซ้ำเกิน 2 ครั้งติด (`consecutive_attack_count <= 2`) · Phase 2 เริ่มที่ HP < 50% (ไม่ใช่ `<=`)


## sprite ที่วาดด้วยโค้ด + viewer
- art ทุกตัวในระบบนี้เป็น placeholder ที่ **วาดด้วยสคริปต์** (`*/tools/gen_*.gd`) — แก้ภาพ = แก้สคริปต์แล้วรัน `godot --headless --path game --script res://systems/enemy/<ตัว>/tools/gen_<...>.gd`
- viewer (`*/tools/*_viewer.html`) = template (`*_viewer.template.html`) + รูปฝัง base64 → สร้าง sheet ใหม่แล้วต้องสร้าง viewer ใหม่: `sh game/systems/enemy/common/tools/embed_viewer.sh <template> <sheet.png> <out.html>`
- viewer ใหญ่ ~2 MB ขึ้นไป (Minotaur) preview ของ Claude desktop เปิดไฟล์ตรงไม่ได้ → `node game/systems/enemy/common/tools/serve_viewers.js` แล้วเปิด `http://127.0.0.1:8765/<ตัว>/tools/<viewer>.html`
- ค่าเวลา/ระยะใน viewer เป็นค่าที่เสนอ — ของจริงต้องเป็น `@export` ในโค้ดศัตรู
- กับดัก GDScript ที่เจอ: อย่าตั้งชื่อฟังก์ชัน `_set` (ชน `Object._set`) · `a if c else b` ระหว่าง typed array ได้ `Array` ธรรมดา → ใช้ if/else · `set_pixel` นอกขอบภาพ error → เช็คขอบก่อน
- Minotaur ใช้หุ่นโครง 3D ง่าย ๆ: ชิ้นทับกันผิดลำดับ → ปรับ `bias` ความลึกใน `_cap`/`_ell` (ขา -5 = อยู่หลังลำตัวเสมอ, เกราะบ่า +1.5 = ทับกล้ามไหล่เสมอ)

## เทสต์
- `game/tests/test_enemy_*.gd`
