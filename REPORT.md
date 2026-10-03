# รายงานผลงาน: เฟส 4 บอสมิโนทอร์ AI (issue #44)

## 1. ทำอะไร
- **สร้างคลาสและ Scene บอสมิโนทอร์**:
  - `game/systems/enemy/boss_minotaur/boss_minotaur.gd` (`class_name BossMinotaur`, `enemy_id = &"boss_minotaur"`)
  - `game/systems/enemy/boss_minotaur/boss_minotaur.tscn`
  - รองรับมุมมอง isometric: Sprite2D ขนาด 128×128 (60 columns × 8 rows), ตั้งค่า `offset = Vector2(0, -46)` ให้ตำแหน่งเท้า (y = 110 ในเฟรม) อยู่ที่ origin (0, 0) พอดีสำหรับการเรียงลำดับ y-sort
  - หัน 8 ทิศทาง screen-space ตาม `Dir8.from_vector` / `Dir8.from_vector_sticky`
- **AI State Machine & การเลือกท่าตามระยะ**:
  - ลำดับสถานะ: `IDLE` → (ตรวจพบผู้เล่น) `CHASE` (เดินหนัก 8 ทิศ) → `WINDUP` → `ACTIVE` → `RECOVER`, `HURT`, `DEAD`
  - ตรวจจับผู้เล่นผ่าน Area2D `Detect` (physics layer `player`) แล้ว emit `EventBus.boss_engaged(self, health, "มิโนทอร์")` ครั้งเดียว
  - เลือกท่าตามระยะห่าง:
    - **ระยะใกล้** (<= 70 px): ฟาดเหนือหัว (`CLEAVE`), กวาดขวาน (`SWEEP`), เสยขวานขึ้น (`RISING`)
    - **ระยะกลาง** (70–140 px): กระทืบกีบ (`STOMP` - AoE วงรอบตัว/เท้า)
    - **ระยะไกล** (140–260 px): พุ่งชนด้วยเขา (`CHARGE` - เส้นตรงล็อคทิศทางตอน telegraph), กระโดดทุบ (`LEAP` - ล็อคจุดตกตอน telegraph พร้อมแสดง `TelegraphMarker` ที่จุดตก)
  - กฎห้ามใช้ท่าเดิมซ้ำเกิน 2 ครั้งติด (`consecutive_attack_count <= 2` เสมอ)
- **ระบบ Telegraph และ Hitbox ประจำท่า**:
  - ทุกท่ามีช่วง `WINDUP` (ค้างเฟรมง้าง telegraph, กระพริบสีแดงเตือน, ค่าเวลา `@export` ต่อท่า ~0.55–0.80s)
  - ช่วง `ACTIVE`: เปิด Hitbox พร้อมรูปทรงและค่า stat ตามท่า:
    - ฟาด / เสย: วงกลมด้านหน้าตามทิศที่หัน
    - กวาดขวาน: วงกว้างครอบคลุมส่วนหน้า
    - กระทืบกีบ / กระโดดทุบ: วงรอบจุดลงกระแทก
    - พุ่งชน: Hitbox เคลื่อนที่ไปตามตัวบอสระหว่างพุ่ง
  - มี flag `is_attack_active` สำหรับตรวจสถานะ active อย่างแม่นยำ (ไม่ติด delay ของ `set_deferred` ใน Area2D)
- **ระบบ 2 Phase**:
  - เมื่อ HP < 50%: ช่วง windup ลดลงเหลือ 75% (`phase_2_windup_multiplier = 0.75`) และเพิ่มคอมโบ (ฟาดเหนือหัว `CLEAVE` จะต่อด้วยกวาดขวาน `SWEEP` ทันที)
- **ระบบ Poise & Super Armor**:
  - ตั้งค่า `poise = 60.0`: ดาเมจธรรมดาจะไม่ทำให้บอสเสียจังหวะ โดยจะสะสม stagger ไว้ เมื่อสะสมเกิน poise จึงจะเข้าสถานะ `HURT` (เซ) แล้วรีเซ็ตค่าสะสมเป็น 0
- **การตาย (Death)**:
  - เล่นแอนิเมชันคุกเข่าปักขวาน (เฟรม 52–59), ค้างที่เฟรม 59 แล้วค่อย ๆ จางหาย (`corpse_time`), emit `EventBus.enemy_died` ครั้งเดียว และปิด hitbox ทุกทางออก
