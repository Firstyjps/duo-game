class_name InputConfig
extends RefCounted
## จัดการ InputMap runtime: move_up/down/left/right, attack, dodge, ui_pause
## รองรับ rebind คีย์บอร์ดและจอย, กันปุ่มซ้ำ, reset default, เซฟ/โหลด user://input.cfg

const CONFIG_PATH: String = "user://input.cfg"
static var config_path: String = CONFIG_PATH

const ACTIONS: Array[StringName] = [
	&"move_up",
	&"move_down",
	&"move_left",
	&"move_right",
	&"attack",
	&"dodge",
	&"parry",
	&"lock_on",
	&"heal",
	&"interact",
	&"ui_pause",
]

const UI_PROTECTED_ACTIONS: Array[StringName] = [
	&"ui_accept",
	&"ui_cancel",
	&"ui_pause",
]


## รายการปิดตาย (ไม่สแกน InputMap — กัน action debug ของ sandbox โผล่/ถูก reset) · เพิ่ม action ใหม่ของ Player ต้องเพิ่มที่ ACTIONS + get_default_events
static func get_actions() -> Array[StringName]:
	Player.ensure_input_actions()
	return ACTIONS.duplicate()


static func make_key_event(keycode: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.device = -1
	ev.physical_keycode = keycode
	ev.keycode = keycode
	return ev


static func make_mouse_event(button: MouseButton) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.device = -1
	ev.button_index = button
	return ev


static func make_joy_button_event(button: JoyButton) -> InputEventJoypadButton:
	var ev := InputEventJoypadButton.new()
	ev.device = -1
	ev.button_index = button
	return ev


static func make_joy_motion_event(axis: JoyAxis, axis_value: float) -> InputEventJoypadMotion:
	var ev := InputEventJoypadMotion.new()
	ev.device = -1
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
		&"parry":
			list.append(make_key_event(KEY_F))
			list.append(make_mouse_event(MOUSE_BUTTON_RIGHT))
			list.append(make_joy_button_event(JOY_BUTTON_LEFT_SHOULDER))
		&"lock_on":
			list.append(make_key_event(KEY_TAB))
			list.append(make_mouse_event(MOUSE_BUTTON_MIDDLE))
			list.append(make_joy_button_event(JOY_BUTTON_RIGHT_SHOULDER))
		&"heal":
			list.append(make_key_event(KEY_R))
			list.append(make_joy_button_event(JOY_BUTTON_Y))
		&"interact":
			list.append(make_key_event(KEY_E))
			list.append(make_joy_button_event(JOY_BUTTON_A))
		&"ui_pause":
			list.append(make_key_event(KEY_ESCAPE))
			list.append(make_joy_button_event(JOY_BUTTON_START))
	return list


## ลงทะเบียน input actions ตอน runtime ถ้ายังไม่มีใน InputMap
## ห้ามเอา Space ออกจาก ui_accept
static func ensure_input_actions() -> void:
	Player.ensure_input_actions()

	for action: StringName in get_actions():
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var defaults: Array[InputEvent] = get_default_events(action)
		for ev: InputEvent in defaults:
			var cat: String = get_event_category(ev)
			if get_action_event_at(action, cat, 0) == null:
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


## หา event ที่ category และ index ที่กำหนดใน action
static func get_action_event_at(action: StringName, category: String, index: int) -> InputEvent:
	if not InputMap.has_action(action):
		return null
	var count: int = 0
	for ev: InputEvent in InputMap.action_get_events(action):
		if get_event_category(ev) == category:
			if count == index:
				return ev
			count += 1
	return null


## ค้นหาว่า event นี้ถูกผูกอยู่กับ action อื่นแล้วหรือไม่ (กันปุ่มซ้ำ)
## ตรวจสอบทั้ง ACTIONS และ UI actions (ui_accept, ui_cancel, ui_pause)
## คืนชื่อ action ที่พบ หรือ StringName(&"") ถ้ายังไม่ถูกผูก
static func find_action_with_event(event: InputEvent, exclude_action: StringName = &"") -> StringName:
	for action: StringName in get_actions():
		if action == exclude_action:
			continue
		if not InputMap.has_action(action):
			continue
		for cur: InputEvent in InputMap.action_get_events(action):
			if events_match(cur, event):
				return action

	for action: StringName in UI_PROTECTED_ACTIONS:
		if action == exclude_action:
			continue
		if not InputMap.has_action(action):
			continue
		for cur: InputEvent in InputMap.action_get_events(action):
			# Spacebar ใช้ร่วมกับ dodge เป็น default — ไม่ถือว่าชนกับ ui_accept สำหรับ dodge
			if exclude_action == &"dodge" and cur is InputEventKey and (cur.physical_keycode == KEY_SPACE or cur.keycode == KEY_SPACE):
				continue
			if events_match(cur, event):
				return action

	return &""


## Rebind action: แทนที่ event ที่ index เดิมภายในชนิดเดียวกัน (ไม่ต่อท้าย)
## ถ้า new_event ชนกับ action อื่น จะคืน false (กันปุ่มซ้ำ)
## ถ้าเปลี่ยนเป็นปุ่มที่ action เดียวกันมีอยู่แล้ว จะสลับตำแหน่งเฉพาะภายในชนิดเดียวกัน
static func rebind(action: StringName, new_event: InputEvent, old_event: InputEvent = null) -> bool:
	if new_event == null:
		return false
	new_event.device = -1

	var cat: String = get_event_category(new_event)
	if cat == "unknown":
		return false

	if not InputMap.has_action(action):
		InputMap.add_action(action)

	# 1. กันปุ่มซ้ำ: เช็คว่าปุ่มใหม่ซ้ำกับ action อื่น หรือ UI actions หรือไม่
	var conflict: StringName = find_action_with_event(new_event, action)
	if not conflict.is_empty():
		return false

	var current_events: Array[InputEvent] = InputMap.action_get_events(action)
	var new_events: Array[InputEvent] = current_events.duplicate()

	# 2. ตรวจสอบว่า new_event มีอยู่ใน action นี้ในชนิดเดียวกัน (cat) หรือไม่ (เพื่อสลับตำแหน่ง)
	var existing_idx: int = -1
	for i: int in range(new_events.size()):
		if get_event_category(new_events[i]) == cat and events_match(new_events[i], new_event):
			existing_idx = i
			break

	# 3. หาตำแหน่งของ old_event ใน current_events ภายในชนิดเดียวกัน (cat) เท่านั้น
	var old_idx: int = -1
	if old_event != null and get_event_category(old_event) == cat:
		for i: int in range(new_events.size()):
			if get_event_category(new_events[i]) == cat and events_match(new_events[i], old_event):
				old_idx = i
				break

	if old_idx == -1:
		for i: int in range(new_events.size()):
			if get_event_category(new_events[i]) == cat:
				old_idx = i
				break

	# 4. สลับเฉพาะภายในชนิดเดียวกัน หรือแทนที่
	if existing_idx != -1:
		# มี new_event ในชนิดเดียวกันอยู่แล้ว -> สลับตำแหน่ง (swap) ภายในชนิดเดียวกัน
		if old_idx != -1 and old_idx != existing_idx and get_event_category(new_events[old_idx]) == cat:
			var temp: InputEvent = new_events[old_idx]
			new_events[old_idx] = new_events[existing_idx]
			new_events[existing_idx] = temp
	else:
		# แทนที่ที่ตำแหน่ง index เดิมภายในชนิดเดียวกัน (ไม่ข้ามชนิดและไม่ต่อท้าย)
		if old_idx != -1 and get_event_category(new_events[old_idx]) == cat:
			new_events[old_idx] = new_event
		else:
			new_events.append(new_event)

	# อัปเดต InputMap คืนตามลำดับเดิม
	InputMap.action_erase_events(action)
	for ev: InputEvent in new_events:
		InputMap.action_add_event(action, ev)

	return true


## Alias รองรับลำดับ argument (action, old_event, new_event)
static func rebind_event(action: StringName, old_event: InputEvent, new_event: InputEvent) -> bool:
	return rebind(action, new_event, old_event)


## คืนค่าเริ่มต้นทุก action (ห้ามเอา Space ออกจาก ui_accept)
static func reset_to_defaults() -> void:
	for action: StringName in get_actions():
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


static func save_to_file(path: String = "") -> Error:
	var target_path: String = path if not path.is_empty() else config_path
	var cfg := ConfigFile.new()
	for action: StringName in get_actions():
		var list: Array = []
		if InputMap.has_action(action):
			for ev: InputEvent in InputMap.action_get_events(action):
				var d: Dictionary = event_to_dict(ev)
				if not d.is_empty():
					list.append(d)
		cfg.set_value("input", String(action), list)
	return cfg.save(target_path)


static func load_from_file(path: String = "") -> Error:
	var target_path: String = path if not path.is_empty() else config_path
	var cfg := ConfigFile.new()
	var err: Error = cfg.load(target_path)
	if err != OK:
		return err
	for action: StringName in get_actions():
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


static func load_and_apply(path: String = "") -> void:
	var target_path: String = path if not path.is_empty() else config_path
	ensure_input_actions()
	if FileAccess.file_exists(target_path):
		load_from_file(target_path)

