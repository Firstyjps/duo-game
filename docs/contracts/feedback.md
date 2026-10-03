# Contract: feedback — ทุกระบบ → กล้อง (A)

- เวอร์ชัน: 1 · อัปเดต: 2026-10-03 · ร่าง: Kron (#51, user อนุมัติ) · รีวิวย้อนหลัง: Few
- ผู้ส่ง: ใครก็ได้ (enemy/บอส/dungeon/ระเบิด) · ผู้รับ: camera (A, @Firstyjps)

## Signals (ใน `EventBus`)
| signal | args | emit เมื่อ | ผู้รับต้องทำ |
|---|---|---|---|
| `screen_shake_requested` | `strength: float, position: Vector2` | เหตุการณ์ที่ควรสั่นจอ เช่น บอสกระทืบ/ทุบพื้น, เท้ากระแทก, ระเบิด | กล้องเพิ่ม trauma = `strength` (0..1, clamp) · อาจลดแรงตามระยะจาก `position` |

## ห้าม / ข้อควรระวัง
- ดาเมจที่ตีโดนอยู่แล้ว**ไม่ต้อง** emit — กล้องสั่นจาก `damage_dealt` ให้เองแล้ว (contract damage)
- strength แนะนำ: เท้าเดินหนัก 0.15 · กระทืบ/ทุบ 0.4–0.6 · ระเบิดใหญ่ 0.8 · อย่าส่งทุกเฟรม (trauma สะสม)
- ผู้ฟังฝั่งกล้อง: เพิ่มใน `GameCamera` (#41 — ยังไม่ต่อ ณ v1)

## Changelog
- v1 — สร้าง (#51)