- **Sandbox ลองเล่น**:
  - `game/systems/enemy/boss_minotaur/debug/minotaur_sandbox.tscn` + `minotaur_sandbox.gd`: มีหุ่น Dummy ผู้เล่น (Team PLAYER), บอสมิโนทอร์ (Team ENEMY), กล้อง, พื้นหลัง และ UI แสดงสถานะ Boss HP / Phase / State / Poise แบบสด

---

## 2. ไฟล์ที่สร้างและแก้ไข
- `game/systems/enemy/boss_minotaur/boss_minotaur.gd` (สร้างใหม่)
- `game/systems/enemy/boss_minotaur/boss_minotaur.tscn` (สร้างใหม่)
- `game/systems/enemy/boss_minotaur/debug/minotaur_sandbox.gd` (สร้างใหม่)
- `game/systems/enemy/boss_minotaur/debug/minotaur_sandbox.tscn` (สร้างใหม่)
- `game/tests/test_enemy_boss_minotaur.gd` (สร้างใหม่: ชุดทดสอบ 12 ข้อ)
- `game/systems/enemy/CLAUDE.md` (อัปเดตไฟล์สำคัญและกับดัก)
- `docs/GLOSSARY.md` (อัปเดตคำนิยาม `BossMinotaur`)

---

## 3. วิธีลองเล่น
- **Scene**: `res://systems/enemy/boss_minotaur/debug/minotaur_sandbox.tscn`
  - เปิดเล่นใน Godot Editor ด้วยการกด **F6** บน scene นี้
  - หรือรันผ่านคำสั่ง: `godot --path game res://systems/enemy/boss_minotaur/debug/minotaur_sandbox.tscn`
- **ปุ่มควบคุม**:
  - **ลูกศร / WASD**: บังคับหุ่น Dummy เดินหลบหรือเข้าหาบอส
  - **Space bar**: ฟันดาบโจมตีบอส (ทำดาเมจ 8, stagger 25 ต่อครั้ง เพื่อทดสอบการลด HP และการทำ Poise Break ให้บอสเซเมื่อครบ 60 stagger)
- **สิ่งที่สังเกตได้**:
  - บอสจะเดินเข้าหาผู้เล่นแบบนักล่า 8 ทิศ
  - เมื่ออยู่ระยะไกล บอสจะเลือกพุ่งชน (ล็อคเส้นทาง) หรือกระโดดทุบ (มีวงแดง `TelegraphMarker` เตือนจุดตก)
  - เมื่ออยู่ระยะกลาง บอสจะกระทืบพื้นเป็นคลื่นกระแทก AoE
  - เมื่ออยู่ระยะประชิด บอสจะเลือกฟาดเหนือหัว, กวาดขวาน หรือเสยขวาน
  - เมื่อ HP ลดต่ำกว่า 60 (< 50%) บอสจะง้างท่าเร็วขึ้นอย่างเห็นได้ชัด และเมื่อฟาดเหนือหัวจะออกท่ากวาดขวานตามทันทีเป็นคอมโบ

---

## 4. ผลการรันเทสต์
รันคำสั่ง:
```bash
godot --headless --path game --import && godot --headless --path game --script res://tests/run_tests.gd
```
ผลลัพธ์:
```text
tests: 64 passed, 0 failed
```
(เทสต์เดิม 52 ข้อ + เทสต์บอสมิโนทอร์ 12 ข้อ ผ่านครบ 100%)

