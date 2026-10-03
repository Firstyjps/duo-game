# รายงานผลการทำงาน: เฟส 5 ห้องดันเจี้ยน isometric (issue #39)

- **ระบบ:** `dungeon`
- **Branch:** `kron/39-iso-dungeon`
- **Commit:** `[dungeon] เฟส 5 ห้องดันเจี้ยน isometric ต่อ 3 ห้อง ประตู และแสง (#39)`

---

## 1. สิ่งที่ทำในงานนี้

1. **Placeholder Isometric Tileset 64×32 (`iso_tiles.png` & `gen_iso_tiles.py`):**
   - พัฒนาสคริปต์ Python+PIL ใน `game/systems/dungeon/tools/gen_iso_tiles.py` เพื่อวาด tileset สำหรับมุมมอง isometric ขนาด 64×32 ตามโทนลานวัดญี่ปุ่นยามค่ำ (Navy, Plum, Slate, Kintsugi Gold, Lantern Fire)
   - ประกอบด้วย:
     - หินพื้นหลายแบบ: พื้นหินวัดสะอาด, หินพื้นสึกกร่อนมีรอยกระเทาะ, หินพื้นมีรอยร้าวทองคินสึงิ 2 แบบ, หินสลักลายเพชรวัด, พื้นทางผ่านประตู, และวงเวทจุดเกิดศัตรู
     - กำแพงบล็อกสูง 32 px: ใช้ขนาดใน atlas แบบ 1×2 (64×64 px) พร้อมตั้ง `texture_origin = Vector2i(0, -16)` เพื่อให้ฐานเพชรของกำแพงตรงกับเพชรพื้นพอดี มีแบบบล็อกเรียบ, บล็อกรอยร้าวทองคินสึงิ, บล็อกสลักลวดลาย, บล็อกผุพัง, และโคมหิน
     - ประตูทางเข้า/ออก: ประตูไม้ระแนงปิดลงยันต์ทอง (Closed) และซุ้มประตูเปิดโล่ง (Open)

2. **TileSet Resource (`dungeon_tileset.tres` & `build_tileset.gd`):**
   - ตั้งค่า `tile_shape = TileSet.TILE_SHAPE_ISOMETRIC`, `tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN`, `tile_size = Vector2i(64, 32)`
   - กำหนด physics layer 0 เป็น `Combat.LAYER_WORLD` (layer 1)
   - บล็อกกำแพงทุกบล็อกมี collision polygon รูปเพชร `[Vector2(0, -16), Vector2(32, 0), Vector2(0, 16), Vector2(-32, 0)]` สำหรับชนกับผู้เล่นและศัตรู

3. **ระบบประตู (`Door` — `door.gd` + `door.tscn`):**
   - ประตูขอบห้องมีสถานะ `is_open`
   - เมื่อปิด (Locked): แสดงภาพประตูปิด + เปิดการทำงานของ `Blocker` (`StaticBody2D` บน `Combat.LAYER_WORLD`) ปิดกั้นไม่ให้ผู้เล่นเดินผ่าน
   - เมื่อเปิด (Cleared): แสดงภาพประตูเปิด + ปิดการทำงานของ Blocker + เปิดการทำงานของ `ExitTrigger` (`Area2D` mask `Combat.LAYER_PLAYER`) เพื่อตรวจจับเมื่อผู้เล่นก้าวผ่านประตู
   - มีการใช้ `set_deferred` เมื่ออยู่ใน SceneTree เพื่อป้องกัน error `Can't change this state while flushing queries` ในช่วง physics callback

