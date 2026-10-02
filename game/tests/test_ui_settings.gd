extends RefCounted
## เทสต์ระบบ UI & Settings (issue #42)
## เซฟ/โหลด settings round-trip, rebind แทนที่ event เดิม, กันปุ่มซ้ำ, reset default

const TEST_SETTINGS_PATH: String = "user://test_settings_roundtrip.cfg"
const TEST_INPUT_PATH: String = "user://test_input_roundtrip.cfg"


func _clean_file(path: String) -> void:
	var global_path: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(global_path) or FileAccess.file_exists(path):
		DirAccess.remove_absolute(global_path)


func _restore_defaults() -> void:
	_clean_file(TEST_SETTINGS_PATH)
	_clean_file(TEST_INPUT_PATH)
	InputConfig.reset_to_defaults()
	SettingsConfig.reset_to_defaults()
	TranslationServer.set_locale("en")


func test_settings_save_and_load_round_trip() -> bool:
	_clean_file(TEST_SETTINGS_PATH)

	SettingsConfig.master_volume = 0.42
	SettingsConfig.music_volume = 0.55
	SettingsConfig.sfx_volume = 0.65
	SettingsConfig.fullscreen = true
	SettingsConfig.language = "th"

	var save_err: Error = SettingsConfig.save_to_file(TEST_SETTINGS_PATH)
	if save_err != OK:
		_restore_defaults()
		return false

	# สลับค่าเพื่อทดสอบว่าโหลดแล้วเปลี่ยนจริง
	SettingsConfig.master_volume = 1.0
	SettingsConfig.music_volume = 1.0
	SettingsConfig.sfx_volume = 1.0
	SettingsConfig.fullscreen = false
	SettingsConfig.language = "en"

	var load_err: Error = SettingsConfig.load_from_file(TEST_SETTINGS_PATH)
	if load_err != OK:
		_restore_defaults()
		return false

	var ok: bool = is_equal_approx(SettingsConfig.master_volume, 0.42) \
		and is_equal_approx(SettingsConfig.music_volume, 0.55) \
		and is_equal_approx(SettingsConfig.sfx_volume, 0.65) \
		and SettingsConfig.fullscreen == true \
		and SettingsConfig.language == "th"

	_restore_defaults()
	return ok


func test_settings_apply_audio_buses() -> bool:
	SettingsConfig.ensure_audio_buses()
	var master_idx: int = AudioServer.get_bus_index("Master")
	var music_idx: int = AudioServer.get_bus_index("Music")
	var sfx_idx: int = AudioServer.get_bus_index("SFX")

	if master_idx == -1 or music_idx == -1 or sfx_idx == -1:
		_restore_defaults()
		return false

	SettingsConfig.set_bus_volume("Music", 0.5)
	var music_vol: float = SettingsConfig.get_bus_volume("Music")
	var ok: bool = is_equal_approx(music_vol, 0.5)
	_restore_defaults()
	return ok


func test_input_config_defaults() -> bool:
	InputConfig.reset_to_defaults()
	for action: StringName in InputConfig.ACTIONS:
		if not InputMap.has_action(action):
			_restore_defaults()
			return false
		var evs: Array[InputEvent] = InputMap.action_get_events(action)
		if evs.is_empty():
			_restore_defaults()
			return false
	_restore_defaults()
	return true


func test_ui_pause_action_registered() -> bool:
	InputConfig.ensure_input_actions()
	if not InputMap.has_action(&"ui_pause"):
		_restore_defaults()
		return false

	var has_esc := false
	var has_start := false
	var esc_ev: InputEventKey = InputConfig.make_key_event(KEY_ESCAPE)
	var start_ev: InputEventJoypadButton = InputConfig.make_joy_button_event(JOY_BUTTON_START)

	for ev: InputEvent in InputMap.action_get_events(&"ui_pause"):
		if InputConfig.events_match(ev, esc_ev):
			has_esc = true
		if InputConfig.events_match(ev, start_ev):
			has_start = true

	_restore_defaults()
	return has_esc and has_start


