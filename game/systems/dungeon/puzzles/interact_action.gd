class_name InteractAction
extends RefCounted
## Helper สำหรับลงทะเบียน input action "interact" ตอน runtime (E / Joypad A)
## ไม่แก้ project.godot ตามกติกา issue #57

const ACTION_NAME: StringName = &"interact"


static func ensure_registered() -> void:
	if not InputMap.has_action(ACTION_NAME):
		InputMap.add_action(ACTION_NAME)
		var ev_key := InputEventKey.new()
		ev_key.physical_keycode = KEY_E
		InputMap.action_add_event(ACTION_NAME, ev_key)

		var ev_joy := InputEventJoypadButton.new()
		ev_joy.button_index = JOY_BUTTON_A
		InputMap.action_add_event(ACTION_NAME, ev_joy)
