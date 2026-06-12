class_name PlayerSettingsAccess
extends RefCounted

const PERFORMANCE_PROFILE_DEFAULT: int = 0
const PERFORMANCE_PROFILE_LOW: int = 1
const PERFORMANCE_PROFILE_ULTRA_LOW: int = 2
const DEFAULT_ACCENT: Color = Color(1.0, 0.12, 0.05, 1.0)

const _SETTINGS_NODE_NAME: StringName = &"PlayerSettings"
const _SETTINGS_CHANGED_SIGNAL: StringName = &"settings_changed"
const _PERFORMANCE_PROFILE_CHANGED_SIGNAL: StringName = &"performance_profile_changed"


static func get_settings() -> Node:
	var main_loop: MainLoop = Engine.get_main_loop()
	if not (main_loop is SceneTree):
		return null

	var root: Window = (main_loop as SceneTree).root
	if root == null:
		return null
	return root.get_node_or_null(NodePath(String(_SETTINGS_NODE_NAME)))


static func has_settings() -> bool:
	return get_settings() != null


static func sanitize_performance_profile(profile: int) -> int:
	return clampi(profile, PERFORMANCE_PROFILE_DEFAULT, PERFORMANCE_PROFILE_ULTRA_LOW)


static func get_performance_profile() -> int:
	return sanitize_performance_profile(get_int(&"performance_profile", PERFORMANCE_PROFILE_DEFAULT))


static func is_low_power_profile() -> bool:
	return get_performance_profile() != PERFORMANCE_PROFILE_DEFAULT


static func is_ultra_low_profile() -> bool:
	return get_performance_profile() == PERFORMANCE_PROFILE_ULTRA_LOW


static func get_display_name(fallback: String = "Player") -> String:
	var clean_name: String = get_string(&"display_name", fallback).strip_edges()
	return fallback if clean_name.is_empty() else clean_name


static func get_accent_color() -> Color:
	var value: Variant = get_value(&"accent_color", DEFAULT_ACCENT)
	return value if value is Color else DEFAULT_ACCENT


static func get_value(property_name: StringName, fallback: Variant = null) -> Variant:
	var settings: Node = get_settings()
	if settings == null:
		return fallback

	var value: Variant = settings.get(property_name)
	return fallback if value == null else value


static func get_bool(property_name: StringName, fallback: bool = false) -> bool:
	return bool(get_value(property_name, fallback))


static func get_int(property_name: StringName, fallback: int = 0) -> int:
	return int(get_value(property_name, fallback))


static func get_float(property_name: StringName, fallback: float = 0.0) -> float:
	return float(get_value(property_name, fallback))


static func get_string(property_name: StringName, fallback: String = "") -> String:
	return str(get_value(property_name, fallback))


static func set_value(property_name: StringName, value: Variant) -> bool:
	var settings: Node = get_settings()
	if settings == null:
		return false
	settings.set(property_name, value)
	return true


static func connect_settings_changed(callback: Callable) -> void:
	_connect_signal(_SETTINGS_CHANGED_SIGNAL, callback)


static func connect_performance_profile_changed(callback: Callable) -> void:
	_connect_signal(_PERFORMANCE_PROFILE_CHANGED_SIGNAL, callback)


static func save_settings() -> void:
	_call_settings_method(&"save_settings")


static func apply_display_settings() -> void:
	_call_settings_method(&"apply_display_settings")


static func set_performance_profile(profile: int, apply_now: bool = true) -> void:
	_call_settings_method(&"set_performance_profile", [sanitize_performance_profile(profile), apply_now])


static func apply_to_player(player: Node) -> void:
	if player == null:
		return
	_call_settings_method(&"apply_to_player", [player])


static func apply_to_visual_director(visual_director: Node) -> void:
	if visual_director == null:
		return
	_call_settings_method(&"apply_to_visual_director", [visual_director])


static func _connect_signal(signal_name: StringName, callback: Callable) -> void:
	var settings: Node = get_settings()
	if settings == null or not settings.has_signal(signal_name):
		return
	if settings.is_connected(signal_name, callback):
		return
	settings.connect(signal_name, callback)


static func _call_settings_method(method_name: StringName, args: Array = []) -> Variant:
	var settings: Node = get_settings()
	if settings == null or not settings.has_method(method_name):
		return null
	return settings.callv(method_name, args)
