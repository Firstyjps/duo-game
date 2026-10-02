class_name KeyRebind
extends Control
## เมนูกำหนดปุ่มควบคุม (Key Rebind)
## รองรับ move_up/down/left/right, attack, dodge, ui_pause
## ทั้งคีย์บอร์ด เมาส์ และจอยสติ๊ก, กันปุ่มซ้ำ, รีเซ็ตค่าเริ่มต้น

signal closed

@export var config_path: String = InputConfig.CONFIG_PATH

var container_actions: VBoxContainer
var btn_reset: Button
var overlay_listening: Control
var lbl_prompt: Label
var lbl_status: Label
var btn_cancel_listen: Button

var _listening_action: StringName = &""
var _listening_category: String = ""
var _listening_slot_index: int = 0
var _listening_old_event: InputEvent = null
var _listening_source_btn: Button = null
var _row_buttons: Array[Button] = []


func _ready() -> void:
	setup()


func setup(p_config_path: String = "") -> void:
	if not p_config_path.is_empty():
		config_path = p_config_path

	container_actions = get_node_or_null("VBox/Scroll/ActionList") as VBoxContainer
	btn_reset = get_node_or_null("VBox/BottomRow/BtnReset") as Button
	overlay_listening = get_node_or_null("ListeningOverlay") as Control
	lbl_prompt = get_node_or_null("ListeningOverlay/Center/VBox/PromptLabel") as Label
	lbl_status = get_node_or_null("ListeningOverlay/Center/VBox/StatusLabel") as Label
	btn_cancel_listen = get_node_or_null("ListeningOverlay/Center/VBox/BtnCancel") as Button

	if btn_reset != null and not btn_reset.pressed.is_connected(_on_reset_pressed):
		btn_reset.pressed.connect(_on_reset_pressed)
	if btn_cancel_listen != null and not btn_cancel_listen.pressed.is_connected(cancel_listening):
		btn_cancel_listen.pressed.connect(cancel_listening)

	if overlay_listening != null:
		overlay_listening.visible = false

	InputConfig.ensure_input_actions()
	build_rows()
	update_texts()


func build_rows() -> void:
	if container_actions == null:
		return

	# ลบแถวเก่าถ้ามี
	for child: Node in container_actions.get_children():
		child.queue_free()
	_row_buttons.clear()

	var previous_row_btn: Button = null

	for action: StringName in InputConfig.ACTIONS:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_theme_constant_override("separation", 12)

		var lbl_name := Label.new()
		lbl_name.custom_minimum_size = Vector2(160, 32)
		lbl_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl_name.text = _get_action_label(action)
		row.add_child(lbl_name)

		# หา event จริงของ index 0 ของแต่ละประเภท
		var kb_event: InputEvent = InputConfig.get_action_event_at(action, "keyboard_mouse", 0)
		var joy_event: InputEvent = InputConfig.get_action_event_at(action, "joypad", 0)

		# ปุ่มสำหรับ Keyboard / Mouse (ช่อง keyboard_mouse index 0)
		var btn_kb := Button.new()
		btn_kb.custom_minimum_size = Vector2(140, 32)
		btn_kb.focus_mode = Control.FOCUS_ALL
		btn_kb.text = InputConfig.get_event_text(kb_event) if kb_event != null else "-"
		btn_kb.pressed.connect(_on_slot_clicked.bind(action, "keyboard_mouse", 0, btn_kb))
		row.add_child(btn_kb)
		_row_buttons.append(btn_kb)

		# ปุ่มสำหรับ Joypad (ช่อง joypad index 0)
		var btn_joy := Button.new()
		btn_joy.custom_minimum_size = Vector2(140, 32)
		btn_joy.focus_mode = Control.FOCUS_ALL
		btn_joy.text = InputConfig.get_event_text(joy_event) if joy_event != null else "-"
		btn_joy.pressed.connect(_on_slot_clicked.bind(action, "joypad", 0, btn_joy))
		row.add_child(btn_joy)
		_row_buttons.append(btn_joy)

		btn_kb.name = "BtnKb"
		btn_joy.name = "BtnJoy"
		# Focus neighbors แนวนอน
		btn_kb.focus_neighbor_right = NodePath("../BtnJoy")
		btn_joy.focus_neighbor_left = NodePath("../BtnKb")

		container_actions.add_child(row)

	_setup_vertical_focus()


func _enter_tree() -> void:
	_setup_vertical_focus()


func _setup_vertical_focus() -> void:
	if not is_inside_tree() or _row_buttons.is_empty():
		return

	# ตั้ง focus neighbors แนวตั้งระหว่างแถว
	for i: int in range(_row_buttons.size()):
		var btn: Button = _row_buttons[i]
		if i >= 2:
			btn.focus_neighbor_top = _row_buttons[i - 2].get_path()
		if i + 2 < _row_buttons.size():
			btn.focus_neighbor_bottom = _row_buttons[i + 2].get_path()
		elif btn_reset != null:
			btn.focus_neighbor_bottom = btn_reset.get_path()

	if btn_reset != null and _row_buttons.size() >= 2:
		btn_reset.focus_neighbor_top = _row_buttons[_row_buttons.size() - 2].get_path()


func refresh_rows() -> void:
	if container_actions == null:
		return
	var rows: Array[Node] = container_actions.get_children()
	for i: int in range(mini(rows.size(), InputConfig.ACTIONS.size())):
		var row := rows[i] as HBoxContainer
		if row == null:
			continue
		var action: StringName = InputConfig.ACTIONS[i]
		var lbl_name := row.get_child(0) as Label
		var btn_kb := row.get_child(1) as Button
		var btn_joy := row.get_child(2) as Button

		if lbl_name != null:
			lbl_name.text = _get_action_label(action)

		var kb_event: InputEvent = InputConfig.get_action_event_at(action, "keyboard_mouse", 0)
		var joy_event: InputEvent = InputConfig.get_action_event_at(action, "joypad", 0)

		if btn_kb != null:
			btn_kb.text = InputConfig.get_event_text(kb_event) if kb_event != null else "-"
		if btn_joy != null:
			btn_joy.text = InputConfig.get_event_text(joy_event) if joy_event != null else "-"


