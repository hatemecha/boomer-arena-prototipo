class_name OptionsMenu
extends Control

signal resume_requested
signal respawn_requested
signal leave_match_requested
signal quit_game_requested
signal back_requested
signal menu_visibility_changed(is_visible: bool)

const FRAME_LIMITS: Array[int] = [0, 30, 60, 120]
const CROSSHAIR_STYLE_COUNT: int = 12
const ArenaMenuStyleScript: GDScript = preload("res://scripts/ui/arena_menu_style.gd")
const ArenaMenuMotionScript: GDScript = preload("res://scripts/ui/arena_menu_motion.gd")
const ArenaMenuBackdropScript: GDScript = preload("res://scripts/ui/arena_menu_backdrop.gd")
const DEFAULT_SCROLL_MINIMUM_SIZE: Vector2 = Vector2(320.0, 300.0)
const ULTRA_LOW_SCROLL_MINIMUM_SIZE: Vector2 = Vector2(300.0, 220.0)
const DEFAULT_MENU_SCALE: Vector2 = Vector2.ONE
const ULTRA_LOW_MENU_SCALE: Vector2 = Vector2(0.74, 0.74)
const DEFAULT_MENU_SEPARATION: int = 8
const ULTRA_LOW_MENU_SEPARATION: int = 6

@onready var name_edit: LineEdit = %NameEdit
@onready var accent_picker: ColorPickerButton = %AccentPicker
@onready var crosshair_style_option: OptionButton = %CrosshairStyleOption
@onready var mouse_sensitivity_slider: HSlider = %MouseSensitivitySlider
@onready var mouse_sensitivity_value: Label = %MouseSensitivityValue
@onready var fov_slider: HSlider = %FovSlider
@onready var fov_value: Label = %FovValue
@onready var weapon_hold_option: OptionButton = %WeaponHoldOption
@onready var fullscreen_check: CheckBox = %FullscreenCheck
@onready var vsync_check: CheckBox = %VsyncCheck
@onready var performance_profile_option: OptionButton = %PerformanceProfileOption
@onready var frame_limit_option: OptionButton = %FrameLimitOption
@onready var psx_filter_check: CheckBox = %PsxFilterCheck
@onready var style_header: Label = $Center/Scroll/Content/StyleHeader
@onready var time_preset_row: HBoxContainer = $Center/Scroll/Content/TimePresetRow
@onready var time_preset_option: OptionButton = %TimePresetOption
@onready var lens_preset_row: HBoxContainer = $Center/Scroll/Content/LensPresetRow
@onready var lens_preset_option: OptionButton = %LensPresetOption
@onready var crosshair_check: CheckBox = %CrosshairCheck
@onready var debug_hud_check: CheckBox = %DebugHudCheck
@onready var debug_draw_check: CheckBox = %DebugDrawCheck
@onready var game_title: Label = $Center/Scroll/Content/GameTitle
@onready var scroll: ScrollContainer = $Center/Scroll
@onready var content: VBoxContainer = $Center/Scroll/Content
@onready var back_button: Button = %BackButton
@onready var resume_button: Button = %ResumeButton
@onready var leave_match_button: Button = %LeaveMatchButton
@onready var quit_game_button: Button = %QuitGameButton
@onready var refill_ammo_button: Button = %RefillAmmoButton
@onready var heal_player_button: Button = %HealPlayerButton
@onready var damage_player_button: Button = %DamagePlayerButton
@onready var respawn_player_button: Button = %RespawnPlayerButton

var _player: PlayerController
var _hud: HUD
var _visual_director: PSXVisualDirector
var _debug_draw_manager: ArenaDebugDrawManager
var _is_syncing_controls: bool = false
var _menu_motion
var _in_match: bool = false
var _accent_before_edit: Color = Color(1.0, 0.12, 0.05)
var _accent_edit_committed: bool = false
var _time_preset_row_initial_visible: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	visible = false
	ArenaMenuBackdropScript.apply(self)
	ArenaMenuStyleScript.apply_to_menu(self)
	_menu_motion = ArenaMenuMotionScript.new()
	_menu_motion.bind(self)
	_time_preset_row_initial_visible = time_preset_row != null and time_preset_row.visible
	_populate_options()
	_connect_controls()
	_configure_dev_buttons()
	if PlayerSettings != null:
		PlayerSettings.settings_changed.connect(_on_player_settings_changed)
		PlayerSettings.performance_profile_changed.connect(_on_performance_profile_changed)
	_apply_menu_profile_layout()


