# ระบบ: ui (เมนู, ตั้งค่า, Rebind ปุ่ม, หยุดเกม)

- เจ้าของ: @Firstyjps (Kron) · issue: #42

## ทำอะไร
- **TitleScreen** (`title/title_screen.tscn`): เมนูหน้าเริ่มเกม ชื่อเกม "Kintsugi", ปุ่มเริ่มเกม (`@export_file start_scene` default `res://mockup/mockup.tscn`), ตั้งค่า, ออกจากเกม
- **PauseMenu** (`pause/pause_menu.tscn`): เมนูหยุดเกม ทำงานเป็น `CanvasLayer` พร้อม `process_mode = PROCESS_MODE_ALWAYS` (ทำงานแม้ `tree.paused = true`), รองรับ Esc / จอย Start, ปุ่มกลับเกม, ตั้งค่า, กลับหน้าเริ่ม
- **SettingsMenu** (`settings/settings_menu.tscn`): ปรับระดับเสียง Master, Music, SFX (สร้าง audio buses ตอน runtime), สลับจอเต็ม/หน้าต่าง, สลับภาษา TH/EN (ผ่าน `TranslationServer`), เซฟ/โหลด `user://settings.cfg`
- **KeyRebind** (`settings/key_rebind.tscn`): รายการ action (`move_up`, `move_down`, `move_left`, `move_right`, `attack`, `dodge`, `parry`, `lock_on`, `ui_pause`), กดตั้งปุ่มใหม่ได้ทั้ง Keyboard, Mouse และ Joypad, กันปุ่มซ้ำ, รีเซ็ตค่าเริ่มต้น, เซฟ/โหลด `user://input.cfg`

## ไฟล์สำคัญ
| ไฟล์ | หน้าที่ |
|---|---|
| `title/title_screen.tscn` + `.gd` | หน้าจอหลัก เริ่มเกม/ตั้งค่า/ออก |
| `pause/pause_menu.tscn` + `.gd` | หน้าต่างหยุดเกม Esc/Joypad Start |
| `settings/settings_menu.tscn` + `.gd` | เมนูตั้งค่าเสียง/ภาพ/ภาษา/ปุ่ม |
| `settings/key_rebind.tscn` + `.gd` | แผง rebind ปุ่ม คีย์บอร์ดและจอย |
| `settings/settings_config.gd` | จัดการ ConfigFile `user://settings.cfg`, AudioServer buses, Fullscreen, ข้อความแปลใน `TRANSLATION_DATA` |
| `settings/input_config.gd` | จัดการ ConfigFile `user://input.cfg`, InputMap actions, กันปุ่มซ้ำ, events serialize |
| `debug/pause_sandbox.tscn` + `.gd` | Sandbox ทดสอบการหยุดเกมร่วมกับวัตถุเคลื่อนไหว |

## ส่ง / รับ ข้ามระบบ
- เปลี่ยน Scene ไปยัง `start_scene` (mockup หรือ gameplay scene) เมื่อกดเริ่มเกม
- ควบคุม `SceneTree.paused` เพื่อหยุดเกมและรันต่อ
- จัดการ `InputMap` ตอน runtime โดยไม่ต้องแก้ `project.godot`
- ใช้ `InputConfig.load_and_apply()` และ `SettingsConfig.load_and_apply()` แบบ static เมื่อเปิดเมนู
- ข้อความภาษา TH/EN ถูกจัดการเป็นแหล่งเดียวผ่าน `SettingsConfig.TRANSLATION_DATA` ในโค้ด และลงทะเบียนผ่าน `TranslationServer`

## กติกาเฉพาะระบบ / กับดักที่เคยเจอ
- อย่าใช้ `@onready` สำหรับโหนดที่ต้องเทสต์นอก tree — ให้ผูกโหนดใน `setup()`
- `get_path()` บนโหนดจะเกิด runtime error ถ้าโหนดยังไม่ได้อยู่ใน SceneTree — สำหรับ focus navigation ให้ใช้ relative `NodePath("../NodeName")` หรือตรวจสอบ `if is_inside_tree():` ก่อนเรียก `get_path()`
- การเข้าถึง `get_tree()` ให้ตรวจสอบ `is_inside_tree()` ก่อนเสมอ หรือใช้ fallback `Engine.get_main_loop() as SceneTree` เพื่อให้รันใน headless test ได้อย่างปลอดภัย
- ห้ามแก้ `default_bus_layout.tres` — ให้ใช้ `SettingsConfig.ensure_audio_buses()` ในการสร้าง bus "Music" และ "SFX" ตอน runtime
- จอยสติ๊กสำหรับ `ui_pause` ให้ลงทะเบียน `JOY_BUTTON_START`
- `InputConfig.ensure_input_actions()` ต้องเติม default เฉพาะตอนที่ยังไม่มี action นั้น หรือยังไม่มี event ใน category นั้น เพื่อไม่ให้ทับค่าที่ผู้เล่น rebind ไว้แล้ว
- ห้ามเอา Space ออกจาก `ui_accept` เด็ดขาด เพราะกระทบ UI ทั้งเกม ให้กันซ้ำเฉพาะตอน rebind เท่านั้น
- ระหว่างรอรับปุ่มใน `KeyRebind` ให้ข้าม event ที่ชนิดไม่ตรงกับช่อง (ช่องคีย์บอร์ดรับเฉพาะ Key/MouseButton, ช่องจอยรับเฉพาะ JoypadButton/JoypadMotion)
- `InputConfig.rebind()` ต้องค้นหา index ภายในชนิดเดียวกันเท่านั้น และสลับเฉพาะภายในชนิดเดียวกัน (ไม่กระทบชนิดอื่น)
- ตรวจสอบปุ่มซ้ำต้องครอบคลุมทั้ง action เกม (`move_*`, `attack`, `dodge`, `parry`, `lock_on`) และปุ่มระบบ UI (`ui_accept`, `ui_cancel`, `ui_pause`)
- `SettingsConfig.set_fullscreen()` ต้องไม่บังคับ `WINDOW_MODE_WINDOWED` หากหน้าจอไม่ได้เป็น Fullscreen อยู่ และคืนค่า mode ก่อนหน้า (ค่าเริ่มต้น `MAXIMIZED`)
- เมนูและคอมโพเนนต์ทั้งหมด (`TitleScreen`, `PauseMenu`, `SettingsMenu`, `KeyRebind`) ต้องรองรับ custom config path ใน `setup()` เพื่อให้เทสต์ไม่ไปแตะไฟล์คอนฟิกจริงใน `user://`
- เมื่อรันเทสต์ ต้องเก็บสำเนา InputMap (action → events) และ TranslationServer locale ก่อนเทสต์ แล้วคืนค่าเดิมจริงท้ายเทสต์

