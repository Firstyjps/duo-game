# Game Design

> แก้ผ่าน PR · เรื่องที่ตัดสินแล้วให้ลง `DECISIONS.md` ด้วย
> สถานะ: **ตกลงแล้วทั้งคู่** (#8 ร่างโดย Few · Kron approve ใน #9)

## Pitch (1 ย่อหน้า)
Action RPG แบบ real-time ภาพ pixel art มุม top-down 3/4 เล่นคนเดียวบน PC — ต่อสู้ใช้ฝีมือแบบ Souls-lite (อ่านท่าศัตรู, dodge, จัดการ stamina) ผสมการล่าของและสร้าง build ลึก ๆ แบบ Diablo / Path of Exile ในโลกที่มืดและมีแสงสวยแบบ Core Keeper

**Ref:** gameplay — Dimraeth, Diablo, Path of Exile, Soul Knight, Ragnarok, Albion Online · art — Dimraeth, Romestead, Core Keeper

## Core loop
- **30 วินาที:** สู้ — อ่าน telegraph ของศัตรู → หลบ/โจมตี/ใช้สกิล
- **5 นาที:** เคลียร์ห้อง/ชั้นดันเจี้ยน → เก็บดรอป → เทียบและเปลี่ยนของ
- **1 ชั่วโมง:** อัปสกิล/ปรับ build → ลงดันเจี้ยนที่ยากขึ้น → ล้มบอส

## Platform / input
- PC (Steam) · เมาส์+คีย์บอร์ด และจอย
- Single-player (co-op ไว้ทีหลัง — ดู "ไม่ทำ")

## Art direction
| เรื่อง | สเปก |
|---|---|
| มุมมอง | top-down 3/4 (แบบ Zelda: ALttP / Romestead / Core Keeper) — **ไม่ใช่** isometric |
| Rendering | Godot 2D: `TileMapLayer` + y-sort · ความลึกได้จากแสงและการเรียงลำดับ ไม่ใช้โมเดล 3D |
| ขนาด tile | **32×32 px** · ตัวละครสูงประมาณ 48–64 px |
| ความละเอียดฐาน | 960×540 · stretch `viewport` + aspect `expand` + scale `integer` → 1080p = ×2 พอดี · 1440p = ×2 เห็นพื้นที่ 1280×720 · 4K = ×4 · HUD ต้อง anchor ขอบจอ · ระยะ aggro/spawn ห้ามผูกกับขนาดจอ |
| Texture | filter `nearest` (pixel คม) · ไม่หมุน/scale sprite แบบไม่เป็นจำนวนเต็ม |
| แสง | `CanvasModulate` ทำฉากมืด + `PointLight2D` (คบเพลิง, เวท, ดรอป) · normal map เฉพาะ sprite หลัก |
| Palette | palette กลางไฟล์เดียวใน `game/core/assets/` ใช้ร่วมกันทั้งสองคน (เลือกทีหลัง) |
| กล้อง | ตามผู้เล่นแบบนุ่ม · snap ทีละ pixel ด้วย `rendering/2d/snap/snap_2d_transforms_to_pixel` (เปิดแล้ว ไม่ต้องเขียนเอง) |
| Combat readability | ศัตรูทุกตัวต้องมี telegraph (ท่าเตรียม + VFX) ก่อนโจมตี |

## ระบบหลัก
| ระบบ | เจ้าของ | สถานะ |
|---|---|---|
| ผู้เล่น + ต่อสู้ + สกิล/build + UI/HUD | _ข้อเสนอ: ระบบ A_ | ยังไม่เริ่ม |
| ดันเจี้ยน/ห้อง + ศัตรู AI + loot/ไอเทม | _ข้อเสนอ: ระบบ B_ | ยังไม่เริ่ม |

> ใครถือระบบไหน → ตกลงกันแล้วแก้ `docs/OWNERS.md` ใน PR แยก · จุดข้ามระบบแรกที่ต้องมี contract: ความเสียหาย/hit, telegraph ของศัตรู, การดรอปไอเทม

## ขอบเขต MVP (ตัดได้อะไรตัด)
- [ ] 1 อาชีพ, สกิล 3–4 อัน, dodge + stamina
- [ ] ดันเจี้ยน 1 แห่ง (หลายห้อง) + บอส 1 ตัว
- [ ] ศัตรู 3–5 แบบ มี telegraph ชัดเจน
- [ ] ดรอปไอเทม + ใส่ของ (stat แบบ random ง่าย ๆ)
- [ ] ระบบแสงในดันเจี้ยน

## ไม่ทำ (อย่างน้อยใน MVP)
- co-op / online / MMO
- สร้างฐาน / crafting
- หลายเผ่า / หลายอาชีพ
- open world
