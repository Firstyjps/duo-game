extends RefCounted
## เทสต์ระบบ UI & Settings (issue #42)
## เซฟ/โหลด settings round-trip, rebind แทนที่ event เดิม, กันปุ่มซ้ำ, reset default

const TEST_SETTINGS_PATH: String = "user://test_settings_roundtrip.cfg"
const TEST_INPUT_PATH: String = "user://test_input_roundtrip.cfg"


func _clean_file(path: String) -> void:
	var global_path: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(global_path) or FileAccess.file_exists(path):
		DirAccess.remove_absolute(global_path)


func test_settings_save_and_load_round_trip() -> bool:
	_clean_file(TEST_SETTINGS_PATH)

	SettingsConfig.master_volume = 0.42
	SettingsConfig.music_volume = 0.55
	SettingsConfig.sfx_volume = 0.65
	SettingsConfig.fullscreen = true
	SettingsConfig.language = "th"

	var save_err: Error = SettingsConfig.save_to_file(TEST_SETTINGS_PATH)
	if save_err != OK:
		return false

	# สลับค่าเพื่อทดสอบว่าโหลดแล้วเปลี่ยนจริง
	SettingsConfig.master_volume = 1.0
	SettingsConfig.music_volume = 1.0
	SettingsConfig.sfx_volume = 1.0
	SettingsConfig.fullscreen = false
	SettingsConfig.language = "en"

	var load_err: Error = SettingsConfig.load_from_file(TEST_SETTINGS_PATH)
	if load_err != OK:
		return false

	var ok: bool = is_equal_approx(SettingsConfig.master_volume, 0.42) \
		and is_equal_approx(SettingsConfig.music_volume, 0.55) \
		and is_equal_approx(SettingsConfig.sfx_volume, 0.65) \
		and SettingsConfig.fullscreen == true \
		and SettingsConfig.language == "th"

	_clean_file(TEST_SETTINGS_PATH)
	SettingsConfig.reset_to_defaults()
	return ok


func test_settings_apply_audio_buses() -> bool:
	SettingsConfig.ensure_audio_buses()
	var master_idx: int = AudioServer.get_bus_index("Master")
	var music_idx: int = AudioServer.get_bus_index("Music")
	var sfx_idx: int = AudioServer.get_bus_index("SFX")

	if master_idx == -1 or music_idx == -1 or sfx_idx == -1:
		return false

	SettingsConfig.set_bus_volume("Music", 0.5)
	var music_vol: float = SettingsConfig.get_bus_volume("Music")
	return is_equal_approx(music_vol, 0.5)


func test_input_config_defaults() -> bool:
	InputConfig.reset_to_defaults()
	for action: StringName in InputConfig.ACTIONS:
		if not InputMap.has_action(action):
			return false
		var evs: Array[InputEvent] = InputMap.action_get_events(action)
		if evs.is_empty():
			return false
	return true


func test_ui_pause_action_registered() -> bool:
	InputConfig.ensure_input_actions()
	if not InputMap.has_action(&"ui_pause"):
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
		return false

	# ทำการ rebind แทนที่ KEY_J ด้วย KEY_K
	var success: bool = InputConfig.rebind(&"attack", new_ev, old_ev)
	if not success:
		return false

	# ตรวจสอบว่า KEY_J ต้องไม่มีแล้ว และมี KEY_K แทน
	var still_has_old := false
	var has_new := false
	for ev: InputEvent in InputMap.action_get_events(&"attack"):
		if InputConfig.events_match(ev, old_ev):
			still_has_old = true
		if InputConfig.events_match(ev, new_ev):
			has_new = true

	InputConfig.reset_to_defaults()
	return (not still_has_old) and has_new


func test_input_prevents_duplicate_rebind() -> bool:
	InputConfig.reset_to_defaults()
	# KEY_W ผูกกับ move_up อยู่แล้ว
	var dup_ev: InputEventKey = InputConfig.make_key_event(KEY_W)

	# พยายาม rebind KEY_W ให้ attack -> ต้องถูกปฏิเสธ (กันปุ่มซ้ำ)
	var success: bool = InputConfig.rebind(&"attack", dup_ev)
	if success:
		InputConfig.reset_to_defaults()
		return false

	# ตรวจสอบว่า attack ต้องไม่มี KEY_W
	for ev: InputEvent in InputMap.action_get_events(&"attack"):
		if InputConfig.events_match(ev, dup_ev):
			InputConfig.reset_to_defaults()
			return false

	# ตรวจสอบว่า move_up ยังต้องมี KEY_W ตามเดิม
	var move_up_has_w := false
	for ev: InputEvent in InputMap.action_get_events(&"move_up"):
		if InputConfig.events_match(ev, dup_ev):
			move_up_has_w = true
			break

	InputConfig.reset_to_defaults()
	return move_up_has_w