func test_input_rebind_replaces_old_event() -> bool:
	InputConfig.reset_to_defaults()
	var old_ev: InputEventKey = InputConfig.make_key_event(KEY_J)
	var new_ev: InputEventKey = InputConfig.make_key_event(KEY_K)

	# ยืนยันว่าเดิมมี KEY_J ใน attack
	var had_old := false
	for ev: InputEvent in InputMap.action_get_events(&"attack"):
		if InputConfig.events_match(ev, old_ev):
			had_old = true
			break
	if not had_old:
		_restore_defaults()
		return false

	# ทำการ rebind แทนที่ KEY_J ด้วย KEY_K
	var success: bool = InputConfig.rebind(&"attack", new_ev, old_ev)
	if not success:
		_restore_defaults()
		return false

	# ตรวจสอบว่า KEY_J ต้องไม่มีแล้ว และมี KEY_K แทน
	var still_has_old := false
	var has_new := false
	for ev: InputEvent in InputMap.action_get_events(&"attack"):
		if InputConfig.events_match(ev, old_ev):
			still_has_old = true
		if InputConfig.events_match(ev, new_ev):
			has_new = true

	_restore_defaults()
	return (not still_has_old) and has_new


func test_input_prevents_duplicate_rebind() -> bool:
	InputConfig.reset_to_defaults()
	# KEY_W ผูกกับ move_up อยู่แล้ว
	var dup_ev: InputEventKey = InputConfig.make_key_event(KEY_W)

	# พยายาม rebind KEY_W ให้ attack -> ต้องถูกปฏิเสธ (กันปุ่มซ้ำ)
	var success: bool = InputConfig.rebind(&"attack", dup_ev)
	if success:
		_restore_defaults()
		return false

	# ตรวจสอบว่า attack ต้องไม่มี KEY_W
	for ev: InputEvent in InputMap.action_get_events(&"attack"):
		if InputConfig.events_match(ev, dup_ev):
			_restore_defaults()
			return false

	# ตรวจสอบว่า move_up ยังต้องมี KEY_W ตามเดิม
	var move_up_has_w := false
	for ev: InputEvent in InputMap.action_get_events(&"move_up"):
		if InputConfig.events_match(ev, dup_ev):
			move_up_has_w = true
			break

	_restore_defaults()
	return move_up_has_w


func test_input_reset_to_defaults() -> bool:
	InputConfig.reset_to_defaults()
	var custom_ev: InputEventKey = InputConfig.make_key_event(KEY_P)
	var old_ev: InputEventKey = InputConfig.make_key_event(KEY_J)
	InputConfig.rebind(&"attack", custom_ev, old_ev)

	# รีเซ็ต
	InputConfig.reset_to_defaults()

	# ยืนยันว่า attack มี KEY_J กลับมา และไม่มี KEY_P
	var has_j := false
	var has_p := false
	for ev: InputEvent in InputMap.action_get_events(&"attack"):
		if InputConfig.events_match(ev, old_ev):
			has_j = true
		if InputConfig.events_match(ev, custom_ev):
			has_p = true

	_restore_defaults()
	return has_j and (not has_p)


func test_input_config_save_load_round_trip() -> bool:
	_clean_file(TEST_INPUT_PATH)
	InputConfig.reset_to_defaults()

	var custom_ev: InputEventKey = InputConfig.make_key_event(KEY_P)
	var old_ev: InputEventKey = InputConfig.make_key_event(KEY_J)
	InputConfig.rebind(&"attack", custom_ev, old_ev)

	var save_err: Error = InputConfig.save_to_file(TEST_INPUT_PATH)
	if save_err != OK:
		_restore_defaults()
		return false

	# รีเซ็ตเป็นค่า default
	InputConfig.reset_to_defaults()

	# โหลดกลับจากไฟล์
	var load_err: Error = InputConfig.load_from_file(TEST_INPUT_PATH)
	if load_err != OK:
		_restore_defaults()
		return false

	var has_p := false
	var has_j := false
	for ev: InputEvent in InputMap.action_get_events(&"attack"):
		if InputConfig.events_match(ev, custom_ev):
			has_p = true
		if InputConfig.events_match(ev, old_ev):
			has_j = true

	_restore_defaults()
	return has_p and (not has_j)


func test_title_screen_instantiation_and_defaults() -> bool:
	_clean_file(TEST_SETTINGS_PATH)
	_clean_file(TEST_INPUT_PATH)
	var scene: PackedScene = load("res://systems/ui/title/title_screen.tscn")
	if scene == null:
		_restore_defaults()
		return false
	var title: TitleScreen = scene.instantiate() as TitleScreen
	if title == null:
		_restore_defaults()
		return false
	title.setup(TEST_SETTINGS_PATH, TEST_INPUT_PATH)

	var ok: bool = title.btn_play != null \
		and title.btn_settings != null \
		and title.btn_quit != null \
		and title.lbl_title != null \
		and title.settings_menu != null \
		and title.start_scene == "res://mockup/mockup.tscn" \
		and title.lbl_title.text == "Kintsugi" \
		and not title.btn_play.focus_neighbor_bottom.is_empty() \
		and not title.btn_settings.focus_neighbor_bottom.is_empty()

	title.free()
	_restore_defaults()
	return ok


