# ระบบ: dungeon

- เจ้าของ: @kronkawin2549-create (Few) · contract ที่เกี่ยว: _รอ contract_ (ห้องเริ่ม/เคลียร์)

## ทำอะไร
- ผู้เล่น: เดินผ่านห้องในดันเจี้ยนมุมมอง isometric (64×32) ห้องปิดขังเมื่อศัตรูเกิด เปิดประตูเมื่อกำจัดศัตรูหมด มีห้องบอส
- โค้ด: จัดการระบบห้อง (`Room`), ระบบดันเจี้ยน (`Dungeon`), ประตู (`Door`), และฉาก sandbox (`DungeonSandbox`)

## ไฟล์สำคัญ
| ไฟล์ | หน้าที่ |
|---|---|
| `dungeon.gd` / `dungeon.tscn` | `Dungeon`: คุมลำดับห้อง 3 ห้อง (ห้อง 1 -> ห้อง 2 -> ห้อง 3 บอส), ย้ายผู้เล่นผ่านประตู, ดัก `EventBus.player_died` รีเซ็ตกลับห้องแรก |
| `room/room.gd` / `room/room.tscn` | `Room`: คุมสถานะ IDLE -> LOCKED -> CLEARED, spawn สไลม์, นับ `EventBus.enemy_died` เฉพาะตัวของห้อง, คุมประตูและแสง |
| `room/door.gd` / `room/door.tscn` | `Door`: ประตูทางออก ปิดกั้นด้วย Blocker (physics layer `world`) เมื่อ locked, เปิดทางและเปิด `ExitTrigger` (Area2D layer `player`) เมื่อ cleared |
| `dungeon_tileset.tres` | TileSet isometric 64×32 (`TILE_SHAPE_ISOMETRIC`, `TILE_LAYOUT_DIAMOND_DOWN`, physics layer `world`) |
| `art/iso_tiles.png` | Spritesheet พื้นหินลานวัดญี่ปุ่น, รอยร้าวทองคินสึงิ, กำแพงบล็อกสูง 32px, ประตูเปิด/ปิด, โคมหิน |
| `tools/gen_iso_tiles.py` | สคริปต์ Python+PIL วาด `iso_tiles.png` |
| `tools/build_tileset.gd` | สคริปต์ GDScript สร้าง `dungeon_tileset.tres` |
| `tools/build_dungeon_scenes.gd` | สคริปต์ GDScript ประกอบและบันทึก `room.tscn` และ `dungeon.tscn` |
| `debug/dungeon_sandbox.gd` / `.tscn` | ฉากทดสอบลองเล่น (instance Player + GameCamera + Dungeon + HUD) |

## ส่ง / รับ ข้ามระบบ
- listen: `EventBus.enemy_died(enemy, enemy_id, position)` — นับจำนวนศัตรูที่ห้องนี้ spawn ไว้ เพื่อปลดล็อกห้องเมื่อครบ
- listen: `EventBus.player_died` — รีเซ็ตดันเจี้ยนและส่งผู้เล่นกลับห้องแรก
- _รอ contract_: เสนอสัญญาณ `room_started(room_id, room_index)` และ `room_cleared(room_id, room_index)` ข้ามระบบให้ HUD/กล้อง/BGM ทราบ

## กติกาเฉพาะระบบ / กับดักที่เคยเจอ
- มุมมอง isometric: ใช้ TileSet `TILE_SHAPE_ISOMETRIC` + `TILE_LAYOUT_DIAMOND_DOWN` tile 64×32
- บล็อกกำแพงสูง 32 px ใช้ `size_in_atlas = Vector2i(1, 2)` (64×64 px) และต้องตั้ง `texture_origin = Vector2i(0, 16)` (ห้ามใช้ค่าลบ -16) เพื่อให้ฐานเพชรของกำแพงตรงกับ collision polygon ของ cell พอดี
- การสร้าง scene ซ้อน (`tools/build_dungeon_scenes.gd`): ห้ามตั้ง owner ให้ลูกของ node ที่มาจาก scene อื่น (`node.scene_file_path != ""`) เพราะ PackedScene จะบันทึก node ซ้ำซ้อนและทำให้เกิด RID leak ตอน instantiate/free
- การ spawn ศัตรู: ต้อง `add_child` เข้า tree ก่อน แล้วค่อยตั้ง `global_position = marker.global_position` เพื่อให้พิกัดคำนวณถูกเมื่อห้องไม่ได้อยู่ที่ origin
- ศัตรูที่ถูก free โดยไม่ผ่าน `EventBus.enemy_died`: ต้องต่อ `tree_exiting` ลบออกจาก `spawned_enemies` เพื่อไม่ให้ห้องค้างที่ LOCKED
- Player detector callback: ใช้ `start_room.call_deferred()` หลีกเลี่ยงการสลับ physics state ระหว่าง query flush
- Y-Sort: ต้องเปิด `y_sort_enabled = true` ที่ root ของ Sandbox, Dungeon, Room, EnemyContainer, Doors, WallLayer เพื่อให้การ render ทับซ้อนถูกต้อง
- แสงสลัว: ใช้ `CanvasModulate` ตัวเดียวที่ระดับ `Dungeon` (ไม่ใส่ซ้ำในแต่ละห้อง) เพื่อไม่ให้สี modulate ทับซ้อนกัน
- กำแพงต้องมี collision polygon รูปเพชร `[Vector2(0, -16), Vector2(32, 0), Vector2(0, 16), Vector2(-32, 0)]` บน physics layer `world` (`Combat.LAYER_WORLD`)
- การ toggle `disabled` และ `monitoring` ของ `Door` ต้องใช้ `set_deferred` เมื่ออยู่ใน SceneTree เพื่อป้องกัน error `Can't change this state while flushing queries` ในช่วง physics callback
- นับ `EventBus.enemy_died` เฉพาะตัวที่อยู่ใน `spawned_enemies` ของห้องนั้น ไม่นับศัตรูของห้องอื่น
- ห้องที่ไม่มีศัตรู (เช่น ห้อง 3 บอสที่ยังไม่ spawn) ต้องเปลี่ยนสถานะเป็น CLEARED ทันทีที่เข้าห้อง
- ทุก script ใน `tools/` ต้องรันใน `_initialize()` ไม่ใช่ `_init()` เพื่อให้ autoload `EventBus` โหลดเสร็จก่อน

## เทสต์
- `game/tests/test_dungeon_room.gd`
