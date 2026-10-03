# ระบบ: hud

- เจ้าของ: @Firstyjps (Kron) · contract ที่เกี่ยว: `docs/contracts/damage.md` (v1)

## ทำอะไร
- ผู้เล่น: แสดงสถานะผู้เล่น (หลอดเลือด HP สีแดง, หลอด stamina สีเขียวที่กระพริบแดงเมื่อหมด, ไอคอนขวดชาฟื้นพลังใต้หลอด stamina), หลอดเลือดบอสพร้อมชื่อกลางบนจอ, ตัวเลขดาเมจลอยขึ้นและจางหายตามตำแหน่งโลก, และเป้า lock-on เหนือศัตรู
- โค้ด: `GameHud` (`CanvasLayer` layer 10) anchor ขอบจอบน base 960×540 (aspect expand), ผูก Health และ duck typing stamina/lock-on/flasks_changed, ฟัง EventBus

## ไฟล์สำคัญ
| ไฟล์ | หน้าที่ |
|---|---|
| `hud.tscn` + `hud.gd` | `GameHud`: CanvasLayer แสดงหลอด HP/Stamina และไอคอนขวดชาซ้ายล่าง, หลอดบอสกลางบน, ตัวเลขดาเมจลอยตามโลก, เป้า lock-on |
| `debug/hud_sandbox.tscn` + `hud_sandbox.gd` | scene ทดสอบ HUD (F6) พร้อมปุ่ม/คีย์ 1–6 และ R จำลองเหตุการณ์ |

## ส่ง / รับ ข้ามระบบ
- listen: `EventBus.boss_engaged(boss, health, display_name)` — แสดงชื่อและหลอดเลือดบอส ผูก `health.changed`, ซ่อนหลัง 1.5 วิ เมื่อ `health.died`, ซ่อนทันทีเมื่อ `health.tree_exiting` หรือ `health.hp <= 0`
- listen: `EventBus.player_died` — ซ่อนหลอดบอสทันที
- listen: `EventBus.damage_dealt(target, info, final_amount)` — แสดงตัวเลขดาเมจจัดกึ่งกลางและลอยขึ้นตามตำแหน่งโลก (คำนวณใหม่ทุกเฟรมจาก canvas transform)
- bind: `bind_player(health, stamina_source, flask_source = null)` — ผูก `health.changed`, `stamina_source.stamina_changed`, `stamina_source.stamina_empty` (อ่านค่า max จาก `stamina_max`), และ duck typing ตรวจจับ signal `flasks_changed(current, maximum)` เพื่อแสดงไอคอนขวดชา
- bind: `bind_lock_source(source)` — duck typing ฟัง `source.lock_target_changed(target: Node2D)` แสดงเครื่องหมายเป้าเหนือตัวศัตรูตามตำแหน่งโลก (ซ่อนเมื่อ null หรือเป้าถูก free)

## กติกาเฉพาะระบบ / กับดักที่เคยเจอ
- layer = 10 และ root Control ต้อง anchor ขอบจอ (`PRESET_BOTTOM_LEFT`, `PRESET_CENTER_TOP`) เพื่อรองรับ aspect expand
- การเชื่อมต่อ EventBus: connect ใน `_enter_tree()`, disconnect ใน `_exit_tree()` เพื่อรองรับการ remove และ re-add เข้า scene tree โดยไม่ค้างหรือหลุด
- binding ของ player, boss, และ lock source ให้ล้างเฉพาะตอน `NOTIFICATION_PREDELETE` (ไม่ล้างใน `_exit_tree()`)
- หลอดบอสต้อง connect `health.tree_exiting` → `hide_boss()` และ disconnect เมื่อเปลี่ยนบอสหรือ cleanup เพื่อป้องกันหลอดค้างกรณีบอส despawn/free โดยไม่ตาย
- หลอด stamina ผู้เล่นใช้ชื่อตัวแปร `stamina_max` ตาม `player.gd` (ไม่ใช่ `max_stamina`/`STAMINA_MAX`)
- ตัวเลขดาเมจต้องจัดกึ่งกลาง (`label.position = screen_pos - label.size * 0.5`) และเก็บ `world_pos` คำนวณตำแหน่งจอใหม่ทุกเฟรมใน `tick(delta)` เพื่อให้เลื่อนตามกล้องอย่างถูกต้องเมื่อ canvas transform ไม่ใช่ identity
- ผูก node และ signal ใน `setup()` และแยก logic รายเฟรมไว้ใน `tick(delta)` เพื่อให้ unit test ทำงานได้แบบ deterministic แม้ไม่ได้อยู่ใน scene tree
- ค่าตกแต่งและตำแหน่งต่าง ๆ (jitter, เวลา flash, outline_size, offset ของ box, offset ของ lock marker, สี/ขนาดขวดชา) ต้องเป็น `@export`
- ไอคอนขวดชาแสดงใต้หลอด stamina ใน `flask_container: HBoxContainer` วาดด้วยโค้ด/ColorRect ขนาด 8×10 px พร้อมคอขวด 4×2 px (สีเขียวชา `flask_full_color` เมื่อมี / จางโปร่งแสง `flask_empty_color` เมื่อขวดหมด) ไม่พึ่งพาภาพ asset

## เทสต์
- `game/tests/test_hud.gd`