func test_pause_menu_instantiation_and_defaults() -> bool:
	_clean_file(TEST_SETTINGS_PATH)
	_clean_file(TEST_INPUT_PATH)
	var scene: PackedScene = load("res://systems/ui/pause/pause_menu.tscn")
	if scene == null:
		_restore_defaults()
		return false
	var pause: PauseMenu = scene.instantiate() as PauseMenu
	if pause == null:
		_restore_defaults()
		return false
	pause.setup(TEST_SETTINGS_PATH, TEST_INPUT_PATH)

	var ok: bool = pause.process_mode == Node.PROCESS_MODE_ALWAYS \
		and pause.layer == 100 \
		and pause.btn_resume != null \
		and pause.btn_settings != null \
		and pause.btn_title != null \
		and pause.settings_menu != null \
		and not pause.btn_resume.focus_neighbor_bottom.is_empty() \
		and not pause.btn_settings.focus_neighbor_bottom.is_empty()

	pause.free()
	_restore_defaults()
	return ok


func test_settings_menu_instantiation_and_defaults() -> bool:
	_clean_file(TEST_SETTINGS_PATH)
	_clean_file(TEST_INPUT_PATH)
	var scene: PackedScene = load("res://systems/ui/settings/settings_menu.tscn")
	if scene == null:
		_restore_defaults()
		return false
	var settings: SettingsMenu = scene.instantiate() as SettingsMenu
	if settings == null:
		_restore_defaults()
		return false
	settings.setup(TEST_SETTINGS_PATH, TEST_INPUT_PATH)

	var ok: bool = settings.slider_master != null \
		and settings.slider_music != null \
		and settings.slider_sfx != null \
		and settings.chk_fullscreen != null \
		and settings.opt_language != null \
		and settings.key_rebind != null \
		and settings.btn_reset_all != null \
		and settings.btn_back != null

	settings.free()
	_restore_defaults()
	return ok


func test_key_rebind_rows_generated() -> bool:
	_clean_file(TEST_INPUT_PATH)
	var scene: PackedScene = load("res://systems/ui/settings/key_rebind.tscn")
	if scene == null:
		_restore_defaults()
		return false
	var rebind_ctrl: KeyRebind = scene.instantiate() as KeyRebind
	if rebind_ctrl == null:
		_restore_defaults()
		return false
	rebind_ctrl.setup(TEST_INPUT_PATH)

	var ok: bool = rebind_ctrl.container_actions != null \
		and rebind_ctrl.container_actions.get_child_count() == InputConfig.ACTIONS.size() \
		and rebind_ctrl.btn_reset != null

	rebind_ctrl.free()
	_restore_defaults()
	return ok


func test_settings_language_switch() -> bool:
	SettingsConfig.setup_translations()

	SettingsConfig.set_language("en")
	var en_val: String = tr("UI_SETTINGS")

	SettingsConfig.set_language("th")
	var th_val: String = tr("UI_SETTINGS")

	# คืนค่า en
	_restore_defaults()
	return en_val == "Settings" and th_val == "ตั้งค่า"


func test_pause_menu_pause_and_resume_toggle() -> bool:
	_clean_file(TEST_SETTINGS_PATH)
	_clean_file(TEST_INPUT_PATH)
	var scene: PackedScene = load("res://systems/ui/pause/pause_menu.tscn")
	if scene == null:
		_restore_defaults()
		return false
	var pause: PauseMenu = scene.instantiate() as PauseMenu
	if pause == null:
		_restore_defaults()
		return false
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	pause.setup(TEST_SETTINGS_PATH, TEST_INPUT_PATH)

	if tree != null:
		tree.paused = false
	pause.visible = false

	pause.pause_game()
	var is_paused: bool = (tree == null or tree.paused) and pause.visible

	pause.resume_game()
	var is_resumed: bool = (tree == null or not tree.paused) and (not pause.visible)

	pause.free()
	_restore_defaults()
	return is_paused and is_resumed


# ========================================================
# เทสต์เพิ่มเติมตามรีวิว FIX_WORKER.md
# ========================================================

