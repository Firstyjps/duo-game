# Decisions

ใหม่สุดอยู่บน · 1 เรื่อง 3–5 บรรทัด · เปลี่ยนใจ = เพิ่มรายการใหม่อ้างอันเดิม (ไม่ลบของเก่า)

## 2026-10-02 · แนวเกม ARPG + art pixel 32 px top-down 3/4 (#8)
- ใครตัดสิน: Few · สถานะ: **รอ Kron ยืนยัน**
- ARPG real-time · single-player · PC (Steam) · MVP ตาม `DESIGN.md`
- art: pixel 32×32 px, มุม top-down 3/4 (ref Dimraeth / Romestead / Core Keeper), Godot 2D + แสง 2D, ฐาน 960×540 scale จำนวนเต็ม
- ผลกระทบ: ทุก asset ต้องตามสเปกนี้ · ศัตรูทุกตัวต้องมี telegraph · co-op ไม่ทำใน MVP

## 2026-10-02 · Few ยืนยัน engine = Godot 4.7 (#8)
- ยืนยันรายการ "engine = Godot 4.7 (ชั่วคราว)" ด้านล่าง → ตกลงแล้วทั้งคู่

## 2026-10-02 · engine = Godot 4.7 (ชั่วคราว)
- ใครตัดสิน: Kron · สถานะ: **รอเพื่อนยืนยัน**
- เหตุผล: ใช้ทำ Emberglade มาแล้ว, ไฟล์ scene เป็น text (diff/merge ได้), เทสต์ headless ใน CI ได้
- ถ้าเปลี่ยน engine: แก้ `game/`, CI, `CLAUDE.md` ส่วนคำสั่งเทสต์
