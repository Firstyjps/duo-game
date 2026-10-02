# Contract: <ระบบ A> ↔ <ระบบ B>

- เวอร์ชัน: 1 · อัปเดต: YYYY-MM-DD
- ผู้ส่ง (emit/provide): <ระบบ> (@เจ้าของ) · ผู้รับ (listen/use): <ระบบ> (@เจ้าของ)

## Signals (ใน `EventBus`)
| signal | args | emit เมื่อ | ผู้รับต้องทำ |
|---|---|---|---|
| `enemy_died` | `enemy_id: StringName, position: Vector2` | ศัตรู HP ≤ 0 (ครั้งเดียวต่อตัว) | สุ่มดรอปที่ตำแหน่งนั้น |

## Data / interface
_resource, group, method ที่อีกฝั่งเรียกได้ — ระบุ type ชัด_

## ห้าม / ข้อควรระวัง
- 

## Changelog
- v1 — สร้าง
