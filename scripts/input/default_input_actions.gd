class_name DefaultInputActions
extends RefCounted


static func ensure_default_actions() -> void:
	_ensure_key_action("move_forward", KEY_W)
	_ensure_key_action("move_back", KEY_S)
	_ensure_key_action("move_left", KEY_A)
	_ensure_key_action("move_right", KEY_D)
	_ensure_key_action("jump", KEY_SPACE)
	_ensure_key_action("sprint", KEY_SHIFT)
	_ensure_key_action("crouch", KEY_CTRL)
	_ensure_mouse_action("fire", MOUSE_BUTTON_LEFT)
	_ensure_mouse_action("aim", MOUSE_BUTTON_RIGHT)
	_ensure_key_action("reload", KEY_R)
	_ensure_key_action("interact", KEY_E)
	_ensure_key_action("music_next", KEY_F)
	_ensure_key_action("weapon_1", KEY_1)
	_ensure_key_action("weapon_2", KEY_2)
	_ensure_key_action("weapon_3", KEY_3)
	_ensure_key_action("weapon_4", KEY_4)
	_ensure_key_action("weapon_5", KEY_5)
	_ensure_mouse_action("weapon_next", MOUSE_BUTTON_WHEEL_DOWN)
	_ensure_mouse_action("weapon_prev", MOUSE_BUTTON_WHEEL_UP)
	_ensure_key_action("pause", KEY_ESCAPE)
	_ensure_key_action("debug_draw_toggle", KEY_F3)
	_ensure_key_action("lan_host", KEY_F6)
	_ensure_key_action("lan_join", KEY_F7)
	_ensure_key_action("lan_disconnect", KEY_F8)
	_ensure_joy_axis_action("look_left", JOY_AXIS_RIGHT_X, -1.0)
	_ensure_joy_axis_action("look_right", JOY_AXIS_RIGHT_X, 1.0)
	_ensure_joy_axis_action("look_up", JOY_AXIS_RIGHT_Y, -1.0)
	_ensure_joy_axis_action("look_down", JOY_AXIS_RIGHT_Y, 1.0)


static func _ensure_key_action(action_name: StringName, physical_keycode: Key) -> void:
	_ensure_action(action_name)
	if not InputMap.action_get_events(action_name).is_empty():
		return

	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = physical_keycode
	InputMap.action_add_event(action_name, event)


static func _ensure_mouse_action(action_name: StringName, button_index: MouseButton) -> void:
	_ensure_action(action_name)
	if not InputMap.action_get_events(action_name).is_empty():
		return

	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = button_index
	InputMap.action_add_event(action_name, event)


static func _ensure_joy_axis_action(action_name: StringName, axis: int, axis_value: float) -> void:
	_ensure_action(action_name)
	if not InputMap.action_get_events(action_name).is_empty():
		return

	var event: InputEventJoypadMotion = InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = axis_value
	InputMap.action_add_event(action_name, event)


static func _ensure_action(action_name: StringName) -> void:
	if InputMap.has_action(action_name):
		return
	InputMap.add_action(action_name)
