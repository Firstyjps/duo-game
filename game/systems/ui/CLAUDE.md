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
- `InputConfig.ensure_input_actions()` ต้องเติม default เฉพาะตอนที่ยังไม่มี action นั้น (`has_action`) เพื่อไม่ให้ทับค่าที่ผู้เล่น rebind ไว้แล้ว
- การ rebind ต้องแทนที่ที่ index เดิมใน array ของ action (ไม่ต่อท้าย) และหากเป็นปุ่มที่มีใน action เดียวกันอยู่แล้วให้สลับตำแหน่ง (swap)
- ตรวจสอบปุ่มซ้ำต้องกันทั้งข้าม action ในเกม และปุ่มลัดระบบ UI (`ui_accept`, `ui_cancel`, `ui_pause`)
- `SettingsConfig.set_fullscreen()` ต้องไม่บังคับ `WINDOW_MODE_WINDOWED` หากหน้าจอไม่ได้เป็น Fullscreen อยู่ และคืนค่า mode ก่อนหน้า (ค่าเริ่มต้น `MAXIMIZED`)
- เมนูและคอมโพเนนต์ทั้งหมด (`TitleScreen`, `PauseMenu`, `SettingsMenu`, `KeyRebind`) ต้องรองรับ custom config path ใน `setup()` เพื่อให้เทสต์ไม่ไปแตะไฟล์คอนฟิกจริงใน `user://`
- เมื่อรันเทสต์ ต้องคืนค่า InputMap และ TranslationServer locale ให้กลับเป็นค่าเริ่มต้นเสมอ

## เทสต์
- `game/tests/test_ui_settings.gd`
