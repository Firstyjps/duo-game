extends RefCounted
## เทสต์ระบบ UI & Settings (issue #42)
## เซฟ/โหลด settings round-trip, rebind แทนที่ event เดิม, กันปุ่มซ้ำ, reset default

const TEST_SETTINGS_PATH: String = "user://test_settings_roundtrip.cfg"
const TEST_INPUT_PATH: String = "user://test_input_roundtrip.cfg"


var _orig_locale: String = ""
var _orig_input_map: Dictionary = {}
var _orig_deadzone: Dictionary = {}


func _init() -> void:
	_orig_locale = TranslationServer.get_locale()
	_orig_input_map.clear()
	for action: StringName in InputMap.get_actions():
		var list: Array[InputEvent] = []
		for ev: InputEvent in InputMap.action_get_events(action):
			list.append(ev.duplicate() as InputEvent)
		_orig_input_map[action] = list
		_orig_deadzone[action] = InputMap.action_get_deadzone(action)


func _clean_file(path: String) -> void:
	var global_path: String = ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(global_path) or FileAccess.file_exists(path):
		DirAccess.remove_absolute(global_path)


func _restore_defaults() -> void:
	_clean_file(TEST_SETTINGS_PATH)
	_clean_file(TEST_INPUT_PATH)
	# คืนค่า InputMap เดิมจริง
	for action: StringName in InputMap.get_actions():
		InputMap.erase_action(action)
	for action: StringName in _orig_input_map.keys():
		InputMap.add_action(action, _orig_deadzone.get(action, 0.5))
		for ev: InputEvent in _orig_input_map[action]:
			InputMap.action_add_event(action, ev.duplicate() as InputEvent)
	# คืนค่า locale เดิมจริง
	if not _orig_locale.is_empty():
		TranslationServer.set_locale(_orig_locale)
	SettingsConfig.reset_to_defaults()


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
		and title.start_scene == "res://systems/ui/run/game_run.tscn" \
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


## 6. เทสต์: คลิกบน btn_cancel_listen แล้วยกเลิก (คำนวณ rect จริงใน tree และ assert ว่า attack ไม่ถูกเปลี่ยน)
func test_key_rebind_cancel_button_click_cancels() -> bool:
	_clean_file(TEST_INPUT_PATH)
	InputConfig.reset_to_defaults()
	var scene: PackedScene = load("res://systems/ui/settings/key_rebind.tscn")
	if scene == null:
		_restore_defaults()
		return false
	var rebind_ctrl: KeyRebind = scene.instantiate() as KeyRebind
	if rebind_ctrl == null:
		_restore_defaults()
		return false

	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var root: Window = tree.root if tree != null else null
	if root != null:
		root.add_child(rebind_ctrl)

	rebind_ctrl.setup(TEST_INPUT_PATH)
	rebind_ctrl.custom_minimum_size = Vector2(800, 600)

	# บันทึก events เดิมของ attack ทั้งหมดก่อนเริ่มเทสต์
	var attack_events_before: Array[InputEvent] = []
	for ev: InputEvent in InputMap.action_get_events(&"attack"):
		attack_events_before.append(ev.duplicate() as InputEvent)

	# เริ่มฟังที่ช่อง keyboard_mouse ของ attack
	var cur_ev: InputEvent = InputConfig.get_action_event_at(&"attack", "keyboard_mouse", 0)
	rebind_ctrl.start_listening(&"attack", "keyboard_mouse", 0, cur_ev, null)

	var listening_started: bool = (rebind_ctrl._listening_action == &"attack")

	# คำนวณ rect จริงของ btn_cancel_listen
	var cancel_btn: Button = rebind_ctrl.btn_cancel_listen
	if cancel_btn == null:
		if rebind_ctrl.get_parent() != null:
			rebind_ctrl.get_parent().remove_child(rebind_ctrl)
		rebind_ctrl.free()
		_restore_defaults()
		return false

	cancel_btn.custom_minimum_size = Vector2(100, 40)
	cancel_btn.size = Vector2(100, 40)
	cancel_btn.position = Vector2(350, 400)
	var cancel_rect: Rect2 = cancel_btn.get_global_rect()

	var click_ev := InputEventMouseButton.new()
	click_ev.button_index = MOUSE_BUTTON_LEFT
	click_ev.pressed = true
	click_ev.global_position = cancel_rect.get_center()

	rebind_ctrl._input(click_ev)

	var cancelled: bool = rebind_ctrl._listening_action.is_empty()

	# Assert ว่า attack ไม่ถูกเปลี่ยน (events ทุกตัวยังคงเดิมตาม attack_events_before)
	var attack_events_after: Array[InputEvent] = InputMap.action_get_events(&"attack")
	var attack_unchanged: bool = attack_events_before.size() == attack_events_after.size()
	if attack_unchanged:
		for i: int in range(attack_events_before.size()):
			if not InputConfig.events_match(attack_events_before[i], attack_events_after[i]):
				attack_unchanged = false
				break

	if rebind_ctrl.get_parent() != null:
		rebind_ctrl.get_parent().remove_child(rebind_ctrl)
	rebind_ctrl.free()
	_restore_defaults()
	return listening_started and cancelled and attack_unchanged


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


