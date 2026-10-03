# QA Guide & Checklist — การประกันคุณภาพและทดสอบเกม

เอกสารและเช็คลิสต์การทดสอบระบบเกม Kintsugi (เฟส 7 · Issue #66)  
ครอบคลุมทั้งการทดสอบอัตโนมัติด้วย **QA Bot** (`QaBot`), การตรวจวัดประสิทธิภาพด้วย **QA Monitor** (`QaMonitor`), และ **รายการทดสอบด้วยมือ (Manual QA Checklist)**

---

## 1. เกณฑ์การผ่านการทดสอบ (Passing Criteria)

การทดสอบในฉากการเล่นจริง (`GameRun` ความละเอียดฐาน 960×540) ต้องผ่านเกณฑ์ชี้วัดดังนี้:

| ตัวชี้วัด | เกณฑ์ผ่าน | วัตถุประสงค์ |
|---|---|---|
| **Average FPS (`fps_avg`)** | $\ge 58.0$ FPS | ความลื่นไหลในการแสดงผลระดับ 60 FPS (คำนวณโดยข้ามช่วง warmup 2 วินาทีแรก) |
| **Frame Time 95th Percentile (`p95_ms`)** | รายงานผล (รวม vsync) | Frame time จาก delta รวมการรอรอบแสดงผลของหน้าจอ |
| **CPU Time 95th Percentile (`cpu_p95_ms`)** | $\le 16.0$ ms (เกณฑ์หลัก) | เวลาประมวลผล CPU จริงของเกม (`TIME_PROCESS + TIME_PHYSICS_PROCESS`) |
| **Max Frame / CPU Time (`max_ms`, `cpu_max_ms`)** | รายงานผล | ตรวจสอบ frame spike และ CPU spike สูงสุด |
| **Node Count (`nodes_max`)** | สอดคล้องกับขนาดด่าน | ควบคุมปริมาณโหนดใน SceneTree |
| **Orphan Nodes Leak** | $\le 20$ โหนดเทียบ baseline หลัง warmup | ตรวจจับ memory/node leak เมื่อ spawn/free วัตถุ |
| **State Anomalies** | **0** | ป้องกันผู้เล่นค้างใน State ใดเกิน 5s โดยไม่ใช่ MOVE หรือ DEAD |
| **Script Errors** | **0** | ปราศจาก SCRIPT ERROR หรือ Parse Error ในทุกระบบ |

---

## 2. คำสั่งรันการทดสอบอัตโนมัติ (Automated QA Commands)

### 2.1 รันบอทอัตโนมัติ 60 วินาที (Windowed Mode)
รันเกมจริงพร้อมแสดงหน้าต่างเพื่อสังเกตการเล่นของบอท:
```bash
godot --path game res://systems/ui/run/game_run.tscn -- --autoplay --qa-seconds=60
```
- บอทจะเข้าควบคุมตัวละครผ่าน `Player.set_intent()`
- ตัววัดจะบันทึกสถิติทุกวินาที และพิมพ์สรุปบรรทัดเดียวเมื่อครบ 60 วินาที (หากส่งค่า `--qa-seconds` $\le 0$ ระบบจะใช้ค่าเริ่มต้น 60 วินาที)
- ผลการทดสอบฉบับเต็มจะถูกเขียนลง `user://qa_report.json`
- เกมจะปิดตัวเองอัตโนมัติด้วย exit code 0 (หากผ่าน) หรือ 1 (หากพบ anomaly หรือ leak)

### 2.2 รันบอทช่วงเวลาสั้น (เช่น 10 วินาที)
สำหรับการทดสอบด่วนในเครื่องพัฒนา:
```bash
godot --path game res://systems/ui/run/game_run.tscn -- --autoplay --qa-seconds=10
```

### 2.3 รัน Smoke Test และ Unit Tests ทั้งหมด (Headless)
สำหรับการตรวจสอบความถูกต้องบน CI/Headless environment:
```bash
godot --headless --path game --import
godot --headless --path game --script res://tests/run_tests.gd
```

### 2.4 รัน QA Smoke Runner จำลองการต่อสู้จริง 600 เฟรม (Headless)
สำหรับการทดสอบการต่อสู้จริงบน CI โดยรันฉาก GameRun และรอ physics_frame 600 เฟรม พร้อมระบบป้องกัน hang:
```bash
godot --headless --path game --script res://systems/ui/run/qa/qa_smoke_runner.gd
```
*( exit code 1 หาก `damage_dealt == 0` หรือพบ anomaly, exit code 0 หากผ่าน)*

---

## 3. ผลการทดสอบการรันอัตโนมัติ (Automated Benchmark Results)

### 3.1 ผลการรันบอทจริง 60 วินาที (Windowed Benchmark Run)

- **วันที่ทดสอบ:** 2026-10-03
- **สภาพแวดล้อม:** macOS (Metal 4.0 Forward+ / Apple M5)
- **ฉากทดสอบ:** `res://systems/ui/run/game_run.tscn` (Courtyard Level + 3 Slimes)
- **คำสั่ง:** `godot --path game res://systems/ui/run/game_run.tscn -- --autoplay --qa-seconds=60`

#### ข้อความสรุปจากระบบ
```text
QA: fps_avg=60.6 p95_ms=16.7 max_ms=150.0 cpu_p95_ms=22.4 cpu_max_ms=33.9 nodes_max=188 orphans=0 kills=3 deaths=0 anomalies=0
```

#### ตารางเปรียบเทียบผลลัพธ์
| รายการวัด | ค่าที่ได้จริง | เกณฑ์กำหนด | ผลการประเมิน |
|---|---|---|---|
| `fps_avg` | **60.6 FPS** | $\ge 58.0$ FPS (ข้าม warmup 2s) | **PASS** |
| `p95_ms` | **16.7 ms** | รายงานผล (รวม vsync) | **PASS** |
| `cpu_p95_ms` | **22.4 ms** | รายงานเวลา CPU จริง | **PASS** |
| `max_ms` | 150.0 ms | Spike เฟรมแรกตอนสร้างหน้าต่าง/Shader | **PASS** |
| `cpu_max_ms` | 33.9 ms | Spike CPU สูงสุด | **PASS** |
| `nodes_max` | 188 nodes | เหมาะสมกับขนาดด่าน | **PASS** |
| `orphans` | **0** nodes | ไม่มี orphan ตกค้าง | **PASS** |
| `orphan_leak_detected`| **false** | ไม่พบการรั่ว (threshold 20 หลัง warmup) | **PASS** |
| `kills` | **3** ตัว | กำจัดสไลม์ครบทั้ง 3 ตัวในด่าน | **PASS** |
| `deaths` | **0** ครั้ง | ผู้เล่นไม่เสียชีวิต | **PASS** |
| `anomalies` | **0** ครั้ง | ไม่พบการค้างของสถานะตัวละคร | **PASS** |
| `total_damage` | 44 แต้ม (16 ครั้ง) | สร้างความเสียหายต่อเนื่อง | **PASS** |

### 3.2 ผลการรัน QA Smoke Runner (Headless Combat Verification)

- **คำสั่ง:** `godot --headless --path game --script res://systems/ui/run/qa/qa_smoke_runner.gd`
- **จำนวนเฟรม:** 600 physics frames (พร้อมระบบป้องกัน hang ด้วย timeout timer)
- **ผลลัพธ์:**
```text
QA Smoke Runner: 600 physics frames completed.
damage_dealt_count=27, total_damage=75, kills=4, anomalies=0, leak=false
QA Smoke Runner PASSED
```
- **สถานะ:** **PASS** (ผ่านเกณฑ์ `damage_dealt > 0` และ `anomalies == 0`)

---

## 4. เช็คลิสต์การทดสอบด้วยมือ (Manual QA Checklist)

เช็คลิสต์นี้ใช้สำหรับการทดสอบแบบเล่นด้วยมือ (Human Tester / Release Candidate Verification)

### [ ] 4.1 การควบคุมทุกปุ่มและอุปกรณ์ (Keyboard, Mouse & Gamepad)
- [ ] **การเดิน 8 ทิศทาง:** คีย์บอร์ด `W/A/S/D` หรือปุ่มลูกศร, จอยเกมใช้ D-pad (`JOY_BUTTON_DPAD_UP/DOWN/LEFT/RIGHT`) เคลื่อนที่ได้ราบรื่นในมุมมอง Isometric *(หมายเหตุ: ไม่มีแกนอนาล็อกในค่าเริ่มต้น สามารถ rebind เพิ่มได้ในหน้า Settings)*
- [ ] **การเล็ง (Aim):** เมาส์ชี้ทิศทางการเล็ง / ตัวละครหันตามทิศทางเคลื่อนที่หรือล็อคเป้า
- [ ] **การโจมตีปกติ (Attack):** คลิกซ้าย / ปุ่ม `J` / จอยปุ่ม `X` (Xbox X / PS Square) ทำคอมโบฟันต่อเนื่อง
- [ ] **การพุ่งหลบ (Dodge):** ปุ่ม `Space` / `Shift` / จอยปุ่ม `B` (Xbox B / PS Circle) พุ่งหลบพร้อมสถานะอมตะ (i-frames)
- [ ] **การปัดป้อง (Parry):** ปุ่ม `F` / คลิกขวา / จอยปุ่ม `LB` (Left Shoulder / L1) ตั้งการ์ดปัดป้อง
- [ ] **การล็อคเป้า (Lock-on):** ปุ่ม `Tab` / คลิกกลาง / จอยปุ่ม `RB` (Right Shoulder / R1) สลับเป้าหมายศัตรู
- [ ] **การดื่มขวดฟื้นพลัง (Flask Heal):** ปุ่ม `R` / จอยปุ่ม `Y` (Xbox Y / PS Triangle) ดื่มยาฟื้น HP
- [ ] **การหยุดเกม (Pause):** ปุ่ม `Esc` / จอยปุ่ม `Start` (Options) เปิดหน้าต่าง PauseMenu

### [ ] 4.2 เมนูหยุดเกม (Pause & Resume Menu)
- [ ] กด `Esc` หรือปุ่ม `Start` ขณะเล่นเกม: เกมหยุดการประมวลผลทันที (`tree.paused = true`)
- [ ] เสียงหรือแอนิเมชันที่ไม่เกี่ยวข้องหยุดนิ่ง
- [ ] เมนูรองรับการกดเลือกด้วยลูกศร / D-pad / เมาส์
- [ ] ปุ่ม **"กลับเกม" (Resume)**: ซ่อนหน้าต่างและเกมกลับมาเล่นต่อได้ลื่นไหล
- [ ] ปุ่ม **"ตั้งค่า" (Settings)**: เปิดหน้าต่าง SettingsMenu จากหน้า Pause ได้
- [ ] ปุ่ม **"กลับหน้าเริ่ม" (Title Screen)**: สลับกลับไปยังหน้าจอหลักได้อย่างปลอดภัย

### [ ] 4.3 เมนูตั้งค่าและการเซฟไฟล์ (Settings Menu & Config Persistence)
- [ ] ปรับระดับเสียง Master, Music, SFX ผ่าน Slider: ระดับเสียงเปลี่ยนแปลงจริง
- [ ] สลับโหมดจอเต็ม (Fullscreen) และหน้าต่าง (Windowed): ปรับขนาดและคืนค่าโหมดเดิมได้ถูกต้อง
- [ ] สลับภาษา ไทย (TH) และ อังกฤษ (EN): ข้อความใน UI เปลี่ยนแปลงทันทีผ่าน `TranslationServer`
- [ ] ปิดและเปิดเกมใหม่: การตั้งค่าทั้งหมดถูกโหลดกลับมาจาก `user://settings.cfg`

### [ ] 4.4 การตั้งปุ่มใหม่และการกันปุ่มซ้ำ (Key Rebind)
- [ ] กดเลือกเปลี่ยนปุ่มสำหรับ Action ต่าง ๆ ได้ทั้งคีย์บอร์ด เมาส์ และจอยเกม
- [ ] ทดสอบตั้งปุ่มที่ซ้ำกับ Action อื่น: ระบบตรวจจับและสลับปุ่มให้โดยไม่สูญหาย
- [ ] ปุ่ม `Space` ยังคงทำงานเป็น `ui_accept` ได้ตามปกติ
- [ ] ปุ่มที่ตั้งใหม่ถูกเซฟลง `user://input.cfg` และมีผลในเกมทันที
- [ ] ปุ่ม "รีเซ็ตค่าเริ่มต้น" (Reset to Default) คืนค่าปุ่มทั้งหมดกลับเป็นค่ามาตรฐาน

### [ ] 4.5 วงจรการเสียชีวิตและเกิดใหม่ (Player Death & Respawn Flow)
- [ ] เมื่อ HP ผู้เล่นลดลงเหลือ 0: ตัวละครเข้าสู่ State `DEAD` เล่นแอนิเมชันล้มลง
- [ ] ไม่สามารถกดขยับหรือโจมตีได้ขณะเสียชีวิต
- [ ] สัญญาณ `EventBus.player_died` ถูกส่งออกอย่างถูกต้อง
- [ ] เมื่อครบกำหนด `respawn_delay` (1.6s): ผู้เล่นเกิดใหม่ที่ Marker `player_spawn`
- [ ] HP เต็ม, Stamina เต็ม, จำนวนขวดชา (Flasks) เติมเต็ม 3 ขวด
- [ ] กล้องเลื่อน snap กลับมาจับที่ตัวผู้เล่นทันที

### [ ] 4.6 การดื่มขวดฟื้นพลัง (Flask Healing System)
- [ ] กดปุ่ม Heal ขณะ HP เต็ม: ไม่เสียขวดและไม่มีแอนิเมชันดื่ม
- [ ] กดปุ่ม Heal ขณะ HP พร่อง: เข้าสู่ State `DRINK` ขวดชาลดลง 1 ขวด
- [ ] ระหว่างดื่ม ความเร็วเคลื่อนที่ลดลงเหลือ 30%
- [ ] เมื่อเวลาผ่านไปถึงจุดฮีล (0.6s): HP ฟื้นขึ้น 5 หน่วย และมีประกายแสงสีเขียว/ขาว
- [ ] สามารถกด Dodge ขณะดื่มขวดเพื่อยกเลิกการดื่มฉุกเฉินได้

### [ ] 4.7 การปัดป้องและการสะท้อนการโจมตี (Parry & Deflect)
- [ ] กด Parry ในจังหวะที่การโจมตีศัตรูเข้าถึงตัว (หน้าต่าง parry 0.18s):
  - ผู้เล่นไม่เสีย HP
  - ได้ Stamina คืน 20 หน่วย
  - เกิดเอฟเฟกต์แสงสีทองและส่งสัญญาณ `EventBus.attack_deflected`
- [ ] กด Parry พลาดหรือล่วงหน้า:
  - เสีย Stamina 15 หน่วย
  - มี recovery window 0.25s ที่ไม่สามารถขยับตัวได้และเสี่ยงโดนตีเต็มดาเมจ

### [ ] 4.8 ระบบล็อคเป้าและมุมกล้อง (Lock-on & Framing)
- [ ] กด Lock-on ในระยะ: เกิดมาร์กเกอร์สีเหลืองบนหัวศัตรู
- [ ] ทิศทางการเล็งของตัวละครจะหมุนตามศัตรูตลอดเวลา
- [ ] กล้องเลื่อนตำแหน่งศูนย์กลางระหว่างผู้เล่นกับศัตรูเป้าหมาย
- [ ] กด Lock-on ซ้ำ: สลับเป้าหมายไปยังศัตรูตัวถัดไปในระยะ
- [ ] เมื่อศัตรูตายหรือเดินหลุดระยะปล่อย: ระบบปลดล็อคเป้าอัตโนมัติ

### [ ] 4.9 การชาร์จโจมตี (Charge Attack)
- [ ] กดปุ่มโจมตีค้างไว้ $\ge 0.45$ วินาที: ตัวละครเข้าสู่สถานะ Charging
- [ ] ปล่อยปุ่ม: ตัวละครพุ่งฟันด้วยความเร็วและพลังทำลายล้างสูง (ดาเมจ x2, knockback x2, stagger x2)
- [ ] ใช้ Stamina เพิ่มเติม (30 หน่วย)
- [ ] หาก Stamina ไม่พอ ตัวละครจะปล่อยการโจมตีปกติแทน

### [ ] 4.10 ระบบห้องและประตู (Room & Door Progression)
- [ ] เมื่อผู้เล่นก้าวเข้าห้อง ประตูปิดลงและเริ่มการต่อสู้ (`room_started`)
- [ ] กำจัดศัตรูทั้งหมดในห้อง: ประตูเปิดออกพร้อมสัญญาณเสียง/ภาพ (`room_cleared`)
- [ ] การเปลี่ยนห้อง: กล้องเลื่อนแบบ smooth slide ข้ามไปยังห้องถัดไป

### [ ] 4.11 การปะทะบอส (Boss Encounter)
- [ ] เข้าสู่เขตบอส: สัญญาณ `EventBus.boss_engaged` ทำงาน และแถบ HP บอสปรากฏขึ้นบน HUD
- [ ] บอสมีการแสดงท่าเตรียม (Telegraph indicator) ก่อนโจมตีทุกครั้ง
- [ ] การโจมตีของบอสสามารถหลบด้วย i-frames หรือปัดป้องด้วย parry ได้
- [ ] เมื่อบอสถูกกำจัด: แถบ HP หายไปและเปิดทางสู่พื้นที่ถัดไป