## เทสต์
- `game/tests/test_ui_settings.gd`
- `game/tests/test_ui_game_run.gd`
- `game/tests/test_ui_qa_smoke.gd`

## เพิ่ม action ใหม่
- action ใหม่ของ Player (เช่น `heal`) ต้องเพิ่มใน `InputConfig.ACTIONS` + `get_default_events()` ให้ตรงกับ `Player.ensure_input_actions()` — รายการปิดตาย ไม่สแกน InputMap (กัน action debug ของ sandbox)

## GameRun (เฟส 7 · #64)
- `run/game_run.tscn` = ฉากเล่นจริง: `level_scene` (@export) + Player + GameCamera + GameHud + PauseMenu + AudioDirector (ถ้ามี `res://systems/audio/audio_director.tscn`) · TitleScreen เริ่มที่ฉากนี้
- ด่าน: Marker2D กลุ่ม `player_spawn` = จุดเกิด · มี node กลุ่ม `respawn_handler` (เช่น Dungeon) = ด่านจัดการฟื้นเองผ่าน `EventBus.player_respawn_requested` ไม่งั้น GameRun ฟื้นผู้เล่นที่จุดเกิดหลัง `respawn_delay`
- ด่านทดสอบตอนนี้ `run/levels/courtyard_level.tscn` (ลานวัด + สไลม์ 3) → สลับเป็น dungeon จริงเมื่อ #39 merge

## QA Bot & Monitor (เฟส 7 · #66)
- `run/qa/qa_bot.gd` (`QaBot`): โหนดบอทจำลอง input ผ่าน `Player.set_intent()` (ตั้ง `player.manual_control = true`) หาศัตรูใกล้สุดด้วย Area2D mask layer enemy (หรือ EventBus/group) เข้าไปฟัน ล็อคเป้า สุ่ม dodge/parry เมื่ออยู่ในระยะอันตราย ดื่มขวดเมื่อ HP < 40% และเดินสุ่ม/แก้ติดกำแพง
- `run/qa/qa_monitor.gd` (`QaMonitor`): โหนดเก็บ metrics รายวินาที (FPS, frame time p95/max จาก delta ต่อเฟรม, `cpu_*` จาก `TIME_PROCESS` เป็นข้อมูลประกอบเท่านั้น (อัปเดตวินาทีละครั้ง รวม vsync), node count, orphans, memory) บันทึก event จาก EventBus ตรวจจับ Player stuck anomaly (>5s ไม่ใช่ MOVE/DEAD) และ orphan leak บันทึก `user://qa_report.json` + พิมพ์สรุปบรรทัดเดียว `QA: fps_avg=.. p95_ms=.. max_ms=.. nodes_max=.. orphans=.. kills=.. deaths=.. anomalies=..`
- รันอัตโนมัติ: `godot --path game res://systems/ui/run/game_run.tscn -- --autoplay --qa-seconds=60`
- smoke (headless, 600 physics frames, exit 1 ถ้าบอทไม่ได้ตีโดนศัตรู/ฆ่าไม่ได้/anomaly): `godot --headless --path game --script res://systems/ui/run/qa/qa_smoke_runner.gd`
- `GameRun.setup()` เรียกซ้ำได้ (กันฉากซ้อนเมื่อ runner เรียกก่อน `_ready`)
- กับดัก/ข้อควรระวัง:
  - การเทสต์ใน headless แบบเรียก `tick(delta)` นอก SceneTree ห้ามเรียก `move_and_slide()` เพราะ physics space ยังไม่ได้ถูกสร้าง ให้เรียก `tick(delta)` ของ Player ตรง ๆ
  - บอทต้องตั้ง `player.manual_control = true` เพื่อไม่ให้ `Player._read_input()` เขียนทับค่า intent จาก Input จริง
  - ใน headless test ให้ตั้ง `monitor.auto_quit = false` เพื่อไม่ให้สั่งปิด test runner ก่อนตรวจ assertion
