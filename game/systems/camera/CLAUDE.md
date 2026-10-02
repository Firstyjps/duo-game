# ระบบ: camera

- เจ้าของ: @Firstyjps (Kron) · contract ที่เกี่ยว: `docs/contracts/damage.md` (v1)

## ทำอะไร
- ผู้เล่น: กล้องติดตามตัวละครแบบนุ่มนวล ไม่หลุดนอกห้อง/ขอบฉาก สั่นสะเทือนตามความแรงเมื่อเกิดดาเมจ และมี hitstop ให้ความรู้สึกกระแทก
- โค้ด: GameCamera (Camera2D) คุม lerp ตามเป้าหมาย, clamp bounds, สั่นแบบ trauma², จัดการ Engine.time_scale สำหรับ hitstop แบบซ้อนได้

## ไฟล์สำคัญ
| ไฟล์ | หน้าที่ |
|---|---|
| `game_camera.gd` | `GameCamera` extends Camera2D: follow, trauma decay, shake offset, bounds clamp, hitstop, `slide_to(rect, duration)`, `set_focus_target(node)` |
| `debug/camera_sandbox.tscn` | scene ทดสอบกล้องเดิม (F6): กล่องเคลื่อนที่ด้วยลูกศร/WASD + กด Space เพื่อสั่น |
| `debug/camera_sandbox.gd` | สคริปต์ควบคุม sandbox เดิม, ลงทะเบียน input, แสดงสถานะ HUD |
| `debug/iso_camera_sandbox.tscn` | scene ทดสอบกล้อง iso (F6): พื้น iso 64×32, บล็อกสูง, silhouette, ปุ่ม 1/2 slide ข้ามห้อง, L = focus dummy |
| `debug/iso_camera_sandbox.gd` | สคริปต์ควบคุม iso sandbox |
| `debug/iso_tall_block.gd` | บล็อกทรงสูง isometric 2.5D พร้อม physics base (layer world) และ occlusion area |
| `res://systems/player/occlusion/occlusion_silhouette.gd` | โหนด silhouette ใต้ตัวละคร วาดสำเนาสไปรต์สีม่วงอ่อนเมื่อถูกบล็อกข้างหน้าบัง (y มากกว่า) |

## ส่ง / รับ ข้ามระบบ
- listen: `EventBus.damage_dealt(target, info, final_amount)` — สั่นกล้อง (target อยู่ใน group "player" สั่นแรงกว่า) และเรียก hitstop

## กติกาเฉพาะระบบ / กับดักที่เคยเจอ
- ตำแหน่งสุดท้ายของกล้องและ offset ต้อง round เป็น integer pixel เสมอเพื่อคงความคมชัดของ pixel art
- hitstop ซ้อนกันได้ด้วย reference counter/timer callback และต้องคืน `Engine.time_scale = 1.0` ใน `_exit_tree` เสมอ ห้ามค้าง
- `slide_to(rect, duration)`: ระหว่างเลื่อนกล้องข้ามห้อง ต้องไม่ follow ผู้เล่นและไม่โดน bounds เก่า clamp จนกว่าจะเลื่อนเสร็จสิ้นจึงเรียก `set_bounds(rect)`
- `set_focus_target(node)`: คำนวณ offset จุดกึ่งกลางระหว่างผู้เล่นกับเป้าหมายด้วย `focus_weight` และ clamp ระยะห่างด้วย `max_focus_offset` หากเป้าหมายเป็น null หรือถูกทำลายจะกลับไปตามผู้เล่นตามปกติ
- ใน isometric Y-sort: วัตถุที่บังตัวละครคือวัตถุที่ฐาน (origin/feet) มี Y มากกว่าเท้าตัวละคร และมีส่วนทรงสูงทับสไปรต์ตัวละคร
- แยก static logic (decay_trauma, clamp_to_bounds, calculate_shake_offset, compute_follow_position, compute_slide_position, compute_focus_offset, compute_focus_point) เพื่อให้รัน unit test ได้โดยไม่ต้องพึ่ง scene tree

## เทสต์
- `game/tests/test_camera_system.gd`
- `game/tests/test_camera_iso.gd`