func _process(delta: float) -> void:
	if _menu_motion != null:
		_menu_motion.update(delta)


func _configure_dev_buttons() -> void:
	var dev_buttons: Array[Button] = [
		refill_ammo_button,
		heal_player_button,
		damage_player_button,
		respawn_player_button,
	]
	for button in dev_buttons:
		button.icon = null


func bind_context(
	player: PlayerController = null,
	hud: HUD = null,
	visual_director: PSXVisualDirector = null,
	debug_draw_manager: ArenaDebugDrawManager = null,
	in_match: bool = false
) -> void:
	_player = player
	_hud = hud
	_visual_director = visual_director
	_debug_draw_manager = debug_draw_manager
	_in_match = in_match
	_update_mode_visibility()
	_sync_controls_from_game()


func _update_mode_visibility() -> void:
	back_button.visible = not _in_match
	resume_button.visible = _in_match
	leave_match_button.visible = _in_match
	if game_title != null:
		game_title.text = "PAUSA" if _in_match else "OPCIONES"
	var has_player: bool = _player != null
	refill_ammo_button.visible = has_player
	heal_player_button.visible = has_player
	damage_player_button.visible = has_player
	respawn_player_button.visible = has_player
	debug_hud_check.visible = has_player
	debug_draw_check.visible = has_player and _debug_draw_manager != null


func open() -> void:
	_sync_controls_from_game()
	visible = true
	set_process(true)
	get_tree().paused = _in_match
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _in_match:
		resume_button.grab_focus()
	else:
		back_button.grab_focus()
	if _menu_motion != null:
		_menu_motion.play_open()
	menu_visibility_changed.emit(true)


func close() -> void:
	visible = false
	set_process(false)
	get_tree().paused = false
	if _in_match:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	menu_visibility_changed.emit(false)


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func _populate_options() -> void:
	performance_profile_option.clear()
	performance_profile_option.add_item("Default", PlayerSettings.PerformanceProfile.DEFAULT)
	performance_profile_option.add_item("Low", PlayerSettings.PerformanceProfile.LOW)
	performance_profile_option.add_item("Ultra Low", PlayerSettings.PerformanceProfile.ULTRA_LOW)

	frame_limit_option.clear()
	frame_limit_option.add_item("Sin límite", 0)
	frame_limit_option.add_item("30 FPS", 30)
	frame_limit_option.add_item("60 FPS", 60)
	frame_limit_option.add_item("120 FPS", 120)

	time_preset_option.clear()
	time_preset_option.add_item("Mañana", PSXVisualDirector.TimeOfDayPreset.MORNING)
	time_preset_option.add_item("Tarde", PSXVisualDirector.TimeOfDayPreset.AFTERNOON)
	time_preset_option.add_item("Noche", PSXVisualDirector.TimeOfDayPreset.NIGHT)

	lens_preset_option.clear()
	lens_preset_option.add_item("Off", PSXVisualDirector.LensPreset.OFF)
	lens_preset_option.add_item("Gameplay", PSXVisualDirector.LensPreset.GAMEPLAY)
	lens_preset_option.add_item("PSX 8mm", PSXVisualDirector.LensPreset.PSX_8MM)
	lens_preset_option.add_item("Extreme Debug", PSXVisualDirector.LensPreset.EXTREME_DEBUG)

	crosshair_style_option.clear()
	crosshair_style_option.add_item("Clásica", -1)
	for index in range(CROSSHAIR_STYLE_COUNT):
		crosshair_style_option.add_item("Estilo %d" % (index + 1), index)

	weapon_hold_option.clear()
	weapon_hold_option.add_item("Default", PlayerController.WeaponHoldMode.DEFAULT)
	weapon_hold_option.add_item("Doom", PlayerController.WeaponHoldMode.DOOM)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if not event.is_action_pressed("ui_cancel"):
		return
	if _is_accent_popup_open():
		_cancel_accent_edit()
		get_viewport().set_input_as_handled()
		return
	if _in_match:
		close()
		resume_requested.emit()
	else:
		_on_back_pressed()
	get_viewport().set_input_as_handled()


