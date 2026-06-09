class_name HudIcons
extends RefCounted

const ICON_SIZE: Vector2 = Vector2(16.0, 16.0)
const TAG_MIN_SIZE: Vector2 = Vector2(72.0, 16.0)

const HEALTH: String = "VIDA"
const WEAPON: String = "ARMA"
const AMMO: String = "MUNICIÓN"
const PLAYER: String = "JUGADOR"
const SCORE: String = "K/D"
const MATCH: String = "PARTIDA"
const NETWORK: String = "RED"
const PING: String = "PING"
const DEBUG: String = "DEBUG"
const POSITION: String = "POS"
const SPEED: String = "VEL"

const HUD_TINT: Color = Color(0.92, 0.9, 0.86, 1.0)
const HUD_WARN_TINT: Color = Color(1.0, 0.28, 0.12, 1.0)
const HUD_TAG_TINT: Color = Color(1.0, 0.12, 0.05, 1.0)


static func make_icon(texture: Texture2D, tint: Color = HUD_TINT) -> TextureRect:
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.texture = texture
	icon.custom_minimum_size = ICON_SIZE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.modulate = tint
	return icon


static func make_tag(text: String, tint: Color = HUD_TAG_TINT) -> Label:
	var tag := Label.new()
	tag.name = "Tag"
	tag.custom_minimum_size = TAG_MIN_SIZE
	tag.text = text
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tag.modulate = tint
	tag.add_theme_font_size_override("font_size", 14)
	return tag


static func make_stat_row(row_name: String, label_name: String, marker: Variant) -> Dictionary:
	var row := HBoxContainer.new()
	row.name = row_name
	row.add_theme_constant_override("separation", 6)
	var marker_control: Control
	if marker is Texture2D:
		marker_control = make_icon(marker)
	else:
		marker_control = make_tag(str(marker))
	row.add_child(marker_control)
	var label := Label.new()
	label.name = label_name
	row.add_child(label)
	return {
		"row": row,
		"marker": marker_control,
		"label": label,
	}
