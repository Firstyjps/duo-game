# ระบบ: player (ผู้เล่น)

- เจ้าของ: @Firstyjps (Kron) · contract ที่เกี่ยว: `docs/contracts/damage.md`

## ทำอะไร
- มุมผู้เล่น: ควบคุมอัศวิน เดิน (WASD) เล็งเมาส์ ฟันโจมตี 3 จังหวะ (กดค้างเป็นท่าชาร์จ), dodge หลบพร้อม i-frames, parry ปัดป้องการโจมตีคืน stamina, และ lock-on ล็อคเป้าหมายศัตรู
- มุมโค้ด: `CharacterBody2D` มี FSM (MOVE/DODGE/ATTACK/HURT/DEAD/PARRY), คุม stamina regen, จัดการ i-frames ผ่าน `Hurtbox.invulnerable`, ทำดาเมจผ่าน `Hitbox`, รับดาเมจและ emit signal ตาม contract damage

## ไฟล์สำคัญ
| ไฟล์ | หน้าที่ |
|---|---|
| `player.tscn` | scene หลักของผู้เล่น (DirSprite ตัวเอก Kintsugi 8 ทิศ, Health, Hurtbox, Hitbox, LockArea, CollisionShape2D) |
| `player.gd` | logic ผู้เล่น FSM, stamina, input intent, dodge, parry, charge attack, lock-on, damage handling |
| `art/knight.png` | ภาพอัศวิน placeholder เดิม (ไม่ได้ใช้ใน player.tscn แล้ว — `setup()` ยังรองรับ Sprite2D) |
| `debug/player_sandbox.tscn` | sandbox สำหรับเปิดลองเดิน ฟัน ชาร์จ dodge parry และ lock-on กับหุ่นฝึก |
| `debug/player_sandbox.gd` | ควบคุม UI HUD และรับปุ่ม T เพื่อสั่งหุ่น Dummy โจมตีทดสอบ parry |
| `debug/dummy.gd` | หุ่นลองรับดาเมจและสั่งโจมตีปล่อย Hitbox เพื่อทดสอบ parry |
| `iso/dir8.gd` | `Dir8` เลือก 1 ใน 8 ทิศจากเวกเตอร์บนจอ (+ แบบ sticky กันกระพริบตรงรอยต่อ) · ลำดับ = แถวใน atlas |
| `iso/dir_sprite.gd` | `DirSprite` (AnimatedSprite2D) เล่น `"<ท่า>_<ทิศ>"` · เลี้ยวกลางท่าเล่นต่อเฟรมเดิม · ท่าที่ไม่มี → idle |
| `art/kintsugi_hero/` | ตัวเอก isometric 64 px 8 ทิศ: `kintsugi_hero.png` (atlas ช่อง 96) + `_frames.tres` (SpriteFrames) + `.json` · ท่า idle/walk/run/dodge/hurt/death — **สร้างจาก tools/ ห้ามแก้มือ** |
| `tools/fetch_pixellab_character.py` → `tools/build_dir_atlas.py` | pipeline PixelLab → atlas (วิธีใช้อยู่หัวไฟล์) · raw เก็บที่ `kintsugi/assets/sprites/hero_iso/` (นอก game/) · PixelLab character id `af4cec7c-aadf-4901-a9cd-136679db32ae` |
| `debug/iso/iso_courtyard.tscn` | ลานวัด isometric ทดสอบเดิน 8 ทิศ (WASD · Shift วิ่ง · Space พุ่งหลบ · H โดนตี · K ตาย · R ฟื้น) · `-- --shot` ถ่ายภาพครบ 8 ทิศลง `user://` · tile ชั่วคราวจาก `make_tiles.py` |

## ส่ง / รับ ข้ามระบบ
- emit: `EventBus.damage_dealt(target, info, dealt)` — เมื่อผู้เล่นโดนดาเมจและหัก HP แล้ว
- emit: `EventBus.player_died()` — เมื่อผู้เล่น HP หมด (`Health.died`) ปล่อยครั้งเดียว
- listen: `Hurtbox.hurt(info)` — รับดาเมจ หัก defense แล้วเรียก `Health.take_damage()` (เว้นแต่ parry สำเร็จ)
- listen: `EventBus.enemy_died(enemy, id, pos)` — ปลด lock_target เมื่อเป้าหมายที่ล็อคไว้ตาย

