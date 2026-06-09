class_name ArenaMenuCamera
extends Camera3D

@export_range(8.0, 40.0, 0.5) var orbit_radius: float = 24.0
@export_range(2.0, 16.0, 0.25) var orbit_height: float = 7.5
@export_range(0.0, 6.0, 0.1) var look_height: float = 1.8
@export_range(0.02, 0.35, 0.01) var orbit_speed: float = 0.11
@export_range(60.0, 110.0, 1.0) var menu_fov: float = 88.0

var _orbit_angle: float = 0.0
var _menu_active: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	fov = menu_fov
	current = false


func set_menu_active(active: bool) -> void:
	_menu_active = active
	current = active
	if active:
		_snap_to_orbit()


func _process(delta: float) -> void:
	if not _menu_active:
		return

	_orbit_angle += orbit_speed * delta
	_apply_orbit_transform()


func _snap_to_orbit() -> void:
	_apply_orbit_transform()


func _apply_orbit_transform() -> void:
	var look_target := Vector3(0.0, look_height, 0.0)
	global_position = Vector3(
		cos(_orbit_angle) * orbit_radius,
		orbit_height,
		sin(_orbit_angle) * orbit_radius
	)
	look_at(look_target, Vector3.UP)