ครอบคลุมหัวข้อทดสอบ:
1. `test_hurtbox_is_enemy_team_and_hitbox_starts_off`: ตั้งค่าทีมและเริ่มต้นปิด Hitbox ถูกต้อง
2. `test_all_attacks_have_windup_before_active`: ครบทั้ง 6 ท่ามีช่วง windup ก่อน active (ตรวจผ่าน flag `is_attack_active`)
3. `test_attack_selection_by_distance`: เลือกท่าตามระยะใกล้/กลาง/ไกล ถูกต้อง
4. `test_no_attack_repeated_more_than_twice`: สุ่มเลือกท่า 120 ครั้ง ไม่มีการใช้ท่าเดิมเกิน 2 ครั้งติดต่อกัน
5. `test_phase_2_transitions_at_half_hp`: ตรวจสอบการเปลี่ยน Phase 2 ที่ HP < 50% และเวลา windup ลดลงเหลือ 0.75x
6. `test_phase_2_combo_cleave_to_sweep`: ตรวจสอบการออกคอมโบ ฟาดเหนือหัว → กวาดขวาน ติดกันใน Phase 2
7. `test_boss_engaged_emitted_once`: emit `boss_engaged` ครั้งเดียวพร้อมชื่อ `"มิโนทอร์"`
8. `test_enemy_died_emitted_once`: emit `enemy_died` ครั้งเดียวเมื่อพลังชีวิตหมด
9. `test_hitbox_closed_on_death`: Hitbox และ flag active ปิดสนิทเมื่อบอสตาย
10. `test_poise_stagger_mechanic`: ตรวจสอบการสะสมค่า stagger และการเข้าสู่สถานะ `HURT` เฉพาะเมื่อเกินค่า poise
11. `test_leap_shows_telegraph_marker`: แสดง `TelegraphMarker` ที่จุดตกและซ่อนเมื่อลงพื้น
12. `test_charge_locks_direction`: ล็อคทิศทางการพุ่งชนตั้งแต่ช่วง windup แม้ผู้เล่นจะขยับหนี

---

## 5. ค้าง / ข้อเสนอแนะ Contract
- **จอสั่นตอนกระทืบกีบ / ทุบพื้น (Camera Shake)**:
  ตามกติกาของโปรเจกต์ ห้ามเพิ่ม signal ข้ามระบบเองโดยไม่มี contract ปัจจุบัน `game/core/event_bus.gd` ยังไม่มี signal สำหรับขอให้กล้องสั่น
  **ข้อเสนอ contract**:
  เสนอเพิ่ม signal ใน `EventBus` สำหรับส่งต่อให้ `GameCamera` ในระบบ camera:
  ```gdscript
  ## ร้องขอให้จอสั่น (strength = ความแรง px, duration = ระยะเวลา วินาที)
  signal screen_shake_requested(strength: float, duration: float)
  ```
  เพื่อให้ท่ากระทืบกีบ (Stomp) และกระโดดทุบ (Leap) สามารถเรียกใช้งานเพื่อเพิ่มความหนักแน่นของการต่อสู้ได้

---

## 6. แก้ตามรีวิว

ได้ปรับปรุงโค้ดและชุดทดสอบครบทั้ง 9 ข้อตาม `FIX_WORKER.md`:

1. **[สูง] แก้ LEAP ทำดาเมจตลอดทางลอย**:
   - ปรับ `_enter(State.ACTIVE)` ไม่เปิด hitbox ทันทีสำหรับ LEAP (`is_attack_active = false`, `hitbox.deactivate()`)
   - ใน `_tick_active()`: เปิด hitbox (`activate()` + `is_attack_active = true`) ใน tick แรกที่ลงพื้น (`_state_t >= leap_time`) ที่จุดตก

2. **[สูง] ปรับวงเตือน TelegraphMarker ให้ตรงพื้นที่โดนจริง**:
   - ซ่อน `TelegraphMarker` ตอนเข้า `State.RECOVER` (ไม่ซ่อนตอนเริ่มกระโดด)
   - ท่า AoE บนพื้น (`STOMP`, `LEAP`): ปรับ `hitbox_shape.scale = Vector2(1.0, telegraph_marker.squash)` (0.55) ให้สเกล Hitbox วงรีตรงกับวงเตือนบนพื้น isometric
   - ท่ากระทืบ (`STOMP`): แสดง marker รัศมี `stomp_radius` ที่เท้าบอสพร้อมอัปเดต progress ระหว่างช่วง windup

3. **[กลาง] แก้เฟรม Telegraph ของ LEAP**:
   - ปรับ `ATTACK_COLS[AttackType.LEAP]["tele"] = 42` (เฟรม 0 ของกระโดดทุบ คือท่าย่อลึกค้าง)

4. **[กลาง] คำนวณความสัมพันธ์ของระยะโจมตี (Range Consistency)**:
   - ปรับช่วงระยะ: `near_attack_range = 70.0`, `mid_attack_range = 110.0`, `far_attack_range = 240.0`
   - ปรับ `stomp_radius = 120.0` (`>= mid_attack_range + 10.0`)
   - ปรับระยะพุ่งชน: `charge_speed = 340.0`, `charge_duration = 0.60` (ระยะเคลื่อนที่ 204 px + hitbox 44 px = 248 px `>= far_attack_range`)
   - ใน `setup()`: ตรวจสอบและคำนวณความสัมพันธ์ของค่า stat อัตโนมัติ
   - เพิ่ม `get_attack_reach(atk)` และใน `choose_attack()` หาก fallback จะเลือกเฉพาะท่าที่ระยะเอื้อมถึงระยะห่าง `dist`
   - เพิ่มเทสต์ `test_every_chosen_attack_reaches_target_distance` ยืนยันว่าทุกท่าที่เลือกตีถึงระยะเป้าหมายเสมอ