# ========================================================
# เทสต์เพิ่มเติมตามรีวิวรอบ 2 FIX2_WORKER.md
# ========================================================

## 10. เทสต์: ห้ามเอา Space ออกจาก ui_accept (Space ยังคงอยู่ใน ui_accept หลัง ensure/reset)
func test_space_remains_in_ui_accept() -> bool:
	InputConfig.reset_to_defaults()
	InputConfig.ensure_input_actions()

	var has_space := false
	for ev: InputEvent in InputMap.action_get_events(&"ui_accept"):
		if ev is InputEventKey and (ev.physical_keycode == KEY_SPACE or ev.keycode == KEY_SPACE):
			has_space = true
			break

	var space_ev: InputEventKey = InputConfig.make_key_event(KEY_SPACE)
	var dodge_rebind_space: bool = InputConfig.rebind(&"dodge", space_ev)

	_restore_defaults()
	return has_space and dodge_rebind_space


## 11. เทสต์: ระหว่างรอปุ่ม ข้าม event ที่ชนิดไม่ตรงกับช่อง
func test_key_rebind_skips_mismatched_event_types() -> bool:
	_clean_file(TEST_INPUT_PATH)
	InputConfig.reset_to_defaults()
	var scene: PackedScene = load("res://systems/ui/settings/key_rebind.tscn")
	if scene == null:
		_restore_defaults()
		return false
	var rebind_ctrl: KeyRebind = scene.instantiate() as KeyRebind
	if rebind_ctrl == null:
		_restore_defaults()
		return false
	rebind_ctrl.setup(TEST_INPUT_PATH)

	# 1. ฟังช่อง keyboard_mouse ของ attack -> ส่ง JoypadButton และ JoypadMotion -> ต้องถูกข้าม
	var kb_ev: InputEvent = InputConfig.get_action_event_at(&"attack", "keyboard_mouse", 0)
	rebind_ctrl.start_listening(&"attack", "keyboard_mouse", 0, kb_ev, null)

	var joy_btn := InputEventJoypadButton.new()
	joy_btn.button_index = JOY_BUTTON_Y
	joy_btn.pressed = true
	rebind_ctrl._input(joy_btn)

	var still_listening_kb: bool = (rebind_ctrl._listening_action == &"attack")

	var joy_motion := InputEventJoypadMotion.new()
	joy_motion.axis = JOY_AXIS_LEFT_X
	joy_motion.axis_value = 1.0
	rebind_ctrl._input(joy_motion)

	still_listening_kb = still_listening_kb and (rebind_ctrl._listening_action == &"attack")

	# ส่ง InputEventKey ที่ถูกต้อง -> ต้องยอมรับและจบ listening
	var key_k: InputEventKey = InputConfig.make_key_event(KEY_K)
	key_k.pressed = true
	rebind_ctrl._input(key_k)

	var kb_accepted: bool = rebind_ctrl._listening_action.is_empty()

	# 2. ฟังช่อง joypad ของ attack -> ส่ง Key และ MouseButton -> ต้องถูกข้าม
	var joy_ev: InputEvent = InputConfig.get_action_event_at(&"attack", "joypad", 0)
	rebind_ctrl.start_listening(&"attack", "joypad", 0, joy_ev, null)

	var key_z: InputEventKey = InputConfig.make_key_event(KEY_Z)
	key_z.pressed = true
	rebind_ctrl._input(key_z)

	var still_listening_joy: bool = (rebind_ctrl._listening_action == &"attack")

	var mouse_btn: InputEventMouseButton = InputConfig.make_mouse_event(MOUSE_BUTTON_RIGHT)
	mouse_btn.pressed = true
	rebind_ctrl._input(mouse_btn)

	still_listening_joy = still_listening_joy and (rebind_ctrl._listening_action == &"attack")

	# ส่ง InputEventJoypadButton ที่ถูกต้อง -> ต้องยอมรับและจบ listening
	var joy_a := InputEventJoypadButton.new()
	joy_a.button_index = JOY_BUTTON_A
	joy_a.pressed = true
	rebind_ctrl._input(joy_a)

	var joy_accepted: bool = rebind_ctrl._listening_action.is_empty()

	rebind_ctrl.free()
	_restore_defaults()
	return still_listening_kb and kb_accepted and still_listening_joy and joy_accepted


