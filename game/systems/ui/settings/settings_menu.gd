class_name SettingsMenu
extends Control
## เมนูการตั้งค่า (Settings Menu): เสียง, ภาพ, ภาษา และปุ่มควบคุม
## ออกแบบสำหรับความละเอียด 960x540 integer scale

signal closed

@export var settings_config_path: String = SettingsConfig.CONFIG_PATH
@export var input_config_path: String = InputConfig.CONFIG_PATH
@export var config_path: String = ""

var btn_tab_general: Button
var btn_tab_controls: Button
var page_general: Control
var page_controls: Control
var key_rebind: KeyRebind

var slider_master: HSlider
var lbl_master_val: Label
var slider_music: HSlider
var lbl_music_val: Label
var slider_sfx: HSlider
var lbl_sfx_val: Label
var chk_fullscreen: CheckBox
var opt_language: OptionButton

var btn_reset_all: Button
var btn_back: Button

var lbl_title: Label
var lbl_master: Label
var lbl_music: Label
var lbl_sfx: Label
var lbl_display: Label
var lbl_lang: Label


func _ready() -> void:
	setup()


func setup(p_settings_path: String = "", p_input_path: String = "") -> void:
	if not p_settings_path.is_empty():
		settings_config_path = p_settings_path
	elif not config_path.is_empty():
		settings_config_path = config_path

	if not p_input_path.is_empty():
		input_config_path = p_input_path
	elif not config_path.is_empty():
		input_config_path = config_path

	# ค้นหาโหนดต่างๆ
	lbl_title = get_node_or_null("Center/Panel/VBox/Header/TitleLabel") as Label
	btn_tab_general = get_node_or_null("Center/Panel/VBox/TabsRow/BtnTabGeneral") as Button
	btn_tab_controls = get_node_or_null("Center/Panel/VBox/TabsRow/BtnTabControls") as Button

	page_general = get_node_or_null("Center/Panel/VBox/Content/GeneralPage") as Control
	page_controls = get_node_or_null("Center/Panel/VBox/Content/ControlsPage") as Control
	key_rebind = get_node_or_null("Center/Panel/VBox/Content/ControlsPage/KeyRebind") as KeyRebind

	slider_master = get_node_or_null("Center/Panel/VBox/Content/GeneralPage/AudioGrid/SliderMaster") as HSlider
	lbl_master_val = get_node_or_null("Center/Panel/VBox/Content/GeneralPage/AudioGrid/LblMasterVal") as Label
	slider_music = get_node_or_null("Center/Panel/VBox/Content/GeneralPage/AudioGrid/SliderMusic") as HSlider
	lbl_music_val = get_node_or_null("Center/Panel/VBox/Content/GeneralPage/AudioGrid/LblMusicVal") as Label
	slider_sfx = get_node_or_null("Center/Panel/VBox/Content/GeneralPage/AudioGrid/SliderSFX") as HSlider
	lbl_sfx_val = get_node_or_null("Center/Panel/VBox/Content/GeneralPage/AudioGrid/LblSFXVal") as Label

	chk_fullscreen = get_node_or_null("Center/Panel/VBox/Content/GeneralPage/DisplayGrid/ChkFullscreen") as CheckBox
	opt_language = get_node_or_null("Center/Panel/VBox/Content/GeneralPage/DisplayGrid/OptLanguage") as OptionButton

	lbl_master = get_node_or_null("Center/Panel/VBox/Content/GeneralPage/AudioGrid/LblMaster") as Label
	lbl_music = get_node_or_null("Center/Panel/VBox/Content/GeneralPage/AudioGrid/LblMusic") as Label
	lbl_sfx = get_node_or_null("Center/Panel/VBox/Content/GeneralPage/AudioGrid/LblSFX") as Label
	lbl_display = get_node_or_null("Center/Panel/VBox/Content/GeneralPage/DisplayGrid/LblDisplay") as Label
	lbl_lang = get_node_or_null("Center/Panel/VBox/Content/GeneralPage/DisplayGrid/LblLang") as Label

	btn_reset_all = get_node_or_null("Center/Panel/VBox/BottomRow/BtnResetAll") as Button
	btn_back = get_node_or_null("Center/Panel/VBox/BottomRow/BtnBack") as Button

	# เชื่อมต่อ Signals
	_connect_signals()

	# เติมตัวเลือกภาษา
	if opt_language != null:
		opt_language.clear()
		opt_language.add_item("English", 0)
		opt_language.set_item_metadata(0, "en")
		opt_language.add_item("ไทย (Thai)", 1)
		opt_language.set_item_metadata(1, "th")

	if key_rebind != null:
		key_rebind.setup(input_config_path)

	# ซิงค์ข้อมูลจากการตั้งค่าปัจจุบัน
	sync_ui_from_config()
	_show_tab(0)
	_setup_focus_navigation()
	update_texts()


