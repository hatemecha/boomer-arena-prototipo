class_name ArenaMenuCamera
extends Camera3D

enum Preset {
	EXTERIOR,
	INTERIOR,
}

@export var camera_preset: Preset = Preset.INTERIOR
@export_range(8.0, 40.0, 0.5) var orbit_radius: float = 24.0
@export_range(2.0, 16.0, 0.25) var orbit_height: float = 7.5
@export_range(0.0, 6.0, 0.1) var look_height: float = 1.8
@export_range(0.02, 0.35, 0.01) var orbit_speed: float = 0.11
@export_range(60.0, 110.0, 1.0) var menu_fov: float = 88.0

@export_range(4.0, 20.0, 0.5) var interior_radius: float = 10.0
@export_range(1.0, 8.0, 0.25) var interior_height: float = 3.5
@export_range(0.0, 4.0, 0.1) var interior_look_height: float = 1.5

var _orbit_angle: float = 0.85
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

	var speed: float = orbit_speed
	if camera_preset == Preset.INTERIOR:
		speed *= 0.35
	_orbit_angle += speed * delta
	_apply_orbit_transform()


func _snap_to_orbit() -> void:
	_apply_orbit_transform()


func _apply_orbit_transform() -> void:
	var radius: float = orbit_radius
	var height: float = orbit_height
	var target_height: float = look_height
	if camera_preset == Preset.INTERIOR:
		radius = interior_radius
		height = interior_height
		target_height = interior_look_height

	var look_target := Vector3(0.0, target_height, 0.0)
	global_position = Vector3(
		cos(_orbit_angle) * radius,
		height,
		sin(_orbit_angle) * radius
	)
	look_at(look_target, Vector3.UP)