## 12. เทสต์: rebind() หา index ภายในชนิดเดียวกันเท่านั้น และสลับเฉพาะภายในชนิดเดียวกัน
func test_rebind_scoped_to_same_category_and_swaps_only_within_same_category() -> bool:
	InputConfig.reset_to_defaults()

	# attack มี [Mouse LMB, Key J, Joy X]
	var lmb_ev: InputEvent = InputConfig.get_action_event_at(&"attack", "keyboard_mouse", 0)
	var j_ev: InputEvent = InputConfig.get_action_event_at(&"attack", "keyboard_mouse", 1)
	var joy_x_before: InputEvent = InputConfig.get_action_event_at(&"attack", "joypad", 0)

	# 1. สลับภายใน category เดียวกัน (rebind slot 0 ให้เป็น Key J)
	var ok_swap: bool = InputConfig.rebind(&"attack", j_ev, lmb_ev)
	if not ok_swap:
		_restore_defaults()
		return false

	var slot_0_after: InputEvent = InputConfig.get_action_event_at(&"attack", "keyboard_mouse", 0)
	var slot_1_after: InputEvent = InputConfig.get_action_event_at(&"attack", "keyboard_mouse", 1)
	var joy_x_after: InputEvent = InputConfig.get_action_event_at(&"attack", "joypad", 0)

	var swapped_kb: bool = InputConfig.events_match(slot_0_after, j_ev) \
		and InputConfig.events_match(slot_1_after, lmb_ev)
	var joy_untouched: bool = InputConfig.events_match(joy_x_before, joy_x_after)

	# 2. ส่ง old_event ที่เป็น joypad แต่ new_event เป็น keyboard
	# rebind() ต้องหา index และแทนที่เฉพาะภายใน keyboard_mouse เท่านั้น Joypad X ต้องไม่ถูกแตะต้อง
	var new_key_k: InputEventKey = InputConfig.make_key_event(KEY_K)
	var ok_rebind_cross: bool = InputConfig.rebind(&"attack", new_key_k, joy_x_after)
	if not ok_rebind_cross:
		_restore_defaults()
		return false

	var joy_x_still_present: bool = false
	for ev: InputEvent in InputMap.action_get_events(&"attack"):
		if InputConfig.events_match(ev, joy_x_before):
			joy_x_still_present = true
			break

	var key_k_in_attack: bool = false
	for ev: InputEvent in InputMap.action_get_events(&"attack"):
		if InputConfig.events_match(ev, new_key_k):
			key_k_in_attack = true
			break

	_restore_defaults()
	return swapped_kb and joy_untouched and joy_x_still_present and key_k_in_attack