func _connect_signals() -> void:
	if btn_tab_general != null and not btn_tab_general.pressed.is_connected(_on_tab_general_pressed):
		btn_tab_general.pressed.connect(_on_tab_general_pressed)
	if btn_tab_controls != null and not btn_tab_controls.pressed.is_connected(_on_tab_controls_pressed):
		btn_tab_controls.pressed.connect(_on_tab_controls_pressed)

	if slider_master != null and not slider_master.value_changed.is_connected(_on_master_slider_changed):
		slider_master.value_changed.connect(_on_master_slider_changed)
	if slider_music != null and not slider_music.value_changed.is_connected(_on_music_slider_changed):
		slider_music.value_changed.connect(_on_music_slider_changed)
	if slider_sfx != null and not slider_sfx.value_changed.is_connected(_on_sfx_slider_changed):
		slider_sfx.value_changed.connect(_on_sfx_slider_changed)

	if chk_fullscreen != null and not chk_fullscreen.toggled.is_connected(_on_fullscreen_toggled):
		chk_fullscreen.toggled.connect(_on_fullscreen_toggled)
	if opt_language != null and not opt_language.item_selected.is_connected(_on_language_selected):
		opt_language.item_selected.connect(_on_language_selected)

	if btn_reset_all != null and not btn_reset_all.pressed.is_connected(_on_reset_all_pressed):
		btn_reset_all.pressed.connect(_on_reset_all_pressed)
	if btn_back != null and not btn_back.pressed.is_connected(_on_back_pressed):
		btn_back.pressed.connect(_on_back_pressed)


func sync_ui_from_config() -> void:
	if slider_master != null:
		slider_master.value = SettingsConfig.master_volume * 100.0
	if lbl_master_val != null:
		lbl_master_val.text = "%d%%" % int(SettingsConfig.master_volume * 100.0)

	if slider_music != null:
		slider_music.value = SettingsConfig.music_volume * 100.0
	if lbl_music_val != null:
		lbl_music_val.text = "%d%%" % int(SettingsConfig.music_volume * 100.0)

	if slider_sfx != null:
		slider_sfx.value = SettingsConfig.sfx_volume * 100.0
	if lbl_sfx_val != null:
		lbl_sfx_val.text = "%d%%" % int(SettingsConfig.sfx_volume * 100.0)

	if chk_fullscreen != null:
		chk_fullscreen.button_pressed = SettingsConfig.fullscreen

	if opt_language != null:
		for i: int in range(opt_language.item_count):
			if opt_language.get_item_metadata(i) == SettingsConfig.language:
				opt_language.selected = i
				break


func _enter_tree() -> void:
	_setup_focus_navigation()


func _setup_focus_navigation() -> void:
	if btn_tab_general != null and btn_tab_controls != null:
		btn_tab_general.focus_neighbor_right = NodePath("../BtnTabControls")
		btn_tab_controls.focus_neighbor_left = NodePath("../BtnTabGeneral")

	if btn_reset_all != null and btn_back != null:
		btn_reset_all.focus_neighbor_right = NodePath("../BtnBack")
		btn_back.focus_neighbor_left = NodePath("../BtnResetAll")

	if not is_inside_tree():
		return

	if btn_tab_general != null and slider_master != null:
		btn_tab_general.focus_neighbor_bottom = slider_master.get_path()
		slider_master.focus_neighbor_top = btn_tab_general.get_path()

	if opt_language != null and btn_back != null:
		opt_language.focus_neighbor_bottom = btn_back.get_path()
		btn_back.focus_neighbor_top = opt_language.get_path()


