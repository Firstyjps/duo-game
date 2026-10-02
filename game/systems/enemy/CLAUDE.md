# ระบบ: enemy

- เจ้าของ: @kronkawin2549-create (Few) · contract ที่เกี่ยว: `docs/contracts/damage.md` (v1)

## ทำอะไร
- ผู้เล่น: ศัตรูที่อ่านท่าได้ — ทุกท่าโจมตีมี telegraph ก่อนเสมอ
- โค้ด: AI (state machine), ท่าโจมตี, HP ของศัตรู, ตายแล้วแจ้ง loot

## ไฟล์สำคัญ
| ไฟล์ | หน้าที่ |
|---|---|
| `slime/slime.tscn` + `slime.gd` | สไลม์: IDLE → CHASE (เด้ง) → WINDUP (วงเตือน) → LEAP (Hitbox เปิด) → RECOVER · HURT · DEAD |
| `slime/slime_sheet.png` | sprite 11 เฟรม 32×32 — สร้างจาก `slime/tools/gen_slime_sheet.gd` (placeholder art, แก้สีแล้วรันใหม่) |
| `common/telegraph_marker.gd` | `TelegraphMarker` วงเตือนบนพื้น ใช้ซ้ำกับศัตรูตัวอื่นได้ |
| `debug/enemy_sandbox.tscn` | scene ลองศัตรู (F6) มีหุ่นแทนผู้เล่น: ลูกศรเดิน, Space ฟัน |

## ส่ง / รับ ข้ามระบบ
- emit: `EventBus.damage_dealt` — หลังหัก HP ศัตรูแล้ว
- emit: `EventBus.enemy_died(enemy, enemy_id, position)` — ครั้งเดียวต่อตัว → loot ดรอปของ
- หาผู้เล่น: Area2D `Detect` mask physics layer `player` เท่านั้น (ไม่ get_node เข้าระบบ A)

## กติกาเฉพาะระบบ / กับดักที่เคยเจอ
- art ตามสเปกใน `docs/DESIGN.md` (pixel 32 px, top-down 3/4) · sprite `offset.y = -14` ให้เท้าอยู่ที่ origin (y-sort ถูก)
- ห้ามโจมตีโดยไม่มี telegraph — `Hitbox.activate()` หลัง windup เท่านั้น
- `TelegraphMarker` ต้อง `top_level = true` + `z_index = -1` → พื้น/TileMap ต้อง z ต่ำกว่า -1 ไม่งั้นบังวง
- เทสต์รันตอน root ยังไม่อยู่ใน tree → อย่าใช้ `@onready` กับ node ที่เทสต์ต้องใช้ · ผูก node ใน `setup()` และแยก AI ไว้ใน `tick()` (ไม่มี physics)

## เทสต์
- `game/tests/test_enemy_*.gd`
