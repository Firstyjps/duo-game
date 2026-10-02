# ระบบ: player (ผู้เล่น)

- เจ้าของ: @Firstyjps (Kron) · contract ที่เกี่ยว: `docs/contracts/damage.md`

## ทำอะไร
- มุมผู้เล่น: ควบคุมอัศวิน เดิน (WASD) เล็งเมาส์ ฟันโจมตี 3 จังหวะ และ dodge หลบพร้อม i-frames โดยใช้ stamina
- มุมโค้ด: `CharacterBody2D` มี FSM (MOVE/DODGE/ATTACK/HURT/DEAD), คุม stamina regen, จัดการ i-frames ผ่าน `Hurtbox.invulnerable`, ทำดาเมจผ่าน `Hitbox`, รับดาเมจและ emit signal ตาม contract damage

## ไฟล์สำคัญ
| ไฟล์ | หน้าที่ |
|---|---|
| `player.tscn` | scene หลักของผู้เล่น (Sprite2D, Health, Hurtbox, Hitbox, CollisionShape2D) |
| `player.gd` | logic ผู้เล่น FSM, stamina, input intent, dodge, attack phases, damage handling |
| `art/knight.png` | ภาพ sprite ตัวละคร placeholder |
| `debug/player_sandbox.tscn` | sandbox สำหรับเปิดลองเดิน ฟัน และ dodge สู้กับหุ่นฝึก |
| `debug/dummy.gd` | หุ่นลองรับดาเมจ (Hurtbox ENEMY + Health) สำหรับ sandbox |

## ส่ง / รับ ข้ามระบบ
- emit: `EventBus.damage_dealt(target, info, dealt)` — เมื่อผู้เล่นโดนดาเมจและหัก HP แล้ว
- emit: `EventBus.player_died()` — เมื่อผู้เล่น HP หมด (`Health.died`) ปล่อยครั้งเดียว
- listen: `Hurtbox.hurt(info)` — รับดาเมจ หัก defense แล้วเรียก `Health.take_damage()`

## กติกาเฉพาะระบบ / กับดักที่เคยเจอ
- อย่าเรียก `move_and_slide()` ใน `tick(delta)` — แยกให้เทสต์เรียก `tick(delta)` แบบ deterministic ได้
- ป้อน input สำหรับเทสต์ผ่าน `set_intent(move, aim, attack, dodge)`
- Input actions (`move_*`, `attack`, `dodge`) ลงทะเบียนตอน runtime ด้วย `ensure_input_actions()` เสมอ (ห้ามแก้ `project.godot`)
- ระหว่าง dodge ให้เปลี่ยน `collision_mask` เหลือเพียง `Combat.LAYER_WORLD` เท่านั้น แล้วคืนค่า `WORLD | ENEMY` เมื่อจบ dodge

## เทสต์
- `game/tests/test_player_combat.gd`