## 13. เทสต์: rebind attack -> F ถูกปฏิเสธเพราะ parry ใช้อยู่ + label TH/EN ครบ
func test_rebind_attack_to_f_rejected_due_to_parry_and_labels() -> bool:
	InputConfig.reset_to_defaults()
	Player.ensure_input_actions()

	# ยืนยันว่า parry มี KEY_F
	var parry_has_f := false
	var key_f: InputEventKey = InputConfig.make_key_event(KEY_F)
	for ev: InputEvent in InputMap.action_get_events(&"parry"):
		if InputConfig.events_match(ev, key_f):
			parry_has_f = true
			break
	if not parry_has_f:
		_restore_defaults()
		return false

	# พยายาม rebind attack เป็น KEY_F -> ต้องถูกปฏิเสธ (false) เพราะ parry ใช้อยู่
	var success: bool = InputConfig.rebind(&"attack", key_f)
	if success:
		_restore_defaults()
		return false

	# ตรวจสอบว่า find_action_with_event คืนชื่อ action &"parry"
	var conflict_action: StringName = InputConfig.find_action_with_event(key_f, &"attack")
	if conflict_action != &"parry":
		_restore_defaults()
		return false

	# ตรวจสอบว่า attack ไม่มี KEY_F
	for ev: InputEvent in InputMap.action_get_events(&"attack"):
		if InputConfig.events_match(ev, key_f):
			_restore_defaults()
			return false

	# ตรวจสอบ label ภาษา TH และ EN ของ parry และ lock_on
	var scene: PackedScene = load("res://systems/ui/settings/key_rebind.tscn")
	var rebind_ctrl: KeyRebind = scene.instantiate() as KeyRebind
	rebind_ctrl.setup(TEST_INPUT_PATH)

	SettingsConfig.set_language("en")
	var parry_lbl_en: String = rebind_ctrl._get_action_label(&"parry")
	var lock_on_lbl_en: String = rebind_ctrl._get_action_label(&"lock_on")

	SettingsConfig.set_language("th")
	var parry_lbl_th: String = rebind_ctrl._get_action_label(&"parry")
	var lock_on_lbl_th: String = rebind_ctrl._get_action_label(&"lock_on")

	rebind_ctrl.free()
	_restore_defaults()

	var ok_labels: bool = (parry_lbl_en == "Parry" and parry_lbl_th == "ปัดป้อง" \
		and lock_on_lbl_en == "Lock-on" and lock_on_lbl_th == "ล็อคเป้า")

	return (not success) and (conflict_action == &"parry") and ok_labels



## Reset แล้ว heal ยังมีปุ่ม R/Joy Y · ไม่มี action debug ในรายการ · rebind attack → R ถูกปฏิเสธ (heal ใช้อยู่)
func test_heal_defaults_and_closed_action_list() -> bool:
	InputMap.add_action(&"restart_debug_probe")
	InputConfig.reset_to_defaults()
	var heal_keys: Array[int] = []
	for ev: InputEvent in InputMap.action_get_events(&"heal"):
		if ev is InputEventKey:
			heal_keys.append((ev as InputEventKey).physical_keycode)
	var acts: Array[StringName] = InputConfig.get_actions()
	var closed: bool = acts.has(&"heal") and not acts.has(&"restart_debug_probe")
	var dup_blocked: bool = not InputConfig.rebind(&"attack", InputConfig.make_key_event(KEY_R), null)
	InputMap.erase_action(&"restart_debug_probe")
	_restore_defaults()
	return heal_keys.has(KEY_R) and closed and dup_blocked