4. **ระบบห้องดันเจี้ยน (`Room` — `room.gd` + `room.tscn`):**
   - รองรับสถานะห้องแบบ FSM: `IDLE` → `LOCKED` → `CLEARED`
   - `IDLE`: ประตูเปิดรอผู้เล่น เมื่อผู้เล่นก้าวเข้า `PlayerDetector` (Area2D layer player) จะเปลี่ยนเป็น `LOCKED`
   - `LOCKED`: ประตูปิดขังผู้เล่น, spawn ศัตรูสไลม์ (`res://systems/enemy/slime/slime.tscn`) ตามตำแหน่งจุดเกิด (`Marker2D` ในกลุ่ม `spawn_points`)
   - การนับ Kill: ดักฟัง `EventBus.enemy_died` และนับลดเฉพาะศัตรูที่อยู่ในรายการ `spawned_enemies` ของห้องนั้น ไม่นับศัตรูจากห้องอื่น
   - `CLEARED`: เมื่อศัตรูที่ห้อง spawn ตายครบ จะเปลี่ยนสถานะเป็น `CLEARED`, ปลดล็อกและเปิดประตูทุกบาน, emit signal `room_cleared`
   - ห้องที่ไม่มีศัตรู: หากห้องไม่มีจุด spawn เมื่อเริ่มห้องจะเคลียร์ทันที (`clear_room()`)
   - ระบบแสง: ติดตั้ง `CanvasModulate` ย้อมโทนราตรีน้ำเงินอมม่วง และ `PointLight2D` (โคมไฟหินส่องแสงอบอุ่น GradientTexture2D)

5. **ระบบดันเจี้ยน (`Dungeon` — `dungeon.gd` + `dungeon.tscn`):**
   - เชื่อมต่อ 3 ห้องต่อเนื่อง:
     - ห้อง 1: สไลม์ 2 ตัว
     - ห้อง 2: สไลม์ 4 ตัว (ยากขึ้น)
     - ห้อง 3: ห้องบอส (เว้นว่างไว้ 0 ตัว เคลียร์ทันทีเมื่อเข้า)
   - เดินผ่านประตู: เมื่อผู้เล่นเดินเข้า `ExitDoor` ของห้องปัจจุบัน ดันเจี้ยนจะส่งตัวผู้เล่นไปยัง `PlayerSpawnPoint` ของห้องถัดไป และย้ายตำแหน่งกล้อง
   - ดักฟัง `EventBus.player_died`: หากผู้เล่นตาย จะรีเซ็ตดันเจี้ยน ล้างศัตรู และส่งผู้เล่นกลับจุดเกิดของห้องที่ 1

6. **ฉากทดสอบลองเล่น (`dungeon_sandbox.gd` + `dungeon_sandbox.tscn`):**
   - Instance `res://systems/player/player.tscn` (ไม่แก้ไขไฟล์ผู้เล่นเดิม)
   - Instance `res://systems/camera/game_camera.gd`
   - มี HUD แสดงข้อมูลห้อง, สถานะ (IDLE / LOCKED / CLEARED), ศัตรูที่เหลือ, หลอด HP/Stamina ของผู้เล่น, และคำแนะนำปุ่มกด

7. **เอกสารและคำศัพท์:**
   - อัปเดต `game/systems/dungeon/CLAUDE.md` บันทึกโครงสร้างไฟล์, กติกา, และกับดัก
   - เพิ่มคำศัพท์ใหม่ใน `docs/GLOSSARY.md` (`Dungeon`, `Room`, `Door`, `Room.State`, `spawn_points`)

---

## 2. ไฟล์ทั้งหมดที่เพิ่มและแก้ไข

### สร้างใหม่ (`game/systems/dungeon/`):
- `game/systems/dungeon/art/iso_tiles.png` (และ `.import`): Spritesheet isometric tileset 512×128
- `game/systems/dungeon/dungeon_tileset.tres`: TileSet isometric 64×32
- `game/systems/dungeon/room/door.gd`, `door.tscn`: คลาสและ scene ประตูทางออก
- `game/systems/dungeon/room/room.gd`, `room.tscn`: คลาสและ scene ห้องดันเจี้ยน
- `game/systems/dungeon/dungeon.gd`, `dungeon.tscn`: คลาสและ scene ดันเจี้ยน 3 ห้อง
- `game/systems/dungeon/debug/dungeon_sandbox.gd`, `dungeon_sandbox.tscn`: ฉากทดสอบลองเล่น
- `game/systems/dungeon/tools/gen_iso_tiles.py`: สคริปต์ Python สำหรับสร้างภาพ tileset
- `game/systems/dungeon/tools/build_tileset.gd`: สคริปต์ GDScript สร้าง tileset resource
- `game/systems/dungeon/tools/build_dungeon_scenes.gd`: สคริปต์ GDScript ประกอบ scene ห้องและดันเจี้ยน