func _connect_controls() -> void:
	back_button.pressed.connect(_on_back_pressed)
	resume_button.pressed.connect(_on_resume_pressed)
	leave_match_button.pressed.connect(_on_leave_match_pressed)
	quit_game_button.pressed.connect(_on_quit_game_pressed)
	name_edit.text_changed.connect(_on_name_changed)
	accent_picker.color_changed.connect(_on_accent_changed)
	accent_picker.pressed.connect(_on_accent_picker_pressed)
	var accent_popup: PopupPanel = accent_picker.get_popup()
	if accent_popup != null:
		accent_popup.about_to_popup.connect(_on_accent_about_to_popup)
		accent_popup.popup_hide.connect(_on_accent_popup_hidden)
	crosshair_style_option.item_selected.connect(_on_crosshair_style_selected)
	mouse_sensitivity_slider.value_changed.connect(_on_mouse_sensitivity_changed)
	fov_slider.value_changed.connect(_on_fov_changed)
	weapon_hold_option.item_selected.connect(_on_weapon_hold_selected)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	vsync_check.toggled.connect(_on_vsync_toggled)
	performance_profile_option.item_selected.connect(_on_performance_profile_selected)
	frame_limit_option.item_selected.connect(_on_frame_limit_selected)
	psx_filter_check.toggled.connect(_on_psx_filter_toggled)
	time_preset_option.item_selected.connect(_on_time_preset_selected)
	lens_preset_option.item_selected.connect(_on_lens_preset_selected)
	crosshair_check.toggled.connect(_on_crosshair_toggled)
	debug_hud_check.toggled.connect(_on_debug_hud_toggled)
	debug_draw_check.toggled.connect(_on_debug_draw_toggled)
	refill_ammo_button.pressed.connect(_on_refill_ammo_pressed)
	heal_player_button.pressed.connect(_on_heal_player_pressed)
	damage_player_button.pressed.connect(_on_damage_player_pressed)
	respawn_player_button.pressed.connect(_on_respawn_player_pressed)


func _sync_controls_from_game() -> void:
	_is_syncing_controls = true

	if PlayerSettings != null:
		name_edit.text = PlayerSettings.display_name
		accent_picker.color = PlayerSettings.accent_color
		mouse_sensitivity_slider.value = PlayerSettings.mouse_sensitivity
		fov_slider.value = PlayerSettings.fov
		_select_crosshair_style(PlayerSettings.crosshair_index)
		crosshair_check.button_pressed = PlayerSettings.crosshair_enabled
		_select_option_by_id(weapon_hold_option, PlayerSettings.weapon_hold_mode)
		fullscreen_check.button_pressed = PlayerSettings.fullscreen
		vsync_check.button_pressed = PlayerSettings.vsync
		_select_option_by_id(performance_profile_option, int(PlayerSettings.performance_profile))
		_select_frame_limit(PlayerSettings.fps_cap)
		psx_filter_check.button_pressed = PlayerSettings.psx_filter_enabled
		_select_option_by_id(time_preset_option, PlayerSettings.time_of_day_preset)
		_select_option_by_id(lens_preset_option, PlayerSettings.lens_preset)
		_update_psx_option_visibility()
	elif _player != null:
		mouse_sensitivity_slider.value = _player.mouse_sensitivity
		fov_slider.value = _player.fov
		_select_option_by_id(weapon_hold_option, int(_player.weapon_hold_mode))

	if _player != null:
		_update_mouse_sensitivity_label(_player.mouse_sensitivity)
		_update_fov_label(_player.fov)
	else:
		_update_mouse_sensitivity_label(mouse_sensitivity_slider.value)
		_update_fov_label(fov_slider.value)

	if _visual_director != null and PlayerSettings == null:
		psx_filter_check.button_pressed = _visual_director.post_process_enabled
		_select_option_by_id(time_preset_option, _visual_director.time_of_day_preset)
		_select_option_by_id(lens_preset_option, _visual_director.lens_preset)
		_update_psx_option_visibility()

	if _hud != null:
		crosshair_check.button_pressed = _hud.is_crosshair_enabled()
		debug_hud_check.button_pressed = _hud.is_debug_visible()

	if _debug_draw_manager != null:
		debug_draw_check.button_pressed = _debug_draw_manager.debug_draw_enabled
	else:
		debug_draw_check.button_pressed = false
		debug_draw_check.disabled = true

	_is_syncing_controls = false


