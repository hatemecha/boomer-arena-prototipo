class_name ArenaMenuStyle
extends RefCounted

const VALUE_TINT: Color = HudIcons.HUD_TINT
const MUTED: Color = Color(0.62, 0.62, 0.56, 1.0)
const BLACK_CLEAR: Color = Color(0.0, 0.0, 0.0, 0.0)
const PANEL_BG: Color = Color(0.04, 0.04, 0.04, 0.42)
const TITLE_FONT: FontFile = preload("res://fonts/WO3.ttf")

const TAG_WIDTH: int = 100
const FONT_SIZE: int = 14
const TITLE_SIZE: int = 18
const SECTION_SIZE: int = 13
const PANEL_PADDING: int = 14
const CONTENT_MIN_WIDTH: float = 272.0
const ACTION_BUTTON_MIN_WIDTH: float = 252.0


static func _accent() -> Color:
	return HudIcons.get_tag_tint()


static func apply_to_menu(root: Control) -> void:
	if root == null:
		return

	for child in root.find_children("*", "Control", true, false):
		var control := child as Control
		if control == null:
			continue
		_apply_control_style(control)

	apply_menu_layout(root)


static func apply_menu_layout(root: Control) -> void:
	if root == null:
		return

	for child in root.find_children("*", "HBoxContainer", true, false):
		var row := child as HBoxContainer
		if row.name.ends_with("Row") or row.name == "DevelopmentActions" or row.name == "SectionTabs":
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	for child in root.find_children("*", "Button", true, false):
		var button := child as Button
		if _is_primary_action_button(button):
			button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	for child in root.find_children("*", "CheckBox", true, false):
		(child as CheckBox).size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

	for child in root.find_children("*", "ItemList", true, false):
		(child as ItemList).size_flags_horizontal = Control.SIZE_SHRINK_CENTER


static func configure_content_column(column: VBoxContainer) -> void:
	if column == null:
		return
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL


static func wrap_menu_shell(node: Control) -> PanelContainer:
	if node == null:
		return null

	var parent := node.get_parent()
	if parent is PanelContainer and parent.name == "MenuShell":
		return parent as PanelContainer

	var index := node.get_index()
	var panel := PanelContainer.new()
	panel.name = "MenuShell"
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var margin := _make_panel_margin()
	parent.remove_child(node)
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	margin.add_child(node)
	panel.add_child(margin)
	parent.add_child(panel)
	parent.move_child(panel, index)
	return panel


static func configure_centered_scroll(
	scroll: ScrollContainer,
	content: VBoxContainer,
	available_size: Vector2,
	min_width: float,
	max_width: float
) -> void:
	if scroll == null:
		return

	var menu_width: float = clampf(available_size.x, min_width, max_width)
	var inner_width: float = maxf(menu_width - float(PANEL_PADDING) * 2.0, CONTENT_MIN_WIDTH)
	scroll.custom_minimum_size.x = inner_width
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	if content != null:
		content.custom_minimum_size.x = inner_width
		content.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	sync_scroll_height(scroll, content, available_size.y)


static func sync_scroll_height(scroll: ScrollContainer, content: Control, max_height: float) -> void:
	if scroll == null or content == null:
		return

	var content_height: float = content.get_combined_minimum_size().y
	if content_height <= 0.0:
		content_height = 160.0

	var safe_max_height: float = maxf(max_height, 160.0)
	var target_height: float = minf(content_height, safe_max_height)
	scroll.custom_minimum_size.y = target_height
	scroll.vertical_scroll_mode = (
		ScrollContainer.SCROLL_MODE_AUTO
		if content_height > target_height + 1.0
		else ScrollContainer.SCROLL_MODE_DISABLED
	)


static func configure_menu_width(content: Control, available_width: float, min_width: float, max_width: float) -> void:
	if content == null:
		return
	var menu_width: float = clampf(available_width, min_width, max_width)
	var inner_width: float = maxf(menu_width - float(PANEL_PADDING) * 2.0, CONTENT_MIN_WIDTH)
	content.custom_minimum_size.x = inner_width
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL


static func _make_panel_margin() -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", PANEL_PADDING)
	margin.add_theme_constant_override("margin_top", PANEL_PADDING)
	margin.add_theme_constant_override("margin_right", PANEL_PADDING)
	margin.add_theme_constant_override("margin_bottom", PANEL_PADDING)
	return margin


