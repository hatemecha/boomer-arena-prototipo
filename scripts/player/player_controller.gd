class_name PlayerController
extends CharacterBody3D

signal debug_stats_changed(world_position: Vector3, speed: float)
signal active_weapon_changed(weapon: WeaponBase)
signal damaged(amount: int)
signal died
signal respawned
signal weapon_fired(weapon_name: String)
signal local_view_motion_changed(view_delta: Vector2, local_velocity: Vector2)

@export_range(1.0, 30.0) var walk_speed: float = 7.5
@export_range(1.0, 40.0) var run_speed: float = 12.5
@export_range(1.0, 30.0) var jump_velocity: float = 7.8
@export_range(0.1, 80.0) var ground_acceleration: float = 52.0
@export_range(0.1, 40.0) var air_acceleration: float = 16.0
@export_range(0.1, 60.0) var friction: float = 24.0
@export_range(0.01, 1.0) var mouse_sensitivity: float = 0.25
@export_range(60.0, 120.0) var fov: float = 90.0
@export_range(45.0, 100.0) var aim_fov: float = 60.0
@export_range(1.0, 40.0) var aim_enter_speed: float = 14.0
@export_range(1.0, 40.0) var aim_exit_speed: float = 10.0
@export_range(0.1, 1.0) var aim_mouse_sensitivity_multiplier: float = 0.55
@export_range(0.02, 0.25) var aim_sight_depth: float = 0.065
@export var aim_weapon_position: Vector3 = Vector3(0.0, -0.22, -0.4)
@export var aim_view_offset: Vector3 = Vector3.ZERO
@export var double_jump_enabled: bool = true
@export_range(0, 8) var max_air_jumps: int = 1
@export var wall_jump_enabled: bool = true
@export_range(0.1, 3.0) var wall_check_distance: float = 0.75
@export_range(1.0, 30.0) var wall_jump_up_velocity: float = 8.4
@export_range(1.0, 35.0) var wall_jump_push_velocity: float = 11.0
@export_range(0.0, 20.0) var wall_jump_forward_boost: float = 2.5
@export_range(0.0, 1.0) var wall_jump_air_control_lock_time: float = 0.12
@export_range(0.0, 1.0) var wall_jump_air_control_multiplier: float = 0.25
@export_range(0.0, 1.0) var wall_jump_cooldown: float = 0.18
@export_range(0.0, 1.0) var wall_jump_coyote_time: float = 0.12
@export_range(0.0, 1.0) var wall_jump_min_air_time: float = 0.05
@export_range(0.0, 1.0) var wall_jump_camera_kick: float = 0.035
@export var player_id: int = 1
@export var display_name: String = "Player"
@export var input_prefix: String = ""
@export var mouse_look_enabled: bool = true
@export_range(0.2, 8.0) var gamepad_look_sensitivity: float = 3.0
@export_range(0.0, 5.0) var respawn_invulnerability_time: float = 1.0
@export_range(1.0, 40.0) var network_interpolation_speed: float = 18.0
@export_range(0.5, 20.0) var network_snap_distance: float = 6.0
@export var crouch_enabled: bool = true
@export_range(0.2, 2.0) var crouch_height_multiplier: float = 0.55
@export_range(1.0, 20.0) var crouch_speed: float = 4.5
@export_range(1.0, 30.0) var crouch_transition_speed: float = 12.0
@export_range(0.0, 1.0) var crouch_camera_drop: float = 0.45
@export var camera_motion_enabled: bool = true
@export_range(0.0, 3.0) var walk_bob_amount: float = 0.035
@export_range(0.0, 3.0) var run_bob_amount: float = 0.065
@export_range(0.0, 20.0) var bob_frequency: float = 8.0
@export_range(0.0, 20.0) var run_fov_boost: float = 5.0
@export_range(1.0, 30.0) var fov_transition_speed: float = 10.0
@export_range(0.0, 0.2) var landing_camera_dip: float = 0.06
@export var weapon_motion_enabled: bool = true
@export_range(0.0, 1.0) var weapon_sway_amount: float = 0.06
@export_range(0.0, 1.0) var weapon_rotation_sway_amount: float = 0.035
@export_range(0.0, 1.0) var weapon_movement_sway_amount: float = 0.045
@export_range(0.1, 3.0) var weapon_run_sway_multiplier: float = 1.45
@export_range(0.0, 1.0) var weapon_crouch_sway_multiplier: float = 0.45
@export_range(0.0, 1.0) var weapon_aim_sway_multiplier: float = 0.12
@export_range(1.0, 30.0) var weapon_sway_smoothing: float = 13.0
@export_range(0.0, 0.2) var weapon_jump_drop: float = 0.045
@export_range(0.0, 0.2) var weapon_landing_kick: float = 0.055
@export var hide_body_for_local_player: bool = true

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/PlayerCamera
@onready var health: PlayerHealth = $PlayerHealth
@onready var body_mesh: MeshInstance3D = $BodyMesh
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var weapon: WeaponBase