func _select_crosshair_style(index: int) -> void:
	for item_index in range(crosshair_style_option.get_item_count()):
		if crosshair_style_option.get_item_id(item_index) == index:
			crosshair_style_option.select(item_index)
			return
	crosshair_style_option.select(0)


func _select_frame_limit(limit: int) -> void:
	var option_id: int = limit
	if not FRAME_LIMITS.has(limit):
		option_id = 0
	_select_option_by_id(frame_limit_option, option_id)


func _select_option_by_id(option_button: OptionButton, id: int) -> void:
	for item_index in range(option_button.get_item_count()):
		if option_button.get_item_id(item_index) == id:
			option_button.select(item_index)
			return
	option_button.select(0)


func _on_back_pressed() -> void:
	close()
	back_requested.emit()


func _on_resume_pressed() -> void:
	close()
	resume_requested.emit()


func _on_leave_match_pressed() -> void:
	close()
	leave_match_requested.emit()


func _on_quit_game_pressed() -> void:
	_save_player_settings()
	quit_game_requested.emit()


func _on_name_changed(new_text: String) -> void:
	if _is_syncing_controls or PlayerSettings == null:
		return
	PlayerSettings.display_name = new_text.strip_edges()
	if _player != null and not PlayerSettings.display_name.is_empty():
		_player.display_name = PlayerSettings.display_name
	PlayerSettings.save_settings()


func _on_accent_picker_pressed() -> void:
	_accent_edit_committed = false


func _on_accent_about_to_popup() -> void:
	if PlayerSettings != null:
		_accent_before_edit = PlayerSettings.accent_color
	call_deferred("_style_accent_picker_popup")


func _style_accent_picker_popup() -> void:
	var picker: ColorPicker = accent_picker.get_picker()
	if picker == null:
		return
	picker.edit_alpha = false
	ArenaMenuStyleScript.apply_to_menu(picker)


func _on_accent_popup_hidden() -> void:
	if _accent_edit_committed or PlayerSettings == null:
		return
	_commit_accent_color(accent_picker.color)


func _on_accent_changed(color: Color) -> void:
	if _is_syncing_controls or PlayerSettings == null:
		return
	_apply_accent_preview(color)


func _apply_accent_preview(color: Color) -> void:
	HudIcons.set_accent_color(color)
	ArenaMenuStyleScript.apply_to_menu(self)
	if _hud != null:
		_hud.apply_accent_theme()


func _commit_accent_color(color: Color) -> void:
	if PlayerSettings == null:
		return
	_accent_edit_committed = true
	PlayerSettings.accent_color = color
	PlayerSettings.save_settings()
	_apply_accent_preview(color)


func _cancel_accent_edit() -> void:
	accent_picker.get_popup().hide()
	accent_picker.color = _accent_before_edit
	_apply_accent_preview(_accent_before_edit)
	if PlayerSettings != null:
		PlayerSettings.accent_color = _accent_before_edit


func _is_accent_popup_open() -> bool:
	var popup: PopupPanel = accent_picker.get_popup()
	return popup != null and popup.visible


func _on_crosshair_style_selected(index: int) -> void:
	if _is_syncing_controls or PlayerSettings == null:
		return
	PlayerSettings.crosshair_index = crosshair_style_option.get_item_id(index)
	PlayerSettings.save_settings()
	_apply_crosshair_style()


func _on_player_settings_changed() -> void:
	ArenaMenuStyleScript.apply_to_menu(self)
	_apply_menu_profile_layout()
	_apply_crosshair_style()
	_update_psx_option_visibility()
	if _hud != null:
		_hud.apply_accent_theme()


func _apply_crosshair_style() -> void:
	if _hud == null or PlayerSettings == null:
		return
	var use_sprite: bool = PlayerSettings.crosshair_index >= 0
	_hud.rebuild_crosshair(use_sprite, maxi(PlayerSettings.crosshair_index, 0))
	_hud.set_crosshair_enabled(PlayerSettings.crosshair_enabled)