5. **[กลาง] แก้แรงกระเด็นตอนเซ (Knockback Velocity)**:
   - ปรับใน `_on_hurt()`: กำหนด `velocity = info.knockback * 0.5` **หลัง** เรียก `_enter(State.HURT)` เพื่อไม่ให้ถูก `_enter()` รีเซ็ตเป็น Vector2.ZERO

6. **[กลาง] เพิ่มและปรับปรุงชุดการทดสอบ**:
   - `test_no_attack_repeated_more_than_twice`: ทดสอบที่ระยะกลางอย่างเดียว (Mid distance) 60 รอบ ยืนยันว่า STOMP ไม่ซ้ำเกิน 2 ครั้งติด รวมถึงทดสอบระยะใกล้ ไกล และสลับระยะ
   - `test_hitbox_closed_on_death`: เปลี่ยนมา assert ผ่าน `is_attack_active` ตาม contract แทน `hitbox.monitoring` ที่ดีเลย์ด้วย `set_deferred`
   - เพิ่ม `test_stagger_in_active_closes_hitbox`: ยืนยันว่าเมื่อโดนตีจนเซกลางช่วง ACTIVE กล่อง Hitbox จะปิดทันที
   - เพิ่ม `test_leap_hitbox_active_only_on_landing`: ยืนยันว่า LEAP ช่วงลอยตัว Hitbox จะไม่เปิด และจะเปิดเฉพาะตอนแตะพื้น
   - เพิ่ม `test_hit_during_leap_windup_hides_marker`: ยืนยันว่าหากโดนตีจนเซระหว่าง windup ของ LEAP วงเตือนจะหายไปทันที

7. **[ต่ำ] ท่ากวาด (SWEEP) เป็นครึ่งวงหน้าจริง**:
   - ใช้ `ConvexPolygonShape2D` พร้อม `Geometry2D.convex_hull` คำนวณจุดครึ่งวงกลมด้านหน้า 180 องศาตาม `facing_vec` รัศมี 72 px จุดศูนย์กลางที่ลำตัว โดยไม่มีส่วนใดล้นไปข้างหลังบอส

8. **[ต่ำ] กระโดดทุบ Clamp จุดตกไม่ให้ลงในกำแพง**:
   - ฟังก์ชัน `_clamp_leap_position()`: ใช้ `space_state.intersect_point()` กับ `Combat.LAYER_WORLD` หากจุดตกทับกำแพง จะถอยเข้าหาตำแหน่งบอสทีละ 8 px จนกว่าจะพ้นกำแพง

9. **[docs] คืนข้อความเดิมของ `minotaur_sheet.png` ใน `game/systems/enemy/CLAUDE.md`**:
   - คืนข้อความคำอธิบายเดิมทั้งหมดจาก `origin/main` และเติมรายละเอียดส่วนเฟส 4 ต่อท้าย พร้อมอัปเดตรายละเอียด `TelegraphMarker`

### ผลการรันเทสต์หลังแก้:
```text
godot --headless --path game --script res://tests/run_tests.gd
tests: 71 passed, 0 failed
```
(เทสต์เดิมทั้งหมด 64 ข้อ + เทสต์ใหม่ที่เพิ่มตามรีวิว ผ่านครบ 100% ปราศจาก Warning)

---

## 7. แก้รอบ 2