### เทสต์:
- `game/tests/test_dungeon_room.gd`: ชุดทดสอบระบบดันเจี้ยนและห้อง

### เอกสารที่อัปเดต:
- `game/systems/dungeon/CLAUDE.md`
- `docs/GLOSSARY.md`

---

## 3. วิธีลองเล่น (Playtesting Instructions)

- **Scene ที่เปิดเล่น:**
  `res://systems/dungeon/debug/dungeon_sandbox.tscn`
- **ปุ่มควบคุม:**
  - `W`, `A`, `S`, `D` หรือปุ่มลูกศร: เดิน (Screen-space 8 ทิศทาง)
  - `J` / `Z` / คลิกซ้าย: โจมตีฟันดาบ (Attack)
  - `Space` / `K` / `Shift`: กลิ้งหลบ (Dodge — มี i-frames อมตะชั่วคราว, ใช้ Stamina 25)
  - `R`: รีเซ็ตดันเจี้ยนกลับห้องแรก
  - `1`, `2`, `3`: กระโดดข้ามไปยังห้อง 1, 2, 3 ทันที (Debug Jump)
  - `K`: ปลิดชีพศัตรูทั้งหมดในห้องปัจจุบันทันที (Debug Kill สำหรับทดสอบประตูเปิด)
- **ลำดับการทดสอบ Gameplay:**
  1. เริ่มที่ห้อง 1 (Room 1): ก้าวเดินเข้าไปในห้อง สังเกตสถานะเปลี่ยนเป็น `LOCKED` ประตูปิดขัง และสไลม์ 2 ตัว spawn ลงมา
  2. โจมตีสไลม์จนครบ 2 ตัว: เมื่อตายหมด ประตูห้องจะเปิดออก (`CLEARED`)
  3. เดินเข้าประตูทางออก (ExitDoor): ตัวละครจะถูกส่งไปยังห้อง 2 (Room 2) กล้องเลื่อนตาม
  4. ห้อง 2 สไลม์จะ spawn 4 ตัว: กำจัดครบ ประตูห้อง 2 เปิด
  5. เดินเข้าประตูไปยังห้อง 3 (Room 3): ห้องบอส (ไม่มีศัตรู) ห้องจะเคลียร์ทันที
  6. ทดสอบการตาย: หากโดนสไลม์โจมตีจน HP เหลือ 0 ระบบจะฟัง `EventBus.player_died` และรีเซ็ตผู้เล่นกลับห้อง 1

---

## 4. ผลการรันเทสต์ (Test Results)

รันคำสั่ง:
```bash
godot --headless --path game --script res://tests/run_tests.gd
```

**ผลลัพธ์:**
```text
tests: 53 passed, 0 failed
```
(เทสต์เดิม 46 รายการ + เทสต์ dungeon ใหม่ 7 รายการ ผ่านทั้งหมด 100%)

