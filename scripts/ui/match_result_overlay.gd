class_name MatchResultOverlay
extends Control

signal rematch_requested
signal menu_requested

const TITLE_FONT: FontFile = preload("res://fonts/WO3.ttf")
const SUBTITLE_FONT: FontFile = preload("res://fonts/2097.ttf")
const ArenaMenuStyleScript: GDScript = preload("res://scripts/ui/arena_menu_style.gd")
const ArenaMenuBackdropScript: GDScript = preload("res://scripts/ui/arena_menu_backdrop.gd")
const WIN_COLOR: Color = Color(0.24, 1.0, 0.38, 1.0)
const LOSE_COLOR: Color = Color(1.0, 0.08, 0.08, 1.0)
const DRAW_COLOR: Color = Color(0.92, 0.92, 0.86, 1.0)

@onready var backdrop: ColorRect = %Backdrop
@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var score_label: Label = %ScoreLabel
@onready var rematch_button: Button = %RematchButton
@onready var menu_button: Button = %MenuButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	ArenaMenuBackdropScript.apply(self)
	ArenaMenuStyleScript.apply_to_menu(self)
	_apply_fonts()
	rematch_button.pressed.connect(_on_rematch_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	if PlayerSettings != null:
		PlayerSettings.settings_changed.connect(_on_settings_changed)


func _apply_fonts() -> void:
	if title_label != null:
		title_label.add_theme_font_override("font", TITLE_FONT)
		title_label.add_theme_font_size_override("font_size", 44)
	if subtitle_label != null:
		subtitle_label.add_theme_font_override("font", SUBTITLE_FONT)
		subtitle_label.add_theme_font_size_override("font_size", 16)
	if score_label != null:
		score_label.add_theme_font_override("font", SUBTITLE_FONT)
		score_label.add_theme_font_size_override("font_size", 14)


func _on_settings_changed() -> void:
	ArenaMenuStyleScript.apply_to_menu(self)


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
