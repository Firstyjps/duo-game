# kintsugi/ — งาน Kintsugi / Merakintsugi (ข้อมูลอ้างอิง ไม่ใช่ส่วนของเกม Godot)

รวมทุกอย่างจากโปรเจกต์ Kitsune / Merakintsugi (Kron, 2026-10-02) มาไว้ที่เดียว · อยู่นอก `game/` → Godot ไม่ import, CI ไม่แตะ
⚠️ ตัวละคร Merakintsugi = **ของทดสอบ** (sample ของชุดที่ขาย + เฟรม PixelLab ที่สร้างต่อจากภาพนั้น ยังไม่ได้เช็คสิทธิ์เชิงพาณิชย์) — ตัวละครจริงจะออกแบบใหม่

## เปิดดู (เว็บทั้งหมด ต้องผ่าน static server)
```
python3 -m http.server 8740 -d kintsugi
```
| หน้า | ลิงก์ (หลังเปิด server) |
|---|---|
| Hub โปรเจกต์ | http://localhost:8740/ |
| Studio (ตรวจเฟรม ดูท่า concept เอกสาร) | /studio/ |
| เกมเว็บ v4 — 2 ด่าน 23 แอนิเมชัน PixelLab | /game-pixellab/ |
| เกมเว็บแบบโมดูล (session อื่นทำ) | /game/ |
| ต้นแบบมุมมอง 2.5D ทั้ง 4 แบบ | /prototypes/25d/ (A HD-2D · B `hd2d/#depth` · C beat 'em up ยังไม่เสร็จ · **D isometric = แบบที่เลือก**) |
| Moveset gallery (GIF ทุกท่า) | /showcase/ |

ฉากทดสอบใน Godot: `godot --path game res://mockup/merakintsugi/merakintsugi_sandbox.tscn` (โฟลเดอร์ `game/mockup/merakintsugi/`)

## โครงสร้าง
| โฟลเดอร์ | มีอะไร |
|---|---|
| `game-pixellab/` | เกม v4 single-file + `atk.png/atk.js` (PixelLab 23 ท่า) + `pixellab/` เฟรมดิบทุกท่า + `build_atk.py` (seq/align/flip) + `fetch.sh` |
| `prototypes/25d/` | ต้นแบบ 4 แบบ + `HANDOFF.md` (แผน isometric, การตัดสินใจ, คำถามที่ค้าง) + สเปกที่ส่งให้ worker |
| `showcase/` | `all_actions.gif` + GIF แยก 26 ท่า + `build_showcase.py`, `gen_html.py` |
| `assets/` | `sprites/` (aseprite + sheet + PixelLab) · `concepts/` (ภาพคอนเซปต์ตัวละคร) · `tiny-swords/` (asset pack ของ Pixel Frog) · `reference/gif_timing.json` |
| `source/` | ไฟล์ต้นฉบับ sample: `.aseprite`, sprite sheet, เฟรมแตกแล้ว, zip, timing metadata |
| `docs/design/` | `CHARACTER_DESIGN_ANALYSIS_GUIDE.md`, `MOVESET_REFERENCE.md` |
| `docs/vault/` | สำเนาบันทึกจาก Vault: แผน isometric (handoff), แผน 2.5D, สถานะเกม v1–v4 |
| `studio/`, `index.html`, `shared/`, `tools/`, `docs/` | hub + studio ของ Kitsune (`docs/KITSUNE_README.md` = README เดิม) |

## ไม่ได้ใส่
- GIF/ภาพตัวอย่างของชุด Merakintsugi ที่ขาย (มีลายน้ำ "PREVIEW") + เฟรมที่แตกจาก GIF พวกนั้น + วิดีโอจาก YouTube → แท็บ "ท่าทั้งหมด" ใน Studio จะไม่มีภาพอ้างอิงขึ้น
- ไฟล์ซ้ำชื่อลงท้าย " 2" (สำเนาจากระบบไฟล์ชนกัน)
