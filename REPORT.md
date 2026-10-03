# รายงานผลการทำงาน: เฟส 2 กล้อง iso + silhouette (Issue #41)

## 1. สิ่งที่ทำ
- **กล้อง (`GameCamera` ใน `game/systems/camera/game_camera.gd`)**:
  - เพิ่มฟังก์ชัน `slide_to(rect: Rect2, duration: float)`: เลื่อนกล้องไปยังห้องใหม่อย่างนุ่มนวลด้วยการคำนวณ smoothstep interpolation โดยระหว่างเลื่อนกล้องจะไม่ follow ผู้เล่นและไม่โดน bounds เก่าตัดขอบ เมื่อเลื่อนเสร็จสิ้นจึงเรียก `set_bounds(rect)` และ emit `slide_completed`
  - เพิ่มฟังก์ชัน `set_focus_target(node: Node2D)`: จัดเฟรมกล้องแบบ lock-on framing โดยคำนวณจุดโฟกัสระหว่างผู้เล่นกับเป้าหมายตามน้ำหนัก `@export focus_weight` (~0.35) และจำกัดระยะห่างไม่เกิน `@export max_focus_offset` (64.0 px) หากส่ง `null` หรือเป้าหมายถูกทำลาย กล้องจะกลับไปติดตามผู้เล่นตามเดิม
  - ตำแหน่งสุดท้ายของกล้อง round เป็นพิกเซลจำนวนเต็มเสมอเพื่อคงความคมชัดของ pixel art
  - แยก Static Functions สำหรับคำนวณ (`compute_slide_position`, `compute_focus_offset`, `compute_focus_point`) ให้รัน unit test ได้แบบ deterministic โดยไม่ต้องพึ่ง SceneTree
  - คงความเข้ากันได้ 100% กับฟังก์ชันเดิม (trauma shake, hitstop, clamp bounds) และเทสต์เดิมผ่านครบทั้งหมด
- **Silhouette (`game/systems/player/occlusion/occlusion_silhouette.gd` + `occlusion_silhouette.gdshader`)**:
  - พัฒนาโหนด `OcclusionSilhouette` เป็นโหนดลูกสำหรับติดใต้ตัวละคร ชี้ไปยัง `CanvasItem` สไปรต์ของตัวนั้น (`@export sprite_path`)
  - ตรวจจับวัตถุบังด้วย `Area2D` (physics layer 1: world): เมื่อมีวัตถุอยู่ "ข้างหน้า" ในแกน isometric depth (ฐานหรือเท้าวัตถุมี Y มากกว่าเท้าตัวละคร) และทับพื้นที่สไปรต์ตัวละคร จะแสดงสำเนาสไปรต์เป็นสีเดียวม่วงอ่อน (`@export color` ~ `#c8b8ff` alpha 0.55) ด้วย `z_index = 10` ซึ่งสูงกว่ากำแพงและบล็อก
  - เมื่อไม่ถูกบัง (`is_occluding == false`) จะซ่อน silhouette อัตโนมัติ
  - ซิงก์ texture, animation frame, และ `flip_h`/`flip_v` ตามสไปรต์เป้าหมาย ทั้ง `Sprite2D` และ `AnimatedSprite2D`
  - แยก Static Functions (`is_occluding`, `is_in_front`) สำหรับเทสต์ตรรกะข้างหน้า vs ข้างหลัง
- **Isometric Sandbox (`game/systems/camera/debug/iso_camera_sandbox.tscn`)**:
  - สร้างฉากทดสอบประกอบด้วยพื้น isometric 64×32 diamond tiles, บล็อกทรงสูงหลายก้อน (`IsoTallBlock`) ที่มี collision ฐานและ occlusion volume
  - ตัวละครกล่องที่เดินได้แบบ screen-space (ลูกศร / WASD) พร้อมโหนด `OcclusionSilhouette`
  - รองรับการทดสอบเลื่อนกล้องข้ามห้อง (ปุ่ม 1/2) และ Lock-on Focus ไปยัง Dummy (ปุ่ม L)
- **Unit Tests (`game/tests/test_camera_iso.gd`)**:
  - เทสต์การทำงานของ `slide_to` จบที่ rect ถูกต้องและ round เป็นจำนวนเต็มพิกเซล
  - เทสต์การคำนวณ smoothstep slide interpolation
  - เทสต์การ clamp ระยะห่างของ focus offset และการ framing กลับมาเมื่อเลิก focus
  - เทสต์การตัดสินบัง/ไม่บัง (ข้างหน้า `y > feet_y` vs ข้างหลัง `y <= feet_y`)
  - เทสต์การซิงก์ frame และ flip ของทั้ง Sprite2D และ AnimatedSprite2D

