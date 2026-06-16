extends Node

signal settings_changed
signal performance_profile_changed(profile: int)

const CONFIG_PATH: String = "user://player_settings.cfg"
const SECTION_PROFILE: String = "profile"
const SECTION_INPUT: String = "input"
const SECTION_VIDEO: String = "video"
const SECTION_VISUAL: String = "visual"
const DEFAULT_ACCENT: Color = Color(1.0, 0.12, 0.05, 1.0)
const DEFAULT_INTERNAL_RESOLUTION: Vector2i = Vector2i(640, 360)
const ULTRA_LOW_INTERNAL_RESOLUTION: Vector2i = Vector2i(426, 240)
const DEFAULT_DISPLAY_NAME: String = "Player"
const MIN_MOUSE_SENSITIVITY: float = 0.02
const MAX_MOUSE_SENSITIVITY: float = 0.50
const MIN_FOV: float = 75.0
const MAX_FOV: float = 110.0
const VALID_FPS_CAPS: Array[int] = [0, 30, 60, 120]
const MIN_CROSSHAIR_INDEX: int = -1
const MAX_CROSSHAIR_INDEX: int = SpriteCrosshair.MAX_STYLE_INDEX

enum PerformanceProfile {
	DEFAULT,
	LOW,
	ULTRA_LOW,
}

var display_name: String = DEFAULT_DISPLAY_NAME
var accent_color: Color = DEFAULT_ACCENT
var crosshair_index: int = 0
var crosshair_enabled: bool = true
var weapon_hold_mode: int = PlayerController.WeaponHoldMode.DEFAULT
var mouse_sensitivity: float = 0.25
var fov: float = 90.0
var fullscreen: bool = false
var vsync: bool = false
var fps_cap: int = 0
var performance_profile: PerformanceProfile = PerformanceProfile.DEFAULT
var psx_filter_enabled: bool = true
var lens_preset: int = PSXVisualDirector.LensPreset.PSX_8MM
var time_of_day_preset: int = PSXVisualDirector.TimeOfDayPreset.NIGHT

var _loaded: bool = false


func _ready() -> void:
	load_settings()
	apply_display_settings()


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		_loaded = true
		return

	_load_profile_settings(config)
	_load_input_settings(config)
	_load_video_settings(config)
	_load_visual_settings(config)
	_loaded = true
	settings_changed.emit()


func _load_profile_settings(config: ConfigFile) -> void:
	display_name = _sanitize_display_name(_read_string(config, SECTION_PROFILE, "display_name", display_name))
	accent_color = _read_color(config, SECTION_PROFILE, "accent_color", accent_color)
	crosshair_index = _sanitize_crosshair_index(_read_int(config, SECTION_PROFILE, "crosshair_index", crosshair_index))
	crosshair_enabled = _read_bool(config, SECTION_PROFILE, "crosshair_enabled", crosshair_enabled)
	weapon_hold_mode = _sanitize_weapon_hold_mode(_read_int(config, SECTION_PROFILE, "weapon_hold_mode", weapon_hold_mode))


func _load_input_settings(config: ConfigFile) -> void:
	mouse_sensitivity = _sanitize_mouse_sensitivity(_read_float(config, SECTION_INPUT, "mouse_sensitivity", mouse_sensitivity))
	fov = _sanitize_fov(_read_float(config, SECTION_INPUT, "fov", fov))


func _load_video_settings(config: ConfigFile) -> void:
	fullscreen = _read_bool(config, SECTION_VIDEO, "fullscreen", fullscreen)
	vsync = _read_bool(config, SECTION_VIDEO, "vsync", vsync)
	fps_cap = _sanitize_fps_cap(_read_int(config, SECTION_VIDEO, "fps_cap", fps_cap))
	performance_profile = _sanitize_performance_profile(
		_read_int(config, SECTION_VIDEO, "performance_profile", performance_profile)
	)


func _load_visual_settings(config: ConfigFile) -> void:
	psx_filter_enabled = _read_bool(config, SECTION_VISUAL, "psx_filter_enabled", psx_filter_enabled)
	lens_preset = _sanitize_lens_preset(_read_int(config, SECTION_VISUAL, "lens_preset", lens_preset))
	time_of_day_preset = _sanitize_time_of_day_preset(_read_int(config, SECTION_VISUAL, "time_of_day_preset", time_of_day_preset))


func save_settings() -> void:
	_sanitize_current_settings()
	var config := ConfigFile.new()
	_save_profile_settings(config)
	_save_input_settings(config)
	_save_video_settings(config)
	_save_visual_settings(config)
	var save_error: Error = config.save(CONFIG_PATH)
	if save_error != OK:
		push_warning("Could not save player settings to %s: %s" % [CONFIG_PATH, error_string(save_error)])
	settings_changed.emit()