var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
var _pitch_degrees: float = 0.0
var _air_jumps_used: int = 0
var _weapons: Array[WeaponBase] = []
var _weapon_default_transforms: Dictionary = {}
var _active_weapon_index: int = -1
var _is_dead: bool = false
var _gameplay_input_enabled: bool = true
var _local_control_enabled: bool = true
var _is_invulnerable: bool = false
var last_damage_source_player_id: int = 0
var _is_aiming: bool = false
var _aim_blend: float = 0.0
var _has_network_target: bool = false
var _network_target_position: Vector3 = Vector3.ZERO
var _network_target_yaw: float = 0.0
var _network_target_pitch_degrees: float = 0.0
var _network_target_velocity: Vector3 = Vector3.ZERO
var _network_target_is_crouching: bool = false
var _is_crouching: bool = false
var _crouch_blend: float = 0.0
var _standing_collision_height: float = 0.0
var _crouching_collision_height: float = 0.0
var _standing_collision_position: Vector3 = Vector3.ZERO
var _standing_camera_pivot_position: Vector3 = Vector3.ZERO
var _standing_body_position: Vector3 = Vector3.ZERO
var _standing_body_scale: Vector3 = Vector3.ONE
var _bob_time: float = 0.0
var _landing_offset: float = 0.0
var _was_on_floor: bool = false
var _wall_jump_cooldown_timer: float = 0.0
var _wall_jump_air_control_lock_timer: float = 0.0
var _air_time: float = 0.0
var _last_wall_normal: Vector3 = Vector3.ZERO
var _last_wall_contact_time: float = -999.0
var _last_wall_jump_normal: Vector3 = Vector3.ZERO
var _has_left_wall_since_last_jump: bool = true
var _wall_jump_camera_kick_offset: Vector3 = Vector3.ZERO
var _weapon_sway_position: Vector3 = Vector3.ZERO
var _weapon_sway_rotation: Vector3 = Vector3.ZERO
var _previous_yaw: float = 0.0
var _previous_pitch: float = 0.0
var _weapon_velocity_sway: Vector3 = Vector3.ZERO
var _last_view_delta: Vector2 = Vector2.ZERO


func _ready() -> void:
	DefaultInputActions.ensure_default_actions()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera.fov = fov
	_cache_standing_pose()
	_collect_weapons()
	_set_active_weapon(0)
	_update_body_visibility()
	health.died.connect(_on_health_died)
	_previous_yaw = rotation.y
	_previous_pitch = _pitch_degrees


func _input(event: InputEvent) -> void:
	if not _is_locally_controlled() or not _gameplay_input_enabled:
		return

	if mouse_look_enabled and event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var is_aiming_now: bool = not _is_dead and weapon != null and Input.is_action_pressed(_action("aim"))
		var effective_sensitivity: float = mouse_sensitivity
		if is_aiming_now:
			effective_sensitivity *= aim_mouse_sensitivity_multiplier
		rotate_y(deg_to_rad(-event.relative.x * effective_sensitivity))
		_pitch_degrees = clampf(_pitch_degrees - event.relative.y * effective_sensitivity, -88.0, 88.0)
		camera_pivot.rotation_degrees.x = _pitch_degrees
		_last_view_delta += event.relative

	if event.is_action_pressed(_action("fire")):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if event.is_action_pressed(_action("aim")):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	if not _is_locally_controlled():
		_update_remote_interpolation(delta)
		_update_crouch_visual(delta)
		return

	_is_aiming = _gameplay_input_enabled and not _is_dead and weapon != null and Input.is_action_pressed(_action("aim"))
	if weapon != null:
		weapon.is_aiming = _is_aiming
	_update_aim_state(delta)
	_update_crouch_visual(delta)
	_update_camera_motion(delta)