func test_input_reset_to_defaults() -> bool:
	InputConfig.reset_to_defaults()
	# เปลี่ยนปุ่ม attack
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

	return has_j and (not has_p)


func test_input_config_save_load_round_trip() -> bool:
	_clean_file(TEST_INPUT_PATH)
	InputConfig.reset_to_defaults()

	var custom_ev: InputEventKey = InputConfig.make_key_event(KEY_P)
	var old_ev: InputEventKey = InputConfig.make_key_event(KEY_J)
	InputConfig.rebind(&"attack", custom_ev, old_ev)

	var save_err: Error = InputConfig.save_to_file(TEST_INPUT_PATH)
	if save_err != OK:
		InputConfig.reset_to_defaults()
		return false

	# รีเซ็ตเป็นค่า default
	InputConfig.reset_to_defaults()

	# โหลดกลับจากไฟล์
	var load_err: Error = InputConfig.load_from_file(TEST_INPUT_PATH)
	if load_err != OK:
		InputConfig.reset_to_defaults()
		return false

	var has_p := false
	var has_j := false
	for ev: InputEvent in InputMap.action_get_events(&"attack"):
		if InputConfig.events_match(ev, custom_ev):
			has_p = true
		if InputConfig.events_match(ev, old_ev):
			has_j = true

	_clean_file(TEST_INPUT_PATH)
	InputConfig.reset_to_defaults()
	return has_p and (not has_j)


func test_title_screen_instantiation_and_defaults() -> bool:
	var scene: PackedScene = load("res://systems/ui/title/title_screen.tscn")
	if scene == null:
		return false
	var title: TitleScreen = scene.instantiate() as TitleScreen
	if title == null:
		return false
	title.setup()

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
	return ok


func test_pause_menu_instantiation_and_defaults() -> bool:
	var scene: PackedScene = load("res://systems/ui/pause/pause_menu.tscn")
	if scene == null:
		return false
	var pause: PauseMenu = scene.instantiate() as PauseMenu
	if pause == null:
		return false
	pause.setup()

	var ok: bool = pause.process_mode == Node.PROCESS_MODE_ALWAYS \
		and pause.layer == 100 \
		and pause.btn_resume != null \
		and pause.btn_settings != null \
		and pause.btn_title != null \
		and pause.settings_menu != null \
		and not pause.btn_resume.focus_neighbor_bottom.is_empty() \
		and not pause.btn_settings.focus_neighbor_bottom.is_empty()

	pause.free()
	return ok


func test_settings_menu_instantiation_and_defaults() -> bool:
	var scene: PackedScene = load("res://systems/ui/settings/settings_menu.tscn")
	if scene == null:
		return false
	var settings: SettingsMenu = scene.instantiate() as SettingsMenu
	if settings == null:
		return false
	settings.setup()

	var ok: bool = settings.slider_master != null \
		and settings.slider_music != null \
		and settings.slider_sfx != null \
		and settings.chk_fullscreen != null \
		and settings.opt_language != null \
		and settings.key_rebind != null \
		and settings.btn_reset_all != null \
		and settings.btn_back != null

	settings.free()
	return ok


func test_key_rebind_rows_generated() -> bool:
	var scene: PackedScene = load("res://systems/ui/settings/key_rebind.tscn")
	if scene == null:
		return false
	var rebind_ctrl: KeyRebind = scene.instantiate() as KeyRebind
	if rebind_ctrl == null:
		return false
	rebind_ctrl.setup()

	var ok: bool = rebind_ctrl.container_actions != null \
		and rebind_ctrl.container_actions.get_child_count() == InputConfig.ACTIONS.size() \
		and rebind_ctrl.btn_reset != null

	rebind_ctrl.free()
	return ok


func test_settings_language_switch() -> bool:
	SettingsConfig.setup_translations()

	SettingsConfig.set_language("en")
	var en_val: String = tr("UI_SETTINGS")

	SettingsConfig.set_language("th")
	var th_val: String = tr("UI_SETTINGS")

	# คืนค่า en
	SettingsConfig.set_language("en")

	return en_val == "Settings" and th_val == "ตั้งค่า"


func test_pause_menu_pause_and_resume_toggle() -> bool:
	var scene: PackedScene = load("res://systems/ui/pause/pause_menu.tscn")
	if scene == null:
		return false
	var pause: PauseMenu = scene.instantiate() as PauseMenu
	if pause == null:
		return false
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	pause.setup()

	# สถานะเริ่มต้น: ไม่ได้ pause และเมนูซ่อนอยู่
	if tree != null:
		tree.paused = false
	pause.visible = false

	# สั่ง pause
	pause.pause_game()
	var is_paused: bool = (tree == null or tree.paused) and pause.visible

	# สั่ง resume
	pause.resume_game()
	var is_resumed: bool = (tree == null or not tree.paused) and (not pause.visible)

	pause.free()
	return is_paused and is_resumed