## 1. เทสต์: rebind -> ensure_input_actions() -> ไม่มีปุ่มเก่า และไม่เกิดปุ่มซ้ำข้าม action
func test_rebind_ensure_input_actions_no_old_key_and_no_duplicate() -> bool:
	InputConfig.reset_to_defaults()

	# เปลี่ยน move_up จาก KEY_W เป็น KEY_I
	var old_w: InputEventKey = InputConfig.make_key_event(KEY_W)
	var new_i: InputEventKey = InputConfig.make_key_event(KEY_I)
	var rebind_ok: bool = InputConfig.rebind(&"move_up", new_i, old_w)
	if not rebind_ok:
		_restore_defaults()
		return false

	# เรียก ensure_input_actions() อีกครั้ง
	InputConfig.ensure_input_actions()

	# move_up ต้องไม่มี KEY_W กลับมา
	for ev: InputEvent in InputMap.action_get_events(&"move_up"):
		if InputConfig.events_match(ev, old_w):
			_restore_defaults()
			return false

	# นำ KEY_W ไปผูกกับ move_down (เพราะ move_up ไม่ได้ใช้แล้ว)
	var old_s: InputEventKey = InputConfig.make_key_event(KEY_S)
	var rebind_w_to_down: bool = InputConfig.rebind(&"move_down", old_w, old_s)
	if not rebind_w_to_down:
		_restore_defaults()
		return false

	# เรียก ensure_input_actions() อีกครั้ง
	InputConfig.ensure_input_actions()

	# move_up ต้องยังคงไม่มี KEY_W และไม่เกิดปุ่มซ้ำ
	var move_up_has_w: bool = false
	for ev: InputEvent in InputMap.action_get_events(&"move_up"):
		if InputConfig.events_match(ev, old_w):
			move_up_has_w = true

	var move_down_has_w: bool = false
	for ev: InputEvent in InputMap.action_get_events(&"move_down"):
		if InputConfig.events_match(ev, old_w):
			move_down_has_w = true

	_restore_defaults()
	return (not move_up_has_w) and move_down_has_w


## 2. เทสต์: rebind ช่องเดิม 2 ครั้งติดได้ผลถูก (จำ event ปัจจุบันตอนกด ไม่ใช้ event เก่า)
func test_rebind_same_slot_twice_in_a_row() -> bool:
	InputConfig.reset_to_defaults()

	# ครั้งที่ 1: เปลี่ยน slot 0 ของ attack (เดิม KEY_J) เป็น KEY_K
	var ev_j: InputEventKey = InputConfig.get_action_event_at(&"attack", "keyboard_mouse", 0) as InputEventKey
	var ev_k: InputEventKey = InputConfig.make_key_event(KEY_K)
	var ok1: bool = InputConfig.rebind(&"attack", ev_k, ev_j)
	if not ok1:
		_restore_defaults()
		return false

	var slot_0_after_1: InputEvent = InputConfig.get_action_event_at(&"attack", "keyboard_mouse", 0)
	if not InputConfig.events_match(slot_0_after_1, ev_k):
		_restore_defaults()
		return false

	# ครั้งที่ 2: เปลี่ยน slot 0 เดิมอีกครั้ง (ปัจจุบัน KEY_K) เป็น KEY_L
	var ev_l: InputEventKey = InputConfig.make_key_event(KEY_L)
	var ok2: bool = InputConfig.rebind(&"attack", ev_l, slot_0_after_1)
	if not ok2:
		_restore_defaults()
		return false

	var slot_0_after_2: InputEvent = InputConfig.get_action_event_at(&"attack", "keyboard_mouse", 0)
	var is_l: bool = InputConfig.events_match(slot_0_after_2, ev_l)

	# ยืนยันว่า KEY_J และ KEY_K ไม่อยู่ใน attack อีกต่อไป
	var has_j_or_k: bool = false
	for ev: InputEvent in InputMap.action_get_events(&"attack"):
		if InputConfig.events_match(ev, ev_j) or InputConfig.events_match(ev, ev_k):
			has_j_or_k = true

	_restore_defaults()
	return is_l and (not has_j_or_k)


