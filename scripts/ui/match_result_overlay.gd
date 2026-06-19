class_name MatchResultOverlay
extends Control

const PlayerSettingsAccess = preload("res://scripts/game/player_settings_access.gd")

signal rematch_requested
signal menu_requested

const TITLE_FONT: FontFile = preload("res://fonts/WO3.ttf")
const SUBTITLE_FONT: FontFile = preload("res://fonts/2097.ttf")
const ArenaMenuStyleScript: GDScript = preload("res://scripts/ui/arena_menu_style.gd")
const ArenaMenuBackdropScript: GDScript = preload("res://scripts/ui/arena_menu_backdrop.gd")
const WIN_COLOR: Color = Color(0.24, 1.0, 0.38, 1.0)
const LOSE_COLOR: Color = Color(1.0, 0.08, 0.08, 1.0)
const DRAW_COLOR: Color = Color(0.92, 0.92, 0.86, 1.0)
const DEFAULT_TITLE_MINIMUM_SIZE: Vector2 = Vector2(420.0, 58.0)
const ULTRA_LOW_TITLE_MINIMUM_SIZE: Vector2 = Vector2(330.0, 46.0)
const DEFAULT_BUTTON_MINIMUM_SIZE: Vector2 = Vector2(180.0, 28.0)
const ULTRA_LOW_BUTTON_MINIMUM_SIZE: Vector2 = Vector2(150.0, 24.0)
const DEFAULT_CONTENT_SEPARATION: int = 14
const ULTRA_LOW_CONTENT_SEPARATION: int = 8
const DEFAULT_BUTTON_SEPARATION: int = 16
const ULTRA_LOW_BUTTON_SEPARATION: int = 8

@onready var backdrop: ColorRect = %Backdrop
@onready var content: VBoxContainer = $Center/Content
@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var score_label: Label = %ScoreLabel
@onready var buttons: HBoxContainer = $Center/Content/Buttons
@onready var rematch_button: Button = %RematchButton
@onready var menu_button: Button = %MenuButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	ArenaMenuBackdropScript.apply(self)
	ArenaMenuStyleScript.wrap_menu_shell(content)
	ArenaMenuStyleScript.configure_content_column(content)
	ArenaMenuStyleScript.apply_to_menu(self)
	_apply_menu_profile_layout()
	rematch_button.pressed.connect(_on_rematch_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	if PlayerSettingsAccess.has_settings():
		PlayerSettingsAccess.connect_settings_changed(_on_settings_changed)
		PlayerSettingsAccess.connect_performance_profile_changed(_on_performance_profile_changed)
	resized.connect(_apply_menu_profile_layout)


func _apply_fonts() -> void:
	var use_ultra_low_layout: bool = PlayerSettingsAccess.is_ultra_low_profile()
	if title_label != null:
		title_label.add_theme_font_override("font", TITLE_FONT)
		title_label.add_theme_font_size_override("font_size", 32 if use_ultra_low_layout else 44)
	if subtitle_label != null:
		subtitle_label.add_theme_font_override("font", SUBTITLE_FONT)
		subtitle_label.add_theme_font_size_override("font_size", 14 if use_ultra_low_layout else 16)
	if score_label != null:
		score_label.add_theme_font_override("font", SUBTITLE_FONT)
		score_label.add_theme_font_size_override("font_size", 12 if use_ultra_low_layout else 14)


func _on_settings_changed() -> void:
	ArenaMenuStyleScript.apply_to_menu(self)
	_apply_menu_profile_layout()


func _on_performance_profile_changed(_profile: int) -> void:
	_apply_menu_profile_layout()


func _apply_menu_profile_layout() -> void:
	var use_ultra_low_layout: bool = PlayerSettingsAccess.is_ultra_low_profile()
	var viewport_width: float = get_viewport_rect().size.x
	var base_title_size: Vector2 = ULTRA_LOW_TITLE_MINIMUM_SIZE if use_ultra_low_layout else DEFAULT_TITLE_MINIMUM_SIZE
	var title_minimum_size := Vector2(minf(base_title_size.x, viewport_width - 32.0), base_title_size.y)
	var button_width: float = clampf((viewport_width - 48.0) * 0.5, 120.0, 180.0)
	var button_minimum_size: Vector2 = (
		ULTRA_LOW_BUTTON_MINIMUM_SIZE if use_ultra_low_layout else DEFAULT_BUTTON_MINIMUM_SIZE
	)
	button_minimum_size.x = minf(button_minimum_size.x, button_width)
	if title_label != null:
		title_label.custom_minimum_size = title_minimum_size
	if buttons != null:
		buttons.add_theme_constant_override(
			"separation",
			ULTRA_LOW_BUTTON_SEPARATION if use_ultra_low_layout else DEFAULT_BUTTON_SEPARATION
		)
	for button in [rematch_button, menu_button]:
		if button is Button:
			(button as Button).custom_minimum_size = button_minimum_size
	if content != null:
		content.scale = Vector2.ONE
		content.add_theme_constant_override(
			"separation",
			ULTRA_LOW_CONTENT_SEPARATION if use_ultra_low_layout else DEFAULT_CONTENT_SEPARATION
		)
		content.pivot_offset = content.get_combined_minimum_size() * 0.5 if use_ultra_low_layout else Vector2.ZERO
	_apply_fonts()


func show_result(
	winner_id: int,
	local_player_id: int,
	match_manager: MatchManager,
	is_host: bool,
	is_networked: bool,
	winner_display_name: String = ""
) -> void:
	if match_manager == null:
		return

	var winner_name: String = winner_display_name.strip_edges()
	if winner_name.is_empty():
		winner_name = match_manager.get_player_name(winner_id) if winner_id > 0 else "Nadie"

	if winner_id <= 0:
		title_label.text = "EMPATE"
		title_label.add_theme_color_override("font_color", DRAW_COLOR)
	elif winner_id == local_player_id:
		title_label.text = "GANASTE"
		title_label.add_theme_color_override("font_color", WIN_COLOR)
	else:
		title_label.text = "PERDISTE"
		title_label.add_theme_color_override("font_color", LOSE_COLOR)

	if match_manager.win_mode == MatchManager.WinMode.TIME_LIMIT:
		subtitle_label.text = "FIN DEL TIEMPO"
	else:
		subtitle_label.text = "PRIMERO A %d" % match_manager.score_limit

	score_label.text = "GANADOR: %s" % winner_name.to_upper()
	rematch_button.visible = true
	rematch_button.disabled = is_networked and not is_host
	rematch_button.text = "REVANCHA"
	_apply_menu_profile_layout()
	menu_button.grab_focus()
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func hide_overlay() -> void:
	visible = false


func _on_rematch_pressed() -> void:
	hide_overlay()
	rematch_requested.emit()


func _on_menu_pressed() -> void:
	hide_overlay()
	menu_requested.emit()