## 2. รายการไฟล์ที่สร้างและแก้ไข
### ไฟล์ที่สร้างใหม่:
- `game/systems/player/occlusion/occlusion_silhouette.gd`: โหนดจัดการ silhouette เมื่อตัวละครถูกวัตถุบัง
- `game/systems/player/occlusion/occlusion_silhouette.gdshader`: CanvasItem shader วาดสีม่วงอ่อนคงค่า alpha ของสไปรต์
- `game/systems/camera/debug/iso_camera_sandbox.tscn`: Scene ทดสอบกล้อง iso และ silhouette
- `game/systems/camera/debug/iso_camera_sandbox.gd`: สคริปต์ควบคุม sandbox และรับ input
- `game/systems/camera/debug/iso_tall_block.gd`: บล็อกทรงสูง 2.5D isometric สำหรับ sandbox
- `game/tests/test_camera_iso.gd`: Unit test สำหรับกล้อง iso และ silhouette

### ไฟล์ที่แก้ไข:
- `game/systems/camera/game_camera.gd`: เพิ่ม `slide_to`, `set_focus_target`, signal `slide_completed`, static math functions
- `game/systems/camera/CLAUDE.md`: อัปเดตรายการไฟล์สำคัญ, กติกาเฉพาะระบบ, กับดัก และรายชื่อไฟล์เทสต์
- `docs/GLOSSARY.md`: เพิ่มคำศัพท์ `GameCamera.slide_to` (เลื่อนกล้องข้ามห้อง), `GameCamera.set_focus_target` (จัดเฟรม lock-on), และ `OcclusionSilhouette` (ซิลูเอตเมื่อถูกบัง)

## 3. วิธีลองเล่น
- **Scene**: `res://systems/camera/debug/iso_camera_sandbox.tscn` (เปิดใน Godot แล้วกด F6 หรือรันคำสั่ง `godot --path game res://systems/camera/debug/iso_camera_sandbox.tscn`)
- **ปุ่มควบคุม**:
  - `ลูกศร` หรือ `W, A, S, D`: บังคับตัวละครกล่องสีฟ้าเดินในระนาบ isometric (screen-space)
  - **ทดสอบ Silhouette**: เดินตัวละครไปด้านหลังบล็อกทรงสูง จะเห็น Silhouette สีม่วงอ่อนโปร่งใสปรากฏขึ้นวาดทับบล็อกทันที และเมื่อเดินออกมาด้านหน้าบล็อก Silhouette จะหายไป
  - `1`: สั่งให้กล้องเลื่อนสไลด์อย่างนุ่มนวลไปยัง Room 1 (`Rect2(0, 0, 960, 540)`)
  - `2`: สั่งให้กล้องเลื่อนสไลด์อย่างนุ่มนวลไปยัง Room 2 (`Rect2(960, 0, 960, 540)`)
  - `L`: สลับเปิด/ปิด Lock-on Focus ไปยัง Dummy (กล้องจะจัดเฟรมกึ่งกลางระหว่างตัวละครกับ Dummy ภายในระยะไม่เกิน 64 px)
  - `Space`: ทดสอบกล้องสั่น (Trauma Shake)
  - `H`: ทดสอบ Hitstop (หยุดเวลาชั่วคราว)

## 4. ผลการรันเทสต์
คำสั่ง:
```bash
godot --headless --path game --script res://tests/run_tests.gd
```
ผลลัพธ์:
```
tests: 53 passed, 0 failed
```
(เทสต์เดิม 46 ข้อ + เทสต์ระบบกล้อง iso/silhouette ใหม่ 7 ข้อ ผ่านทั้งหมด 100%)

## 5. ค้าง / ข้อเสนอแนะเรื่อง Contract ข้ามระบบ
- **ข้อเสนอแนะ**: ในอนาคตเมื่อระบบ World หรือ Dungeon มีการเปลี่ยนผ่านห้อง (Room Transitions) อาจพิจารณาเพิ่ม signal ลงใน `EventBus` เช่น:
  `signal room_transition_requested(room_rect: Rect2, slide_duration: float)`
  เพื่อให้ระบบ Dungeon สามารถส่งสัญญาณบอกกล้องให้เปลี่ยนห้องได้โดยไม่ต้องเรียกใช้หรือถือ instance ของ `GameCamera` โดยตรง