รายการเทสต์ใหม่ใน `test_dungeon_room.gd`:
1. `test_tileset_isometric_specs`: ตรวจสอบคุณสมบัติ isometric 64×32 diamond down, world physics layer, wall size_in_atlas 1×2 และ texture_origin (0, -16)
2. `test_door_collision_and_trigger_toggles`: ตรวจสอบการ toggle ของ Blocker และ ExitTrigger เมื่อเปิด/ปิดประตู
3. `test_enemy_died_counts_only_spawned_enemies`: ตรวจสอบการนับ `enemy_died` เฉพาะศัตรูของห้องนั้น ไม่นับศัตรูจากห้องอื่น
4. `test_doors_open_when_room_cleared`: ตรวจสอบว่าประตูเปิดเมื่อศัตรูถูกกำจัดครบ
5. `test_room_with_no_enemies_clears_immediately`: ตรวจสอบว่าห้องที่ไม่มีศัตรูจะเคลียร์และเปิดประตูทันที
6. `test_dungeon_room_sequence_and_order`: ตรวจสอบลำดับห้อง 1 (2 ตัว) -> 2 (4 ตัว) -> 3 (0 ตัว) และการเปลี่ยนห้องผ่านประตู
7. `test_player_died_resets_dungeon_to_room_one`: ตรวจสอบว่าเมื่อผู้เล่นตาย ดันเจี้ยนจะรีเซ็ตกลับห้องแรก

---

## 5. ข้อเสนอ Contract ข้ามระบบ (Contract Proposals)

ตามกติกาข้อ 3 และข้อ 20 ของ `TASK_WORKER.md`: **ห้ามแก้ไข `game/core/event_bus.gd` เอง** จึงขอเสนอ contract ใหม่เพื่อพิจารณาเพิ่มลงใน PR ถัดไป:

### ข้อเสนอ Contract `room` (dungeon ↔ UI/HUD/camera/audio)
เสนอเพิ่ม signals ต่อไปนี้ใน `game/core/event_bus.gd`:
```gdscript
# ── ดันเจี้ยนและห้อง · docs/contracts/room.md ──
## ระบบ dungeon (B) emit เมื่อผู้เล่นเข้าห้องและห้องเริ่มทำงาน (LOCKED)
signal room_started(room_id: StringName, room_index: int)

## ระบบ dungeon (B) emit เมื่อผู้เล่นกำจัดศัตรูครบและห้องปลดล็อก (CLEARED)
signal room_cleared(room_id: StringName, room_index: int)

## ระบบ dungeon (B) emit เมื่อผู้เล่นเดินผ่านประตูเปลี่ยนห้อง
signal room_transitioned(from_index: int, to_index: int)
```

**ประโยชน์ต่อระบบอื่น:**
- **UI / HUD (ระบบ A):** แสดงประกาศแบนเนอร์กลางจอ เช่น *"CHAMBER LOCKED"* และ *"ROOM CLEARED"*, แสดงแผนที่ย่อ (Minimap) ว่าอยู่ที่ห้องไหน
- **Camera (ระบบ A):** สั่ง camera shake เบาๆ ตอนประตูปิด/เปิด, clamp bounds ขอบเขตกล้องให้อยู่ภายในห้องที่กำลังเล่น
- **Audio / BGM:** สลับเพลงดนตรีต่อสู้ (Battle BGM) เมื่อ `room_started` และกลับเป็นเสียงบรรยากาศสงัด (Ambient BGM) เมื่อ `room_cleared`


---

## 6. แก้ตามรีวิว (issue #39)

### 1. รายละเอียดการแก้ไข
1. **[Critical] แก้ไขจุด spawn ศัตรู (`room.gd`):**
   - เปลี่ยนลำดับการทำงานใน `spawn_enemies()` โดยเรียก `enemy_container.add_child(enemy)` ก่อน แล้วจึงกำหนด `global_position = marker.global_position` เพื่อให้ตำแหน่งอิงตามลำดับชั้น transform ของห้องอย่างถูกต้อง แม้ห้องจะไม่ได้อยู่ที่ origin (0, 0)
   - เพิ่ม unit test `test_spawn_enemies_in_offset_room_matches_marker_position` ทดสอบการ spawn ในห้องที่วางไว้ตำแหน่ง (1400, 300) แล้วศัตรูเกิดตรงจุด marker ทุกตัว