func _save_profile_settings(config: ConfigFile) -> void:
	config.set_value(SECTION_PROFILE, "display_name", display_name.strip_edges())
	config.set_value(SECTION_PROFILE, "accent_color", accent_color)
	config.set_value(SECTION_PROFILE, "crosshair_index", crosshair_index)
	config.set_value(SECTION_PROFILE, "crosshair_enabled", crosshair_enabled)
	config.set_value(SECTION_PROFILE, "weapon_hold_mode", weapon_hold_mode)


func _save_input_settings(config: ConfigFile) -> void:
	config.set_value(SECTION_INPUT, "mouse_sensitivity", mouse_sensitivity)
	config.set_value(SECTION_INPUT, "fov", fov)


func _save_video_settings(config: ConfigFile) -> void:
	config.set_value(SECTION_VIDEO, "fullscreen", fullscreen)
	config.set_value(SECTION_VIDEO, "vsync", vsync)
	config.set_value(SECTION_VIDEO, "fps_cap", fps_cap)
	config.set_value(SECTION_VIDEO, "performance_profile", int(performance_profile))


func _save_visual_settings(config: ConfigFile) -> void:
	config.set_value(SECTION_VISUAL, "psx_filter_enabled", psx_filter_enabled)
	config.set_value(SECTION_VISUAL, "lens_preset", lens_preset)
	config.set_value(SECTION_VISUAL, "time_of_day_preset", time_of_day_preset)


func get_accent_color() -> Color:
	return accent_color


func apply_display_settings() -> void:
	_apply_window_mode()
	_apply_vsync()
	_apply_internal_resolution()
	Engine.max_fps = get_effective_fps_cap()
	HudIcons.set_accent_color(accent_color)


func _apply_window_mode() -> void:
	var mode: int = DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)


func _apply_vsync() -> void:
	var vsync_mode: int = DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(vsync_mode)


func apply_to_player(player: PlayerController) -> void:
	if player == null:
		return
	player.mouse_sensitivity = _sanitize_mouse_sensitivity(mouse_sensitivity)
	player.fov = _sanitize_fov(fov)
	player.aim_fov = minf(player.aim_fov, player.fov - 15.0)
	player.weapon_hold_mode = _sanitize_weapon_hold_mode(weapon_hold_mode) as PlayerController.WeaponHoldMode
	player.display_name = _sanitize_display_name(display_name)
	player.apply_performance_profile(int(performance_profile))


func apply_to_visual_director(visual_director: PSXVisualDirector) -> void:
	if visual_director == null:
		return

	var next_post_process_enabled: bool = true if is_low_power_profile() else psx_filter_enabled
	var next_lens_preset: int = get_effective_lens_preset()
	var needs_refresh: bool = _visual_director_needs_refresh(visual_director, next_post_process_enabled)
	var lens_changed: bool = int(visual_director.lens_preset) != next_lens_preset
	var performance_changed: bool = int(visual_director.get("_performance_profile")) != int(performance_profile)

	visual_director.post_process_enabled = next_post_process_enabled
	visual_director.time_of_day_preset = time_of_day_preset
	visual_director.apply_performance_profile(int(performance_profile), false)
	visual_director.apply_lens_preset(next_lens_preset as PSXVisualDirector.LensPreset, false)
	if needs_refresh or lens_changed or performance_changed:
		visual_director.refresh_visual_style()


func _visual_director_needs_refresh(visual_director: PSXVisualDirector, next_post_process_enabled: bool) -> bool:
	return (
		visual_director.post_process_enabled != next_post_process_enabled
		or int(visual_director.time_of_day_preset) != time_of_day_preset
	)


func set_performance_profile(profile: int, apply_now: bool = true) -> void:
	var safe_profile := _sanitize_performance_profile(profile)
	if performance_profile == safe_profile:
		if apply_now:
			apply_display_settings()
		return

	performance_profile = safe_profile
	if apply_now:
		apply_display_settings()
	performance_profile_changed.emit(performance_profile)
	settings_changed.emit()


func get_internal_resolution() -> Vector2i:
	if performance_profile == PerformanceProfile.ULTRA_LOW:
		return ULTRA_LOW_INTERNAL_RESOLUTION
	return DEFAULT_INTERNAL_RESOLUTION


func get_effective_lens_preset() -> int:
	var safe_lens: int = clampi(lens_preset, 0, PSXVisualDirector.LensPreset.size() - 1)
	match performance_profile:
		PerformanceProfile.LOW:
			return mini(safe_lens, PSXVisualDirector.LensPreset.GAMEPLAY)
		PerformanceProfile.ULTRA_LOW:
			return PSXVisualDirector.LensPreset.OFF
		_:
			return safe_lens


