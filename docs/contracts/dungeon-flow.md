# Contract: dungeon-flow — dungeon (B) ↔ ผู้เล่น/กล้อง/HUD (A)

- เวอร์ชัน: 1.1 · อัปเดต: 2026-10-03 · ร่าง: Kron (#51, user อนุมัติ) · รีวิวย้อนหลัง: Few
- ผู้ส่ง: dungeon (B, @kronkawin2549-create) · ผู้รับ: player / camera / hud (A, @Firstyjps)

## Signals (ใน `EventBus`)
| signal | args | emit เมื่อ | ผู้รับต้องทำ |
|---|---|---|---|
| `room_started` | `room: Node, room_rect: Rect2` | **ทุกครั้งที่ผู้เล่นเข้าห้อง** (รวมห้องที่เคลียร์แล้ว — ห้องไม่มีศัตรู/เคลียร์แล้วส่ง `room_cleared` ตามทันที) · ห้องมีศัตรู = ประตูปิดเริ่มสู้ · หลัง respawn ส่งของห้องที่ฟื้นด้วย | กล้อง: `slide_to(room_rect)`/bounds · HUD/เพลง: โหมดสู้ (ไม่บังคับ) |
| `room_cleared` | `room: Node` | ศัตรูของห้องนี้หมด ประตูเปิด | HUD/เพลง/เสียง (ไม่บังคับ) |
| `player_respawn_requested` | `position: Vector2` | หลัง `player_died` และ dungeon รีเซ็ตห้องเสร็จ | Player `revive(position)`: HP/stamina เต็ม, state MOVE, ปลด lock, ชนได้ตามปกติ |

## Data / interface
- `room_rect` = พื้นที่ห้องเป็นพิกัดโลก (ใช้ตั้งขอบกล้อง)
- ผู้เล่นอยู่ใน group `"player"` — dungeon ตรวจจับผู้เล่นด้วย Area2D mask physics layer `player` เท่านั้น (ไม่เรียก method ของ Player ตรง ๆ)

## ห้าม / ข้อควรระวัง
- ห้าม dungeon ย้าย/ฟื้นผู้เล่นเอง — ส่ง `player_respawn_requested` แล้ว Player จัดการตัวเอง
- `player_respawn_requested` ส่ง**หลัง**รีเซ็ตห้อง (ศัตรูเก่าถูกลบแล้ว) ไม่งั้นผู้เล่นฟื้นกลางศัตรู
- ศัตรูที่ถูก free โดยไม่ emit `enemy_died` ต้องไม่ทำให้ห้องค้าง (dungeon ฟัง `tree_exiting` เอง)

## Changelog
- v1.1 — ระบุชัด: `room_started` ส่งทุกครั้งที่เข้าห้อง (กล้องใช้ตั้งขอบ) · กล้องฟังแล้ว (#41) · ไม่เปลี่ยน signal/args
- v1 — สร้าง (#51)