2. **[High] ตายแล้วเล่นต่อได้ (`dungeon.gd`, `dungeon_sandbox.gd`):**
   - เพิ่มสัญญาณภายใน `signal run_reset_requested` ในคลาส `Dungeon` และ emit เมื่อดักจับ `EventBus.player_died`
   - ใน `dungeon_sandbox.gd` ต่อสัญญาณ `dungeon.run_reset_requested` เข้ากับ `get_tree().reload_current_scene.call_deferred()` ทำให้เมื่อผู้เล่นตาย ฉากจะรีโหลดใหม่ ผู้เล่นมี HP เต็ม และเริ่มเล่นรอบใหม่ได้ทันที
   - ใน `dungeon.gd` เมธอด `reset_dungeon()` สั่งทุกห้องรีเซ็ตกลับสู่สถานะ `IDLE` และล้างศัตรูทั้งหมด

3. **[High] แก้ไข `texture_origin` กำแพงกลับเครื่องหมาย (`build_tileset.gd`, `dungeon_tileset.tres`):**
   - แก้ไขค่า `texture_origin` ของบล็อกกำแพงและประตูเปิดขนาด 1×2 ใน `tools/build_tileset.gd` จาก `Vector2i(0, -16)` เป็น `Vector2i(0, 16)`
   - สั่งรันสร้าง `dungeon_tileset.tres` ใหม่ ทำให้ภาพฐานเพชรของกำแพงตรงกับแนว collision polygon ของ cell พอดี
   - ปรับแก้ assert ใน `test_dungeon_room.gd:20` ให้ล็อคค่า `Vector2i(0, 16)`
   - บันทึกกับดักนี้ลงใน `game/systems/dungeon/CLAUDE.md`

4. **[High] เปิด Y-Sort ให้สมบูรณ์ (`build_dungeon_scenes.gd`, `dungeon_sandbox.tscn`):**
   - เปิด `y_sort_enabled = true` ที่ root ของ `DungeonSandbox` (`dungeon_sandbox.tscn`)
   - เปิด `y_sort_enabled = true` ที่ root ของ `Dungeon` (`build_dungeon_scenes.gd` และ `dungeon.tscn`)
   - ตรวจสอบโหนดทุกระดับระหว่างผู้เล่น ศัตรู และกำแพง (`Room`, `EnemyContainer`, `WallLayer`, `Doors`, `ExitDoor`) ให้มี `y_sort_enabled = true` ครบถ้วน

5. **[Medium] แก้ไขประตูลูกซ้ำและขจัด RID leaks (`build_dungeon_scenes.gd`, `room.tscn`, `dungeon.tscn`):**
   - แก้ไข `_set_owner_recursive()` ไม่ตั้ง owner ให้กับลูกของโหนดที่เป็น external scene instance (`node.scene_file_path != ""`)
   - สั่งรัน `build_dungeon_scenes.gd` สร้าง `room.tscn` และ `dungeon.tscn` ใหม่ ทำให้ `ExitDoor` มีเฉพาะลูกจริงของตนเอง ไม่บันทึกซ้ำซ้อน
   - เพิ่ม unit test `test_door_has_exact_children_count_no_duplicates` ยืนยันว่า `Door` ทั้งแบบเดี่ยว ใน `room.tscn` และใน `dungeon.tscn` มีลูกตรงตามจำนวนจริง 3 โหนด (`Sprite2D`, `Blocker`, `ExitTrigger`)
   - ตรวจสอบผลการรันเทสต์ทั้งชุด พบว่า RID allocations leak (Body2D, Area2D, Shape2D, CanvasItem, ObjectDB) หายไปทั้งหมด 100%

6. **[Medium] ปรับปรุง Detector callback และตัด Enemy setup ซ้ำ (`room.gd`):**
   - ปรับ `_on_player_detector_body_entered` ให้เรียก `start_room.call_deferred()` ป้องกันปัญหา flushing queries ในช่วง physics callback
   - ลบการเรียก `enemy.setup()` ใน `spawn_enemies()` เนื่องจาก `_ready()` ของ `slime.gd` เรียก `setup()` อัตโนมัติอยู่แล้ว