ได้ดำเนินการแก้ไขตามรีวิวรอบ 2 และปรับให้สอดคล้องกับ contract ล่าสุด (`origin/main` issue #52) ครบถ้วน:

0. **Merge `origin/main`**:
   - รวม contract ใหม่: `EventBus.screen_shake_requested(strength: float, pos: Vector2)`, `Hitbox.deflected(hurtbox: Hurtbox, info: DamageInfo)`
   - จัดการข้อขัดแย้งใน `docs/GLOSSARY.md` โดยเก็บครบทุกแถวจากทั้งสองฝั่ง

1. **[กลาง] STOMP & LEAP ตีโดน 8 ทิศทางและคิดตามรูปทรงวงรี Isometric**:
   - `choose_attack()` และ `get_attack_candidates()`: คำนวณระยะด้วยสมการวงรี `sqrt(dx² + (dy / squash)²)` ตามค่า `squash` ของ telegraph marker / hitbox
   - `get_attack_reach()`: ท่า `STOMP` และ `LEAP` นำตัวคูณ `squash` มาคำนวณระยะเอื้อมจริง
   - Hitbox ของ `STOMP` และ `LEAP` วางตำแหน่ง origin ที่ `Vector2.ZERO` (ตรงกับจุดเตือนที่เท้าบอสพอดี)
   - เพิ่มเทสต์ physics จริง:
     - `test_stomp_hits_all_8_directions_real_physics()`: spawn เข้า `Engine.get_main_loop().root` พร้อม Hurtbox ผู้เล่น (รัศมี 10 ที่ y = -16 ตาม `player.tscn`) ทดสอบทั้ง 8 ทิศทาง AI เลือก STOMP และโจมตีโดนครบทุกทิศทาง
     - `test_leap_hits_all_8_directions_real_physics()`: จำลองการกระโดดทุบลงทั้ง 8 ทิศทาง AI พิจารณา LEAP เป็น candidate และทุบโดนเป้าหมายครบทุกทิศทาง

2. **[ต่ำ] จุดตก LEAP ป้องกันติดกำแพงด้วย Circle Shape จริง**:
   - ปรับปรุง `_clamp_leap_position()` ให้ใช้ `space_state.intersect_shape()` ด้วย `CircleShape2D` รัศมีลำตัวบอส (16 px) แทนการเช็คเพียงจุดเดียว
   - หากจุดตกซ้อนทับกับ layer โลก (`Combat.LAYER_WORLD`) จะถอยกลับทีละ 8 px เข้าหาตำแหน่งเดิมของบอสจนกว่าจะพ้นสิ่งกีดขวาง
   - เพิ่มเทสต์ `test_leap_clamp_with_real_static_body_wall()`: วาง `StaticBody2D` กำแพงจริงใน physics space และยืนยันว่าบอสไม่ตกเข้าไปในกำแพง

3. **[contract] ระบบ Screen Shake (`EventBus.screen_shake_requested`)**:
   - เพิ่ม `@export_group("Screen Shake")` ใน `boss_minotaur.gd`:
     - `stomp_screen_shake = 0.5` (กระทืบเท้าเข้า `State.ACTIVE`)
     - `leap_screen_shake = 0.6` (กระโดดกระแทกลงพื้น)
     - `footstep_screen_shake = 0.12` (ฝีเท้าหนักตอนเดินในคอลัมน์แอนิเมชัน 4 และ 8)
     - `death_knee_screen_shake = 0.3` (เข่ากระแทกพื้นตอนตายที่คอลัมน์แอนิเมชัน 54)
   - เพิ่มเทสต์ `test_screen_shake_requested_emits()`: ตรวจสอบการส่งสัญญาณและความแรงของ screen shake ครบทุกจังหวะ

4. **[contract] ระบบ Parry / Deflect (`hitbox.deflected`)**:
   - เชื่อมต่อสัญญาณ `hitbox.deflected` ใน `setup()`
   - เมื่อผู้เล่น parry ได้ผล (`Result.DEFLECTED`):
     - ท่าประชิด (`CLEAVE`, `SWEEP`, `RISING`) และท่าพุ่งชน (`CHARGE`): บอสจะถูกขัดจังหวะเข้าสู่ `State.HURT` พร้อมแรงกระเด็นถอยหลัง (`parried_knockback = 180.0`) และระยะเวลาชะงัก (`parried_stagger_time = 0.6s`)
     - ท่ากระแทกพื้น (`STOMP`, `LEAP`): ไม่สามารถ parry ได้ และบอสจะไม่เซ
   - เพิ่มเทสต์ `test_hitbox_deflected_parry_behavior()`: ยืนยันพฤติกรรมการ deflect ของทุกท่าครบถ้วน

### ผลการรันเทสต์หลังแก้รอบ 2:
```text
godot --headless --path game --script res://tests/run_tests.gd
tests: 121 passed, 0 failed
```
(เทสต์ทั้งหมด 121 ข้อ ผ่านครบ 100% รวมเทสต์ physics และ async)


