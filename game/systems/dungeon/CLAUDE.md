# ระบบ: dungeon

- เจ้าของ: @kronkawin2549-create (Few) · contract ที่เกี่ยว: [`docs/contracts/dungeon-flow.md`](../../docs/contracts/dungeon-flow.md)

## ทำอะไร
- ผู้เล่น: เดินผ่านห้องในดันเจี้ยนมุมมอง isometric (64×32) ห้อง 3 ห้องต่อกันจริงในโลก มีทางเดินสั้นเชื่อม ห้องปิดขังเมื่อศัตรูเกิด ประตูเปิดเมื่อกำจัดศัตรูหมด ผู้เล่นเดินข้ามห้องเองเมื่อประตูเปิด
- โค้ด: จัดการระบบห้อง (`Room`), ระบบดันเจี้ยน (`Dungeon`), ประตู (`Door`), และฉาก sandbox (`DungeonSandbox`)

## ไฟล์สำคัญ
| ไฟล์ | หน้าที่ |
|---|---|
| `dungeon.gd` / `dungeon.tscn` | `Dungeon`: คุมลำดับ 3 ห้องต่อกันจริงในโลก, ดัก `EventBus.player_died` รอ delay ~1.2s แล้วรีเซ็ตห้องพร้อมส่ง `EventBus.player_respawn_requested` |
| `room/room.gd` / `room/room.tscn` | `Room`: คุมสถานะ IDLE -> LOCKED -> CLEARED, spawn สไลม์, นับ `EventBus.enemy_died` เฉพาะตัวของห้อง, คุมประตูและแสง, emit `EventBus.room_started`/`room_cleared` |
| `room/door.gd` / `room/door.tscn` | `Door`: ประตูทางเข้า/ออก ปิดกั้นด้วย Blocker (`Combat.LAYER_WORLD`) เมื่อ locked, เปิดทางและเปิด `ExitTrigger` (`Combat.LAYER_PLAYER`) เมื่อ cleared |
| `dungeon_tileset.tres` | TileSet isometric 64×32 (`TILE_SHAPE_ISOMETRIC`, `TILE_LAYOUT_DIAMOND_DOWN`, physics layer `world`) |
| `art/iso_tiles.png` | Spritesheet พื้นหินลานวัดญี่ปุ่น, รอยร้าวทองคินสึงิ, กำแพงบล็อกสูง 32px, ประตูเปิด/ปิด, โคมหิน |
| `tools/gen_iso_tiles.py` | สคริปต์ Python+PIL วาด `iso_tiles.png` |
| `tools/build_tileset.gd` | สคริปต์ GDScript สร้าง `dungeon_tileset.tres` |
| `tools/build_dungeon_scenes.gd` | สคริปต์ GDScript ประกอบและบันทึก `room.tscn` และ `dungeon.tscn` (เชื่อม 3 ห้องต่อเนื่องพร้อมทางเดิน) |
| `debug/dungeon_sandbox.gd` / `.tscn` | ฉากทดสอบลองเล่น (instance Player + GameCamera + Dungeon + HUD) ต่อกล้องผ่าน `EventBus.room_started` |

## ส่ง / รับ ข้ามระบบ (contract: `docs/contracts/dungeon-flow.md`)
- emit: `EventBus.room_started(room: Node, room_rect: Rect2)` — dungeon emit เมื่อผู้เล่นเข้าห้อง ประตูปิด เริ่มสู้ ส่ง bounding box พิกัดโลกให้กล้องตั้ง bounds
- emit: `EventBus.room_cleared(room: Node)` — dungeon emit เมื่อศัตรูในห้องหมด ประตูเปิด (ห้องที่ไม่มีศัตรูเริ่มแล้ว clear ทันที emit ทั้งคู่)
- emit: `EventBus.player_respawn_requested(position: Vector2)` — dungeon emit หลัง `player_died` + delay ~1.2s + รีเซ็ตห้องเสร็จแล้ว ส่งพิกัด spawn point ห้องแรกให้ Player `revive()`
- listen: `EventBus.enemy_died(enemy, enemy_id, position)` — นับจำนวนศัตรูที่ห้องนี้ spawn ไว้ เพื่อปลดล็อกห้องเมื่อครบ
- listen: `EventBus.player_died` — เริ่มจับเวลา Timer `@export respawn_delay` (~1.2s) ให้ท่าตายเล่นจบ แล้วรีเซ็ตห้องและขอ respawn

## กติกาเฉพาะระบบ / กับดักที่เคยเจอ
- ห้องต่อกันจริง ไม่วาร์ป: วาง 3 ห้องติดกันในโลก มีทางเดินสั้นเชื่อม ผู้เล่นเดินข้ามเองเมื่อประตูเปิด ไม่ใช้การเทเลพอร์ตผู้เล่นระหว่างเล่น
- ไม่เรียกกล้องตรง ๆ: ลบ `camera` export ออกจาก Dungeon — กล้องฟัง `EventBus.room_started` เอง (ใน Sandbox ให้ Sandbox ฟังแล้วเรียก `camera.set_bounds(room_rect)`)
- Detector พ้นประตู: Detector ต้องอยู่ข้างในห้องพ้นประตู เพื่อไม่ให้ห้องเริ่มทำงานตอนผู้เล่นยืนกลางประตู และประตูปิดข้างหลังผู้เล่นโดยไม่ปิดทับ
- ห้องที่ไม่มีศัตรู: เมื่อเริ่มห้อง ต้อง emit ทั้ง `EventBus.room_started` และ `EventBus.room_cleared` ทันที
- Teardown Guard: ใน `room.gd` ต้อง disconnect `tree_exiting` ของศัตรูใน `_exit_tree()` และ `NOTIFICATION_PREDELETE` พร้อมตรวจสอบ `is_queued_for_deletion()` เพื่อป้องกันการ emit `room_cleared` ปลอมตอน free ห้องที่ LOCKED
- ตายแล้วฟื้น (Respawn): ห้ามย้ายผู้เล่นเองหรือ reload ฉาก — ฟัง `player_died` -> รอ delay 1.2s -> รีเซ็ตทุกห้อง -> emit `player_respawn_requested(spawn_pos)` -> ตรวจ `check_player_inside()` บน physics frame ถัดไปเพื่อเริ่มห้อง 1
- มุมมอง isometric: ใช้ TileSet `TILE_SHAPE_ISOMETRIC` + `TILE_LAYOUT_DIAMOND_DOWN` tile 64×32
- บล็อกกำแพงสูง 32 px ใช้ `size_in_atlas = Vector2i(1, 2)` (64×64 px) และต้องตั้ง `texture_origin = Vector2i(0, 16)` เพื่อให้ฐานเพชรของกำแพงตรงกับ collision polygon ของ cell พอดี
- การสร้าง scene ซ้อน (`tools/build_dungeon_scenes.gd`): ห้ามตั้ง owner ให้ลูกของ node ที่มาจาก scene อื่น (`node.scene_file_path != ""`) เพื่อไม่ให้เกิด RID leak
- Y-Sort: เปิด `y_sort_enabled = true` ที่ root ของ Sandbox, Dungeon, Room, EnemyContainer, Doors, WallLayer

## เทสต์
- `game/tests/test_dungeon_room.gd`