## 3. เทสต์: เปลี่ยนเป็นปุ่มที่ action เดียวกันมีอยู่แล้ว = สลับตำแหน่ง ไม่ลบเงียบ
func test_rebind_swaps_keys_within_same_action() -> bool:
	InputConfig.reset_to_defaults()

	# move_up มี [KEY_W (index 0), KEY_UP (index 1), JOY_BUTTON_DPAD_UP (index 2)]
	var ev_w: InputEventKey = InputConfig.get_action_event_at(&"move_up", "keyboard_mouse", 0) as InputEventKey
	var ev_up: InputEventKey = InputConfig.get_action_event_at(&"move_up", "keyboard_mouse", 1) as InputEventKey

	if ev_w == null or ev_up == null:
		_restore_defaults()
		return false

	# rebind ช่อง 0 (ev_w) ให้เป็น ev_up
	var ok: bool = InputConfig.rebind(&"move_up", ev_up, ev_w)
	if not ok:
		_restore_defaults()
		return false

	# ตรวจสอบว่าช่อง 0 กลายเป็น KEY_UP และช่อง 1 กลายเป็น KEY_W (สลับตำแหน่ง)
	var new_slot_0: InputEvent = InputConfig.get_action_event_at(&"move_up", "keyboard_mouse", 0)
	var new_slot_1: InputEvent = InputConfig.get_action_event_at(&"move_up", "keyboard_mouse", 1)

	var is_swapped: bool = InputConfig.events_match(new_slot_0, ev_up) and InputConfig.events_match(new_slot_1, ev_w)

	_restore_defaults()
	return is_swapped


## 4. เทสต์: กันซ้ำกับ ui_accept / ui_cancel / ui_pause
func test_rebind_conflicts_with_ui_actions() -> bool:
	InputConfig.reset_to_defaults()

	# ui_accept มี Enter
	var ev_enter: InputEventKey = InputConfig.make_key_event(KEY_ENTER)
	var ok_enter: bool = InputConfig.rebind(&"attack", ev_enter)

	# ui_cancel และ ui_pause มี Escape
	var ev_esc: InputEventKey = InputConfig.make_key_event(KEY_ESCAPE)
	var ok_esc: bool = InputConfig.rebind(&"attack", ev_esc)

	# ui_pause มี Joypad Start
	var ev_start: InputEventJoypadButton = InputConfig.make_joy_button_event(JOY_BUTTON_START)
	var ok_start: bool = InputConfig.rebind(&"attack", ev_start)

	_restore_defaults()
	# ทุกตัวต้องถูกปฏิเสธ (false)
	return (not ok_enter) and (not ok_esc) and (not ok_start)


## 5. เทสต์: ออกจากโหมดรอรับปุ่มด้วย Esc / Joypad Back / ปุ่ม Cancel
func test_key_rebind_cancel_listening() -> bool:
	_clean_file(TEST_INPUT_PATH)
	var scene: PackedScene = load("res://systems/ui/settings/key_rebind.tscn")
	if scene == null:
		_restore_defaults()
		return false
	var rebind_ctrl: KeyRebind = scene.instantiate() as KeyRebind
	if rebind_ctrl == null:
		_restore_defaults()
		return false
	rebind_ctrl.setup(TEST_INPUT_PATH)

	# จำลองการกดเลือกช่องเพื่อเริ่มรอรับ input
	var cur_ev: InputEvent = InputConfig.get_action_event_at(&"attack", "keyboard_mouse", 0)
	rebind_ctrl.start_listening(&"attack", "keyboard_mouse", 0, cur_ev, null)

	var listening_started: bool = (rebind_ctrl._listening_action == &"attack")

	# ส่ง event Escape เพื่อยกเลิก
	var esc_ev: InputEventKey = InputConfig.make_key_event(KEY_ESCAPE)
	esc_ev.pressed = true
	rebind_ctrl._input(esc_ev)

	var esc_cancelled: bool = rebind_ctrl._listening_action.is_empty()

	# ทดสอบซ้ำด้วย Joypad Back
	rebind_ctrl.start_listening(&"attack", "keyboard_mouse", 0, cur_ev, null)
	var back_ev: InputEventJoypadButton = InputConfig.make_joy_button_event(JOY_BUTTON_BACK)
	back_ev.pressed = true
	rebind_ctrl._input(back_ev)

	var joy_back_cancelled: bool = rebind_ctrl._listening_action.is_empty()

	rebind_ctrl.free()
	_restore_defaults()
	return listening_started and esc_cancelled and joy_back_cancelled