func _physics_process(delta: float) -> void:
	if not _is_locally_controlled():
		return

	if _is_dead:
		return

	_handle_gamepad_look(delta)
	_handle_movement(delta)
	if _gameplay_input_enabled:
		_handle_weapon_input()
	_emit_local_view_motion()
	debug_stats_changed.emit(global_position, Vector2(velocity.x, velocity.z).length())


func add_ammo(amount: int) -> bool:
	if weapon == null:
		push_error("Player has no active weapon to receive ammo.")
		return false
	return weapon.add_ammo(amount)


func heal(amount: int) -> bool:
	return health.heal(amount)


func is_crouching() -> bool:
	return _is_crouching


func apply_damage(amount: int, attacker_player_id: int = 0) -> void:
	if _is_invulnerable:
		return
	var health_before_damage: int = health.current_health
	last_damage_source_player_id = attacker_player_id
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


func set_local_control_enabled(value: bool) -> void:
	_local_control_enabled = value
	if camera != null:
		camera.current = value
	_update_body_visibility()
	set_gameplay_input_enabled(value)


func respawn_at(spawn_position: Vector3, yaw_radians: float = 0.0) -> void:
	global_position = spawn_position
	rotation.y = yaw_radians
	velocity = Vector3.ZERO
	_pitch_degrees = 0.0
	camera_pivot.rotation_degrees.x = 0.0
	camera_pivot.position = _standing_camera_pivot_position
	camera.position = Vector3.ZERO
	camera.rotation_degrees = Vector3.ZERO
	_is_dead = false
	last_damage_source_player_id = 0
	_air_jumps_used = 0
	_is_crouching = false
	_network_target_is_crouching = false
	_crouch_blend = 0.0
	_landing_offset = 0.0
	_air_time = 0.0
	_wall_jump_cooldown_timer = 0.0
	_wall_jump_air_control_lock_timer = 0.0
	_last_wall_normal = Vector3.ZERO
	_last_wall_contact_time = -999.0
	_last_wall_jump_normal = Vector3.ZERO
	_has_left_wall_since_last_jump = true
	_wall_jump_camera_kick_offset = Vector3.ZERO
	_weapon_sway_position = Vector3.ZERO
	_weapon_sway_rotation = Vector3.ZERO
	_weapon_velocity_sway = Vector3.ZERO
	_previous_yaw = rotation.y
	_previous_pitch = _pitch_degrees
	_last_view_delta = Vector2.ZERO
	_apply_crouch_collision(0.0)
	health.respawn()
	_start_respawn_invulnerability()
	respawned.emit()


func apply_network_state(
	next_position: Vector3,
	yaw_radians: float,
	pitch_degrees: float,
	next_velocity: Vector3,
	is_dead_state: bool,
	is_crouching_state: bool = false
) -> void:
	_network_target_position = next_position
	_network_target_yaw = yaw_radians
	_network_target_pitch_degrees = clampf(pitch_degrees, -88.0, 88.0)
	_network_target_velocity = next_velocity
	_network_target_is_crouching = is_crouching_state
	_has_network_target = true

	if not _is_locally_controlled():
		_is_crouching = is_crouching_state
		if global_position.distance_to(next_position) > network_snap_distance:
			_apply_network_state_immediately(next_position, yaw_radians, _network_target_pitch_degrees, next_velocity)
		if _is_dead != is_dead_state:
			set_dead(is_dead_state)
		return

	_apply_network_state_immediately(next_position, yaw_radians, _network_target_pitch_degrees, next_velocity)
	_is_crouching = is_crouching_state
	if _is_dead != is_dead_state:
		set_dead(is_dead_state)


func _apply_network_state_immediately(
	next_position: Vector3,
	yaw_radians: float,
	pitch_degrees: float,
	next_velocity: Vector3
) -> void:
	global_position = next_position
	rotation.y = yaw_radians
	velocity = next_velocity
	_pitch_degrees = clampf(pitch_degrees, -88.0, 88.0)
	if camera_pivot != null:
		camera_pivot.rotation_degrees.x = _pitch_degrees


