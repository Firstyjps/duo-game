# ระบบ: dungeon

- เจ้าของ: @kronkawin2549-create (Few) · contract ที่เกี่ยว: _ยังไม่มี_

## ทำอะไร
- ผู้เล่น: เดินผ่านห้องในดันเจี้ยน ห้องปิดจนกว่าศัตรูหมด มีห้องบอส
- โค้ด: สร้าง/โหลดห้องด้วย `TileMapLayer` (tile 32×32), spawn ศัตรู, จัดการประตูและการเปลี่ยนห้อง

## ไฟล์สำคัญ
| ไฟล์ | หน้าที่ |
|---|---|
| `puzzles/pressure_switch.gd` | สวิตช์เหยียบ isometric (ผู้เล่น/PushBlock) · latch/ไม่ latch · reset() |
| `puzzles/push_block.gd` | บล็อกหินดันได้ 4 แกน isometric grid จากตำแหน่งผู้เล่น · grace 0.12s · blocked_cells |
| `puzzles/stone_lantern.gd` | โคมหินรับ hit ทีม PLAYER จุดไฟ PointLight2D · ติดถาวรปิด monitorable |
| `puzzles/puzzle_gate.gd` | ประตูหินเปิดเมื่อ required inputs ครบ (AND logic) · set_deferred disabled |
| `puzzles/kintsugi_crack.gd` | สะพาน/ประตูแตก ซ่อมด้วยทอง (interact ค้าง + ใช้ GoldShards) |
| `puzzles/rest_shrine.gd` | ศาลเจ้าพักผ่อน จุดเกิดใหม่ · safe radius กันศัตรู + cooldown 3s · emit respawn |
| `puzzles/pickup_shard.gd` | เศษทองเก็บได้ เพิ่มจำนวนใน `GoldShards` |
| `puzzles/gold_shards.gd` | ตัวนับเศษทองชั่วคราว (static var) · ต้อง reset ทุกเริ่มรัน |
| `puzzles/debug/puzzle_sandbox.tscn` | sandbox รวมปริศนาและศาลเจ้าทั้งหมด (ปุ่ม R รีเซ็ตปริศนา) |
| `puzzles/debug/puzzle_physics_runner.gd` | runner ทดสอบฟิสิกส์จริง (กำแพง + เดิน 8 ทิศ) |

## ส่ง / รับ ข้ามระบบ
- `EventBus.player_respawn_requested(position)`: emit เมื่อผู้เล่นพักผ่อนที่ `RestShrine` เพื่อฟื้น HP/ขวด และตั้งจุดเกิดใหม่ตาม contract `dungeon-flow`
- **Dungeon ต้องเรียก `GoldShards.reset()` ตอนเริ่มรัน** (ก่อนเข้าดันเจี้ยนหรือเริ่มชั้นใหม่) เพื่อล้างเศษทองที่ตกค้าง

## กติกาเฉพาะระบบ / กับดักที่เคยเจอ
- art ตามสเปกใน `docs/DESIGN.md` (pixel 32 px, top-down 3/4) และ isometric 64×32 สำหรับ puzzles
- ใช้ y-sort + แสง 2D (`CanvasModulate` + `PointLight2D`) ตาม DESIGN
- เท้าของทุก element อยู่ที่ origin (0, 0)
- เชื่อมต่อภายใน puzzles ด้วย `@export var targets: Array[NodePath]` + `activate(source)` / `deactivate(source)`
- `PushBlock` หาแกนดันจากตำแหน่ง `(บล็อก - ผู้เล่น)` snap เข้า 4 แกน isometric (down-right, down-left, up-left, up-right) ไม่ใช้ velocity · นับเวลาดันเมื่อ dot > 0.2 มี grace timer 0.12s · ป้องกัน soft-lock ด้วย `@export var blocked_cells`
- `StoneLantern` มี `Hurtbox` team `NEUTRAL` กรองเฉพาะ `info.team == Combat.Team.PLAYER` ใน `_on_hurt` · เมื่อติดถาวร (`lit_time == 0.0`) จะ `hurtbox.set_deferred("monitorable", false)` ไม่ให้ lock-on ค้าง
- `PuzzleGate` และ `KintsugiCrack` ปิด/เปิด collision ด้วย `set_deferred("disabled", ...)` เท่านั้น
- `RestShrine` พักได้เมื่อไม่มีศัตรูในรัศมี `@export rest_safe_radius` (~240, Area2D mask enemy) และคูลดาวน์ `@export rest_cooldown` (~3s)
- `KintsugiCrack` และ `RestShrine` ใช้ `InteractAction.ensure_registered()` เพื่อลงทะเบียน action `interact` (E / Joypad A) ตอน runtime โดยไม่แตะ `project.godot`
- `run_tests.gd` เป็น synchronous runner (`suite.call(name) == true`) ใน `_initialize` จึงห้ามใช้ `await` และห้าม hack `body_set_space`

## เทสต์
- Unit tests ทั้งหมด (synchronous):
  ```bash
  godot --headless --path game --script res://tests/run_tests.gd
  ```
- Physics tests จริง (multi-frame SceneTree runner):
  ```bash
  godot --headless --path game --script res://systems/dungeon/puzzles/debug/puzzle_physics_runner.gd
  ```
