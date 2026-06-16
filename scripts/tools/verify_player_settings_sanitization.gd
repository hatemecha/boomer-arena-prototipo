extends SceneTree

const PlayerSettingsScript: GDScript = preload("res://scripts/game/player_settings.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var settings: Node = PlayerSettingsScript.new()
	var config := ConfigFile.new()
	config.set_value("profile", "display_name", "   ")
	config.set_value("profile", "accent_color", "not-a-color")
	config.set_value("profile", "crosshair_index", "99")
	config.set_value("profile", "crosshair_enabled", "false")
	config.set_value("profile", "weapon_hold_mode", -8)
	config.set_value("input", "mouse_sensitivity", "4.5")
	config.set_value("input", "fov", 500.0)
	config.set_value("video", "fullscreen", "true")
	config.set_value("video", "vsync", "false")
	config.set_value("video", "fps_cap", 999)
	config.set_value("video", "performance_profile", 99)
	config.set_value("visual", "psx_filter_enabled", "true")
	config.set_value("visual", "lens_preset", 999)
	config.set_value("visual", "time_of_day_preset", -999)

	settings.call("_load_profile_settings", config)
	settings.call("_load_input_settings", config)
	settings.call("_load_video_settings", config)
	settings.call("_load_visual_settings", config)

	_expect(settings.get("display_name") == "Player", "blank display name falls back to Player")
	_expect(settings.get("accent_color") == PlayerSettingsScript.DEFAULT_ACCENT, "invalid accent color falls back")
	_expect(settings.get("crosshair_index") == PlayerSettingsScript.MAX_CROSSHAIR_INDEX, "crosshair index is clamped")
	_expect(settings.get("crosshair_enabled") == false, "string bool false is parsed")
	_expect(settings.get("weapon_hold_mode") == 0, "weapon hold mode is clamped")
	_expect(is_equal_approx(float(settings.get("mouse_sensitivity")), PlayerSettingsScript.MAX_MOUSE_SENSITIVITY), "mouse sensitivity is clamped")
	_expect(is_equal_approx(float(settings.get("fov")), PlayerSettingsScript.MAX_FOV), "FOV is clamped")
	_expect(settings.get("fullscreen") == true, "string bool true is parsed")
	_expect(settings.get("vsync") == false, "string bool false is parsed")
	_expect(settings.get("fps_cap") == 120, "invalid FPS cap snaps to nearest allowed cap")
	_expect(settings.get("performance_profile") == PlayerSettingsScript.PerformanceProfile.ULTRA_LOW, "performance profile is clamped")
	_expect(settings.get("psx_filter_enabled") == true, "PSX filter bool is parsed")
	_expect(settings.get("lens_preset") == PSXVisualDirector.LensPreset.size() - 1, "lens preset is clamped")
	_expect(settings.get("time_of_day_preset") == 0, "time preset is clamped")

	settings.free()
	print("VERIFY PlayerSettings sanitization OK")
	quit()


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	push_error("PlayerSettings sanitization failed: %s" % message)
	quit(1)