func apply_network_health(
	current_health: int,
	max_health: int,
	is_dead_state: bool,
	damage_source_player_id: int = 0
) -> void:
	if health == null:
		return

	health.max_health = maxi(max_health, 1)
	health.current_health = clampi(current_health, 0, health.max_health)
	health.is_dead = is_dead_state
	last_damage_source_player_id = damage_source_player_id
	if _is_dead != is_dead_state:
		set_dead(is_dead_state)
	health.health_changed.emit(health.current_health, health.max_health)


func set_dead(value: bool) -> void:
	_is_dead = value
	_is_aiming = false
	_aim_blend = 0.0
	if weapon != null:
		weapon.is_aiming = false
	velocity = Vector3.ZERO


func set_body_color(color: Color) -> void:
	if body_mesh == null:
		return

	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	body_mesh.material_override = material


func _handle_movement(delta: float) -> void:
	var was_on_floor_before_move: bool = is_on_floor()
	var input_direction: Vector2 = _get_move_input()
	_update_wall_jump_timers(delta, was_on_floor_before_move)
	var wall_normal: Vector3 = _find_wall_normal()
	_update_crouch_state()
	var wants_sprint: bool = Input.is_action_pressed(_action("sprint")) and not _is_crouching
	var target_speed: float = run_speed if wants_sprint else walk_speed
	if _is_crouching:
		target_speed = crouch_speed
	var target_velocity: Vector3 = (global_transform.basis * Vector3(input_direction.x, 0.0, input_direction.y)).normalized() * target_speed
	var acceleration: float = ground_acceleration if is_on_floor() else air_acceleration
	if not is_on_floor() and _wall_jump_air_control_lock_timer > 0.0:
		acceleration *= wall_jump_air_control_multiplier

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

	if Input.is_action_just_pressed(_action("jump")):
		var jump_wall_normal: Vector3 = _get_wall_jump_normal(wall_normal)
		if _can_wall_jump(jump_wall_normal):
			_perform_wall_jump(jump_wall_normal)
		elif _can_jump():
			if not is_on_floor():
				_air_jumps_used += 1
			velocity.y = jump_velocity

	move_and_slide()
	if not was_on_floor_before_move and is_on_floor():
		_landing_offset = landing_camera_dip
	_was_on_floor = is_on_floor()


func _update_wall_jump_timers(delta: float, is_on_floor_now: bool) -> void:
	_wall_jump_cooldown_timer = maxf(_wall_jump_cooldown_timer - delta, 0.0)
	_wall_jump_air_control_lock_timer = maxf(_wall_jump_air_control_lock_timer - delta, 0.0)
	if is_on_floor_now:
		_air_time = 0.0
		_has_left_wall_since_last_jump = true
	else:
		_air_time += delta


func _find_wall_normal() -> Vector3:
	if not wall_jump_enabled or get_world_3d() == null:
		return Vector3.ZERO

	var basis := global_transform.basis
	var directions: Array[Vector3] = [
		-basis.x,
		basis.x,
		-basis.z,
		(-basis.z - basis.x).normalized(),
		(-basis.z + basis.x).normalized()
	]
	var origin: Vector3 = global_position + Vector3.UP * maxf(0.35, _standing_collision_height * 0.55)
	var direct_space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var best_normal: Vector3 = Vector3.ZERO
	var best_distance: float = INF

	for direction in directions:
		if direction.length_squared() <= 0.0001:
			continue

		var query := PhysicsRayQueryParameters3D.create(origin, origin + direction.normalized() * wall_check_distance)
		query.exclude = [get_rid()]
		query.collision_mask = collision_mask
		query.hit_from_inside = false

		var hit: Dictionary = direct_space_state.intersect_ray(query)
		if hit.is_empty():
			continue

		var normal: Vector3 = hit.get("normal", Vector3.ZERO)
		if normal.length_squared() <= 0.0001 or absf(normal.y) >= 0.35:
			continue

		var hit_position: Vector3 = hit.get("position", origin)
		var distance: float = origin.distance_to(hit_position)
		if distance < best_distance:
			best_distance = distance
			best_normal = normal.normalized()

	_update_wall_recontact_state(best_normal)
	if best_normal != Vector3.ZERO:
		_last_wall_normal = best_normal
		_last_wall_contact_time = _get_game_time_seconds()
	return best_normal