## Signal ภายใน Player
- `stamina_changed(current: float, maximum: float)`
- `stamina_empty`
- `lock_target_changed(target: Node2D)` — แจ้งเตือนเมื่อเป้าล็อคเปลี่ยนหรือปลด (เป็น null)
- `parried(info: DamageInfo)` — ปล่อยเมื่อโดนโจมตีในหน้าต่าง parry สำเร็จ

## กติกาเฉพาะระบบ / กับดักที่เคยเจอ
- อย่าเรียก `move_and_slide()` ใน `tick(delta)` — แยกให้เทสต์เรียก `tick(delta)` แบบ deterministic ได้
- ป้อน input สำหรับเทสต์ผ่าน `set_intent(move, aim, attack, dodge, parry, lock_on, attack_held)` โดยมีค่า default ป้องกันเทสต์เดิมพัง
- Input actions (`move_*`, `attack`, `dodge`, `parry`, `lock_on`) ลงทะเบียนตอน runtime ด้วย `ensure_input_actions()` เสมอ (ห้ามแก้ `project.godot`)
- ระหว่าง dodge ให้เปลี่ยน `collision_mask` เหลือเพียง `Combat.LAYER_WORLD` เท่านั้น แล้วคืนค่า `WORLD | ENEMY` เมื่อจบ dodge
- ขณะ Parry อยู่ในหน้าต่าง `parry_window` หากโดนโจมตีจะไม่เสีย HP และได้รับ stamina คืน `parry_refund`
- ท่าชาร์จเข้าสู่ `CHARGING` เมื่อกดค้างครบ `charge_threshold` (0.15s) ไม่ใช่ windup_time; ปล่อยก่อน `charge_time` เป็นท่าฟันธรรมดาหัก stamina แค่ `attack_cost`; ระหว่างชาร์จสามารถกด dodge หรือ parry ยกเลิกได้
- ห้ามอ่านข้อมูลภายใน enemy entity (`Health`, `is_dead`, `Dummy`) จาก `player.gd` โดยเด็ดขาด — ตรวจหาศัตรูผ่าน `LockArea` (Area2D ที่ตรวจจับ `Hurtbox` ฝั่งศัตรู) เท่านั้น และปลดเป้าหมายผ่าน `EventBus.enemy_died`, หลุดระยะ buffer (`lock_range * lock_release_mult`), หรือ instance ถูกทำลาย
- ใช้ `is_instance_valid(lock_target)` แทนการเช็ค `!= null` ทุกที่ เนื่องจากใน GDScript 4 วัตถุที่ถูก `free()` ไปแล้วจะเทียบ `== null` เป็น true ทำให้ `_set_lock_target(null)` return ก่อนส่งสัญญาณหากไม่ตรวจ `is_instance_valid`
- ต่อ `EventBus.enemy_died` ใน `_enter_tree()` และ disconnect ใน `_exit_tree()` (รวมทั้งใน `NOTIFICATION_PREDELETE`) เสมอ

- isometric (#37): ช่อง atlas 96 px เท้าอยู่ที่ y≈80 → `DirSprite.offset.y = -32` · PixelLab ท่า v3 ขยาย canvas (เช่น 92) — pipeline วางกลางช่องให้เท้าตรงกัน
- ทิศ north ของ kintsugi_hero ผมออกมาเป็นเบจ → `--fix-north-hair` remap เป็นลาเวนเดอร์ (ใช้ทุกครั้งที่ build)
- ตัวละครนี้อิง sample Merakintsugi ที่ยังไม่เช็คสิทธิ์ → ใช้ทดสอบเท่านั้น ก่อนขายต้องออกแบบใหม่

- ภาพ: `sprite` = node ภาพ (DirSprite หรือ Sprite2D) ใช้ทำเอฟเฟกต์ scale/สี · `_animate_dir_sprite()` เลือกท่าตาม state (ATTACK/PARRY ใช้ idle + เอฟเฟกต์จนกว่าจะมีท่าฟัน) · เดิน = หันตามทิศเดิน, โจมตี/lock-on = หันตาม aim, โดนตี = คงทิศ

## เทสต์
- `game/tests/test_player_combat.gd` (เทสต์พื้นฐานเดิม)
- `game/tests/test_player_combat_ext.gd` (Lock-on, Parry, Charge Attack)
- `game/tests/test_player_dir8.gd` (Dir8 / DirSprite)
