# Contract: damage — ผู้เล่น (A) ↔ enemy / dungeon / loot (B)

- เวอร์ชัน: 1 · อัปเดต: 2026-10-02 · ร่าง: Kron (#15) · รีวิวย้อนหลัง: Few
- โค้ดร่วม: `game/core/combat/` (`Combat`, `DamageInfo`, `Hitbox`, `Hurtbox`, `Health`) · signal: `game/core/event_bus.gd`
- เทสต์: `game/tests/test_core_combat.gd`

## ภาพรวม 1 การโจมตี
```
[ผู้โจมตี]  telegraph (ศัตรูต้องมีเสมอ) → Hitbox.activate() ช่วง active frames → Hitbox.deactivate()
                 │ ชนกับ Hurtbox (physics layer `hurtbox`)
                 ▼
[Hitbox]    make_damage_info() → Hurtbox.receive(info)
                 │ ถูกปฏิเสธถ้า: ฝั่งเดียวกัน · Hurtbox.invulnerable (i-frames)
                 ▼
[ผู้ถูกตี]   Hurtbox.hurt(info) → owner หัก defense ของตัวเอง → Health.take_damage(final)
                 → ใส่ knockback/stagger ให้ตัวเอง → EventBus.damage_dealt(self, info, final)
[Hitbox]    hit_landed(hurtbox, info) → hitstop / VFX / เสียง ของฝั่งผู้โจมตี
```

## Classes (`game/core/combat/`)
| class | ใครใช้ | สัญญา |
|---|---|---|
| `Combat.Team` | ทุกคน | `PLAYER` · `ENEMY` · `NEUTRAL` (กับดัก/ของทำลายได้) · ฝั่งเดียวกันไม่โดนกัน · `NEUTRAL` ตีโดนทุกฝั่ง |
| `DamageInfo` | Hitbox สร้าง, ผู้รับอ่าน | `amount` = ดาเมจ**ก่อน**หัก defense · `type` (`&"physical"` ก่อน, ธาตุทีหลัง) · `team` ฝั่งผู้ตี · `knockback` ทิศ×แรง px/s · `stagger` poise damage · `is_crit` · `source` (อาจถูก free → `is_instance_valid`) · `hit_position` |
| `Hitbox` (Area2D) | ท่าโจมตีของ A และ B | เปิดเฉพาะช่วง active ด้วย `activate()`/`deactivate()` · โดน Hurtbox แต่ละตัว **1 ครั้งต่อ activate** · ถูกปฏิเสธ (i-frames) ไม่นับ — หมด i-frames แล้วยังโดนได้ · override `make_damage_info()` เพื่อใส่ stat/crit |
| `Hurtbox` (Area2D) | ตัวผู้เล่น (A), ศัตรู/ของทำลายได้ (B) | ตั้ง `team` · owner คุม `invulnerable` เอง (dodge = A, ท่าอมตะของบอส = B) · ฟัง `hurt` |
| `Health` (Node) | ผู้เล่น (A), ศัตรู (B) | `take_damage()` คืนค่าที่หักจริง · `died` emit **ครั้งเดียว** · `changed(current, max)` ให้ HUD |

## Signals (`EventBus`)
| signal | args | emit โดย / เมื่อ | ผู้ฟัง |
|---|---|---|---|
| `damage_dealt` | `target: Node, info: DamageInfo, final_amount: int` | ผู้ถูกตี หลังหัก HP แล้ว (ไม่ emit ถ้าถูกปฏิเสธ) | A: ตัวเลขดาเมจ, กล้องสั่น · B/อื่น ๆ: ใช้ได้ |
| `enemy_died` | `enemy: Node, enemy_id: StringName, position: Vector2` | B (enemy) ตอน `Health.died` ครั้งเดียวต่อตัว | B (loot): ดรอป · A: นับ kill (ถ้าต้องใช้) |
| `player_died` | — | A ตอน `Health.died` ของผู้เล่น | B (dungeon): รีเซ็ต/กลับจุดเริ่ม |
| `boss_engaged` | `boss: Node, health: Health, display_name: String` | B ตอนเริ่มสู้บอส | A (HUD): หลอด HP บอส ผูกกับ `health.changed` |

## Physics layers (`project.godot`)
| layer | ชื่อ | ใช้กับ |
|---|---|---|
| 1 | `world` | กำแพง/สิ่งกีดขวาง |
| 2 | `player` | body ของผู้เล่น |
| 3 | `enemy` | body ของศัตรู |
| 4 | `hurtbox` | Hurtbox ทุกตัว (Hitbox mask layer นี้ — ตั้งให้อัตโนมัติ) |

## ห้าม / ข้อควรระวัง
- ห้ามเรียก `Health` / script ของอีกระบบตรง ๆ เพื่อทำดาเมจ — ต้องผ่าน Hitbox → Hurtbox เสมอ (i-frames/ทีมจะได้ทำงานเหมือนกันทุกที่)
- ศัตรูทุกท่าต้อง telegraph ก่อน `activate()` (DECISIONS) · telegraph เป็นเรื่องภายใน B ไม่อยู่ใน contract นี้
- defense / ต้านธาตุ / crit คำนวณที่**ผู้รับ** (defense) และ**ผู้ตี** (crit, stat ไอเทมผ่าน `make_damage_info()`) — สูตร stat ของไอเทมอยู่ใน contract `item-stat` (ยังไม่มี)
- ดาเมจหลังหัก defense ถ้าไม่ถูกปฏิเสธ ควรขั้นต่ำ 1 (ตีแล้วต้องรู้สึกว่าโดน)
- `monitoring` ของ Area2D ห้ามเปลี่ยนตรง ๆ ใน callback ชนกัน — ใช้ `activate()`/`deactivate()` (ใช้ `set_deferred` ให้แล้ว)

## ยังไม่อยู่ใน contract นี้
- item / stat schema (B สร้างของ → A ใส่และคำนวณ stat) → contract `item-stat`
- ห้องเริ่ม/เคลียร์ (dungeon → UI/กล้อง) → contract แยกเมื่อต้องใช้

## Changelog
- v1 — สร้าง (Kron, #15) · ทดสอบ overlap ใน physics จริงแล้ว: ก่อน activate ไม่โดน, activate โดน 1 ครั้ง, เปิดใหม่ตอนยังทับกันโดนอีกครั้ง
