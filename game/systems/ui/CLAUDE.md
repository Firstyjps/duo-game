# ระบบ: ui (เมนู, ตั้งค่า, Rebind ปุ่ม, หยุดเกม)

- เจ้าของ: @Firstyjps (Kron) · issue: #42

## ทำอะไร
- **TitleScreen** (`title/title_screen.tscn`): เมนูหน้าเริ่มเกม ชื่อเกม "Kintsugi", ปุ่มเริ่มเกม (`@export_file start_scene` default `res://mockup/mockup.tscn`), ตั้งค่า, ออกจากเกม
- **PauseMenu** (`pause/pause_menu.tscn`): เมนูหยุดเกม ทำงานเป็น `CanvasLayer` พร้อม `process_mode = PROCESS_MODE_ALWAYS` (ทำงานแม้ `tree.paused = true`), รองรับ Esc / จอย Start, ปุ่มกลับเกม, ตั้งค่า, กลับหน้าเริ่ม
- **SettingsMenu** (`settings/settings_menu.tscn`): ปรับระดับเสียง Master, Music, SFX (สร้าง audio buses ตอน runtime), สลับจอเต็ม/หน้าต่าง, สลับภาษา TH/EN (ผ่าน `TranslationServer`), เซฟ/โหลด `user://settings.cfg`
- **KeyRebind** (`settings/key_rebind.tscn`): รายการ action (`move_up`, `move_down`, `move_left`, `move_right`, `attack`, `dodge`, `ui_pause`), กดตั้งปุ่มใหม่ได้ทั้ง Keyboard, Mouse และ Joypad, กันปุ่มซ้ำ, รีเซ็ตค่าเริ่มต้น, เซฟ/โหลด `user://input.cfg`

## ไฟล์สำคัญ
| ไฟล์ | หน้าที่ |
|---|---|
| `title/title_screen.tscn` + `.gd` | หน้าจอหลัก เริ่มเกม/ตั้งค่า/ออก |
| `pause/pause_menu.tscn` + `.gd` | หน้าต่างหยุดเกม Esc/Joypad Start |
| `settings/settings_menu.tscn` + `.gd` | เมนูตั้งค่าเสียง/ภาพ/ภาษา/ปุ่ม |
| `settings/key_rebind.tscn` + `.gd` | แผง rebind ปุ่ม คีย์บอร์ดและจอย |
| `settings/settings_config.gd` | จัดการ ConfigFile `user://settings.cfg`, AudioServer buses, Fullscreen, i18n |
| `settings/input_config.gd` | จัดการ ConfigFile `user://input.cfg`, InputMap actions, กันปุ่มซ้ำ, events serialize |
| `i18n/ui.csv` | ตารางคำแปลภาษาอังกฤษและไทย |
| `debug/pause_sandbox.tscn` + `.gd` | Sandbox ทดสอบการหยุดเกมร่วมกับวัตถุเคลื่อนไหว |

## ส่ง / รับ ข้ามระบบ
- เปลี่ยน Scene ไปยัง `start_scene` (mockup หรือ gameplay scene) เมื่อกดเริ่มเกม
- ควบคุม `SceneTree.paused` เพื่อหยุดเกมและรันต่อ
- จัดการ `InputMap` ตอน runtime โดยไม่ต้องแก้ `project.godot`
- ใช้ `InputConfig.load_and_apply()` และ `SettingsConfig.load_and_apply()` แบบ static เมื่อเปิดเมนู

## กติกาเฉพาะระบบ / กับดักที่เคยเจอ
- อย่าใช้ `@onready` สำหรับโหนดที่ต้องเทสต์นอก tree — ให้ผูกโหนดใน `setup()`
- `get_path()` บนโหนดจะเกิด runtime error ถ้าโหนดยังไม่ได้อยู่ใน SceneTree — สำหรับ focus navigation ให้ใช้ relative `NodePath("../NodeName")` หรือตรวจสอบ `if is_inside_tree():` ก่อนเรียก `get_path()`
- การเข้าถึง `get_tree()` ให้ตรวจสอบ `is_inside_tree()` ก่อนเสมอ หรือใช้ fallback `Engine.get_main_loop() as SceneTree` เพื่อให้รันใน headless test ได้อย่างปลอดภัย
- ห้ามแก้ `default_bus_layout.tres` — ให้ใช้ `SettingsConfig.ensure_audio_buses()` ในการสร้าง bus "Music" และ "SFX" ตอน runtime
- จอยสติ๊กสำหรับ `ui_pause` ให้ลงทะเบียน `JOY_BUTTON_START`

## เทสต์
- `game/tests/test_ui_settings.gd`
