class_name TitleScreen
extends Control
## หน้าจอเริ่มเกม (Title Screen): ชื่อเกม "Kintsugi", ปุ่มเริ่มเกม, ตั้งค่า, ออก
## ออกแบบสำหรับความละเอียด 960x540 integer scale

@export_file("*.tscn") var start_scene: String = "res://systems/ui/run/game_run.tscn"
@export var settings_config_path: String = SettingsConfig.CONFIG_PATH
@export var input_config_path: String = InputConfig.CONFIG_PATH
@export var config_path: String = ""

var btn_play: Button
var btn_settings: Button
var btn_quit: Button
var lbl_title: Label
var menu_container: Control
var settings_menu: SettingsMenu


func _ready() -> void:
	setup()
	if btn_play != null and is_inside_tree():
		btn_play.grab_focus()


func setup(p_settings_path: String = "", p_input_path: String = "") -> void:
	if not p_settings_path.is_empty():
		settings_config_path = p_settings_path
	elif not config_path.is_empty():
		settings_config_path = config_path

	if not p_input_path.is_empty():
		input_config_path = p_input_path
	elif not config_path.is_empty():
		input_config_path = config_path

	InputConfig.load_and_apply(input_config_path)
	SettingsConfig.load_and_apply(settings_config_path)

	lbl_title = get_node_or_null("Center/VBox/TitleLabel") as Label
	menu_container = get_node_or_null("Center/VBox/MenuButtons") as Control
	btn_play = get_node_or_null("Center/VBox/MenuButtons/BtnPlay") as Button
	btn_settings = get_node_or_null("Center/VBox/MenuButtons/BtnSettings") as Button
	btn_quit = get_node_or_null("Center/VBox/MenuButtons/BtnQuit") as Button
	settings_menu = get_node_or_null("SettingsMenu") as SettingsMenu

	if btn_play != null and not btn_play.pressed.is_connected(_on_play_pressed):
		btn_play.pressed.connect(_on_play_pressed)
	if btn_settings != null and not btn_settings.pressed.is_connected(_on_settings_pressed):
		btn_settings.pressed.connect(_on_settings_pressed)
	if btn_quit != null and not btn_quit.pressed.is_connected(_on_quit_pressed):
		btn_quit.pressed.connect(_on_quit_pressed)

	if settings_menu != null:
		settings_menu.setup(settings_config_path, input_config_path)
		settings_menu.visible = false
		if not settings_menu.closed.is_connected(_on_settings_closed):
			settings_menu.closed.connect(_on_settings_closed)

	_setup_focus_navigation()
	update_texts()


func _setup_focus_navigation() -> void:
	if btn_play != null and btn_settings != null and btn_quit != null:
		btn_play.focus_neighbor_bottom = NodePath("../BtnSettings")
		btn_play.focus_neighbor_top = NodePath("../BtnQuit")

		btn_settings.focus_neighbor_top = NodePath("../BtnPlay")
		btn_settings.focus_neighbor_bottom = NodePath("../BtnQuit")

		btn_quit.focus_neighbor_top = NodePath("../BtnSettings")
		btn_quit.focus_neighbor_bottom = NodePath("../BtnPlay")


func update_texts() -> void:
	if lbl_title != null:
		lbl_title.text = tr("UI_TITLE")
	if btn_play != null:
		btn_play.text = tr("UI_PLAY")
	if btn_settings != null:
		btn_settings.text = tr("UI_SETTINGS")
	if btn_quit != null:
		btn_quit.text = tr("UI_QUIT")


func _get_active_tree() -> SceneTree:
	if is_inside_tree():
		return get_tree()
	return Engine.get_main_loop() as SceneTree


func _on_play_pressed() -> void:
	if not start_scene.is_empty():
		var tree: SceneTree = _get_active_tree()
		if tree != null:
			tree.change_scene_to_file(start_scene)


func _on_settings_pressed() -> void:
	if settings_menu != null:
		if menu_container != null:
			menu_container.visible = false
		settings_menu.visible = true
		settings_menu.grab_initial_focus()


func _on_settings_closed() -> void:
	SettingsConfig.save_to_file(settings_config_path)
	InputConfig.save_to_file(input_config_path)
	if settings_menu != null:
		settings_menu.visible = false
	if menu_container != null:
		menu_container.visible = true
	update_texts()
	if btn_settings != null and is_inside_tree():
		btn_settings.grab_focus()


func _on_quit_pressed() -> void:
	var tree: SceneTree = _get_active_tree()
	if tree != null:
		tree.quit()
