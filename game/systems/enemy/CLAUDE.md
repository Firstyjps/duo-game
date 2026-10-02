# ระบบ: enemy

- เจ้าของ: @kronkawin2549-create (Few) · contract ที่เกี่ยว: _ยังไม่มี_

## ทำอะไร
- ผู้เล่น: ศัตรูที่อ่านท่าได้ — ทุกท่าโจมตีมี telegraph ก่อนเสมอ
- โค้ด: AI (state machine), ท่าโจมตี, HP ของศัตรู, ตายแล้วแจ้ง loot

## ไฟล์สำคัญ
| ไฟล์ | หน้าที่ |
|---|---|
| _ยังไม่มี_ | |

## ส่ง / รับ ข้ามระบบ
- _รอ contract_ — damage/hit กับผู้เล่น (ระบบ A), telegraph, ศัตรูตาย → loot

## กติกาเฉพาะระบบ / กับดักที่เคยเจอ
- art ตามสเปกใน `docs/DESIGN.md` (pixel 32 px, top-down 3/4)
- ห้ามโจมตีโดยไม่มี telegraph (ข้อตกลงใน DECISIONS)

## เทสต์
- `game/tests/test_enemy_*.gd`