func _save_player_settings() -> void:
	if PlayerSettings == null:
		return
	PlayerSettings.mouse_sensitivity = clampf(mouse_sensitivity_slider.value, 0.02, 0.50)
	PlayerSettings.fov = clampf(fov_slider.value, 75.0, 110.0)
	PlayerSettings.fullscreen = fullscreen_check.button_pressed
	PlayerSettings.vsync = vsync_check.button_pressed
	PlayerSettings.performance_profile = performance_profile_option.get_item_id(
		performance_profile_option.selected
	) as PlayerSettings.PerformanceProfile
	PlayerSettings.fps_cap = frame_limit_option.get_item_id(frame_limit_option.selected)
	PlayerSettings.psx_filter_enabled = psx_filter_check.button_pressed
	PlayerSettings.lens_preset = lens_preset_option.get_item_id(lens_preset_option.selected)
	PlayerSettings.crosshair_enabled = crosshair_check.button_pressed
	PlayerSettings.weapon_hold_mode = weapon_hold_option.get_item_id(weapon_hold_option.selected)
	PlayerSettings.save_settings()
	PlayerSettings.apply_display_settings()


func _on_mouse_sensitivity_changed(value: float) -> void:
	_update_mouse_sensitivity_label(value)
	if _is_syncing_controls:
		return
	if PlayerSettings != null:
		PlayerSettings.mouse_sensitivity = clampf(value, 0.02, 0.50)
	if _player != null:
		_player.mouse_sensitivity = clampf(value, 0.02, 0.50)


func _on_fov_changed(value: float) -> void:
	_update_fov_label(value)
	if _is_syncing_controls:
		return
	if PlayerSettings != null:
		PlayerSettings.fov = clampf(value, 75.0, 110.0)
	if _player != null:
		_player.fov = clampf(value, 75.0, 110.0)
		_player.aim_fov = minf(_player.aim_fov, _player.fov - 15.0)


func _on_weapon_hold_selected(index: int) -> void:
	if _is_syncing_controls:
		return
	var hold_mode: int = weapon_hold_option.get_item_id(index)
	if PlayerSettings != null:
		PlayerSettings.weapon_hold_mode = hold_mode
		PlayerSettings.save_settings()
	if _player != null:
		_player.weapon_hold_mode = clampi(hold_mode, 0, PlayerController.WeaponHoldMode.size() - 1) as PlayerController.WeaponHoldMode


func _update_mouse_sensitivity_label(value: float) -> void:
	mouse_sensitivity_value.text = "%.2f" % value


func _update_fov_label(value: float) -> void:
	fov_value.text = "%d" % int(roundf(value))


func sync_fullscreen_checkbox() -> void:
	_is_syncing_controls = true
	fullscreen_check.button_pressed = _is_fullscreen_mode()
	_is_syncing_controls = false


func _is_fullscreen_mode() -> bool:
	var mode: int = DisplayServer.window_get_mode()
	return (
		mode == DisplayServer.WINDOW_MODE_FULLSCREEN
		or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	)


func _on_fullscreen_toggled(enabled: bool) -> void:
	if _is_syncing_controls:
		return
	if PlayerSettings != null:
		PlayerSettings.fullscreen = enabled
		PlayerSettings.apply_display_settings()
	else:
		var mode: int = DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED
		DisplayServer.window_set_mode(mode)


func _on_vsync_toggled(enabled: bool) -> void:
	if _is_syncing_controls:
		return
	if PlayerSettings != null:
		PlayerSettings.vsync = enabled
		PlayerSettings.apply_display_settings()
	else:
		var mode: int = DisplayServer.VSYNC_ENABLED if enabled else DisplayServer.VSYNC_DISABLED
		DisplayServer.window_set_vsync_mode(mode)


func _on_frame_limit_selected(index: int) -> void:
	if _is_syncing_controls:
		return
	var limit: int = frame_limit_option.get_item_id(index)
	if PlayerSettings != null:
		PlayerSettings.fps_cap = limit
		PlayerSettings.apply_display_settings()
	else:
		Engine.max_fps = limit


