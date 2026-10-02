# ทดสอบตัวละคร Merakintsugi (ของทิ้งได้)

ลองใส่สไปรต์ Merakintsugi ให้ Player ตัวจริง เพื่อดูหน้าตาในเกม — **ตัวละครจริงจะออกแบบใหม่ทีหลัง** ห้ามใช้ในงานที่ปล่อยจริง
(sample ของชุดที่ขาย + เฟรม PixelLab ที่สร้างต่อจากภาพนั้น: ยังไม่ได้เช็คสิทธิ์เชิงพาณิชย์)

- เปิด: `godot --path game res://mockup/merakintsugi/merakintsugi_sandbox.tscn`
- `merakintsugi_skin.gd` = โหนดลูกของ Player เปลี่ยนเฟรมตาม state (ไม่แก้ `player.gd`)
- ข้อจำกัด: สไปรต์มีแค่หันซ้าย/ขวา (เกมนี้เล็ง 360°) · ท่ามาจากเกม platformer มุมข้าง