func _show_tab(index: int) -> void:
	if page_general != null:
		page_general.visible = (index == 0)
	if page_controls != null:
		page_controls.visible = (index == 1)

	if index == 1 and key_rebind != null:
		key_rebind.refresh_rows()


func update_texts() -> void:
	if lbl_title != null:
		lbl_title.text = tr("UI_SETTINGS")
	if btn_tab_general != null:
		btn_tab_general.text = tr("UI_AUDIO") + " / " + tr("UI_VIDEO")
	if btn_tab_controls != null:
		btn_tab_controls.text = tr("UI_CONTROLS")
	if lbl_master != null:
		lbl_master.text = tr("UI_MASTER_VOL")
	if lbl_music != null:
		lbl_music.text = tr("UI_MUSIC_VOL")
	if lbl_sfx != null:
		lbl_sfx.text = tr("UI_SFX_VOL")
	if lbl_display != null:
		lbl_display.text = tr("UI_FULLSCREEN")
	if lbl_lang != null:
		lbl_lang.text = tr("UI_LANGUAGE")
	if btn_reset_all != null:
		btn_reset_all.text = tr("UI_RESET_DEFAULTS")
	if btn_back != null:
		btn_back.text = tr("UI_BACK")

	if key_rebind != null:
		key_rebind.update_texts()


func _on_tab_general_pressed() -> void:
	_show_tab(0)
	if slider_master != null:
		slider_master.grab_focus()


func _on_tab_controls_pressed() -> void:
	_show_tab(1)
	if key_rebind != null:
		key_rebind.grab_initial_focus()


func _on_master_slider_changed(value: float) -> void:
	var linear_vol: float = value / 100.0
	SettingsConfig.set_master_volume(linear_vol)
	SettingsConfig.save_to_file(settings_config_path)
	if lbl_master_val != null:
		lbl_master_val.text = "%d%%" % int(value)


func _on_music_slider_changed(value: float) -> void:
	var linear_vol: float = value / 100.0
	SettingsConfig.set_music_volume(linear_vol)
	SettingsConfig.save_to_file(settings_config_path)
	if lbl_music_val != null:
		lbl_music_val.text = "%d%%" % int(value)


func _on_sfx_slider_changed(value: float) -> void:
	var linear_vol: float = value / 100.0
	SettingsConfig.set_sfx_volume(linear_vol)
	SettingsConfig.save_to_file(settings_config_path)
	if lbl_sfx_val != null:
		lbl_sfx_val.text = "%d%%" % int(value)


func _on_fullscreen_toggled(button_pressed: bool) -> void:
	SettingsConfig.set_fullscreen(button_pressed)
	SettingsConfig.save_to_file(settings_config_path)


func _on_language_selected(index: int) -> void:
	if opt_language == null:
		return
	var lang: String = opt_language.get_item_metadata(index)
	SettingsConfig.set_language(lang)
	SettingsConfig.save_to_file(settings_config_path)
	update_texts()


func _on_reset_all_pressed() -> void:
	SettingsConfig.reset_to_defaults()
	InputConfig.reset_to_defaults()
	SettingsConfig.save_to_file(settings_config_path)
	InputConfig.save_to_file(input_config_path)
	sync_ui_from_config()
	if key_rebind != null:
		key_rebind.refresh_rows()
	update_texts()


func _on_back_pressed() -> void:
	SettingsConfig.save_to_file(settings_config_path)
	InputConfig.save_to_file(input_config_path)
	closed.emit()


func grab_initial_focus() -> void:
	if not is_inside_tree():
		return
	if btn_tab_general != null:
		btn_tab_general.grab_focus()
	elif slider_master != null:
		slider_master.grab_focus()