func _update_wall_recontact_state(wall_normal: Vector3) -> void:
	if _last_wall_jump_normal == Vector3.ZERO:
		return
	if wall_normal == Vector3.ZERO:
		_has_left_wall_since_last_jump = true
		return
	if wall_normal.normalized().dot(_last_wall_jump_normal.normalized()) < 0.85:
		_has_left_wall_since_last_jump = true


func _get_wall_jump_normal(candidate_normal: Vector3) -> Vector3:
	if candidate_normal != Vector3.ZERO:
		return candidate_normal.normalized()
	if _last_wall_normal == Vector3.ZERO:
		return Vector3.ZERO
	if _get_game_time_seconds() - _last_wall_contact_time > wall_jump_coyote_time:
		return Vector3.ZERO
	return _last_wall_normal.normalized()


func _can_wall_jump(wall_normal: Vector3) -> bool:
	if not wall_jump_enabled or not _gameplay_input_enabled or _is_dead:
		return false
	if is_on_floor() or _air_time < wall_jump_min_air_time:
		return false
	if _wall_jump_cooldown_timer > 0.0 or wall_normal == Vector3.ZERO:
		return false
	if not _has_left_wall_since_last_jump and _is_same_wall_as_last_jump(wall_normal):
		return false
	return true


func _perform_wall_jump(wall_normal: Vector3) -> void:
	var normalized_wall_normal: Vector3 = wall_normal.normalized()
	var forward: Vector3 = -global_transform.basis.z
	var current_horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z) * 0.18
	var push: Vector3 = normalized_wall_normal * wall_jump_push_velocity
	var forward_boost: Vector3 = forward * wall_jump_forward_boost
	var next_horizontal_velocity: Vector3 = push + forward_boost + current_horizontal_velocity

	velocity.x = next_horizontal_velocity.x
	velocity.y = wall_jump_up_velocity
	velocity.z = next_horizontal_velocity.z
	_wall_jump_cooldown_timer = wall_jump_cooldown
	_wall_jump_air_control_lock_timer = wall_jump_air_control_lock_time
	_air_jumps_used = 0
	_last_wall_jump_normal = normalized_wall_normal
	_has_left_wall_since_last_jump = false
	if _is_crouching and _can_stand_up():
		_is_crouching = false
	_apply_wall_jump_camera_kick(normalized_wall_normal)


func _is_same_wall_as_last_jump(wall_normal: Vector3) -> bool:
	return _last_wall_jump_normal != Vector3.ZERO and wall_normal.normalized().dot(_last_wall_jump_normal.normalized()) > 0.85


func _apply_wall_jump_camera_kick(wall_normal: Vector3) -> void:
	if wall_jump_camera_kick <= 0.0:
		return

	var local_wall_normal: Vector3 = global_transform.basis.inverse() * wall_normal
	_wall_jump_camera_kick_offset = Vector3(
		-local_wall_normal.x * wall_jump_camera_kick,
		wall_jump_camera_kick,
		0.0
	)


func _get_game_time_seconds() -> float:
	return float(Time.get_ticks_msec()) / 1000.0


func _get_move_input() -> Vector2:
	return Input.get_vector(_action("move_left"), _action("move_right"), _action("move_forward"), _action("move_back"))


func _can_jump() -> bool:
	if is_on_floor():
		return true
	return double_jump_enabled and _air_jumps_used < max_air_jumps


func _update_crouch_state() -> void:
	if not crouch_enabled or not _gameplay_input_enabled:
		_try_set_crouching(false)
		return

	_try_set_crouching(Input.is_action_pressed(_action("crouch")))


func _try_set_crouching(should_crouch: bool) -> void:
	if should_crouch:
		_is_crouching = true
		return

	if _is_crouching and not _can_stand_up():
		return
	_is_crouching = false


func _can_stand_up() -> bool:
	if collision_shape == null or not (collision_shape.shape is CapsuleShape3D):
		return true

	var standing_shape: CapsuleShape3D = collision_shape.shape.duplicate() as CapsuleShape3D
	standing_shape.height = _standing_collision_height
	var clearance_position: Vector3 = _standing_collision_position + Vector3.UP * 0.04

	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = standing_shape
	query.transform = global_transform * Transform3D(Basis.IDENTITY, clearance_position)
	query.exclude = [get_rid()]
	query.collision_mask = collision_mask
	query.margin = 0.0

	var hits: Array[Dictionary] = get_world_3d().direct_space_state.intersect_shape(query, 1)
	return hits.is_empty()