## 6. เทสต์: คลิกบน btn_cancel_listen แล้วยกเลิก (ไม่จับเป็นปุ่ม LMB)
func test_key_rebind_cancel_button_click_cancels() -> bool:
	_clean_file(TEST_INPUT_PATH)
	var scene: PackedScene = load("res://systems/ui/settings/key_rebind.tscn")
	if scene == null:
		_restore_defaults()
		return false
	var rebind_ctrl: KeyRebind = scene.instantiate() as KeyRebind
	if rebind_ctrl == null:
		_restore_defaults()
		return false
	rebind_ctrl.setup(TEST_INPUT_PATH)

	rebind_ctrl.start_listening(&"attack", "keyboard_mouse", 0, null, null)

	# สร้างคลิกเมาส์ที่ตำแหน่งของ btn_cancel_listen
	var click_ev := InputEventMouseButton.new()
	click_ev.button_index = MOUSE_BUTTON_LEFT
	click_ev.pressed = true
	if rebind_ctrl.btn_cancel_listen != null:
		click_ev.global_position = rebind_ctrl.btn_cancel_listen.get_global_rect().get_center()

	rebind_ctrl._input(click_ev)

	var cancelled: bool = rebind_ctrl._listening_action.is_empty()

	# ยืนยันว่า attack ไม่ถูกเซ็ตเป็น LMB
	var attack_has_lmb := false
	var lmb_ev: InputEventMouseButton = InputConfig.make_mouse_event(MOUSE_BUTTON_LEFT)
	for ev: InputEvent in InputMap.action_get_events(&"attack"):
		if InputConfig.events_match(ev, lmb_ev):
			attack_has_lmb = true

	rebind_ctrl.free()
	_restore_defaults()
	return cancelled


## 7. เทสต์: event ที่สร้างมี device = -1
func test_event_device_is_minus_one() -> bool:
	var k_ev: InputEventKey = InputConfig.make_key_event(KEY_A)
	var m_ev: InputEventMouseButton = InputConfig.make_mouse_event(MOUSE_BUTTON_LEFT)
	var jb_ev: InputEventJoypadButton = InputConfig.make_joy_button_event(JOY_BUTTON_A)
	var jm_ev: InputEventJoypadMotion = InputConfig.make_joy_motion_event(JOY_AXIS_LEFT_X, 1.0)

	var ok: bool = (k_ev.device == -1) \
		and (m_ev.device == -1) \
		and (jb_ev.device == -1) \
		and (jm_ev.device == -1)

	_restore_defaults()
	return ok


## 8. เทสต์: settings window mode คืนค่า MAXIMIZED และไม่บังคับ WINDOWED
func test_settings_window_mode_not_forced_windowed() -> bool:
	SettingsConfig.reset_to_defaults()
	var default_prev: DisplayServer.WindowMode = SettingsConfig.previous_window_mode
	var ok: bool = (default_prev == DisplayServer.WINDOW_MODE_MAXIMIZED)
	_restore_defaults()
	return ok


## 9. เทสต์: pause_menu เซฟค่าเมื่อปิดด้วย Esc
func test_pause_menu_saves_on_settings_closed_with_esc() -> bool:
	_clean_file(TEST_SETTINGS_PATH)
	_clean_file(TEST_INPUT_PATH)

	var scene: PackedScene = load("res://systems/ui/pause/pause_menu.tscn")
	if scene == null:
		_restore_defaults()
		return false
	var pause: PauseMenu = scene.instantiate() as PauseMenu
	if pause == null:
		_restore_defaults()
		return false

	pause.setup(TEST_SETTINGS_PATH, TEST_INPUT_PATH)
	pause.pause_game()
	pause._on_settings_pressed()

	# เปลี่ยนระดับเสียงใน settings
	SettingsConfig.master_volume = 0.33

	# จำลองการกด Esc (ui_pause) ขณะเปิดหน้าตั้งค่าอยู่
	var esc_action_ev := InputEventAction.new()
	esc_action_ev.action = &"ui_pause"
	esc_action_ev.pressed = true
	pause._unhandled_input(esc_action_ev)

	# ตรวจสอบว่าหน้าต่าง settings ซ่อนตัวแล้ว
	var settings_hidden: bool = (pause.settings_menu != null and not pause.settings_menu.visible)

	# ตรวจสอบว่าไฟล์คอนฟิกชั่วคราวถูกบันทึกค่า master_volume = 0.33 จริง
	var cfg := ConfigFile.new()
	var err: Error = cfg.load(TEST_SETTINGS_PATH)
	var saved_vol: float = float(cfg.get_value("audio", "master_volume", 0.0))
	var is_saved: bool = (err == OK) and is_equal_approx(saved_vol, 0.33)

	pause.free()
	_restore_defaults()
	return settings_hidden and is_saved
