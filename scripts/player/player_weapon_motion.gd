class_name PlayerWeaponMotion
extends RefCounted

const HOLD_MODE_DOOM: int = 1
const MIN_SPEED_DENOMINATOR: float = 0.001
const MAX_WEAPON_OFFSET_IDLE: float = 0.3
const MAX_WEAPON_OFFSET_AIM: float = 0.2
const RELOAD_MOTION_DAMP: float = 0.12
const FIRE_KICK_DECAY_SPEED: float = 22.0
const MAX_FIRE_KICK_POSITION: float = 0.22
const MAX_FIRE_KICK_ROTATION: float = 0.42

var _sway_position: Vector3 = Vector3.ZERO
var _sway_rotation: Vector3 = Vector3.ZERO
var _velocity_sway: Vector3 = Vector3.ZERO
var _fire_kick_position: Vector3 = Vector3.ZERO
var _fire_kick_rotation: Vector3 = Vector3.ZERO
var _previous_yaw: float = 0.0
var _previous_pitch: float = 0.0


func reset(yaw_radians: float, pitch_degrees: float) -> void:
	_sway_position = Vector3.ZERO
	_sway_rotation = Vector3.ZERO
	_velocity_sway = Vector3.ZERO
	_fire_kick_position = Vector3.ZERO
	_fire_kick_rotation = Vector3.ZERO
	_previous_yaw = yaw_radians
	_previous_pitch = pitch_degrees


func apply_fire_kick(active_weapon: WeaponBase) -> void:
	if active_weapon == null:
		return

	var kick_strength: float = active_weapon.recoil_degrees * active_weapon.weapon_kick_scale
	var impulse_position := Vector3(
		randf_range(-1.0, 1.0) * kick_strength * 0.0035,
		kick_strength * 0.0065,
		kick_strength * 0.019
	)
	var impulse_rotation := Vector3(
		-deg_to_rad(kick_strength * 1.35),
		randf_range(-1.0, 1.0) * deg_to_rad(kick_strength * 0.18),
		randf_range(-1.0, 1.0) * deg_to_rad(kick_strength * 0.42)
	)

	_fire_kick_position += impulse_position
	_fire_kick_rotation += impulse_rotation

	if _fire_kick_position.length() > MAX_FIRE_KICK_POSITION:
		_fire_kick_position = _fire_kick_position.normalized() * MAX_FIRE_KICK_POSITION
	_fire_kick_rotation.x = clampf(_fire_kick_rotation.x, -MAX_FIRE_KICK_ROTATION, MAX_FIRE_KICK_ROTATION)
	_fire_kick_rotation.y = clampf(_fire_kick_rotation.y, -MAX_FIRE_KICK_ROTATION * 0.35, MAX_FIRE_KICK_ROTATION * 0.35)
	_fire_kick_rotation.z = clampf(_fire_kick_rotation.z, -MAX_FIRE_KICK_ROTATION * 0.55, MAX_FIRE_KICK_ROTATION * 0.55)


func apply_motion(player, active_weapon: WeaponBase, base_transform: Transform3D, delta: float) -> Transform3D:
	if player == null:
		return base_transform

	var smoothing_weight: float = 1.0 - exp(-player.weapon_sway_smoothing * delta)
	var view_delta: Vector2 = _consume_view_delta(player)

	var local_velocity: Vector3 = player.global_transform.basis.inverse() * player.velocity
	_velocity_sway = _velocity_sway.lerp(local_velocity, smoothing_weight)

	var movement_factors: Vector3 = _get_movement_factors(player)
	var target_position: Vector3 = Vector3.ZERO
	var target_rotation: Vector3 = Vector3.ZERO
	if _should_apply_weapon_motion(player):
		target_position = _calculate_target_position(player, view_delta, movement_factors.x, movement_factors.y, movement_factors.z)
		target_rotation = _calculate_target_rotation(player, view_delta, movement_factors.x, movement_factors.y)
		var combined_scale: float = _get_weapon_motion_scale(player) * _get_reload_motion_damp(active_weapon)
		target_position = _clamp_target_position(player, target_position * combined_scale)
		target_rotation = _clamp_target_rotation(target_rotation * combined_scale)

	_sway_position = _sway_position.lerp(target_position, smoothing_weight)
	_sway_rotation = _sway_rotation.lerp(target_rotation, smoothing_weight)
	_decay_fire_kick(delta)

	return _build_weapon_transform(base_transform, active_weapon)


func align_muzzle_lateral_to_crosshair(player, base_transform: Transform3D, active_weapon: WeaponBase) -> Transform3D:
	if player == null or active_weapon == null:
		return base_transform

	var muzzle: Node3D = active_weapon.get_node_or_null("MuzzleFlash") as Node3D
	if muzzle == null:
		return base_transform

	var muzzle_camera_local: Vector3 = base_transform * muzzle.transform.origin
	var corrected_origin: Vector3 = base_transform.origin
	corrected_origin.x += player.weapon_crosshair_lateral_offset - muzzle_camera_local.x
	var aligned_transform := Transform3D(base_transform.basis, corrected_origin)

	if int(player.weapon_hold_mode) == HOLD_MODE_DOOM or player.align_weapon_muzzle_to_crosshair:
		return aligned_transform

	return base_transform.interpolate_with(aligned_transform, player.get_aim_blend())