static func _is_primary_action_button(button: Button) -> bool:
	if button == null:
		return false
	if button.custom_minimum_size.x >= ACTION_BUTTON_MIN_WIDTH:
		return true
	if button.get_parent() is HBoxContainer and button.get_parent().name == "DevelopmentActions":
		return false
	return button.name.ends_with("Button")


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
	if panel.name != "MenuShell":
		return
	panel.add_theme_stylebox_override("panel", _stylebox(PANEL_BG, BLACK_CLEAR, 0, 0, 0))


static func _style_button(button: Button) -> void:
	button.flat = true
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_font_size_override("font_size", FONT_SIZE)
	button.add_theme_color_override("font_color", VALUE_TINT)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", _accent())
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
	line_edit.add_theme_color_override("caret_color", _accent())
	line_edit.add_theme_stylebox_override("normal", _stylebox(BLACK_CLEAR, BLACK_CLEAR, 0, 0, 0))
	line_edit.add_theme_stylebox_override("focus", _stylebox(BLACK_CLEAR, BLACK_CLEAR, 0, 0, 0))
	line_edit.add_theme_stylebox_override("read_only", _stylebox(BLACK_CLEAR, BLACK_CLEAR, 0, 0, 0))


static func _style_spin_box(spin_box: SpinBox) -> void:
	spin_box.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	spin_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spin_box.add_theme_font_size_override("font_size", FONT_SIZE)
	spin_box.add_theme_color_override("font_color", VALUE_TINT)
	spin_box.add_theme_color_override("font_hover_color", Color.WHITE)
	spin_box.add_theme_color_override("font_disabled_color", MUTED)


static func _style_option_button(option_button: OptionButton) -> void:
	option_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	option_button.add_theme_font_size_override("font_size", FONT_SIZE)
	option_button.add_theme_color_override("font_color", VALUE_TINT)
	option_button.add_theme_color_override("font_hover_color", Color.WHITE)
	option_button.add_theme_color_override("font_pressed_color", _accent())
	option_button.add_theme_color_override("font_disabled_color", MUTED)
	option_button.add_theme_stylebox_override("normal", _stylebox(BLACK_CLEAR, BLACK_CLEAR, 0, 0, 0))
	option_button.add_theme_stylebox_override("hover", _stylebox(BLACK_CLEAR, BLACK_CLEAR, 0, 0, 0))
	option_button.add_theme_stylebox_override("pressed", _stylebox(BLACK_CLEAR, BLACK_CLEAR, 0, 0, 0))
	option_button.add_theme_stylebox_override("focus", _stylebox(BLACK_CLEAR, BLACK_CLEAR, 0, 0, 0))
	option_button.add_theme_stylebox_override("disabled", _stylebox(BLACK_CLEAR, BLACK_CLEAR, 0, 0, 0))


static func _style_slider(slider: HSlider) -> void:
	var accent: Color = _accent()
	var track_bg: Color = Color(0.70, 0.68, 0.58, 0.20)
	var grabber: Color = Color(accent.r, accent.g, accent.b, 0.65)
	var grabber_hi: Color = Color(accent.r, accent.g, accent.b, 0.9)
	slider.add_theme_stylebox_override("slider", _stylebox(track_bg, BLACK_CLEAR, 0, 0, 1))
	slider.add_theme_stylebox_override("grabber_area", _stylebox(grabber, BLACK_CLEAR, 0, 0, 1))
	slider.add_theme_stylebox_override("grabber_area_highlight", _stylebox(grabber_hi, BLACK_CLEAR, 0, 0, 1))


static func _style_label(label: Label) -> void:
	label.add_theme_color_override("font_color", VALUE_TINT)
	label.add_theme_font_size_override("font_size", FONT_SIZE)

	if label.name == "GameTitle" or label.name == "TitleLabel":
		label.add_theme_font_override("font", TITLE_FONT)
		label.add_theme_font_size_override("font_size", TITLE_SIZE)
		label.add_theme_color_override("font_color", _accent())
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	elif label.name.contains("Header"):
		label.add_theme_font_size_override("font_size", SECTION_SIZE)
		label.add_theme_color_override("font_color", _accent())
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	elif (
		label.name.contains("Status")
		or label.name.contains("Meta")
		or label.name.contains("Info")
		or label.name == "LocalAddressesLabel"
		or label.name == "SubtitleLabel"
		or label.name == "ScoreLabel"
	):
		label.add_theme_color_override("font_color", MUTED)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	elif label.name.ends_with("Label") and label.get_parent() is HBoxContainer:
		label.custom_minimum_size.x = TAG_WIDTH
		label.add_theme_color_override("font_color", _accent())
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	elif label.name.ends_with("Value"):
		label.custom_minimum_size.x = 40
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
