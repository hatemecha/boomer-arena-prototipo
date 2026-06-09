class_name OptionsMenu
extends Control

signal resume_requested
signal respawn_requested
signal menu_visibility_changed(is_visible: bool)

const FRAME_LIMITS: Array[int] = [0, 30, 60, 120]

@onready var mouse_sensitivity_slider: HSlider = %MouseSensitivitySlider
@onready var mouse_sensitivity_value: Label = %MouseSensitivityValue
@onready var fov_slider: HSlider = %FovSlider
@onready var fov_value: Label = %FovValue
@onready var fullscreen_check: CheckBox = %FullscreenCheck
@onready var vsync_check: CheckBox = %VsyncCheck
@onready var frame_limit_option: OptionButton = %FrameLimitOption
@onready var psx_filter_check: CheckBox = %PsxFilterCheck
@onready var time_preset_option: OptionButton = %TimePresetOption
@onready var lens_preset_option: OptionButton = %LensPresetOption
@onready var crosshair_check: CheckBox = %CrosshairCheck
@onready var debug_hud_check: CheckBox = %DebugHudCheck
@onready var debug_draw_check: CheckBox = %DebugDrawCheck
@onready var resume_button: Button = %ResumeButton
@onready var refill_ammo_button: Button = %RefillAmmoButton
@onready var heal_player_button: Button = %HealPlayerButton
@onready var damage_player_button: Button = %DamagePlayerButton
@onready var respawn_player_button: Button = %RespawnPlayerButton

var _player: PlayerController
var _hud: HUD
var _visual_director: PSXVisualDirector
var _debug_draw_manager: ArenaDebugDrawManager
var _is_syncing_controls: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_populate_options()
	_connect_controls()


func bind_context(
	player: PlayerController,
	hud: HUD,
	visual_director: PSXVisualDirector,
	debug_draw_manager: ArenaDebugDrawManager = null
) -> void:
	if player == null:
		push_error("OptionsMenu cannot bind a null player.")
		return
	if hud == null:
		push_error("OptionsMenu cannot bind a null HUD.")
		return

	_player = player
	_hud = hud
	_visual_director = visual_director
	_debug_draw_manager = debug_draw_manager
	_sync_controls_from_game()


func open() -> void:
	_sync_controls_from_game()
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	resume_button.grab_focus()
	menu_visibility_changed.emit(true)


func close() -> void:
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	menu_visibility_changed.emit(false)


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func _populate_options() -> void:
	frame_limit_option.clear()
	frame_limit_option.add_item("Sin limite", 0)
	frame_limit_option.add_item("30 FPS", 30)
	frame_limit_option.add_item("60 FPS", 60)
	frame_limit_option.add_item("120 FPS", 120)

	time_preset_option.clear()
	time_preset_option.add_item("Manana", PSXVisualDirector.TimeOfDayPreset.MORNING)
	time_preset_option.add_item("Tarde", PSXVisualDirector.TimeOfDayPreset.AFTERNOON)
	time_preset_option.add_item("Noche", PSXVisualDirector.TimeOfDayPreset.NIGHT)

	lens_preset_option.clear()
	lens_preset_option.add_item("Off", PSXVisualDirector.LensPreset.OFF)
	lens_preset_option.add_item("Gameplay", PSXVisualDirector.LensPreset.GAMEPLAY)
	lens_preset_option.add_item("PSX 8mm", PSXVisualDirector.LensPreset.PSX_8MM)
	lens_preset_option.add_item("Extreme Debug", PSXVisualDirector.LensPreset.EXTREME_DEBUG)


func _connect_controls() -> void:
	resume_button.pressed.connect(_on_resume_pressed)
	mouse_sensitivity_slider.value_changed.connect(_on_mouse_sensitivity_changed)
	fov_slider.value_changed.connect(_on_fov_changed)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	vsync_check.toggled.connect(_on_vsync_toggled)
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

	if _player != null:
		mouse_sensitivity_slider.value = _player.mouse_sensitivity
		fov_slider.value = _player.fov
		_update_mouse_sensitivity_label(_player.mouse_sensitivity)
		_update_fov_label(_player.fov)

	fullscreen_check.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	vsync_check.button_pressed = DisplayServer.window_get_vsync_mode() != DisplayServer.VSYNC_DISABLED
	_select_frame_limit(Engine.max_fps)

	if _visual_director != null:
		psx_filter_check.button_pressed = _visual_director.post_process_enabled
		_select_option_by_id(time_preset_option, _visual_director.time_of_day_preset)
		_select_option_by_id(lens_preset_option, _visual_director.lens_preset)

	if _hud != null:
		crosshair_check.button_pressed = _hud.is_crosshair_enabled()
		debug_hud_check.button_pressed = _hud.is_debug_visible()

	if _debug_draw_manager != null:
		debug_draw_check.button_pressed = _debug_draw_manager.debug_draw_enabled
	else:
		debug_draw_check.button_pressed = false
		debug_draw_check.disabled = true

	_is_syncing_controls = false


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


func _on_resume_pressed() -> void:
	close()
	resume_requested.emit()


func _on_mouse_sensitivity_changed(value: float) -> void:
	_update_mouse_sensitivity_label(value)
	if _is_syncing_controls or _player == null:
		return
	_player.mouse_sensitivity = clampf(value, 0.02, 0.50)


func _on_fov_changed(value: float) -> void:
	_update_fov_label(value)
	if _is_syncing_controls or _player == null:
		return
	_player.fov = clampf(value, 75.0, 110.0)
	_player.aim_fov = minf(_player.aim_fov, _player.fov - 15.0)


func _update_mouse_sensitivity_label(value: float) -> void:
	mouse_sensitivity_value.text = "%.2f" % value


func _update_fov_label(value: float) -> void:
	fov_value.text = "%d" % int(roundf(value))


func _on_fullscreen_toggled(enabled: bool) -> void:
	if _is_syncing_controls:
		return
	var mode: int = DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)


func _on_vsync_toggled(enabled: bool) -> void:
	if _is_syncing_controls:
		return
	var mode: int = DisplayServer.VSYNC_ENABLED if enabled else DisplayServer.VSYNC_DISABLED
	DisplayServer.window_set_vsync_mode(mode)


func _on_frame_limit_selected(index: int) -> void:
	if _is_syncing_controls:
		return
	Engine.max_fps = frame_limit_option.get_item_id(index)


func _on_psx_filter_toggled(enabled: bool) -> void:
	if _is_syncing_controls or _visual_director == null:
		return
	_visual_director.post_process_enabled = enabled
	_visual_director.refresh_visual_style()


func _on_time_preset_selected(index: int) -> void:
	if _is_syncing_controls or _visual_director == null:
		return
	_visual_director.time_of_day_preset = time_preset_option.get_item_id(index)
	_visual_director.refresh_visual_style()


func _on_lens_preset_selected(index: int) -> void:
	if _is_syncing_controls or _visual_director == null:
		return
	_visual_director.apply_lens_preset(lens_preset_option.get_item_id(index) as PSXVisualDirector.LensPreset)


func _on_crosshair_toggled(enabled: bool) -> void:
	if _is_syncing_controls or _hud == null:
		return
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