func _consume_view_delta(player) -> Vector2:
	var yaw_delta_degrees: float = rad_to_deg(wrapf(player.rotation.y - _previous_yaw, -PI, PI))
	var pitch_degrees: float = player.get_camera_pitch_degrees()
	var pitch_delta_degrees: float = pitch_degrees - _previous_pitch
	_previous_yaw = player.rotation.y
	_previous_pitch = pitch_degrees
	return Vector2(yaw_delta_degrees, pitch_delta_degrees)


func _should_apply_weapon_motion(player) -> bool:
	return player.weapon_motion_enabled and player.is_gameplay_input_enabled() and player.is_alive()


func _get_movement_factors(player) -> Vector3:
	var max_speed: float = maxf(player.run_speed, MIN_SPEED_DENOMINATOR)
	var motion_blend: float = lerpf(0.72, 1.0, player.get_bob_blend())
	var strafe_factor: float = clampf(_velocity_sway.x / max_speed, -1.0, 1.0) * motion_blend
	var forward_factor: float = clampf(-_velocity_sway.z / max_speed, -1.0, 1.0) * motion_blend
	var vertical_factor: float = clampf(absf(player.velocity.y) / maxf(player.jump_velocity, MIN_SPEED_DENOMINATOR), 0.0, 1.0)
	return Vector3(strafe_factor, forward_factor, vertical_factor)


func _calculate_target_position(player, view_delta: Vector2, strafe_factor: float, forward_factor: float, vertical_factor: float) -> Vector3:
	var target_position := Vector3.ZERO
	target_position.x += -strafe_factor * player.weapon_movement_sway_amount
	target_position.z += forward_factor * player.weapon_movement_sway_amount * (0.9 if forward_factor >= 0.0 else 0.55)
	target_position.x += view_delta.x * player.weapon_sway_amount * 0.032
	target_position.y += view_delta.y * player.weapon_sway_amount * 0.022
	if forward_factor >= 0.0:
		target_position.y -= forward_factor * player.weapon_movement_sway_amount * 0.55
	else:
		target_position.y += -forward_factor * player.weapon_movement_sway_amount * 0.35
	if not player.is_on_floor():
		target_position.y -= player.weapon_jump_drop * vertical_factor
	if player.landing_camera_dip > 0.0 and player.get_landing_offset() > 0.0:
		target_position.y -= player.weapon_landing_kick * clampf(player.get_landing_offset() / player.landing_camera_dip, 0.0, 1.0)
	return target_position


func _calculate_target_rotation(player, view_delta: Vector2, strafe_factor: float, forward_factor: float) -> Vector3:
	var target_rotation := Vector3.ZERO
	target_rotation.x += view_delta.y * player.weapon_rotation_sway_amount * 0.34
	target_rotation.y += -view_delta.x * player.weapon_rotation_sway_amount * 0.38
	target_rotation.z += view_delta.x * player.weapon_rotation_sway_amount * 0.55
	target_rotation.z += -strafe_factor * player.weapon_rotation_sway_amount * 1.2
	target_rotation.x += forward_factor * player.weapon_rotation_sway_amount * 0.48
	return target_rotation


func _get_reload_motion_damp(active_weapon: WeaponBase) -> float:
	if active_weapon != null and active_weapon.is_reloading():
		return RELOAD_MOTION_DAMP
	return 1.0


func _clamp_target_position(player, target_position: Vector3) -> Vector3:
	var max_weapon_offset: float = lerpf(MAX_WEAPON_OFFSET_IDLE, MAX_WEAPON_OFFSET_AIM, player.get_aim_blend())
	if target_position.length() > max_weapon_offset:
		return target_position.normalized() * max_weapon_offset
	return target_position


func _clamp_target_rotation(target_rotation: Vector3) -> Vector3:
	target_rotation.x = clampf(target_rotation.x, -0.32, 0.32)
	target_rotation.y = clampf(target_rotation.y, -0.28, 0.28)
	target_rotation.z = clampf(target_rotation.z, -0.34, 0.34)
	return target_rotation


func _decay_fire_kick(delta: float) -> void:
	var decay: float = exp(-FIRE_KICK_DECAY_SPEED * delta)
	_fire_kick_position *= decay
	_fire_kick_rotation *= decay


func _build_weapon_transform(base_transform: Transform3D, active_weapon: WeaponBase) -> Transform3D:
	var combined_rotation: Vector3 = _sway_rotation + _fire_kick_rotation
	var combined_position: Vector3 = _sway_position + _fire_kick_position
	var motion_basis: Basis = base_transform.basis * Basis.from_euler(combined_rotation)
	var motion_origin: Vector3 = base_transform.origin + base_transform.basis * combined_position
	if active_weapon == null:
		return Transform3D(motion_basis, motion_origin)

	motion_origin += base_transform.basis * active_weapon.reload_anim_position
	var reload_rotation_radians := Vector3(
		deg_to_rad(active_weapon.reload_anim_rotation.x),
		deg_to_rad(active_weapon.reload_anim_rotation.y),
		deg_to_rad(active_weapon.reload_anim_rotation.z)
	)
	return Transform3D(motion_basis * Basis.from_euler(reload_rotation_radians), motion_origin)


func _get_weapon_motion_scale(player) -> float:
	var motion_scale: float = 1.0
	if player.should_use_run_fov():
		motion_scale *= player.weapon_run_sway_multiplier
	if player.is_crouching():
		motion_scale *= player.weapon_crouch_sway_multiplier

	var aim_scale: float = player.weapon_aim_sway_multiplier
	if player.is_aiming() and player.get_horizontal_speed() > 0.35:
		aim_scale = maxf(aim_scale, player.weapon_aim_move_sway_multiplier)
	return lerpf(motion_scale, aim_scale, player.get_aim_blend())
