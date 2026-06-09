class_name ArenaMenuMotion
extends RefCounted

const HOVER_SCALE: float = 1.04
const PRESS_SCALE: float = 0.97

var _root: Control
var _is_bound: bool = false


func bind(root: Control) -> void:
	_root = root
	_is_bound = _root != null
	if _is_bound:
		_configure_interactive_controls()


func play_open() -> void:
	pass


func update(_delta: float) -> void:
	pass


func _configure_interactive_controls() -> void:
	if _root == null:
		return

	for child in _root.find_children("*", "BaseButton", true, false):
		var button := child as BaseButton
		if button == null:
			continue
		button.mouse_entered.connect(_on_control_hovered.bind(button))
		button.focus_entered.connect(_on_control_hovered.bind(button))
		button.mouse_exited.connect(_on_control_exited.bind(button))
		button.focus_exited.connect(_on_control_exited.bind(button))
		if button is Button:
			(button as Button).pressed.connect(_pulse_control.bind(button, PRESS_SCALE))


func _on_control_hovered(control: Control) -> void:
	_pulse_control(control, HOVER_SCALE)


func _on_control_exited(control: Control) -> void:
	_reset_control_scale(control)


func _pulse_control(control: Control, target_scale: float) -> void:
	if control == null or _root == null:
		return

	control.pivot_offset = control.size * 0.5
	var tween := _root.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(control, "scale", Vector2.ONE * target_scale, 0.06).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if is_equal_approx(target_scale, PRESS_SCALE):
		tween.tween_property(control, "scale", Vector2.ONE, 0.08)


func _reset_control_scale(control: Control) -> void:
	if control == null or _root == null:
		return

	control.pivot_offset = control.size * 0.5
	var tween := _root.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(control, "scale", Vector2.ONE, 0.07).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
