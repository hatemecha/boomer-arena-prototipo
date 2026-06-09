class_name CircularCrosshair
extends Control

const INVERT_SHADER: Shader = preload("res://shaders/crosshair_invert.gdshader")
const MASK_COLOR: Color = Color.WHITE

const ARC_POINT_COUNT: int = 24
const ARC_RANGES: Array[Vector2] = [
	Vector2(12.0, 78.0),
	Vector2(102.0, 168.0),
	Vector2(192.0, 258.0),
	Vector2(282.0, 348.0),
]

@export_range(6.0, 40.0, 0.5) var radius: float = 8.0
@export_range(0.25, 4.0, 0.05) var line_width: float = 1.0
@export_range(2.0, 18.0, 0.5) var outer_tick_length: float = 4.0
@export_range(0.0, 8.0, 0.5) var outer_tick_gap: float = 1.0
@export_range(1.0, 16.0, 0.5) var inner_line_length: float = 3.0
@export_range(0.0, 10.0, 0.5) var center_gap: float = 1.8
@export_range(0.0, 4.0, 0.25) var center_dot_radius: float = 0.5
@export_range(0.5, 4.0, 0.25) var aim_dot_radius: float = 1.1
@export_range(0.2, 1.0, 0.05) var aiming_alpha_multiplier: float = 0.88

var _is_aiming: bool = false
var _invert_material: ShaderMaterial


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(radius + outer_tick_length + 4.0, radius + outer_tick_length + 4.0) * 2.0
	_setup_invert_material()
	queue_redraw()


func set_aiming(value: bool) -> void:
	if _is_aiming == value:
		return
	_is_aiming = value
	_update_opacity()
	queue_redraw()


func _setup_invert_material() -> void:
	_invert_material = ShaderMaterial.new()
	_invert_material.shader = INVERT_SHADER
	material = _invert_material
	_update_opacity()


func _update_opacity() -> void:
	if _invert_material == null:
		return
	var target_opacity: float = aiming_alpha_multiplier if _is_aiming else 1.0
	_invert_material.set_shader_parameter("opacity", target_opacity)


func _draw() -> void:
	var center: Vector2 = size * 0.5

	if _is_aiming:
		draw_circle(center, aim_dot_radius, MASK_COLOR)
		return

	_draw_reticle(center, radius, MASK_COLOR, line_width)


func _draw_reticle(center: Vector2, current_radius: float, color: Color, current_width: float) -> void:
	for arc_range in ARC_RANGES:
		draw_arc(
			center,
			current_radius,
			deg_to_rad(arc_range.x),
			deg_to_rad(arc_range.y),
			ARC_POINT_COUNT,
			color,
			current_width,
			true
		)

	var tick_start: float = current_radius + outer_tick_gap
	var tick_end: float = current_radius + outer_tick_gap + outer_tick_length
	_draw_line_pair(center, Vector2(0.0, -tick_start), Vector2(0.0, -tick_end), color, current_width)
	_draw_line_pair(center, Vector2(0.0, tick_start), Vector2(0.0, tick_end), color, current_width)
	_draw_line_pair(center, Vector2(-tick_start, 0.0), Vector2(-tick_end, 0.0), color, current_width)
	_draw_line_pair(center, Vector2(tick_start, 0.0), Vector2(tick_end, 0.0), color, current_width)

	var inner_start: float = center_gap
	var inner_end: float = center_gap + inner_line_length
	_draw_line_pair(center, Vector2(-inner_start, 0.0), Vector2(-inner_end, 0.0), color, current_width)
	_draw_line_pair(center, Vector2(inner_start, 0.0), Vector2(inner_end, 0.0), color, current_width)
	_draw_line_pair(center, Vector2(0.0, -inner_start), Vector2(0.0, -inner_end), color, current_width)
	_draw_line_pair(center, Vector2(0.0, inner_start), Vector2(0.0, inner_end), color, current_width)

	if center_dot_radius > 0.0:
		draw_circle(center, center_dot_radius, color)


func _draw_line_pair(center: Vector2, from_offset: Vector2, to_offset: Vector2, color: Color, current_width: float) -> void:
	draw_line(center + from_offset, center + to_offset, color, current_width, true)