func _on_performance_profile_selected(index: int) -> void:
	if _is_syncing_controls:
		return
	var profile: int = performance_profile_option.get_item_id(index)
	if PlayerSettings != null:
		PlayerSettings.set_performance_profile(profile)
		PlayerSettings.save_settings()
		if _visual_director != null:
			PlayerSettings.apply_to_visual_director(_visual_director)
		if _player != null:
			PlayerSettings.apply_to_player(_player)
	_apply_menu_profile_layout()
	_update_psx_option_visibility()


func _on_performance_profile_changed(_profile: int) -> void:
	_apply_menu_profile_layout()


func _on_psx_filter_toggled(enabled: bool) -> void:
	if _is_syncing_controls:
		return
	if PlayerSettings != null and PlayerSettings.is_low_power_profile():
		return
	if PlayerSettings != null:
		PlayerSettings.psx_filter_enabled = enabled
	if _visual_director != null:
		_visual_director.post_process_enabled = enabled
		_visual_director.refresh_visual_style()


func _on_time_preset_selected(index: int) -> void:
	if _is_syncing_controls:
		return
	var preset: int = time_preset_option.get_item_id(index)
	if PlayerSettings != null:
		PlayerSettings.time_of_day_preset = preset
	if _visual_director != null:
		_visual_director.time_of_day_preset = preset
		_visual_director.refresh_visual_style()


func _on_lens_preset_selected(index: int) -> void:
	if _is_syncing_controls:
		return
	if PlayerSettings != null and PlayerSettings.is_low_power_profile():
		return
	var preset: int = lens_preset_option.get_item_id(index)
	if PlayerSettings != null:
		PlayerSettings.lens_preset = preset
	if _visual_director != null:
		_visual_director.apply_lens_preset(preset as PSXVisualDirector.LensPreset)


func _on_crosshair_toggled(enabled: bool) -> void:
	if _is_syncing_controls:
		return
	if PlayerSettings != null:
		PlayerSettings.crosshair_enabled = enabled
	if _hud != null:
		_hud.set_crosshair_enabled(enabled)


func _on_debug_hud_toggled(enabled: bool) -> void:
	if _is_syncing_controls or _hud == null:
		return
	_hud.set_debug_visible(enabled)


func _on_debug_draw_toggled(enabled: bool) -> void:
	if _is_syncing_controls or _debug_draw_manager == null:
		return
	_debug_draw_manager.set_debug_draw_enabled(enabled)


func _on_refill_ammo_pressed() -> void:
	if _player == null:
		return
	_player.add_ammo(120)


func _on_heal_player_pressed() -> void:
	if _player == null or _player.health == null:
		return
	_player.heal(_player.health.max_health)


func _on_damage_player_pressed() -> void:
	if _player == null:
		return
	_player.apply_damage(25)


func _on_respawn_player_pressed() -> void:
	respawn_requested.emit()


func _update_psx_option_visibility() -> void:
	var show_filter_options: bool = PlayerSettings == null or not PlayerSettings.is_low_power_profile()
	if style_header != null:
		style_header.visible = show_filter_options
	if psx_filter_check != null:
		psx_filter_check.visible = show_filter_options
	if time_preset_row != null:
		time_preset_row.visible = show_filter_options and _time_preset_row_initial_visible
	if lens_preset_row != null:
		lens_preset_row.visible = show_filter_options


func _apply_menu_profile_layout() -> void:
	var use_ultra_low_layout: bool = PlayerSettings != null and PlayerSettings.is_ultra_low_profile()
	var menu_scale: Vector2 = ULTRA_LOW_MENU_SCALE if use_ultra_low_layout else DEFAULT_MENU_SCALE
	if scroll != null:
		scroll.custom_minimum_size = (
			ULTRA_LOW_SCROLL_MINIMUM_SIZE if use_ultra_low_layout else DEFAULT_SCROLL_MINIMUM_SIZE
		)
		scroll.scale = menu_scale
		scroll.pivot_offset = scroll.custom_minimum_size * 0.5 if use_ultra_low_layout else Vector2.ZERO
	if content != null:
		content.add_theme_constant_override(
			"separation",
			ULTRA_LOW_MENU_SEPARATION if use_ultra_low_layout else DEFAULT_MENU_SEPARATION
		)
