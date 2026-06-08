class_name PlayerController
extends CharacterBody3D

signal debug_stats_changed(world_position: Vector3, speed: float)
signal active_weapon_changed(weapon: WeaponBase)
signal damaged(amount: int)
signal died
signal respawned
signal weapon_fired(weapon_name: String)

@export_range(1.0, 30.0) var walk_speed: float = 7.5
@export_range(1.0, 40.0) var run_speed: float = 12.5
@export_range(1.0, 30.0) var jump_velocity: float = 7.8
@export_range(0.1, 80.0) var ground_acceleration: float = 52.0
@export_range(0.1, 40.0) var air_acceleration: float = 16.0
@export_range(0.1, 60.0) var friction: float = 24.0
@export_range(0.01, 1.0) var mouse_sensitivity: float = 0.25
@export_range(60.0, 120.0) var fov: float = 95.0
@export_range(45.0, 100.0) var aim_fov: float = 60.0
@export_range(1.0, 40.0) var aim_enter_speed: float = 14.0
@export_range(1.0, 40.0) var aim_exit_speed: float = 10.0
@export_range(0.1, 1.0) var aim_mouse_sensitivity_multiplier: float = 0.55
@export_range(0.02, 0.25) var aim_sight_depth: float = 0.065
@export var aim_weapon_position: Vector3 = Vector3(0.0, -0.22, -0.4)
@export var aim_view_offset: Vector3 = Vector3.ZERO
@export var double_jump_enabled: bool = true
@export_range(0, 8) var max_air_jumps: int = 1
@export var player_id: int = 1
@export var display_name: String = "Player"

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/PlayerCamera
@onready var health: PlayerHealth = $PlayerHealth

var weapon: WeaponBase

var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
var _pitch_degrees: float = 0.0
var _air_jumps_used: int = 0
var _weapons: Array[WeaponBase] = []
var _weapon_default_transforms: Dictionary = {}
var _active_weapon_index: int = -1
var _is_dead: bool = false
var _gameplay_input_enabled: bool = true
var _is_aiming: bool = false
var _aim_blend: float = 0.0


func _ready() -> void:
	DefaultInputActions.ensure_default_actions()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera.fov = fov
	_collect_weapons()
	_set_active_weapon(0)
	health.died.connect(_on_health_died)


