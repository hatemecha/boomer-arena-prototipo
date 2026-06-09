class_name ArenaMenuStyle
extends RefCounted

const TAG_TINT: Color = HudIcons.HUD_TAG_TINT
const VALUE_TINT: Color = HudIcons.HUD_TINT
const MUTED: Color = Color(0.62, 0.62, 0.56, 1.0)
const BLOOD: Color = HudIcons.HUD_TAG_TINT
const BLACK_CLEAR: Color = Color(0.0, 0.0, 0.0, 0.0)

const TAG_WIDTH: int = 72
const FONT_SIZE: int = 14
const TITLE_SIZE: int = 18
const SECTION_SIZE: int = 13


static func apply_to_menu(root: Control) -> void:
	if root == null:
		return

	for child in root.find_children("*", "Control", true, false):
		var control := child as Control
		if control == null:
			continue
		_apply_control_style(control)


static func _apply_control_style(control: Control) -> void:
	if control is PanelContainer:
		_style_panel(control as PanelContainer)
	elif control is CheckBox:
		_style_check_box(control as CheckBox)
	elif control is Button:
		_style_button(control as Button)
	elif control is LineEdit:
		_style_line_edit(control as LineEdit)
	elif control is SpinBox:
		_style_spin_box(control as SpinBox)
	elif control is HSlider:
		_style_slider(control as HSlider)
	elif control is OptionButton:
		_style_option_button(control as OptionButton)
	elif control is Label:
		_style_label(control as Label)
	elif control is ScrollContainer:
		(control as ScrollContainer).add_theme_stylebox_override("panel", _stylebox(BLACK_CLEAR, BLACK_CLEAR, 0))


static func _style_panel(panel: PanelContainer) -> void:
	panel.add_theme_stylebox_override("panel", _stylebox(BLACK_CLEAR, BLACK_CLEAR, 0, 0, 0))


static func _style_button(button: Button) -> void:
	button.flat = true
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_font_size_override("font_size", FONT_SIZE)
	button.add_theme_color_override("font_color", VALUE_TINT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", BLOOD)
	button.add_theme_color_override("font_disabled_color", Color(0.34, 0.34, 0.31, 0.65))
	button.add_theme_stylebox_override("normal", _stylebox(BLACK_CLEAR, BLACK_CLEAR, 0, 0, 0))
	button.add_theme_stylebox_override("hover", _stylebox(BLACK_CLEAR, BLACK_CLEAR, 0, 0, 0))
	button.add_theme_stylebox_override("pressed", _stylebox(BLACK_CLEAR, BLACK_CLEAR, 0, 0, 0))
	button.add_theme_stylebox_override("focus", _stylebox(BLACK_CLEAR, BLACK_CLEAR, 0, 0, 0))
	button.add_theme_stylebox_override("disabled", _stylebox(BLACK_CLEAR, BLACK_CLEAR, 0, 0, 0))


static func _style_check_box(check_box: CheckBox) -> void:
	check_box.add_theme_font_size_override("font_size", FONT_SIZE)
	check_box.add_theme_color_override("font_color", VALUE_TINT)
	check_box.add_theme_color_override("font_hover_color", Color.WHITE)
	check_box.add_theme_color_override("font_pressed_color", VALUE_TINT)
	check_box.add_theme_color_override("font_disabled_color", MUTED)


static func _style_line_edit(line_edit: LineEdit) -> void:
	line_edit.add_theme_font_size_override("font_size", FONT_SIZE)
	line_edit.add_theme_color_override("font_color", VALUE_TINT)
	line_edit.add_theme_color_override("font_placeholder_color", MUTED)
	line_edit.add_theme_color_override("caret_color", BLOOD)
	line_edit.add_theme_stylebox_override("normal", _stylebox(BLACK_CLEAR, BLACK_CLEAR, 0, 0, 0))
	line_edit.add_theme_stylebox_override("focus", _stylebox(BLACK_CLEAR, BLACK_CLEAR, 0, 0, 0))
	line_edit.add_theme_stylebox_override("read_only", _stylebox(BLACK_CLEAR, BLACK_CLEAR, 0, 0, 0))


static func _style_spin_box(spin_box: SpinBox) -> void:
	spin_box.add_theme_font_size_override("font_size", FONT_SIZE)
	spin_box.add_theme_color_override("font_color", VALUE_TINT)
	spin_box.add_theme_color_override("font_hover_color", Color.WHITE)
	spin_box.add_theme_color_override("font_disabled_color", MUTED)


static func _style_option_button(option_button: OptionButton) -> void:
	option_button.add_theme_font_size_override("font_size", FONT_SIZE)
	option_button.add_theme_color_override("font_color", VALUE_TINT)
	option_button.add_theme_color_override("font_hover_color", Color.WHITE)
	option_button.add_theme_color_override("font_pressed_color", BLOOD)
	option_button.add_theme_color_override("font_disabled_color", MUTED)
	option_button.add_theme_stylebox_override("normal", _stylebox(BLACK_CLEAR, BLACK_CLEAR, 0, 0, 0))
	option_button.add_theme_stylebox_override("hover", _stylebox(BLACK_CLEAR, BLACK_CLEAR, 0, 0, 0))
	option_button.add_theme_stylebox_override("pressed", _stylebox(BLACK_CLEAR, BLACK_CLEAR, 0, 0, 0))
	option_button.add_theme_stylebox_override("focus", _stylebox(BLACK_CLEAR, BLACK_CLEAR, 0, 0, 0))
	option_button.add_theme_stylebox_override("disabled", _stylebox(BLACK_CLEAR, BLACK_CLEAR, 0, 0, 0))


static func _style_slider(slider: HSlider) -> void:
	slider.add_theme_stylebox_override("slider", _stylebox(Color(0.70, 0.68, 0.58, 0.20), BLACK_CLEAR, 0, 0, 1))
	slider.add_theme_stylebox_override("grabber_area", _stylebox(Color(0.92, 0.08, 0.035, 0.65), BLACK_CLEAR, 0, 0, 1))
	slider.add_theme_stylebox_override("grabber_area_highlight", _stylebox(Color(1.0, 0.22, 0.15, 0.9), BLACK_CLEAR, 0, 0, 1))


static func _style_label(label: Label) -> void:
	label.add_theme_color_override("font_color", VALUE_TINT)
	label.add_theme_font_size_override("font_size", FONT_SIZE)

	if label.name == "GameTitle":
		label.add_theme_font_size_override("font_size", TITLE_SIZE)
		label.add_theme_color_override("font_color", BLOOD)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	elif label.name.contains("Header"):
		label.add_theme_font_size_override("font_size", SECTION_SIZE)
		label.add_theme_color_override("font_color", BLOOD)
	elif label.name.contains("Status") or label.name.contains("Meta") or label.name == "LocalAddressesLabel":
		label.add_theme_color_override("font_color", MUTED)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	elif label.name.ends_with("Label") and label.get_parent() is HBoxContainer:
		label.custom_minimum_size.x = TAG_WIDTH
		label.add_theme_color_override("font_color", TAG_TINT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	elif label.name.ends_with("Value"):
		label.add_theme_color_override("font_color", VALUE_TINT)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


static func _stylebox(
	bg_color: Color,
	border_color: Color,
	border_width: int,
	corner_radius: int = 0,
	content_margin: int = 0
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	style.content_margin_left = content_margin
	style.content_margin_top = content_margin
	style.content_margin_right = content_margin
	style.content_margin_bottom = content_margin
	return style
