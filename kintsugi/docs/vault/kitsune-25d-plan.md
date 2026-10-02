# Kintsugi Run → 2.5D (แผนพัฒนาทั้งระบบ) — ร่าง รออนุมัติ

สร้าง: 2026-10-02 (Claude Desktop) · สถานะ: **รอ user เลือกทางเลือกหลัก 4 ข้อ ยังไม่เริ่มลงมือ**

## จุดตั้งต้น
- เกม v4 (single-file canvas, ~1,200 บรรทัด) 2 ด่าน 26 ท่า (PixelLab 23 + ต้นฉบับ 3) เสียง WebAudio
- มีเกมซ้ำอีกชุด: `~/Desktop/Kitsune/game/` (ES modules โดยอีก session) → ต้องรวมเป็นโค้ดเบสเดียวก่อน
- ข้อจำกัด: PixelLab trial หมด (40/40) · ศัตรูยังเป็นก้อนวาดด้วยโค้ด · มีหลาย session/Antigravity แก้ไฟล์ชนกันมาแล้ว 2 ครั้ง

## แนวทางที่แนะนำ: HD-2D side-view (แบบ Octopath)
ตัวละคร/ศัตรูยังเป็นสไปรต์ 2D (billboard) ในโลก 3D, gameplay อยู่บนระนาบ x/y เหมือนเดิม (ท่า 26 ท่าใช้ได้หมด), กล้อง perspective เอียงเล็กน้อย, render ที่ 480×270 แล้วขยายแบบ nearest ให้คงความเป็นพิกเซล
Tech: Three.js (ESM จาก jsdelivr ใช้ใน Artifact ได้) + postprocessing

## สถาปัตยกรรม
- core/ loop 120Hz, input (คีย์/จอย/สัมผัส + remap), save, audio
- sim/ ไม่ผูกกับการวาด: player state machine อ่าน moves.json, physics/tiles, combat (hitbox/hurtbox ต่อเฟรม, hitstop, poise), enemy AI, level loader
- render2d/ (ตัวเดิม ไว้ debug) · render3d/ (Three.js: tile→instanced blocks, sprite billboard, lights, shadows, parallax 3D, particles, post FX)
- content/ levels/*.json, moves.json, enemies.json · tools/ sprite pipeline, level editor, playtest bots

## เฟส (ประมาณการ)
0. ตัดสินใจ + รวมโค้ดเบส (0.5 วัน)
1. Refactor sim/render แยก, moves data-driven, ด่านเป็น JSON, 2D เหมือนเดิมทุกพิกเซล (1–2 วัน)
2. Prototype 2.5D: ฉาก 3D, บล็อก, billboard, กล้อง, สลับ 2D/2.5D ได้ (2–3 วัน)
3. ความสวย: แสงจันทร์/โคม/เศษทองเรือง, เงา, หมอก, bloom, DOF/tilt-shift, VFX 3D, กล้องตามจังหวะต่อสู้ (2–3 วัน)
4. ต่อสู้ + ศัตรู 4 แบบ + บอส, hitbox ต่อเฟรม, gauge คินสึงิ (3–4 วัน)
5. โลก + ความก้าวหน้า: 3 โซน, แผนที่, ปลดล็อกท่า, เซฟ, ศาลเจ้า (3–4 วัน)
6. UI/UX/เสียง: หน้าเริ่ม, pause, ตั้งค่า, จอย, เพลงต่อโซน (2 วัน)
7. เครื่องมือ + QA + perf + deploy (1–2 วัน)

## คำถามที่รอคำตอบ
สไตล์ 2.5D · โค้ดเบสหลัก · งบภาพ (PixelLab อัปเกรด?) · ขอบเขตเกม (metroidvania หรือด่านต่อด่าน)

## อัปเดต 22:20 — user ขอ prototype ทุกแบบก่อนเลือก (ตอบแล้ว: โค้ดเบส = Kitsune repo, ศัตรูวาดด้วยโค้ดก่อน, ขอบเขต = Metroidvania เล็ก)
- PixelLab อัปเป็น Tier 1 แล้ว (2,000 gen/เดือน รีเซ็ต 2 พ.ย.)
- `~/Desktop/Kitsune/prototypes/25d/`
  - `hd2d/` แบบ A (HD-2D มุมข้าง, r3d.js: Three.js r128 + bloom + tilt-shift, off-axis camera ให้ระนาบเกมตรง 1:1 กับ overlay 2D) + แบบ B (`#depth`: ชั้นถ้ำด้านหลังด่าน 1, ประตูที่ col 18/55)
  - `beatemup/` แบบ C → agy บัญชี 3 (TASK.md)
  - `iso/` แบบ D → agy บัญชี 1 (TASK.md)
  - `WORKER_SPEC_COMMON.md` สเปกกลางให้ worker, `index.html` hub
