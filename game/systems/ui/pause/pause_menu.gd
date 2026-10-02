class_name PauseMenu
extends CanvasLayer
## เมนูหยุดเกม (Pause Menu): กลับเกม, ตั้งค่า, กลับหน้าเริ่ม
## CanvasLayer ทำงานตอน get_tree().paused = true (process_mode = ALWAYS)
## รับ input ui_pause (Esc / จอย Start)

var root_control: Control
var menu_container: Control
var lbl_paused: Label
var btn_resume: Button
var btn_settings: Button
var btn_title: Button
var settings_menu: SettingsMenu


func _ready() -> void:
	setup()
	visible = false


func setup() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100

	InputConfig.load_and_apply()
	SettingsConfig.load_and_apply()

	root_control = get_node_or_null("Root") as Control
	menu_container = get_node_or_null("Root/Center/VBox/MenuButtons") as Control
	lbl_paused = get_node_or_null("Root/Center/VBox/TitleLabel") as Label
	btn_resume = get_node_or_null("Root/Center/VBox/MenuButtons/BtnResume") as Button
	btn_settings = get_node_or_null("Root/Center/VBox/MenuButtons/BtnSettings") as Button
	btn_title = get_node_or_null("Root/Center/VBox/MenuButtons/BtnTitle") as Button
	settings_menu = get_node_or_null("Root/SettingsMenu") as SettingsMenu

	if btn_resume != null and not btn_resume.pressed.is_connected(_on_resume_pressed):
		btn_resume.pressed.connect(_on_resume_pressed)
	if btn_settings != null and not btn_settings.pressed.is_connected(_on_settings_pressed):
		btn_settings.pressed.connect(_on_settings_pressed)
	if btn_title != null and not btn_title.pressed.is_connected(_on_title_pressed):
		btn_title.pressed.connect(_on_title_pressed)

	if settings_menu != null:
		settings_menu.setup()
		settings_menu.visible = false
		if not settings_menu.closed.is_connected(_on_settings_closed):
			settings_menu.closed.connect(_on_settings_closed)

	_setup_focus_navigation()
	update_texts()


func _setup_focus_navigation() -> void:
	if btn_resume != null and btn_settings != null and btn_title != null:
		btn_resume.focus_neighbor_bottom = NodePath("../BtnSettings")
		btn_resume.focus_neighbor_top = NodePath("../BtnTitle")

		btn_settings.focus_neighbor_top = NodePath("../BtnResume")
		btn_settings.focus_neighbor_bottom = NodePath("../BtnTitle")

		btn_title.focus_neighbor_top = NodePath("../BtnSettings")
		btn_title.focus_neighbor_bottom = NodePath("../BtnResume")


func update_texts() -> void:
	if lbl_paused != null:
		lbl_paused.text = tr("UI_PAUSED")
	if btn_resume != null:
		btn_resume.text = tr("UI_RESUME")
	if btn_settings != null:
		btn_settings.text = tr("UI_SETTINGS")
	if btn_title != null:
		btn_title.text = tr("UI_TITLE_SCREEN")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_pause"):
		if not visible:
			pause_game()
		else:
			if settings_menu != null and settings_menu.visible:
				_on_settings_closed()
			else:
				resume_game()
		get_viewport().set_input_as_handled()


func _get_active_tree() -> SceneTree:
	if is_inside_tree():
		return get_tree()
	return Engine.get_main_loop() as SceneTree


func pause_game() -> void:
	var tree: SceneTree = _get_active_tree()
	if tree != null:
		tree.paused = true
	visible = true
	if menu_container != null:
		menu_container.visible = true
	if settings_menu != null:
		settings_menu.visible = false
	update_texts()
	if btn_resume != null and is_inside_tree():
		btn_resume.grab_focus()


func resume_game() -> void:
	if settings_menu != null:
		settings_menu.visible = false
	if menu_container != null:
		menu_container.visible = true
	visible = false
	var tree: SceneTree = _get_active_tree()
	if tree != null:
		tree.paused = false


func _on_resume_pressed() -> void:
	resume_game()


func _on_settings_pressed() -> void:
	if settings_menu != null:
		if menu_container != null:
			menu_container.visible = false
		settings_menu.visible = true
		settings_menu.grab_initial_focus()


func _on_settings_closed() -> void:
	if settings_menu != null:
		settings_menu.visible = false
	if menu_container != null:
		menu_container.visible = true
	update_texts()
	if btn_settings != null and is_inside_tree():
		btn_settings.grab_focus()


func _on_title_pressed() -> void:
	var tree: SceneTree = _get_active_tree()
	if tree != null:
		tree.paused = false
		tree.change_scene_to_file("res://systems/ui/title/title_screen.tscn")