---

## 6. แก้ตามรีวิว (Issue #41)

### สรุปการแก้ไขตามข้อเสนอแนะจาก Code Review:
1. **[สูง] แก้ไขบั๊ก Slide ไม่เกิดบนจอ (`game_camera.gd`)**:
   - ปัญหาเดิม: `limit_left/right/top/bottom` ของ Camera2D ยังถูกจำกัดอยู่ที่กรอบห้องเดิม ทำให้เมื่อ `position` เลื่อน หน้าจอกลับถูก viewport limits ล็อกไว้จนกระทั่งจบ slide จึงวาร์ปกระโดดข้ามห้อง
   - การแก้ไข: เมื่อเริ่ม `slide_to(rect, duration)` จะคำนวณ `union_rect = bounds.merge(rect)` และปรับขยาย limit ทั้ง 4 ด้านเป็น union ชั่วคราว เมื่อเลื่อนถึงปลายทางจึงเรียก `set_bounds(rect)` เพื่อตั้ง limit ให้เท่ากับห้องใหม่อย่างพอดี
   - ปรับ `_slide_start_pos` ให้ดึงจาก `get_screen_center_position()` เมื่อกล้องอยู่ใน tree เพื่ออิงตำแหน่งจริงของหน้าจอกล้องก่อนเริ่ม slide
   - เพิ่มเทสต์ `test_slide_in_tree_screen_center_smooth_without_jump` ใน `test_camera_iso.gd` โดยจำลองการเพิ่มกล้องเข้า `Engine.get_main_loop().root` ตรวจสอบว่า `get_screen_center_position()` ค่อย ๆ เปลี่ยนแปลงอย่างต่อเนื่องจากจุดกึ่งกลางห้อง 1 สู่ห้อง 2 โดยไม่กระโดดข้าม และลบโหนดกล้องทิ้งท้ายเทสต์

2. **Silhouette โหมดจริงใช้ Logic เดียวกับเทสต์ & รองรับ TileMapLayer (`occlusion_silhouette.gd`)**:
   - โหมด Area2D จริงเชื่อมโยงเรียก `is_occluding(feet_y, occ_y, spr_rect, occ_rect)` โดยใช้ world sprite rect จาก `get_sprite_world_rect()`
   - รองรับ `TileMapLayer` โดยดักฟิสิกส์ผ่าน `body_shape_entered` / `body_shape_exited` ใช้ `get_coords_for_body_rid()` และ `map_to_local()` หาพิกัดและแกน Y ของแต่ละ tile
   - รองรับ occluder ทั่วไปผ่านชื่อโหนดขึ้นต้นด้วย `OcclusionArea` หรือกำหนด metadata `occluder_y` / `occluder_rect`
   - เพิ่ม Static Helper Functions: `get_tile_world_rect()`, `get_tile_occluder_y()`, `get_occluder_rect()`, `get_occluder_y()` พร้อม unit test ครบถ้วน
   - บันทึก Occlusion Contract ลงใน `game/systems/camera/CLAUDE.md`

3. **Silhouette Global Transform & Scale Flip (`occlusion_silhouette.gd`)**:
   - ซิงก์ตำแหน่งและการหมุน/สเกลด้วย `global_transform = target_sprite.global_transform` เพื่อรองรับกรณีสไปรต์ตัวละครอยู่ในโครงสร้าง Node2D ซับซ้อน หรือมีการทำ scale flip ใน parent node
   - เพิ่มเทสต์ `test_silhouette_global_transform_and_scale_flip` ทดสอบ parent scale -2.0x และ rotation

4. **_process & Visibility Sync (`occlusion_silhouette.gd`)**:
   - อัปเดตการซิงก์ในรอบ `_process(delta)`
   - ตรวจสอบ `target_sprite.is_visible_in_tree()` หากสไปรต์ตัวละครหรือ parent ใน tree ถูกซ่อน (`visible = false`) ตัว silhouette จะถูกซ่อนตามทันที
   - เพิ่มเทสต์ `test_silhouette_hides_when_target_sprite_invisible_in_tree`