func _update_crouch_visual(delta: float) -> void:
	var target_blend: float = 1.0 if _is_crouching or _network_target_is_crouching else 0.0
	var transition_weight: float = 1.0 - exp(-crouch_transition_speed * delta)
	_crouch_blend = lerpf(_crouch_blend, target_blend, transition_weight)
	_apply_crouch_collision(_crouch_blend)

	if body_mesh != null:
		body_mesh.position = _standing_body_position.lerp(Vector3(_standing_body_position.x, _standing_body_position.y * crouch_height_multiplier, _standing_body_position.z), _crouch_blend)
		body_mesh.scale = _standing_body_scale.lerp(Vector3(_standing_body_scale.x, _standing_body_scale.y * crouch_height_multiplier, _standing_body_scale.z), _crouch_blend)


func _apply_crouch_collision(blend: float) -> void:
	if collision_shape == null or not (collision_shape.shape is CapsuleShape3D):
		return

	var capsule_shape: CapsuleShape3D = collision_shape.shape as CapsuleShape3D
	capsule_shape.height = lerpf(_standing_collision_height, _crouching_collision_height, blend)
	collision_shape.position = _standing_collision_position.lerp(
		Vector3(_standing_collision_position.x, _crouching_collision_height * 0.5, _standing_collision_position.z),
		blend
	)


func _update_camera_motion(delta: float) -> void:
	if camera_pivot == null or camera == null:
		return

	var horizontal_speed: float = _get_horizontal_speed()
	var is_moving: bool = horizontal_speed > 0.1 and is_on_floor() and _gameplay_input_enabled and not _is_dead
	var is_running: bool = Input.is_action_pressed(_action("sprint")) and not _is_crouching and horizontal_speed > walk_speed + 0.25
	var crouch_offset: float = crouch_camera_drop * _crouch_blend
	var bob_offset := Vector3.ZERO

	if camera_motion_enabled and is_moving:
		var bob_amount: float = run_bob_amount if is_running else walk_bob_amount
		var frequency: float = bob_frequency * (1.2 if is_running else 1.0)
		_bob_time += delta * frequency
		bob_offset.y = sin(_bob_time * TAU) * bob_amount
		bob_offset.x = cos(_bob_time * TAU * 0.5) * bob_amount * 0.35
	else:
		_bob_time = 0.0

	_landing_offset = move_toward(_landing_offset, 0.0, delta * 0.45)
	_wall_jump_camera_kick_offset = _wall_jump_camera_kick_offset.move_toward(Vector3.ZERO, delta * maxf(wall_jump_camera_kick * 12.0, 0.05))
	camera_pivot.position = _standing_camera_pivot_position + bob_offset + _wall_jump_camera_kick_offset - Vector3(0.0, crouch_offset + _landing_offset, 0.0)


func _get_horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func _get_local_horizontal_velocity() -> Vector2:
	var local_velocity: Vector3 = global_transform.basis.inverse() * velocity
	return Vector2(local_velocity.x, -local_velocity.z)


func _emit_local_view_motion() -> void:
	if not _is_locally_controlled():
		return

	local_view_motion_changed.emit(_last_view_delta, _get_local_horizontal_velocity())
	_last_view_delta = Vector2.ZERO


func _handle_weapon_input() -> void:
	if Input.is_action_just_pressed(_action("weapon_1")):
		_set_active_weapon(0)
	if Input.is_action_just_pressed(_action("weapon_2")):
		_set_active_weapon(1)

	if weapon == null:
		return

	if Input.is_action_pressed(_action("fire")):
		weapon.try_fire(camera)
	if Input.is_action_just_pressed(_action("reload")):
		weapon.reload()


func _handle_gamepad_look(delta: float) -> void:
	if mouse_look_enabled or not _gameplay_input_enabled:
		return

	var look_direction: Vector2 = Input.get_vector(_action("look_left"), _action("look_right"), _action("look_up"), _action("look_down"))
	if look_direction.length_squared() <= 0.0001:
		return

	var effective_sensitivity: float = gamepad_look_sensitivity
	if _is_aiming:
		effective_sensitivity *= aim_mouse_sensitivity_multiplier
	rotate_y(-look_direction.x * effective_sensitivity * delta)
	_pitch_degrees = clampf(_pitch_degrees - look_direction.y * effective_sensitivity * 55.0 * delta, -88.0, 88.0)
	camera_pivot.rotation_degrees.x = _pitch_degrees
	_last_view_delta += look_direction * effective_sensitivity * 180.0 * delta