func update_texts() -> void:
	if lbl_prompt != null:
		lbl_prompt.text = tr("UI_PRESS_ANY_KEY")
	if btn_reset != null:
		btn_reset.text = tr("UI_RESET_DEFAULTS")
	if btn_cancel_listen != null:
		btn_cancel_listen.text = tr("UI_BACK")
	refresh_rows()


func _get_action_label(action: StringName) -> String:
	match action:
		&"move_up": return tr("UI_MOVE_UP")
		&"move_down": return tr("UI_MOVE_DOWN")
		&"move_left": return tr("UI_MOVE_LEFT")
		&"move_right": return tr("UI_MOVE_RIGHT")
		&"attack": return tr("UI_ATTACK")
		&"dodge": return tr("UI_DODGE")
		&"ui_pause": return tr("UI_PAUSE")
		&"ui_accept": return "UI Accept"
		&"ui_cancel": return "UI Cancel"
	return String(action)


func _on_slot_clicked(action: StringName, category: String, slot_index: int, source_btn: Button) -> void:
	var cur_event: InputEvent = InputConfig.get_action_event_at(action, category, slot_index)
	start_listening(action, category, slot_index, cur_event, source_btn)


func start_listening(action: StringName, category: String, slot_index: int, old_event: InputEvent, source_btn: Button) -> void:
	_listening_action = action
	_listening_category = category
	_listening_slot_index = slot_index
	_listening_old_event = old_event
	_listening_source_btn = source_btn

	if lbl_status != null:
		lbl_status.text = ""
	if overlay_listening != null:
		overlay_listening.visible = true
	if btn_cancel_listen != null and is_inside_tree():
		btn_cancel_listen.grab_focus()


func cancel_listening() -> void:
	_listening_action = &""
	_listening_category = ""
	_listening_slot_index = 0
	_listening_old_event = null
	if overlay_listening != null:
		overlay_listening.visible = false
	if _listening_source_btn != null and is_instance_valid(_listening_source_btn) and is_inside_tree():
		_listening_source_btn.grab_focus()
	_listening_source_btn = null


func _set_input_handled() -> void:
	var vp: Viewport = get_viewport()
	if vp != null:
		vp.set_input_as_handled()


func _input(event: InputEvent) -> void:
	if _listening_action.is_empty():
		return

	# ละเว้น mouse motion
	if event is InputEventMouseMotion:
		return

	# 1. เช็คคลิกบน btn_cancel_listen = ยกเลิก (เช็คก่อนจับเป็น input ปุ่ม)
	if event is InputEventMouseButton and event.is_pressed():
		if btn_cancel_listen != null and (btn_cancel_listen.is_visible_in_tree() or (overlay_listening != null and overlay_listening.visible)):
			if btn_cancel_listen.get_global_rect().has_point(event.global_position):
				_set_input_handled()
				cancel_listening()
				return

	# 2. เช็ค Esc หรือ Joypad Back = ยกเลิก ไม่ให้ Esc ทะลุไปเปิด/ปิด pause
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_ESCAPE or event.physical_keycode == KEY_ESCAPE:
			_set_input_handled()
			cancel_listening()
			return

	if event is InputEventJoypadButton and event.is_pressed():
		if event.button_index == JOY_BUTTON_BACK:
			_set_input_handled()
			cancel_listening()
			return

	# 3. ตรวจสอบว่าอินพุตถูกต้องหรือไม่
	var is_valid_input: bool = false
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		is_valid_input = true
	elif event is InputEventMouseButton and event.is_pressed():
		is_valid_input = true
	elif event is InputEventJoypadButton and event.is_pressed():
		is_valid_input = true
	elif event is InputEventJoypadMotion and absf(event.axis_value) >= 0.6:
		is_valid_input = true

	if not is_valid_input:
		return

	_set_input_handled()

	# คัดลอก event และตั้ง device = -1
	var captured: InputEvent = event.duplicate()
	captured.device = -1

	# หา old_event ล่าสุดของช่องนี้อีกครั้งเพื่อความปลอดภัย
	var current_old: InputEvent = _listening_old_event
	if current_old == null:
		current_old = InputConfig.get_action_event_at(_listening_action, _listening_category, _listening_slot_index)

	var success: bool = InputConfig.rebind(_listening_action, captured, current_old)
	if success:
		InputConfig.save_to_file(config_path)
		refresh_rows()
		var btn_to_focus: Button = _listening_source_btn
		cancel_listening()
		if btn_to_focus != null and is_instance_valid(btn_to_focus) and is_inside_tree():
			btn_to_focus.grab_focus()
	else:
		if lbl_status != null:
			var conflict: StringName = InputConfig.find_action_with_event(captured, _listening_action)
			lbl_status.text = tr("UI_KEY_EXISTS") + (" (%s)" % _get_action_label(conflict) if not conflict.is_empty() else "")


func _on_reset_pressed() -> void:
	InputConfig.reset_to_defaults()
	InputConfig.save_to_file(config_path)
	refresh_rows()


func grab_initial_focus() -> void:
	if not is_inside_tree():
		return
	if not _row_buttons.is_empty() and is_instance_valid(_row_buttons[0]):
		_row_buttons[0].grab_focus()
	elif btn_reset != null:
		btn_reset.grab_focus()
