class_name ArenaMenuBackdrop
extends RefCounted

const DIM_COLOR: Color = Color(0.0, 0.0, 0.0, 0.62)


static func apply(root: Control) -> void:
	if root == null:
		return

	_remove_fisheye_overlay(root)
	_ensure_dim_overlay(root)


static func _ensure_dim_overlay(root: Control) -> void:
	var overlay := root.get_node_or_null("DimOverlay") as ColorRect
	if overlay == null:
		var legacy := root.get_node_or_null("BlackBackground") as ColorRect
		if legacy != null:
			legacy.name = "DimOverlay"
			overlay = legacy
		else:
			overlay = ColorRect.new()
			overlay.name = "DimOverlay"
			root.add_child(overlay)

	root.move_child(overlay, 0)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.offset_left = 0.0
	overlay.offset_top = 0.0
	overlay.offset_right = 0.0
	overlay.offset_bottom = 0.0
	overlay.grow_horizontal = Control.GROW_DIRECTION_BOTH
	overlay.grow_vertical = Control.GROW_DIRECTION_BOTH
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.color = DIM_COLOR


static func _remove_fisheye_overlay(root: Control) -> void:
	var overlay := root.get_node_or_null("FisheyeOverlay")
	if overlay != null:
		overlay.queue_free()