7. **[Low] กล้อง, แสง, และปุ่ม Debug (`dungeon.gd`, `build_dungeon_scenes.gd`, `dungeon_sandbox.gd`, `dungeon_sandbox.tscn`):**
   - ปรับการตัดภาพกล้องใน `transition_to_room()` และ `reset_dungeon()` มาใช้ API ของ `GameCamera`: เรียก `camera.snap_to_target()` เมื่อมี target (player) และ `camera.set_camera_position()` เมื่อไม่มี target
   - ใช้ `CanvasModulate` เพียงตัวเดียวที่ระดับ `Dungeon` และนำออกจากแต่ละห้องย่อยใน `_build_room()`
   - แก้ไขปุ่ม debug `KEY_K` ให้สั่งทำดาเมจ 999 ผ่าน `Health.take_damage()` เท่านั้น โดยไม่ emit `EventBus.enemy_died` เอง ปล่อยให้ระบบ Health/Enemy emit ตามปกติ
   - แก้ไขข้อความใน `InfoLabel` ของ `dungeon_sandbox.tscn` เปลี่ยนจาก "หลบ: Space/K/Shift" เป็น "หลบ: Space/Shift" เพื่อไม่ให้ปุ่มซ้ำซ้อนกับปุ่ม K (ฆ่าศัตรู)

8. **[Hardening] ดักจับศัตรูถูก free โดยไม่ผ่าน signal (`room.gd`):**
   - ใน `register_enemy()` เชื่อมสัญญาณ `enemy.tree_exiting` เข้ากับ `_on_enemy_tree_exiting`
   - เมื่อศัตรูออกจาก tree โดยไม่ผ่าน `enemy_died` ระบบจะลบออกจาก `spawned_enemies` และตรวจสอบปลดล็อกห้องหากศัตรูหมด เพื่อป้องกันห้องค้างสถานะ `LOCKED`
   - เพิ่ม unit test `test_enemy_freed_without_signal_clears_from_waiting_list`

9. **[Tests] ลำดับห้องผ่าน door_entered และ player_died รีเซ็ตสถานะ IDLE (`test_dungeon_room.gd`):**
   - อัปเดต `test_dungeon_room_sequence_via_door_entered` จำลองการเดินเข้าประตูผ่านสัญญาณ `door_entered` จริง และทดสอบการเพิกเฉยสัญญาณจากห้องที่ไม่ใช่ห้องปัจจุบัน รวมถึงการ emit `dungeon_completed` เมื่อผ่านห้องสุดท้าย
   - อัปเดต `test_player_died_resets_dungeon_and_rooms_to_idle` ยืนยันว่าเมื่อผู้เล่นตาย ดันเจี้ยนกลับไปห้องแรก และทุกห้องกลับสู่สถานะ `IDLE` พร้อมล้างศัตรูทิ้งทั้งหมด

---

### 2. ผลการรันเทสต์ล่าสุด
```text
godot --headless --path game --script res://tests/run_tests.gd
tests: 81 passed, 0 failed
```
ไม่มี RID / ObjectDB leaks หลงเหลืออยู่ตอน exit

---

### 3. ข้อเสนอ Contract Respawn ผู้เล่น (`docs/contracts/respawn.md`)
ปัจจุบันเมื่อ `Player` เข้าสู่สถานะ `DEAD` ยังไม่มีฟังก์ชันฟื้นชีวิต ทำให้ต้อง reload scene ทั้งหมด เสนอให้เพิ่ม contract การฟื้นชีวิตผู้เล่นดังนี้:

```gdscript
# ── Player Respawn Contract ──
## EventBus signal ขอให้เกิดใหม่
signal player_respawn_requested(respawn_position: Vector2)

## EventBus signal เมื่อผู้เล่นเกิดใหม่เรียบร้อยแล้ว
signal player_respawned(player: Player)
```

