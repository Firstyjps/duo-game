# ระบบ: player (ผู้เล่น)

- เจ้าของ: @Firstyjps (Kron) · contract ที่เกี่ยว: `docs/contracts/damage.md`

## ทำอะไร
- มุมผู้เล่น: ควบคุมอัศวิน เดิน (WASD) เล็งเมาส์ ฟันโจมตี 3 จังหวะ (กดค้างเป็นท่าชาร์จ), dodge หลบพร้อม i-frames, parry ปัดป้องการโจมตีคืน stamina, และ lock-on ล็อคเป้าหมายศัตรู
- มุมโค้ด: `CharacterBody2D` มี FSM (MOVE/DODGE/ATTACK/HURT/DEAD/PARRY), คุม stamina regen, จัดการ i-frames ผ่าน `Hurtbox.invulnerable`, ทำดาเมจผ่าน `Hitbox`, รับดาเมจและ emit signal ตาม contract damage

## ไฟล์สำคัญ
| ไฟล์ | หน้าที่ |
|---|---|
| `player.tscn` | scene หลักของผู้เล่น (Sprite2D, Health, Hurtbox, Hitbox, LockArea, CollisionShape2D) |
| `player.gd` | logic ผู้เล่น FSM, stamina, input intent, dodge, parry, charge attack, lock-on, damage handling |
| `art/knight.png` | ภาพ sprite ตัวละคร placeholder |
| `debug/player_sandbox.tscn` | sandbox สำหรับเปิดลองเดิน ฟัน ชาร์จ dodge parry และ lock-on กับหุ่นฝึก |
| `debug/player_sandbox.gd` | ควบคุม UI HUD และรับปุ่ม T เพื่อสั่งหุ่น Dummy โจมตีทดสอบ parry |
| `debug/dummy.gd` | หุ่นลองรับดาเมจและสั่งโจมตีปล่อย Hitbox เพื่อทดสอบ parry |

## ส่ง / รับ ข้ามระบบ
- emit: `EventBus.damage_dealt(target, info, dealt)` — เมื่อผู้เล่นโดนดาเมจและหัก HP แล้ว
- emit: `EventBus.player_died()` — เมื่อผู้เล่น HP หมด (`Health.died`) ปล่อยครั้งเดียว
- listen: `Hurtbox.hurt(info)` — รับดาเมจ หัก defense แล้วเรียก `Health.take_damage()` (เว้นแต่ parry สำเร็จ)
- listen: `EventBus.enemy_died(enemy, id, pos)` — ปลด lock_target เมื่อเป้าหมายที่ล็อคไว้ตาย

## Signal ภายใน Player
- `stamina_changed(current: float, maximum: float)`
- `stamina_empty`
- `lock_target_changed(target: Node2D)` — แจ้งเตือนเมื่อเป้าล็อคเปลี่ยนหรือปลด (เป็น null)
- `parried(info: DamageInfo)` — ปล่อยเมื่อโดนโจมตีในหน้าต่าง parry สำเร็จ

## กติกาเฉพาะระบบ / กับดักที่เคยเจอ
- อย่าเรียก `move_and_slide()` ใน `tick(delta)` — แยกให้เทสต์เรียก `tick(delta)` แบบ deterministic ได้
- ป้อน input สำหรับเทสต์ผ่าน `set_intent(move, aim, attack, dodge, parry, lock_on, attack_held)` โดยมีค่า default ป้องกันเทสต์เดิมพัง
- Input actions (`move_*`, `attack`, `dodge`, `parry`, `lock_on`) ลงทะเบียนตอน runtime ด้วย `ensure_input_actions()` เสมอ (ห้ามแก้ `project.godot`)
- ระหว่าง dodge ให้เปลี่ยน `collision_mask` เหลือเพียง `Combat.LAYER_WORLD` เท่านั้น แล้วคืนค่า `WORLD | ENEMY` เมื่อจบ dodge
- ขณะ Parry อยู่ในหน้าต่าง `parry_window` หากโดนโจมตีจะไม่เสีย HP และได้รับ stamina คืน `parry_refund`
- ท่าชาร์จเข้าสู่ `CHARGING` เมื่อกดค้างครบ `charge_threshold` (0.15s) ไม่ใช่ windup_time; ปล่อยก่อน `charge_time` เป็นท่าฟันธรรมดาหัก stamina แค่ `attack_cost`; ระหว่างชาร์จสามารถกด dodge หรือ parry ยกเลิกได้
- ห้ามอ่านข้อมูลภายใน enemy entity (`Health`, `is_dead`, `Dummy`) จาก `player.gd` โดยเด็ดขาด — ตรวจหาศัตรูผ่าน `LockArea` (Area2D ที่ตรวจจับ `Hurtbox` ฝั่งศัตรู) เท่านั้น และปลดเป้าหมายผ่าน `EventBus.enemy_died`, หลุดระยะ buffer (`lock_range * lock_release_mult`), หรือ instance ถูกทำลาย
- ใช้ `is_instance_valid(lock_target)` แทนการเช็ค `!= null` ทุกที่ เนื่องจากใน GDScript 4 วัตถุที่ถูก `free()` ไปแล้วจะเทียบ `== null` เป็น true ทำให้ `_set_lock_target(null)` return ก่อนส่งสัญญาณหากไม่ตรวจ `is_instance_valid`
- ต่อ `EventBus.enemy_died` ใน `_enter_tree()` และ disconnect ใน `_exit_tree()` (รวมทั้งใน `NOTIFICATION_PREDELETE`) เสมอ

## เทสต์
- `game/tests/test_player_combat.gd` (เทสต์พื้นฐานเดิม)
- `game/tests/test_player_combat_ext.gd` (Lock-on, Parry, Charge Attack)
