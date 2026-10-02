class_name InputConfig
extends RefCounted
## จัดการ InputMap runtime: move_up/down/left/right, attack, dodge, ui_pause
## รองรับ rebind คีย์บอร์ดและจอย, กันปุ่มซ้ำ, reset default, เซฟ/โหลด user://input.cfg

const CONFIG_PATH: String = "user://input.cfg"

const ACTIONS: Array[StringName] = [
	&"move_up",
	&"move_down",
	&"move_left",
	&"move_right",
	&"attack",
	&"dodge",
	&"ui_pause",
]


static func make_key_event(keycode: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	ev.keycode = keycode
	return ev


static func make_mouse_event(button: MouseButton) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	return ev


static func make_joy_button_event(button: JoyButton) -> InputEventJoypadButton:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	return ev


static func make_joy_motion_event(axis: JoyAxis, axis_value: float) -> InputEventJoypadMotion:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = axis_value
	return ev


## คืนค่า default events ของแต่ละ action
static func get_default_events(action: StringName) -> Array[InputEvent]:
	var list: Array[InputEvent] = []
	match action:
		&"move_up":
			list.append(make_key_event(KEY_W))
			list.append(make_key_event(KEY_UP))
			list.append(make_joy_button_event(JOY_BUTTON_DPAD_UP))
		&"move_down":
			list.append(make_key_event(KEY_S))
			list.append(make_key_event(KEY_DOWN))
			list.append(make_joy_button_event(JOY_BUTTON_DPAD_DOWN))
		&"move_left":
			list.append(make_key_event(KEY_A))
			list.append(make_key_event(KEY_LEFT))
			list.append(make_joy_button_event(JOY_BUTTON_DPAD_LEFT))
		&"move_right":
			list.append(make_key_event(KEY_D))
			list.append(make_key_event(KEY_RIGHT))
			list.append(make_joy_button_event(JOY_BUTTON_DPAD_RIGHT))
		&"attack":
			list.append(make_mouse_event(MOUSE_BUTTON_LEFT))
			list.append(make_key_event(KEY_J))
			list.append(make_joy_button_event(JOY_BUTTON_X))
		&"dodge":
			list.append(make_key_event(KEY_SPACE))
			list.append(make_key_event(KEY_SHIFT))
			list.append(make_joy_button_event(JOY_BUTTON_B))
		&"ui_pause":
			list.append(make_key_event(KEY_ESCAPE))
			list.append(make_joy_button_event(JOY_BUTTON_START))
	return list


## ลงทะเบียน input actions ตอน runtime ถ้ายังไม่มีใน InputMap
static func ensure_input_actions() -> void:
	for action: StringName in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var defaults: Array[InputEvent] = get_default_events(action)
		for ev: InputEvent in defaults:
			var already_has: bool = false
			for cur: InputEvent in InputMap.action_get_events(action):
				if events_match(cur, ev):
					already_has = true
					break
			if not already_has:
				InputMap.action_add_event(action, ev)


static func events_match(a: InputEvent, b: InputEvent) -> bool:
	if a == null or b == null:
		return false
	if a is InputEventKey and b is InputEventKey:
		var ka: Key = a.physical_keycode if a.physical_keycode != KEY_NONE else a.keycode
		var kb: Key = b.physical_keycode if b.physical_keycode != KEY_NONE else b.keycode
		if ka == kb:
			return true
		if a.keycode != KEY_NONE and a.keycode == b.keycode:
			return true
		if a.physical_keycode != KEY_NONE and a.physical_keycode == b.physical_keycode:
			return true
		return false
	if a is InputEventMouseButton and b is InputEventMouseButton:
		return a.button_index == b.button_index
	if a is InputEventJoypadButton and b is InputEventJoypadButton:
		return a.button_index == b.button_index
	if a is InputEventJoypadMotion and b is InputEventJoypadMotion:
		return a.axis == b.axis and signf(a.axis_value) == signf(b.axis_value)
	return false


static func get_event_category(ev: InputEvent) -> String:
	if ev is InputEventKey or ev is InputEventMouseButton:
		return "keyboard_mouse"
	if ev is InputEventJoypadButton or ev is InputEventJoypadMotion:
		return "joypad"
	return "unknown"


## ค้นหาว่า event นี้ถูกผูกอยู่กับ action อื่นแล้วหรือไม่ (กันปุ่มซ้ำ)
## คืนชื่อ action ที่พบ หรือ StringName(&"") ถ้ายังไม่ถูกผูก
static func find_action_with_event(event: InputEvent, exclude_action: StringName = &"") -> StringName:
	for action: StringName in ACTIONS:
		if action == exclude_action:
			continue
		if not InputMap.has_action(action):
			continue
		for cur: InputEvent in InputMap.action_get_events(action):
			if events_match(cur, event):
				return action
	return &""


## Rebind action: แทนที่ event เดิมด้วย new_event
## ถ้า new_event ชนกับ action อื่น จะคืน false (กันปุ่มซ้ำ)
static func rebind(action: StringName, new_event: InputEvent, old_event: InputEvent = null) -> bool:
	if not InputMap.has_action(action):
		InputMap.add_action(action)

	# 1. กันปุ่มซ้ำ: เช็คว่าปุ่มใหม่ซ้ำกับ action อื่นหรือไม่
	var conflict: StringName = find_action_with_event(new_event, action)
	if not conflict.is_empty():
		return false

	var current_events: Array[InputEvent] = InputMap.action_get_events(action)

	# 2. ถ้ามี old_event ระบุ ให้ลบ old_event ที่ตรงกันออก
	if old_event != null:
		var removed := false
		for ev: InputEvent in current_events:
			if events_match(ev, old_event):
				InputMap.action_erase_event(action, ev)
				removed = true
				break
		# ถ้าลบไม่ได้ (อาจไม่เจอ) ให้เช็ค category เดียวกัน
		if not removed:
			var cat: String = get_event_category(new_event)
			for ev: InputEvent in current_events:
				if get_event_category(ev) == cat:
					InputMap.action_erase_event(action, ev)
					break
	else:
		# ถ้าไม่ระบุ old_event ให้แทนที่ event ประเภทเดียวกัน (keyboard/mouse vs joypad)
		var cat: String = get_event_category(new_event)
		for ev: InputEvent in current_events:
			if get_event_category(ev) == cat:
				InputMap.action_erase_event(action, ev)
				break

	# 3. เพิ่ม new_event เข้าไป
	InputMap.action_add_event(action, new_event)
	return true


## Alias รองรับลำดับ argument (action, old_event, new_event)
static func rebind_event(action: StringName, old_event: InputEvent, new_event: InputEvent) -> bool:
	return rebind(action, new_event, old_event)


## คืนค่าเริ่มต้นทุก action
static func reset_to_defaults() -> void:
	for action: StringName in ACTIONS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		else:
			InputMap.action_erase_events(action)
		var defaults: Array[InputEvent] = get_default_events(action)
		for ev: InputEvent in defaults:
			InputMap.action_add_event(action, ev)


static func event_to_dict(ev: InputEvent) -> Dictionary:
	if ev is InputEventKey:
		var kc: Key = ev.physical_keycode if ev.physical_keycode != KEY_NONE else ev.keycode
		return {"type": "key", "keycode": int(kc)}
	elif ev is InputEventMouseButton:
		return {"type": "mouse", "button": int(ev.button_index)}
	elif ev is InputEventJoypadButton:
		return {"type": "joy_button", "button": int(ev.button_index)}
	elif ev is InputEventJoypadMotion:
		return {"type": "joy_motion", "axis": int(ev.axis), "axis_value": float(ev.axis_value)}
	return {}


static func dict_to_event(d: Dictionary) -> InputEvent:
	var type: String = d.get("type", "")
	match type:
		"key":
			var kc: Key = int(d.get("keycode", 0)) as Key
			return make_key_event(kc)
		"mouse":
			var btn: MouseButton = int(d.get("button", 0)) as MouseButton
			return make_mouse_event(btn)
		"joy_button":
			var btn: JoyButton = int(d.get("button", 0)) as JoyButton
			return make_joy_button_event(btn)
		"joy_motion":
			var axis: JoyAxis = int(d.get("axis", 0)) as JoyAxis
			var val: float = float(d.get("axis_value", 0.0))
			return make_joy_motion_event(axis, val)
	return null


static func get_event_text(ev: InputEvent) -> String:
	if ev is InputEventKey:
		var kc: Key = ev.physical_keycode if ev.physical_keycode != KEY_NONE else ev.keycode
		return OS.get_keycode_string(kc)
	elif ev is InputEventMouseButton:
		match ev.button_index:
			MOUSE_BUTTON_LEFT: return "LMB"
			MOUSE_BUTTON_RIGHT: return "RMB"
			MOUSE_BUTTON_MIDDLE: return "MMB"
			MOUSE_BUTTON_WHEEL_UP: return "Wheel Up"
			MOUSE_BUTTON_WHEEL_DOWN: return "Wheel Down"
			_: return "Mouse " + str(ev.button_index)
	elif ev is InputEventJoypadButton:
		match ev.button_index:
			JOY_BUTTON_A: return "Joy A"
			JOY_BUTTON_B: return "Joy B"
			JOY_BUTTON_X: return "Joy X"
			JOY_BUTTON_Y: return "Joy Y"
			JOY_BUTTON_START: return "Joy Start"
			JOY_BUTTON_BACK: return "Joy Select"
			JOY_BUTTON_LEFT_SHOULDER: return "Joy LB"
			JOY_BUTTON_RIGHT_SHOULDER: return "Joy RB"
			JOY_BUTTON_DPAD_UP: return "D-Pad Up"
			JOY_BUTTON_DPAD_DOWN: return "D-Pad Down"
			JOY_BUTTON_DPAD_LEFT: return "D-Pad Left"
			JOY_BUTTON_DPAD_RIGHT: return "D-Pad Right"
			_: return "Joy Btn " + str(ev.button_index)
	elif ev is InputEventJoypadMotion:
		var dir: String = "+" if ev.axis_value > 0 else "-"
		return "Axis %d %s" % [ev.axis, dir]
	return "None"


static func save_to_file(path: String = CONFIG_PATH) -> Error:
	var cfg := ConfigFile.new()
	for action: StringName in ACTIONS:
		var list: Array = []
		if InputMap.has_action(action):
			for ev: InputEvent in InputMap.action_get_events(action):
				var d: Dictionary = event_to_dict(ev)
				if not d.is_empty():
					list.append(d)
		cfg.set_value("input", String(action), list)
	return cfg.save(path)


static func load_from_file(path: String = CONFIG_PATH) -> Error:
	var cfg := ConfigFile.new()
	var err: Error = cfg.load(path)
	if err != OK:
		return err
	for action: StringName in ACTIONS:
		if not cfg.has_section_key("input", String(action)):
			continue
		var list: Array = cfg.get_value("input", String(action), [])
		if list.is_empty():
			continue
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		else:
			InputMap.action_erase_events(action)
		for item: Variant in list:
			if item is Dictionary:
				var ev: InputEvent = dict_to_event(item as Dictionary)
				if ev != null:
					InputMap.action_add_event(action, ev)
	return OK


static func load_and_apply(path: String = CONFIG_PATH) -> void:
	ensure_input_actions()
	if FileAccess.file_exists(path):
		load_from_file(path)
