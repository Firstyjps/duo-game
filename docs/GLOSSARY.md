# Glossary — คำเรียกในเกม

ใช้คำเดียวกันทั้งในโค้ด เอกสาร และคุยกับ AI · เพิ่มคำใหม่ใน PR ที่เริ่มใช้คำนั้น · เรียงตามตัวอักษร

| คำ (ในเกม/คุยกัน) | ชื่อในโค้ด | ความหมาย | ระบบ |
|---|---|---|---|
| _ตัวอย่าง:_ ห้อง | `Room` | พื้นที่ 1 จอ ปิดประตูจนกว่าศัตรูหมด | world |
| ขวดชา | `flask` · `flask_heal` · `flask_max` · `Player.State.DRINK` · `flasks_changed` | ขวดชาฟื้นพลัง ดื่มเพื่อฟื้น HP มีจำนวนจำกัด เติมเต็มเมื่อเกิดใหม่/revive ขณะดื่มเดินช้าลงและเสี่ยงโดนตีขัด | player |
| ข้อมูลดาเมจ | `DamageInfo` | ข้อมูลการโจมตี 1 ครั้ง (ดาเมจก่อนหัก defense, knockback, stagger) | core/combat |
| ท่าชาร์จ | `Charge Attack` · `charge_time` · `charge_mult` | ท่าโจมตีหนักด้วยการกดค้าง ≥ `charge_time` แล้วปล่อย คูณดาเมจ/knockback/stagger และใช้ stamina เพิ่ม | player |
| ท่าเตรียม | telegraph · `TelegraphMarker` (วงเตือนบนพื้น) | ท่า/VFX บอกล่วงหน้าก่อนศัตรูโจมตี (บังคับทุกท่า) | enemy |
| ฝั่ง / ทีม | `Combat.Team` | PLAYER / ENEMY / NEUTRAL — ฝั่งเดียวกันไม่โดนกัน | core/combat |
| พลังชีวิต / HP | `Health` | HP ของผู้เล่น/ศัตรู/ของทำลายได้ | core/combat |
| แพรี่ / ปัดป้อง | `Parry` · `Player.State.PARRY` · `parried` | การตั้งการ์ดปัดป้องในหน้าต่าง `parry_window` เพื่อไม่เสีย HP และได้ stamina คืน พลาดจะโดนตีเต็มช่วง recovery | player |
| ถูกปัด / deflect | `Hurtbox.deflecting` · `Hitbox.deflected` · `EventBus.attack_deflected` | การโจมตีที่โดน parry: ผู้ป้องกันไม่เสียเลือด ผู้ตีได้ `deflected` แทน `hit_landed` | core/combat |
| ฟื้น / respawn | `Player.revive()` · `EventBus.player_respawn_requested` | dungeon สั่งผู้เล่นกลับมาเต็มเลือดที่จุดเกิดหลังตาย | player/dungeon |
| ล็อคเป้า | `Lock-on` · `lock_target` · `lock_target_changed` | การล็อคเป้าศัตรูในระยะ `lock_range` ให้ `aim` หันตามเป้าเสมอ สลับเป้าได้ และปลดเมื่อเป้าตายหรือหลุดระยะ | player |
| ช่วง active | — | ช่วงเฟรมที่ Hitbox ของท่าเปิดอยู่ (`activate()` → `deactivate()`) | core/combat |
| i-frames / อมตะชั่วคราว | `Hurtbox.invulnerable` | ช่วงที่โดนตีไม่เข้า เช่นระหว่าง dodge | core/combat |
| ตัวรับดาเมจ | `Hurtbox` | พื้นที่บนตัวที่โดนตีได้ | core/combat |
| ตัวทำดาเมจ | `Hitbox` | พื้นที่ของท่าโจมตีที่ทำดาเมจ | core/combat |
| เซ / poise | `DamageInfo.stagger` | แรงขัดท่า — ผู้รับตัดสินเองว่าเซไหม | core/combat |
| สไลม์ | `Slime` · `enemy_id = &"slime"` | ศัตรูตัวแรก: เด้งเข้าหา → ย่อตัว + กระพริบแดง (telegraph) → พุ่งทับ | enemy |
| เงาตามตัว | after-image · `_spawn_afterimage()` | สำเนาสไปรต์จาง ๆ ที่ทิ้งไว้ระหว่างพุ่ง | enemy |
| บอสมิโนทอร์ | `boss_minotaur` (ยังไม่มีคลาส) | ผู้สมัครบอส MVP: วัวถือขวานสงคราม 8 ทิศ (ยังไม่ได้ตัดสินว่าเป็นบอสตัวจริง) | enemy |
| บอสสไลม์ | `BossSlime` · `enemy_id = &"boss_slime"` | บอสสไลม์ (Abyssal Maw): ทุบพื้น (AoE + shake 0.5), กระโดดทับ (AoE + shake 0.6), แตกลูก (HP < 50% สูงสุด 4 ตัว) ทุกท่ามี telegraph | enemy |
| เลื่อนกล้องข้ามห้อง | `GameCamera.slide_to` | เลื่อนกล้องข้ามห้องแบบนุ่มนวล โดยไม่ follow ระหว่างเลื่อนและตั้ง bounds เมื่อจบ | camera |
| จัดเฟรม lock-on | `GameCamera.set_focus_target` | จัดเฟรมจุดมองระหว่างผู้เล่นกับเป้าหมายตามน้ำหนักและจำกัดระยะ max_focus_offset | camera |
| ซิลูเอตเมื่อถูกบัง | `OcclusionSilhouette` | สำเนาสไปรต์สีม่วงอ่อนวาดทับเมื่อตัวละครถูกวัตถุข้างหน้าบังในมุมมอง isometric | player/occlusion |
| ทิศ 8 ทิศ | `Dir8` | ทิศของสไปรต์บนจอ ชื่อตาม PixelLab (south, south-east, …) ลำดับ = แถวใน atlas | player/iso |
| สไปรต์ 8 ทิศ | `DirSprite` | AnimatedSprite2D เล่นท่า `"<ท่า>_<ทิศ>"` · `set_facing()` + `play_action()` | player/iso |
| ตัวเอก Kintsugi (ทดสอบ) | `kintsugi_hero` | สาวยักษ์ผมขาวม่วง ชุดน้ำเงินลายทอง 64 px 8 ทิศ (PixelLab อิง Merakintsugi — ยังไม่ใช่ตัวจริง) | player |
| พุ่งหลบ | `dodge` | ท่าหลบแบบพุ่งต่ำ (ไม่กลิ้ง/ไม่หมุนตัว) | player |
| เป้า lock-on | `lock_target` · `LockMarker` | เครื่องหมายบอกเป้าหมายที่กำลังล็อก แสดงเหนือตัวศัตรูตามตำแหน่งโลก | hud |
| เมนูหน้าเริ่ม / Title Screen | `TitleScreen` | หน้าจอหลักก่อนเข้าเล่นเกม (เริ่ม/ตั้งค่า/ออก) | ui |
| เมนูหยุดเกม / Pause Menu | `PauseMenu` | หน้าต่างหยุดเกมขณะเล่น คุมผ่าน `ui_pause` (Esc / จอย Start) | ui |
| เมนูตั้งค่า / Settings Menu | `SettingsMenu` | หน้าต่างปรับเสียง Master/Music/SFX, เต็มจอ, ภาษา และปุ่ม | ui |
| เปลี่ยนปุ่ม / Key Rebind | `KeyRebind` | ระบบและหน้าต่างตั้งปุ่มใหม่ทั้งคีย์บอร์ดและจอย กันปุ่มซ้ำ | ui |

## คำที่ห้ามใช้ปนกัน
<!-- เช่น "ด่าน" vs "ห้อง" — ตกลงว่าใช้คำไหน -->