**สิ่งที่เสนอให้เพิ่มใน `Player` (`game/systems/player/player.gd`):**
```gdscript
func respawn(spawn_pos: Vector2) -> void:
    global_position = spawn_pos
    velocity = Vector2.ZERO
    health.hp = max_hp
    stamina = stamina_max
    state = State.MOVE
    if hurtbox != null:
        hurtbox.set_deferred("monitorable", true)
        hurtbox.invulnerable = false
    set_physics_process(true)
    player_respawned.emit(self)
```
ประโยชน์: ดันเจี้ยนหรือ Game Manager สามารถสั่งฟื้นผู้เล่นกลับมาที่ห้อง 1 ได้ทันทีโดยไม่ต้องโหลดฉากใหม่ทั้งฉาก รักษา state อื่นๆ ของเกมไว้ได้

---

## ใช้ contract #52

- **ระบบ:** `dungeon`
- **Branch:** `kron/39-iso-dungeon`
- **อ้างอิง Contract:** [`docs/contracts/dungeon-flow.md`](docs/contracts/dungeon-flow.md) (PR #52)

### 1. รายละเอียดการปรับปรุงตาม Contract #52

1. **ห้องต่อกันจริงในโลก ไม่วาร์ป (Phase 2 Floor Plan):**
   - วางทั้ง 3 ห้อง (`Room1`, `Room2`, `Room3`) ต่อกันจริงในพิกัดโลก:
     - Room 1 อยู่ที่ `Vector2(0, 0)`
     - Room 2 อยู่ที่ `Vector2(416, 208)` (ต่อจากทางเดินทิศ +X ของห้อง 1)
     - Room 3 อยู่ที่ `Vector2(832, 416)` (ต่อจากทางเดินทิศ +X ของห้อง 2)
   - มีทางเดินสั้น 2 ช่อง (พื้นหิน + กำแพงขนาบสองข้าง) เชื่อมระหว่างทางออกของห้องก่อนหน้าสู่ทางเข้าของห้องถัดไป
   - ผู้เล่นเดินข้ามห้องเองตามธรรมชาติเมื่อประตูเปิด
   - ลบ `transition_to_room()` และ `teleport_player_to_room()` รวมถึงการเซ็ตตำแหน่งผู้เล่นออกจากคลาส `Dungeon` ทั้งหมดตามข้อกำหนด contract
   - ปรับตำแหน่งรูปทรง `PlayerDetector` ให้ตั้งอยู่ภายในห้องลึกพ้นประตู (`PackedVector2Array([Vector2(32, 64), Vector2(256, 176), Vector2(32, 288), Vector2(-160, 176)])`) เพื่อไม่ให้ห้องเริ่มทำงานตอนผู้เล่นยืนอยู่กลางประตู และประตูทางเข้าปิดข้างหลังเมื่อผู้เล่นก้าวเข้ามาเต็มตัวแล้ว (ไม่ปิดทับตัวผู้เล่น)

2. **EventBus Signals ตาม Contract (`room_started`, `room_cleared`):**
   - ใน `room.gd`:
     - เมื่อเรียก `start_room()`: คำนวณ `room_rect` เป็น Rect2 ขอบเขตพิกัดโลกจาก `floor_layer.get_used_rect()` และมุมเพชรทั้ง 4 แล้ว emit `EventBus.room_started.emit(self, room_rect)`
     - เมื่อเรียก `clear_room()`: emit `EventBus.room_cleared.emit(self)`
     - ห้องที่ไม่มีศัตรู (เช่น ห้อง 3 บอส): เมื่อเริ่มห้องจะ emit ทั้ง `EventBus.room_started` และเคลียร์ทันทีพร้อม emit `EventBus.room_cleared` ครบทั้งคู่ตามลำดับ

3. **ป้องกัน Fake `room_cleared` ตอน Teardown (`room.gd`):**
   - ใน `_on_enemy_tree_exiting()`: เพิ่มเงื่อนไขตรวจสอบ `if _is_teardown or is_queued_for_deletion() or (_was_in_tree and not is_inside_tree()): return`
   - ใน `_exit_tree()` และ `_notification(NOTIFICATION_PREDELETE)`: ตั้งค่า `_is_teardown = true` และตัดการเชื่อมต่อ `tree_exiting` ของศัตรูทั้งหมด (`_disconnect_enemies()`)
   - ป้องกันไม่ให้การ free ห้องที่ติดสถานะ `LOCKED` ยิงสัญญาณ `room_cleared` ปลอมออกไปอย่างเด็ดขาด

4. **ระบบตายแล้วฟื้น (Player Respawn Flow):**
   - `Dungeon` ดักฟัง `EventBus.player_died`
   - ทำงานแบบ deferred ผ่าน Timer `@export var respawn_delay: float = 1.2` เพื่อรอให้แอนิเมชันท่าตายของผู้เล่นเล่นจนจบ
   - เมื่อ Timer ครบกำหนด:
     1. เรียก `reset_room()` ทุกห้อง (กลับสู่สถานะ `IDLE` และล้างศัตรูตกค้างทั้งหมด)
     2. emit `EventBus.player_respawn_requested.emit(rooms[0].player_spawn_point.global_position)` เพื่อให้ระบบผู้เล่นจัดการฟื้นตัวเอง (`Player.revive()`)
     3. ลบ `run_reset_requested` และการ reload scene ออก
     4. รอ 1 physics frame (`await get_tree().physics_frame`) เพื่อให้ physics engine อัปเดตตำแหน่ง จากนั้นเรียก `check_player_inside()` ตรวจสอบผู้เล่นที่ยืนอยู่ใน detector และเริ่มห้อง 1 ใหม่อัตโนมัติ

5. **เลิกเรียกกล้องตรง ๆ:**
   - ลบ `@export var camera: GameCamera = null` ออกจากคลาส `Dungeon`
   - ลบการเรียก `camera.snap_to_target()` และ `camera.set_camera_position()` ออกจาก `Dungeon` ทั้งหมด
   - ใน `dungeon_sandbox.gd`: ผูกสัญญาณ `EventBus.room_started` แล้วเรียก API สาธารณะ `camera.set_bounds(room_rect)` เพื่อเลื่อนขอบเขตกล้องตามห้องที่เริ่มทำงาน

6. **ชุดทดสอบครอบคลุม Contract ทั้งหมด (`test_dungeon_room.gd`):**
   - ทดสอบ `EventBus.room_started` และ `room_cleared` พร้อมตรวจสอบความถูกต้องของ `room_rect`
   - ทดสอบห้องไม่มีศัตรู emit ทั้งสองสัญญาณตามลำดับ
   - ทดสอบการ free ห้องที่ LOCKED ไม่เกิด fake `room_cleared`
   - ทดสอบการตาย รอ delay 1.2s แล้ว reset ทุกห้องและส่ง `player_respawn_requested` ด้วยพิกัดจุดเกิด
   - ทดสอบการตรวจจับผู้เล่นหลัง respawn เข้า detector และเริ่มห้อง
   - ทดสอบลำดับการเดินผ่านประตูจริง (`Door.entered` -> `Room._on_door_entered` -> `Dungeon._on_room_door_entered` -> `dungeon_completed`) โดยไม่ emit ภายในตรงๆ
   - ทดสอบตำแหน่งของทั้ง 3 ห้องว่าต่อกันจริงในโลกและมีประตูทางเข้า/ออกถูกต้อง
   - ทดสอบ Contract v1.1: เมื่อผู้เล่นเดินเข้าห้องที่เคลียร์แล้ว (`State.CLEARED`) จะ emit `EventBus.room_started` และ `EventBus.room_cleared` ทันทีโดยไม่ปิดประตู

### 2. ผลการรันเทสต์ทั้งหมด
```bash
godot --headless --path game --script res://tests/run_tests.gd
```
**ผลลัพธ์:**
```text
tests: 128 passed, 0 failed
```
ผ่านทั้งหมด 100% ทุกชุดทดสอบ ไม่มี RID allocations leak และไม่มี ObjectDB leak