func _input(event: InputEvent) -> void:
	if not _gameplay_input_enabled:
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var is_aiming_now: bool = not _is_dead and weapon != null and Input.is_action_pressed("aim")
		var effective_sensitivity: float = mouse_sensitivity
		if is_aiming_now:
			effective_sensitivity *= aim_mouse_sensitivity_multiplier
		rotate_y(deg_to_rad(-event.relative.x * effective_sensitivity))
		_pitch_degrees = clampf(_pitch_degrees - event.relative.y * effective_sensitivity, -88.0, 88.0)
		camera_pivot.rotation_degrees.x = _pitch_degrees

	if event.is_action_pressed("fire"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if event.is_action_pressed("aim"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	_is_aiming = _gameplay_input_enabled and not _is_dead and weapon != null and Input.is_action_pressed("aim")
	if weapon != null:
		weapon.is_aiming = _is_aiming
	_update_aim_state(delta)


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	_handle_movement(delta)
	if _gameplay_input_enabled:
		_handle_weapon_input()
	debug_stats_changed.emit(global_position, Vector2(velocity.x, velocity.z).length())


func add_ammo(amount: int) -> bool:
	if weapon == null:
		push_error("Player has no active weapon to receive ammo.")
		return false
	return weapon.add_ammo(amount)


func heal(amount: int) -> bool:
	return health.heal(amount)


func apply_damage(amount: int) -> void:
	var health_before_damage: int = health.current_health
	health.apply_damage(amount)
	var damage_taken: int = max(health_before_damage - health.current_health, 0)
	if damage_taken > 0:
		damaged.emit(damage_taken)
	if not health.is_dead:
		_shake_camera(0.09, 0.14)


func set_gameplay_input_enabled(value: bool) -> void:
	_gameplay_input_enabled = value
	if value:
		return

	_is_aiming = false
	if weapon != null:
		weapon.is_aiming = false


func respawn_at(spawn_position: Vector3, yaw_radians: float = 0.0) -> void:
	global_position = spawn_position
	rotation.y = yaw_radians
	velocity = Vector3.ZERO
	_pitch_degrees = 0.0
	camera_pivot.rotation_degrees.x = 0.0
	camera.rotation_degrees = Vector3.ZERO
	_is_dead = false
	_air_jumps_used = 0
	health.respawn()
	respawned.emit()


func set_dead(value: bool) -> void:
	_is_dead = value
	_is_aiming = false
	_aim_blend = 0.0
	if weapon != null:
		weapon.is_aiming = false
	velocity = Vector3.ZERO


func _handle_movement(delta: float) -> void:
	var input_direction: Vector2 = _get_move_input()
	var target_speed: float = run_speed if Input.is_action_pressed("sprint") else walk_speed
	var target_velocity: Vector3 = (global_transform.basis * Vector3(input_direction.x, 0.0, input_direction.y)).normalized() * target_speed
	var acceleration: float = ground_acceleration if is_on_floor() else air_acceleration

	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		_air_jumps_used = 0

	if input_direction.length_squared() > 0.0:
		velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * delta)
		velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		velocity.z = move_toward(velocity.z, 0.0, friction * delta)

	if Input.is_action_just_pressed("jump") and _can_jump():
		if not is_on_floor():
			_air_jumps_used += 1
		velocity.y = jump_velocity

	move_and_slide()


func _get_move_input() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_forward", "move_back")


func _can_jump() -> bool:
	if is_on_floor():
		return true
	return double_jump_enabled and _air_jumps_used < max_air_jumps


func _handle_weapon_input() -> void:
	if Input.is_action_just_pressed("weapon_1"):
		_set_active_weapon(0)
	if Input.is_action_just_pressed("weapon_2"):
		_set_active_weapon(1)

	if weapon == null:
		return

	if Input.is_action_pressed("fire"):
		weapon.try_fire(camera)
	if Input.is_action_just_pressed("reload"):
		weapon.reload()


func _collect_weapons() -> void:
	_weapons.clear()
	_weapon_default_transforms.clear()
	for child in camera.get_children():
		if child is WeaponBase:
			_weapons.append(child)
			_weapon_default_transforms[child] = child.transform


func _set_active_weapon(index: int) -> void:
	if index < 0 or index >= _weapons.size() or index == _active_weapon_index:
		return

	if weapon != null and weapon.fired.is_connected(_on_weapon_fired):
		weapon.fired.disconnect(_on_weapon_fired)
		weapon.is_aiming = false

	_aim_blend = 0.0
	_active_weapon_index = index
	weapon = _weapons[index]
	for weapon_index in range(_weapons.size()):
		_weapons[weapon_index].visible = weapon_index == _active_weapon_index

	weapon.fired.connect(_on_weapon_fired)
	active_weapon_changed.emit(weapon)


func _update_aim_state(delta: float) -> void:
	if camera == null:
		return

	var aim_speed: float = aim_enter_speed if _is_aiming else aim_exit_speed
	var transition_weight: float = 1.0 - exp(-aim_speed * delta)
	_aim_blend = lerpf(_aim_blend, 1.0 if _is_aiming else 0.0, transition_weight)
	camera.fov = lerpf(fov, aim_fov, _aim_blend)

	if weapon == null:
		return

	var default_transform: Transform3D = _weapon_default_transforms.get(weapon, weapon.transform)
	var aim_transform: Transform3D = _build_aim_transform(weapon, default_transform)
	weapon.transform = default_transform.interpolate_with(aim_transform, _aim_blend)


func _build_aim_transform(active_weapon: WeaponBase, default_transform: Transform3D) -> Transform3D:
	if active_weapon.has_aim_pose():
		return active_weapon.get_aim_pose_transform()

	var aim_basis: Basis = default_transform.basis
	if not active_weapon.has_aim_sight_alignment():
		return Transform3D(aim_basis, aim_weapon_position)

	var rear_sight: Vector3 = active_weapon.get_aim_sight_local_offset()
	var sight_target: Vector3 = Vector3(0.0, 0.0, -aim_sight_depth)
	var aim_origin: Vector3 = sight_target - (aim_basis * rear_sight)
	if aim_view_offset.length_squared() > 0.0001:
		aim_origin += aim_basis * aim_view_offset

	return Transform3D(aim_basis, aim_origin)


func _on_weapon_fired(fired_weapon: WeaponBase) -> void:
	if fired_weapon == null:
		return

	camera.rotation_degrees.x = -fired_weapon.recoil_degrees
	var tween: Tween = create_tween()
	tween.tween_property(camera, "rotation_degrees:x", 0.0, 0.11)
	weapon_fired.emit(fired_weapon.weapon_name)


func _on_health_died() -> void:
	set_dead(true)
	_shake_camera(0.2, 0.25)
	died.emit()


func _shake_camera(strength: float, duration: float) -> void:
	var original_position: Vector3 = camera.position
	var tween: Tween = create_tween()
	tween.tween_property(camera, "position", original_position + Vector3(randf_range(-strength, strength), randf_range(-strength, strength), 0.0), duration * 0.35)
	tween.tween_property(camera, "position", original_position, duration * 0.65)