5. **ปรับปรุงและเพิ่ม Unit Tests ใน `test_camera_iso.gd`**:
   - แก้ไขบรรทัดที่ 9 ใน `test_camera_iso.gd` ให้ใช้ `cam.set_camera_position(Vector2(480.2, 270.8))` เพื่อตั้งค่า `_internal_pos` ให้ถูกต้องจริง
   - เพิ่มเทสต์ `test_camera_does_not_follow_during_slide`: ระหว่างที่กล้องกำลัง slide แม้เป้าหมายผู้เล่นจะเคลื่อนที่กระโดดไปที่อื่น กล้องจะไม่ติดตามจนกว่าจะ slide จบ
   - เพิ่มเทสต์ `test_focus_target_freed_midway`: กรณีโหนด `focus_target` ถูก free กลางคัน กล้องจะไม่ crash และสามารถ fallback กลับมาติดตามผู้เล่นได้อย่างถูกต้อง
   - เพิ่มเทสต์ `test_slide_instant_zero_duration`: กรณี slide_to โดยระบุ duration = 0.0

6. **ปรับปรุง Sandbox เป็น TileMapLayer Isometric แท้จริง (`iso_camera_sandbox.gd`, `.tscn`)**:
   - ปรับโค้ด `iso_camera_sandbox.gd` ให้สร้าง TileSet แบบ `TILE_SHAPE_ISOMETRIC` + `TILE_LAYOUT_DIAMOND_DOWN` ขนาด 64×32 ตามรูปแบบมาตรฐานของโปรเจกต์ (`iso_courtyard.gd`)
   - สร้างเลเยอร์ `FloorLayer` และ `WallsLayer` (TileMapLayer) พร้อม diamond collision polygon จริง เพื่อพิสูจน์การทำงานของ TileMapLayer occlusion
   - บันทึกใน `game/systems/camera/CLAUDE.md`: "slide ช้าลงตาม hitstop (ตั้งใจ)"

### ผลการทดสอบล่าสุด:
- คำสั่ง: `godot --headless --path game --script res://tests/run_tests.gd`
- ผลลัพธ์: **59 passed, 0 failed** (ผ่าน 100% ครบทุก suite ในโปรเจกต์)

---

## 7. แก้รอบ 2 (Issue #41)