func get_effective_fps_cap() -> int:
	var safe_fps_cap: int = _sanitize_fps_cap(fps_cap)
	if safe_fps_cap == 0:
		return 0
	match performance_profile:
		PerformanceProfile.LOW:
			return mini(safe_fps_cap, 60)
		PerformanceProfile.ULTRA_LOW:
			return mini(safe_fps_cap, 30)
		_:
			return safe_fps_cap


func is_low_power_profile() -> bool:
	return performance_profile != PerformanceProfile.DEFAULT


func is_ultra_low_profile() -> bool:
	return performance_profile == PerformanceProfile.ULTRA_LOW


func _sanitize_current_settings() -> void:
	display_name = _sanitize_display_name(display_name)
	crosshair_index = _sanitize_crosshair_index(crosshair_index)
	weapon_hold_mode = _sanitize_weapon_hold_mode(weapon_hold_mode)
	mouse_sensitivity = _sanitize_mouse_sensitivity(mouse_sensitivity)
	fov = _sanitize_fov(fov)
	fps_cap = _sanitize_fps_cap(fps_cap)
	performance_profile = _sanitize_performance_profile(int(performance_profile))
	lens_preset = _sanitize_lens_preset(lens_preset)
	time_of_day_preset = _sanitize_time_of_day_preset(time_of_day_preset)


func _sanitize_display_name(next_display_name: String) -> String:
	var clean_name: String = next_display_name.strip_edges()
	if clean_name.is_empty():
		return DEFAULT_DISPLAY_NAME
	return clean_name


func _sanitize_crosshair_index(index: int) -> int:
	return clampi(index, MIN_CROSSHAIR_INDEX, MAX_CROSSHAIR_INDEX)


func _sanitize_weapon_hold_mode(mode: int) -> int:
	return clampi(mode, 0, PlayerController.WeaponHoldMode.size() - 1)


func _sanitize_mouse_sensitivity(value: float) -> float:
	return clampf(value, MIN_MOUSE_SENSITIVITY, MAX_MOUSE_SENSITIVITY)


func _sanitize_fov(value: float) -> float:
	return clampf(value, MIN_FOV, MAX_FOV)


func _sanitize_fps_cap(value: int) -> int:
	if VALID_FPS_CAPS.has(value):
		return value

	var closest_cap: int = VALID_FPS_CAPS[0]
	var closest_distance: int = absi(value - closest_cap)
	for cap in VALID_FPS_CAPS:
		var distance: int = absi(value - cap)
		if distance < closest_distance:
			closest_cap = cap
			closest_distance = distance
	return closest_cap


func _sanitize_lens_preset(preset: int) -> int:
	return clampi(preset, 0, PSXVisualDirector.LensPreset.size() - 1)


func _sanitize_time_of_day_preset(preset: int) -> int:
	return clampi(preset, 0, PSXVisualDirector.TimeOfDayPreset.size() - 1)


func _apply_internal_resolution() -> void:
	var root_window := get_tree().root
	if root_window == null:
		return
	root_window.content_scale_size = get_internal_resolution()


func _sanitize_performance_profile(profile: int) -> PerformanceProfile:
	return clampi(profile, 0, PerformanceProfile.size() - 1) as PerformanceProfile


func _read_bool(config: ConfigFile, section: String, key: String, fallback: bool) -> bool:
	var value: Variant = config.get_value(section, key, fallback)
	match typeof(value):
		TYPE_BOOL:
			return bool(value)
		TYPE_STRING:
			var clean_value: String = str(value).strip_edges().to_lower()
			if clean_value == "true" or clean_value == "1":
				return true
			if clean_value == "false" or clean_value == "0":
				return false
	return fallback


func _read_int(config: ConfigFile, section: String, key: String, fallback: int) -> int:
	var value: Variant = config.get_value(section, key, fallback)
	match typeof(value):
		TYPE_INT:
			return int(value)
		TYPE_FLOAT:
			return int(value)
		TYPE_STRING:
			var clean_value: String = str(value).strip_edges()
			if clean_value.is_valid_int():
				return int(clean_value)
	return fallback


func _read_float(config: ConfigFile, section: String, key: String, fallback: float) -> float:
	var value: Variant = config.get_value(section, key, fallback)
	match typeof(value):
		TYPE_FLOAT, TYPE_INT:
			return float(value)
		TYPE_STRING:
			var clean_value: String = str(value).strip_edges()
			if clean_value.is_valid_float():
				return float(clean_value)
	return fallback


func _read_string(config: ConfigFile, section: String, key: String, fallback: String) -> String:
	var value: Variant = config.get_value(section, key, fallback)
	if typeof(value) == TYPE_STRING:
		return str(value)
	return fallback


func _read_color(config: ConfigFile, section: String, key: String, fallback: Color) -> Color:
	var value: Variant = config.get_value(section, key, fallback)
	return value if value is Color else fallback
