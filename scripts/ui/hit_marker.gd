class_name HitMarker
extends Control

@export_range(0.03, 0.3) var duration: float = 0.09
@export_range(2.0, 12.0) var inner_gap: float = 4.0
@export_range(2.0, 14.0) var line_length: float = 5.0
@export_range(0.5, 4.0) var line_width: float = 1.5

var _time_left: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	set_process(false)


func trigger() -> void:
	_time_left = duration
	visible = true
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_time_left -= delta
	if _time_left <= 0.0:
		visible = false
		set_process(false)
		return
	queue_redraw()


func _draw() -> void:
	var center: Vector2 = size * 0.5
	var alpha: float = clampf(_time_left / maxf(duration, 0.001), 0.0, 1.0)
	var color := Color(1.0, 0.08, 0.03, alpha)
	for direction in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var unit_direction: Vector2 = direction.normalized()
		draw_line(
			center + unit_direction * inner_gap,
			center + unit_direction * (inner_gap + line_length),
			color,
			line_width,
			true
		)
