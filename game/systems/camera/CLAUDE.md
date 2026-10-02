# ระบบ: camera

- เจ้าของ: @Firstyjps (Kron) · contract ที่เกี่ยว: `docs/contracts/damage.md` (v1)

## ทำอะไร
- ผู้เล่น: กล้องติดตามตัวละครแบบนุ่มนวล ไม่หลุดนอกห้อง/ขอบฉาก สั่นสะเทือนตามความแรงเมื่อเกิดดาเมจ และมี hitstop ให้ความรู้สึกกระแทก
- โค้ด: GameCamera (Camera2D) คุม lerp ตามเป้าหมาย, clamp bounds, สั่นแบบ trauma², จัดการ Engine.time_scale สำหรับ hitstop แบบซ้อนได้

## ไฟล์สำคัญ
| ไฟล์ | หน้าที่ |
|---|---|
| `game_camera.gd` | `GameCamera` extends Camera2D: follow, trauma decay, shake offset, bounds clamp, hitstop |
| `debug/camera_sandbox.tscn` | scene ทดสอบกล้อง (F6): กล่องเคลื่อนที่ด้วยลูกศร/WASD + กด Space เพื่อสั่น |
| `debug/camera_sandbox.gd` | สคริปต์ควบคุม sandbox, ลงทะเบียน input, แสดงสถานะ HUD |

## ส่ง / รับ ข้ามระบบ
- listen: `EventBus.damage_dealt(target, info, final_amount)` — สั่นกล้อง (target อยู่ใน group "player" สั่นแรงกว่า) และเรียก hitstop

## กติกาเฉพาะระบบ / กับดักที่เคยเจอ
- ตำแหน่งสุดท้ายของกล้องและ offset ต้อง round เป็น integer pixel เสมอเพื่อคงความคมชัดของ pixel art
- hitstop ซ้อนกันได้ด้วย reference counter/timer callback และต้องคืน `Engine.time_scale = 1.0` ใน `_exit_tree` เสมอ ห้ามค้าง
- แยก static logic (decay_trauma, clamp_to_bounds, calculate_shake_offset, compute_follow_position) เพื่อให้รัน unit test ได้โดยไม่ต้องพึ่ง scene tree

## เทสต์
- `game/tests/test_camera_system.gd`
