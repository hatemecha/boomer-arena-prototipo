extends Node

signal settings_changed
signal performance_profile_changed(profile: int)

const CONFIG_PATH: String = "user://player_settings.cfg"
const DEFAULT_ACCENT: Color = Color(1.0, 0.12, 0.05, 1.0)
const DEFAULT_INTERNAL_RESOLUTION: Vector2i = Vector2i(640, 360)
const ULTRA_LOW_INTERNAL_RESOLUTION: Vector2i = Vector2i(426, 240)

enum PerformanceProfile {
	DEFAULT,
	LOW,
	ULTRA_LOW,
}

var display_name: String = "Player"
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

	display_name = config.get_value("profile", "display_name", display_name)
	accent_color = config.get_value("profile", "accent_color", accent_color)
	crosshair_index = int(config.get_value("profile", "crosshair_index", crosshair_index))
	crosshair_enabled = bool(config.get_value("profile", "crosshair_enabled", crosshair_enabled))
	weapon_hold_mode = int(config.get_value("profile", "weapon_hold_mode", weapon_hold_mode))
	mouse_sensitivity = float(config.get_value("input", "mouse_sensitivity", mouse_sensitivity))
	fov = float(config.get_value("input", "fov", fov))
	fullscreen = bool(config.get_value("video", "fullscreen", fullscreen))
	vsync = bool(config.get_value("video", "vsync", vsync))
	fps_cap = int(config.get_value("video", "fps_cap", fps_cap))
	performance_profile = _sanitize_performance_profile(
		int(config.get_value("video", "performance_profile", performance_profile))
	)
	psx_filter_enabled = bool(config.get_value("visual", "psx_filter_enabled", psx_filter_enabled))
	lens_preset = int(config.get_value("visual", "lens_preset", lens_preset))
	time_of_day_preset = int(config.get_value("visual", "time_of_day_preset", time_of_day_preset))
	_loaded = true
	settings_changed.emit()


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("profile", "display_name", display_name.strip_edges())
	config.set_value("profile", "accent_color", accent_color)
	config.set_value("profile", "crosshair_index", crosshair_index)
	config.set_value("profile", "crosshair_enabled", crosshair_enabled)
	config.set_value("profile", "weapon_hold_mode", weapon_hold_mode)
	config.set_value("input", "mouse_sensitivity", mouse_sensitivity)
	config.set_value("input", "fov", fov)
	config.set_value("video", "fullscreen", fullscreen)
	config.set_value("video", "vsync", vsync)
	config.set_value("video", "fps_cap", fps_cap)
	config.set_value("video", "performance_profile", int(performance_profile))
	config.set_value("visual", "psx_filter_enabled", psx_filter_enabled)
	config.set_value("visual", "lens_preset", lens_preset)
	config.set_value("visual", "time_of_day_preset", time_of_day_preset)
	config.save(CONFIG_PATH)
	settings_changed.emit()


func get_accent_color() -> Color:
	return accent_color


func apply_display_settings() -> void:
	var mode: int = (
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen
		else DisplayServer.WINDOW_MODE_WINDOWED
	)
	DisplayServer.window_set_mode(mode)
	var vsync_mode: int = DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(vsync_mode)
	_apply_internal_resolution()
	Engine.max_fps = get_effective_fps_cap()
	HudIcons.set_accent_color(accent_color)


func apply_to_player(player: PlayerController) -> void:
	if player == null:
		return
	player.mouse_sensitivity = clampf(mouse_sensitivity, 0.02, 0.50)
	player.fov = clampf(fov, 75.0, 110.0)
	player.aim_fov = minf(player.aim_fov, player.fov - 15.0)
	player.weapon_hold_mode = clampi(weapon_hold_mode, 0, PlayerController.WeaponHoldMode.size() - 1) as PlayerController.WeaponHoldMode
	if not display_name.strip_edges().is_empty():
		player.display_name = display_name.strip_edges()
	player.apply_performance_profile(int(performance_profile))


func apply_to_visual_director(visual_director: PSXVisualDirector) -> void:
	if visual_director == null:
		return

	var next_post_process_enabled: bool = true if is_low_power_profile() else psx_filter_enabled
	var next_lens_preset: int = get_effective_lens_preset()
	var needs_refresh: bool = (
		visual_director.post_process_enabled != next_post_process_enabled
		or int(visual_director.time_of_day_preset) != time_of_day_preset
	)
	var lens_changed: bool = int(visual_director.lens_preset) != next_lens_preset
	var performance_changed: bool = int(visual_director.get("_performance_profile")) != int(performance_profile)

	visual_director.post_process_enabled = next_post_process_enabled
	visual_director.time_of_day_preset = time_of_day_preset
	visual_director.apply_performance_profile(int(performance_profile), false)
	visual_director.apply_lens_preset(next_lens_preset as PSXVisualDirector.LensPreset, false)
	if needs_refresh or lens_changed or performance_changed:
		visual_director.refresh_visual_style()


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
	if fps_cap == 0:
		return 0
	match performance_profile:
		PerformanceProfile.LOW:
			return mini(fps_cap, 60)
		PerformanceProfile.ULTRA_LOW:
			return mini(fps_cap, 30)
		_:
			return fps_cap


func is_low_power_profile() -> bool:
	return performance_profile != PerformanceProfile.DEFAULT


func is_ultra_low_profile() -> bool:
	return performance_profile == PerformanceProfile.ULTRA_LOW


func _apply_internal_resolution() -> void:
	var root_window := get_tree().root
	if root_window == null:
		return
	root_window.content_scale_size = get_internal_resolution()


func _sanitize_performance_profile(profile: int) -> PerformanceProfile:
	return clampi(profile, 0, PerformanceProfile.size() - 1) as PerformanceProfile
