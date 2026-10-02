# ระบบ: player (ผู้เล่น)

- เจ้าของ: @Firstyjps (Kron) · contract ที่เกี่ยว: `docs/contracts/damage.md`

## ทำอะไร
- มุมผู้เล่น: ควบคุมอัศวิน เดิน (WASD) เล็งเมาส์ ฟันโจมตี 3 จังหวะ และ dodge หลบพร้อม i-frames โดยใช้ stamina
- มุมโค้ด: `CharacterBody2D` มี FSM (MOVE/DODGE/ATTACK/HURT/DEAD), คุม stamina regen, จัดการ i-frames ผ่าน `Hurtbox.invulnerable`, ทำดาเมจผ่าน `Hitbox`, รับดาเมจและ emit signal ตาม contract damage

## ไฟล์สำคัญ
| ไฟล์ | หน้าที่ |
|---|---|
| `player.tscn` | scene หลักของผู้เล่น (Sprite2D, Health, Hurtbox, Hitbox, CollisionShape2D) |
| `player.gd` | logic ผู้เล่น FSM, stamina, input intent, dodge, attack phases, damage handling |
| `art/knight.png` | ภาพ sprite ตัวละคร placeholder |
| `debug/player_sandbox.tscn` | sandbox สำหรับเปิดลองเดิน ฟัน และ dodge สู้กับหุ่นฝึก |
| `debug/dummy.gd` | หุ่นลองรับดาเมจ (Hurtbox ENEMY + Health) สำหรับ sandbox |
| `iso/dir8.gd` | `Dir8` เลือก 1 ใน 8 ทิศจากเวกเตอร์บนจอ (+ แบบ sticky กันกระพริบตรงรอยต่อ) · ลำดับ = แถวใน atlas |
| `iso/dir_sprite.gd` | `DirSprite` (AnimatedSprite2D) เล่น `"<ท่า>_<ทิศ>"` · เลี้ยวกลางท่าเล่นต่อเฟรมเดิม · ท่าที่ไม่มี → idle |
| `art/kintsugi_hero/` | ตัวเอก isometric 64 px 8 ทิศ: `kintsugi_hero.png` (atlas ช่อง 96) + `_frames.tres` (SpriteFrames) + `.json` · ท่า idle/walk/run/dodge/hurt/death — **สร้างจาก tools/ ห้ามแก้มือ** |
| `tools/fetch_pixellab_character.py` → `tools/build_dir_atlas.py` | pipeline PixelLab → atlas (วิธีใช้อยู่หัวไฟล์) · raw เก็บที่ `kintsugi/assets/sprites/hero_iso/` (นอก game/) · PixelLab character id `af4cec7c-aadf-4901-a9cd-136679db32ae` |
| `debug/iso/iso_courtyard.tscn` | ลานวัด isometric ทดสอบเดิน 8 ทิศ (WASD · Shift วิ่ง · Space พุ่งหลบ · H โดนตี · K ตาย · R ฟื้น) · `-- --shot` ถ่ายภาพครบ 8 ทิศลง `user://` · tile ชั่วคราวจาก `make_tiles.py` |

## ส่ง / รับ ข้ามระบบ
- emit: `EventBus.damage_dealt(target, info, dealt)` — เมื่อผู้เล่นโดนดาเมจและหัก HP แล้ว
- emit: `EventBus.player_died()` — เมื่อผู้เล่น HP หมด (`Health.died`) ปล่อยครั้งเดียว
- listen: `Hurtbox.hurt(info)` — รับดาเมจ หัก defense แล้วเรียก `Health.take_damage()`

## กติกาเฉพาะระบบ / กับดักที่เคยเจอ
- อย่าเรียก `move_and_slide()` ใน `tick(delta)` — แยกให้เทสต์เรียก `tick(delta)` แบบ deterministic ได้
- ป้อน input สำหรับเทสต์ผ่าน `set_intent(move, aim, attack, dodge)`
- Input actions (`move_*`, `attack`, `dodge`) ลงทะเบียนตอน runtime ด้วย `ensure_input_actions()` เสมอ (ห้ามแก้ `project.godot`)
- ระหว่าง dodge ให้เปลี่ยน `collision_mask` เหลือเพียง `Combat.LAYER_WORLD` เท่านั้น แล้วคืนค่า `WORLD | ENEMY` เมื่อจบ dodge

- isometric (#37): ช่อง atlas 96 px เท้าอยู่ที่ y≈80 → `DirSprite.offset.y = -32` · PixelLab ท่า v3 ขยาย canvas (เช่น 92) — pipeline วางกลางช่องให้เท้าตรงกัน
- ทิศ north ของ kintsugi_hero ผมออกมาเป็นเบจ → `--fix-north-hair` remap เป็นลาเวนเดอร์ (ใช้ทุกครั้งที่ build)
- ตัวละครนี้อิง sample Merakintsugi ที่ยังไม่เช็คสิทธิ์ → ใช้ทดสอบเท่านั้น ก่อนขายต้องออกแบบใหม่

## เทสต์
- `game/tests/test_player_combat.gd`
- `game/tests/test_player_dir8.gd` (Dir8 / DirSprite)
