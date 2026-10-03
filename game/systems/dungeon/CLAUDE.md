# ระบบ: dungeon

- เจ้าของ: @kronkawin2549-create (Few) · contract ที่เกี่ยว: _ยังไม่มี_

## ทำอะไร
- ผู้เล่น: เดินผ่านห้องในดันเจี้ยน ห้องปิดจนกว่าศัตรูหมด มีห้องบอส
- โค้ด: สร้าง/โหลดห้องด้วย `TileMapLayer` (tile 32×32), spawn ศัตรู, จัดการประตูและการเปลี่ยนห้อง

## ไฟล์สำคัญ
| ไฟล์ | หน้าที่ |
|---|---|
| `puzzles/pressure_switch.gd` | สวิตช์เหยียบ isometric (ผู้เล่น/PushBlock) · latch/ไม่ latch |
| `puzzles/push_block.gd` | บล็อกหินดันได้ 4 แกน isometric grid (intersect_shape ตรวจ world) |
| `puzzles/stone_lantern.gd` | โคมหินรับ hit ทีม PLAYER จุดไฟ PointLight2D |
| `puzzles/puzzle_gate.gd` | ประตูหินเปิดเมื่อ required inputs ครบ (AND logic) |
| `puzzles/kintsugi_crack.gd` | สะพาน/ประตูแตก ซ่อมด้วยทอง (interact ค้าง + ใช้ GoldShards) |
| `puzzles/rest_shrine.gd` | ศาลเจ้าพักผ่อน จุดเกิดใหม่ และ emit `EventBus.player_respawn_requested` |
| `puzzles/pickup_shard.gd` | เศษทองเก็บได้ เพิ่มจำนวนใน `GoldShards` |
| `puzzles/gold_shards.gd` | ตัวนับเศษทองชั่วคราว (static var) |
| `puzzles/debug/puzzle_sandbox.tscn` | sandbox รวมปริศนาและศาลเจ้าทั้งหมด |

## ส่ง / รับ ข้ามระบบ
- `EventBus.player_respawn_requested(position)`: emit เมื่อผู้เล่นพักผ่อนที่ `RestShrine` เพื่อฟื้น HP/ขวด และตั้งจุดเกิดใหม่ตาม contract `dungeon-flow`

## กติกาเฉพาะระบบ / กับดักที่เคยเจอ
- art ตามสเปกใน `docs/DESIGN.md` (pixel 32 px, top-down 3/4) และ isometric 64×32 สำหรับ puzzles
- ใช้ y-sort + แสง 2D (`CanvasModulate` + `PointLight2D`) ตาม DESIGN
- เท้าของทุก element อยู่ที่ origin (0, 0)
- เชื่อมต่อภายใน puzzles ด้วย `@export var targets: Array[NodePath]` + `activate(source)` / `deactivate(source)`
- `PushBlock` ตรวจสอบสิ่งกีดขวางปลายทางด้วย `intersect_shape` บน layer `Combat.LAYER_WORLD` ก่อน tween
- `StoneLantern` มี `Hurtbox` team `NEUTRAL` แต่กรองเฉพาะ `info.team == Combat.Team.PLAYER` ใน `_on_hurt`
- `KintsugiCrack` และ `RestShrine` ใช้ `InteractAction.ensure_registered()` เพื่อลงทะเบียน action `interact` (E / Joypad A) ตอน runtime โดยไม่แตะ `project.godot`
- `run_tests.gd` เป็น synchronous runner (`suite.call(name) == true`) ดังนั้นเทสต์ใน `test_dungeon_puzzles.gd` ห้ามใช้ `await` (เพราะ GDScript จะคืน Coroutine ซึ่งเทียบกับ bool แล้ว script error)

## เทสต์
- `game/tests/test_dungeon_*.gd` (รวม `test_dungeon_puzzles.gd`)