func _collect_weapons() -> void:
	_weapons.clear()
	_weapon_default_transforms.clear()
	for child in camera.get_children():
		if child is WeaponBase:
			_weapons.append(child)
			_weapon_default_transforms[child] = child.transform


func _cache_standing_pose() -> void:
	if camera_pivot != null:
		_standing_camera_pivot_position = camera_pivot.position
	if body_mesh != null:
		_standing_body_position = body_mesh.position
		_standing_body_scale = body_mesh.scale
	if collision_shape == null or not (collision_shape.shape is CapsuleShape3D):
		return

	collision_shape.shape = collision_shape.shape.duplicate()
	var capsule_shape: CapsuleShape3D = collision_shape.shape as CapsuleShape3D
	_standing_collision_height = capsule_shape.height
	_crouching_collision_height = maxf(capsule_shape.radius * 2.0, _standing_collision_height * crouch_height_multiplier)
	_standing_collision_position = collision_shape.position


func _update_body_visibility() -> void:
	if body_mesh == null:
		return
	body_mesh.visible = not (hide_body_for_local_player and _is_locally_controlled())


func _set_active_weapon(index: int) -> void:
	if index < 0 or index >= _weapons.size() or index == _active_weapon_index:
		return

	if weapon != null and weapon.fired.is_connected(_on_weapon_fired):
		weapon.fired.disconnect(_on_weapon_fired)
		weapon.is_aiming = false
		if _weapon_default_transforms.has(weapon):
			weapon.transform = _weapon_default_transforms[weapon]

	_aim_blend = 0.0
	_weapon_sway_position = Vector3.ZERO
	_weapon_sway_rotation = Vector3.ZERO
	_weapon_velocity_sway = Vector3.ZERO
	_previous_yaw = rotation.y
	_previous_pitch = _pitch_degrees
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
	var movement_fov: float = fov + run_fov_boost if _should_use_run_fov() else fov
	var target_fov: float = lerpf(movement_fov, aim_fov, _aim_blend)
	var fov_weight: float = 1.0 - exp(-fov_transition_speed * delta)
	camera.fov = lerpf(camera.fov, target_fov, fov_weight)

	if weapon == null:
		return

	var default_transform: Transform3D = _weapon_default_transforms.get(weapon, weapon.transform)
	var aim_transform: Transform3D = _build_aim_transform(weapon, default_transform)
	var base_transform: Transform3D = default_transform.interpolate_with(aim_transform, _aim_blend)
	weapon.transform = _calculate_weapon_motion(delta, base_transform)