### รายละเอียดการแก้ไข:
1. **Merge origin/main & จัดการ Conflict ใน `docs/GLOSSARY.md`**:
   - Merge `origin/main` เพื่อดึง Contract feedback (#52 — `docs/contracts/feedback.md`) และอัปเดตระบบต่อสู้/ตัวเอก Kintsugi 8 ทิศ
   - แก้ไข Merge Conflict ใน `docs/GLOSSARY.md` โดยเก็บแถวครบถ้วนจากทั้งสองฝั่ง

2. **Silhouette กับ TileMapLayer: เลิกพึ่ง Physics หันมาใช้การคำนวณเชิงเรขาคณิต**:
   - ปัญหาเดิมของฟิสิกส์: `Area2D` ที่ตั้ง `monitorable=false` มองไม่เห็น `StaticBody2D`, `get_coords_for_body_rid` คืนพิกัด quadrant, และ collision shape ของบล็อกมีเฉพาะที่ฐานเพชรไม่ครอบความสูง
   - การแก้ไขใหม่:
     - เพิ่ม `@export var occluder_layers: Array[NodePath]` (และ `direct_occluder_layers: Array[TileMapLayer]`) สำหรับระบุเลเยอร์ TileMapLayer ที่เป็นวัตถุสูง (เช่น กำแพง/เสา)
     - ในรอบประมวลผล แปลงขอบเขตสไปรต์ตัวละครใน world coordinate เป็นช่วงพิกัด cell ด้วย `local_to_map` ของมุมทั้ง 4 และขยายช่วง cell ลงด้านล่าง (+2 แถว) เพื่อตรวจจับ tile ทรงสูงที่ฐานอยู่ต่ำกว่าแต่ตัวกราฟิกยื่นสูงขึ้นมาทับตัวละคร
     - สำหรับแต่ละ cell: คำนวณ bounding box ของ tile ในโลกจาก `map_to_local(cell)` ร่วมกับ `texture_origin` และขนาดภาพจาก `TileSetAtlasSource.texture_region_size × size_in_atlas` (ผ่าน `get_tile_size_in_atlas(atlas_coords)`)
     - กำหนด `occluder_y` เป็น Y ฐานของ cell (`map_to_local(cell).y`) และตัดสินการบังด้วย `is_occluding(feet_y, occ_y, spr_rect, tile_rect)` เดิม
     - เพิ่ม static helper function: `is_tile_layer_occluding(layer, feet_y, spr_rect)` และ `get_node_effective_global_transform(node)` เพื่อให้การคำนวณ transform ถูกต้องสมบูรณ์ทั้งใน SceneTree และนอก tree สำหรับ unit test
     - คง `Area2D` และการตรวจจับวัตถุอื่นบน layer world ไว้ตามเดิม พร้อมปรับปรุงเอกสารให้ตรงกับโค้ดจริง (นับทุก Area2D บน layer world)

3. **ลบโค้ด TileMap ผ่าน Physics เดิมออกทั้งหมด**:
   - ลบตัวแปร `_overlapping_tiles`
   - ลบฟังก์ชัน `_on_body_shape_entered` และ `_on_body_shape_exited`
   - เลิกเชื่อมต่อ signal `body_shape_entered` / `body_shape_exited` ใน `_setup_detection_area`
   - ลบการเรียก `atlas.get_tile_texture_region_size()` ที่ไม่มีอยู่ใน ClassDB

4. **เพิ่ม Unit Test ทดสอบ TileMapLayer จริง (`test_camera_iso.gd`)**:
   - เพิ่ม `test_occlusion_real_tilemap_layer_diamond_down`: สร้าง TileSet ISOMETRIC DIAMOND_DOWN 64×32 ร่วมกับ texture จาก `res://systems/player/debug/iso/iso_tiles.png` tile (3, 0) ขนาด size_in_atlas (1, 2) และ texture_origin (0, 16)
   - ตรวจสอบครบทั้ง 3 เงื่อนไข:
     1. เท้าอยู่หลังกำแพง (`y < occluder_y`) และสไปรต์ทับภาพ → บัง (`silhouette_sprite.visible == true`)
     2. เท้าอยู่หน้ากำแพง (`y > occluder_y`) → ไม่บัง (`silhouette_sprite.visible == false`)
     3. ไกลกำแพงในแนวนอน → ไม่บัง (`silhouette_sprite.visible == false`)

5. **ปรับปรุง Sandbox: พื้นครบถ้วนทั้งสองห้อง และวางกำแพงในห้องจริง (`iso_camera_sandbox.gd`)**:
   - คำนวณช่วง cell พื้นจาก rect รวมของ Room 1 และ Room 2 ด้วย `local_to_map` ทำให้ Room 2 มีพื้นเต็มจอครบทุกจุด
   - วางกำแพงด้วยพิกัดตำแหน่งจริงใน Room 1 และ Room 2 ที่แปลงเป็น cell ผ่าน `local_to_map` (ตรวจสอบว่า `map_to_local` อยู่ในขอบเขตห้องจริง)
   - ผูก `silhouette.occluder_layers` เข้ากับ `WallsLayer`
   - รองรับอาร์กิวเมนต์ `--room2` เพื่อสลับไปห้อง 2 ได้โดยตรง
   - ถ่ายภาพยืนยันการแสดงผลทั้ง Room 1 (`shot_room1.png`) และ Room 2 (`shot_room2.png`) เรียบร้อย และลบไฟล์ภาพชั่วคราวออก

6. **Contract Feedback: GameCamera สั่นตาม `EventBus.screen_shake_requested` (`game_camera.gd`)**:
   - เชื่อมต่อสัญญาณ `EventBus.screen_shake_requested(strength, position)` ใน `_enter_tree()` (และ `setup()`)
   - ตัดสัญญาณใน `_exit_tree()` (และ `_notification(NOTIFICATION_PREDELETE)`)
   - เมื่อได้รับสัญญาณ จะเรียก `add_trauma(clampf(strength, 0.0, 1.0))`
   - เพิ่ม unit test `test_camera_screen_shake_requested` ใน `test_camera_iso.gd` ทดสอบการรับแรงสั่น, การ clamp ค่าไม่เกิน 1.0, การ clamp ค่าติดลบ, และการ disconnect เมื่อหลุดจาก tree

7. **อัปเดตเอกสารคู่มือระบบ (`CLAUDE.md`)**:
   - เพิ่ม Contract feedback (`docs/contracts/feedback.md` v1)
   - บันทึกการฟัง signal `EventBus.screen_shake_requested`
   - อัปเดตรายละเอียด OcclusionSilhouette กฎเรขาคณิต TileMapLayer แบบไม่พึ่งพา physics

### ผลการรันเทสต์ทั้งหมด:
- คำสั่ง: `godot --headless --path game --script res://tests/run_tests.gd`
- ผลลัพธ์: **127 passed, 0 failed** (ผ่านครบทุก suite 100%)


