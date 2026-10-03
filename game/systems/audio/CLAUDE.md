# ระบบ: เสียง (Audio)

- เจ้าของ: @Firstyjps · contract ที่เกี่ยว: `docs/contracts/damage.md`, `docs/contracts/feedback.md`, `docs/contracts/dungeon-flow.md`

## ทำอะไร
จัดการเสียงเอฟเฟกต์ (SFX) และเพลงประกอบ (BGM) ธีมญี่ปุ่นยามค่ำ (In/Miyako-bushi scale)
ควบคุม Audio Bus, pooling ผู้เล่นเสียงทั้ง 2D และ non-2D พร้อม crossfade เพลงอัตโนมัติตามเหตุการณ์ในเกม

## ไฟล์สำคัญ
| ไฟล์ | หน้าที่ |
|---|---|
| `audio_director.gd` | ควบคุม audio bus, player pool, crossfade เพลง, และตอบสนองต่อ EventBus |
| `audio_director.tscn` | Scene โหนด AudioDirector สำหรับวางในฉากเกม |
| `sfx/` | ไฟล์เสียง .wav ทั้งหมด 16 ไฟล์ (14 SFX + 2 Music loops) |
| `tools/gen_sfx.py` | สคริปต์ Python สังเคราะห์เสียงและเพลงซ้ำได้ ไม่พึ่ง external library |
| `debug/audio_sandbox.tscn` | Sandbox จำลองเสียงและ EventBus ผ่านปุ่มจอและคีย์บอร์ด |

## ส่ง / รับ ข้ามระบบ
- listen: `EventBus.damage_dealt` — เล่น `hit_player` หาก target อยู่ในกลุ่ม `player`, นอกนั้นเล่น `hit_flesh`
- listen: `EventBus.attack_deflected` — เล่นเสียง `parry`
- listen: `EventBus.enemy_died` — เล่นเสียง `enemy_die` ตามตำแหน่งศัตรู
- listen: `EventBus.player_died` — fade out เพลงจนเงียบ
- listen: `EventBus.boss_engaged` — เล่น `boss_roar` และ crossfade ไป `music_combat`
- listen: `EventBus.room_started` — crossfade ไป `music_combat`
- listen: `EventBus.room_cleared` — crossfade ไป `music_explore` และเล่นเสียง `door_open`
- listen: `EventBus.screen_shake_requested` — เล่นเสียง `thud` หาก strength >= 0.4

## กติกาเฉพาะระบบ / กับดักที่เคยเจอ
- `AudioDirector` วางในฉากเกม **ไม่ใช่ autoload**
- ต้องตรวจหา Audio Bus `Music` และ `SFX` ก่อนสร้างใหม่ด้วย `ensure_buses()` เสมอ เพราะระบบเมนู (#42) ใช้ชื่อเดียวกัน
- Node นอก SceneTree ห้ามสั่ง `.play()` ตรง ๆ (ใช้ `is_inside_tree()` guard เพื่อให้ deterministic unit test รันได้)
- ไฟล์เพลง WAV ทั้ง 2 แทร็กต้องเปิด `loop_mode = LOOP_FORWARD` (1) ใน `.import` หรือตั้งผ่าน code

## เทสต์
- `game/tests/test_audio_director.gd`