func _calculate_weapon_motion(delta: float, base_transform: Transform3D) -> Transform3D:
	var smoothing_weight: float = 1.0 - exp(-weapon_sway_smoothing * delta)
	var yaw_delta_degrees: float = rad_to_deg(wrapf(rotation.y - _previous_yaw, -PI, PI))
	var pitch_delta_degrees: float = _pitch_degrees - _previous_pitch
	_previous_yaw = rotation.y
	_previous_pitch = _pitch_degrees

	var local_velocity: Vector3 = global_transform.basis.inverse() * velocity
	_weapon_velocity_sway = _weapon_velocity_sway.lerp(local_velocity, smoothing_weight)

	var target_position := Vector3.ZERO
	var target_rotation := Vector3.ZERO
	if weapon_motion_enabled and _gameplay_input_enabled and not _is_dead:
		var max_speed: float = maxf(run_speed, 0.001)
		var strafe_factor: float = clampf(_weapon_velocity_sway.x / max_speed, -1.0, 1.0)
		var forward_factor: float = clampf(-_weapon_velocity_sway.z / max_speed, -1.0, 1.0)
		var vertical_factor: float = clampf(absf(velocity.y) / maxf(jump_velocity, 0.001), 0.0, 1.0)
		var motion_scale: float = _get_weapon_motion_scale()

		target_position.x += -strafe_factor * weapon_movement_sway_amount
		target_position.z += forward_factor * weapon_movement_sway_amount * (0.75 if forward_factor >= 0.0 else 0.45)
		target_position.x += yaw_delta_degrees * weapon_sway_amount * 0.018
		target_position.y += pitch_delta_degrees * weapon_sway_amount * 0.012
		if forward_factor >= 0.0:
			target_position.y -= forward_factor * weapon_movement_sway_amount * 0.4
		else:
			target_position.y += -forward_factor * weapon_movement_sway_amount * 0.25
		if not is_on_floor():
			target_position.y -= weapon_jump_drop * vertical_factor
		if landing_camera_dip > 0.0 and _landing_offset > 0.0:
			target_position.y -= weapon_landing_kick * clampf(_landing_offset / landing_camera_dip, 0.0, 1.0)

		target_rotation.x += pitch_delta_degrees * weapon_rotation_sway_amount * 0.22
		target_rotation.y += -yaw_delta_degrees * weapon_rotation_sway_amount * 0.24
		target_rotation.z += yaw_delta_degrees * weapon_rotation_sway_amount * 0.35
		target_rotation.z += -strafe_factor * weapon_rotation_sway_amount * 0.8
		target_rotation.x += forward_factor * weapon_rotation_sway_amount * 0.35

		target_position *= motion_scale
		target_rotation *= motion_scale
		if target_position.length() > 0.16:
			target_position = target_position.normalized() * 0.16
		target_rotation.x = clampf(target_rotation.x, -0.18, 0.18)
		target_rotation.y = clampf(target_rotation.y, -0.16, 0.16)
		target_rotation.z = clampf(target_rotation.z, -0.18, 0.18)

	_weapon_sway_position = _weapon_sway_position.lerp(target_position, smoothing_weight)
	_weapon_sway_rotation = _weapon_sway_rotation.lerp(target_rotation, smoothing_weight)

	var motion_basis: Basis = base_transform.basis * Basis.from_euler(_weapon_sway_rotation)
	var motion_origin: Vector3 = base_transform.origin + base_transform.basis * _weapon_sway_position
	return Transform3D(motion_basis, motion_origin)


func _get_weapon_motion_scale() -> float:
	var motion_scale: float = 1.0
	if _should_use_run_fov():
		motion_scale *= weapon_run_sway_multiplier
	if _is_crouching:
		motion_scale *= weapon_crouch_sway_multiplier
	return lerpf(motion_scale, weapon_aim_sway_multiplier, _aim_blend)


func _should_use_run_fov() -> bool:
	if _is_aiming or _is_crouching or not _gameplay_input_enabled or _is_dead:
		return false
	if not Input.is_action_pressed(_action("sprint")):
		return false
	return _get_horizontal_speed() > walk_speed + 0.25


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
	if not _is_locally_controlled():
		return

	var original_position: Vector3 = camera.position
	var tween: Tween = create_tween()
	tween.tween_property(camera, "position", original_position + Vector3(randf_range(-strength, strength), randf_range(-strength, strength), 0.0), duration * 0.35)
	tween.tween_property(camera, "position", original_position, duration * 0.65)


func _update_remote_interpolation(delta: float) -> void:
	if not _has_network_target:
		return

	var interpolation_weight: float = 1.0 - exp(-network_interpolation_speed * delta)
	global_position = global_position.lerp(_network_target_position, interpolation_weight)
	rotation.y = lerp_angle(rotation.y, _network_target_yaw, interpolation_weight)
	velocity = _network_target_velocity
	_pitch_degrees = lerpf(_pitch_degrees, _network_target_pitch_degrees, interpolation_weight)
	if camera_pivot != null:
		camera_pivot.rotation_degrees.x = _pitch_degrees


func _start_respawn_invulnerability() -> void:
	_is_invulnerable = respawn_invulnerability_time > 0.0
	if not _is_invulnerable:
		return

	await get_tree().create_timer(respawn_invulnerability_time).timeout
	_is_invulnerable = false


func _action(base_name: StringName) -> StringName:
	if input_prefix.is_empty():
		return base_name
	return StringName("%s%s" % [input_prefix, base_name])


func _is_locally_controlled() -> bool:
	if not _local_control_enabled:
		return false
	if multiplayer.multiplayer_peer == null:
		return true
	return is_multiplayer_authority()
