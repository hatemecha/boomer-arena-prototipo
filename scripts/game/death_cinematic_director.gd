class_name DeathCinematicDirector
extends Node

signal finished

const NORMAL_DURATION: float = 1.9
const MATCH_END_DURATION: float = 2.35
const SLOW_MO_SCALE: float = 0.28
const CAMERA_BACK_DISTANCE: float = 2.8
const CAMERA_SIDE_DISTANCE: float = 1.35
const CAMERA_HEIGHT: float = 1.15
const CAMERA_END_LIFT: float = 0.55
const FOCUS_HEIGHT: float = 0.72
const MIN_CLEAR_DISTANCE: float = 0.35
const COLLISION_MARGIN: float = 0.22
const CAMERA_SMOOTHING: float = 9.5

var _arena: Node3D
var _local_player: PlayerController
var _cinematic_camera: Camera3D
var _playing: bool = false
var _follow_target: Node3D
var _killer_target: Node3D
var _fallback_position: Vector3 = Vector3.ZERO
var _killer_position: Vector3 = Vector3.ZERO
var _has_killer: bool = false
var _smoothed_camera_position: Vector3 = Vector3.ZERO
var _camera_direction: Vector3 = Vector3.BACK
var _camera_side: Vector3 = Vector3.RIGHT
var _elapsed: float = 0.0
var _duration: float = 0.0


func _ready() -> void:
	set_process(false)


func setup(arena: Node3D) -> void:
	_arena = arena


func bind_local_player(player: PlayerController) -> void:
	_local_player = player


func is_playing() -> bool:
	return _playing


func play(victim_position: Vector3, is_match_ending: bool, follow_target: Node3D = null, killer_id: int = -1, killer_position: Vector3 = Vector3.ZERO, killer_target: Node3D = null) -> void:
	if _playing:
		return
	_play_async(victim_position, is_match_ending, follow_target, killer_id, killer_position, killer_target)


func cancel() -> void:
	if not _playing:
		_finish_cinematic()
		return
	_playing = false
	_finish_cinematic()
	Engine.time_scale = 1.0
	set_process(false)
	finished.emit()


func _play_async(victim_position: Vector3, is_match_ending: bool, follow_target: Node3D, killer_id: int, killer_position: Vector3, killer_target: Node3D) -> void:
	_playing = true
	_duration = MATCH_END_DURATION if is_match_ending else NORMAL_DURATION
	_elapsed = 0.0
	_fallback_position = victim_position
	_killer_target = killer_target
	_killer_position = killer_position + Vector3.UP * 1.45
	if killer_target is PlayerController and (killer_target as PlayerController).camera != null:
		_killer_position = (killer_target as PlayerController).camera.global_position
	elif killer_target != null and is_instance_valid(killer_target):
		_killer_position = killer_target.global_position + Vector3.UP * 1.45
	_has_killer = killer_id > 0
	_follow_target = follow_target
	_camera_direction = _choose_camera_direction(victim_position)
	_camera_side = _choose_camera_side(victim_position, _camera_direction)
	Engine.time_scale = SLOW_MO_SCALE

	if _local_player != null:
		_local_player.set_cinematic_view_active(true)

	_setup_topdown_camera()

	set_process(true)

	var timer: SceneTreeTimer = get_tree().create_timer(_duration, true, false, true)
	await timer.timeout

	if not _playing:
		return

	_playing = false
	_finish_cinematic()
	Engine.time_scale = 1.0
	set_process(false)
	finished.emit()


func _process(delta: float) -> void:
	if not _playing or _cinematic_camera == null:
		return

	var unscaled_delta: float = delta / maxf(Engine.time_scale, 0.001)
	_elapsed += unscaled_delta
	_update_ragdoll_camera(unscaled_delta, clampf(_elapsed / maxf(_duration, 0.001), 0.0, 1.0))


func _update_ragdoll_camera(delta: float, progress: float) -> void:
	var victim_position: Vector3 = _fallback_position
	if _follow_target != null and is_instance_valid(_follow_target):
		victim_position = _follow_target.global_position
	elif _local_player != null and is_instance_valid(_local_player) and _local_player.health.is_dead:
		victim_position = _local_player.global_position

	var eased_progress: float = progress * progress * (3.0 - 2.0 * progress)
	var look_target: Vector3 = _get_look_target(victim_position)
	var desired_camera_position: Vector3 = _get_desired_camera_position(victim_position, eased_progress)
	var camera_position: Vector3 = _solve_camera_collision(look_target, desired_camera_position)
	var camera_weight: float = 1.0 - exp(-CAMERA_SMOOTHING * delta)
	_smoothed_camera_position = _solve_camera_collision(look_target, _smoothed_camera_position.lerp(camera_position, camera_weight))
	_cinematic_camera.global_position = _smoothed_camera_position
	if _smoothed_camera_position.distance_squared_to(look_target) > 0.01:
		_cinematic_camera.look_at(look_target, Vector3.UP)


func _setup_topdown_camera() -> void:
	_teardown_camera()

	if _local_player == null or not is_instance_valid(_local_player):
		return

	_cinematic_camera = _local_player.camera
	if _cinematic_camera == null:
		return

	var start_transform: Transform3D = _cinematic_camera.global_transform
	_cinematic_camera.top_level = true
	_cinematic_camera.global_transform = start_transform
	_cinematic_camera.current = true
	_smoothed_camera_position = _get_desired_camera_position(_fallback_position, 0.0) if _has_killer else _cinematic_camera.global_position
	_cinematic_camera.global_position = _smoothed_camera_position
	if _has_killer:
		_cinematic_camera.look_at(_get_look_target(_fallback_position), Vector3.UP)


func _get_look_target(victim_position: Vector3) -> Vector3:
	return victim_position + Vector3.UP * FOCUS_HEIGHT


func _get_desired_camera_position(victim_position: Vector3, progress: float) -> Vector3:
	if _has_killer:
		var impact_position: Vector3 = _fallback_position + Vector3.UP * FOCUS_HEIGHT
		var trajectory: Vector3 = impact_position - _killer_position
		var travel_scale: float = maxf(trajectory.length() - MIN_CLEAR_DISTANCE, 0.0) / maxf(trajectory.length(), 0.001)
		return _killer_position + trajectory * progress * travel_scale

	var back_distance: float = CAMERA_BACK_DISTANCE + (1.0 - progress) * 0.45
	var side_distance: float = lerpf(CAMERA_SIDE_DISTANCE * 0.55, CAMERA_SIDE_DISTANCE, progress)
	var position: Vector3 = victim_position
	position += _camera_direction * back_distance
	position += _camera_side * side_distance
	position.y += CAMERA_HEIGHT + progress * CAMERA_END_LIFT
	return position


func _choose_camera_direction(victim_position: Vector3) -> Vector3:
	if _has_killer:
		var killer_to_victim: Vector3 = victim_position - _killer_position
		killer_to_victim.y = 0.0
		if killer_to_victim.length_squared() > 0.25:
			return killer_to_victim.normalized()

	var fallback_direction: Vector3 = Vector3.BACK
	if _local_player != null and is_instance_valid(_local_player):
		fallback_direction = _local_player.global_transform.basis.z
	fallback_direction.y = 0.0
	if fallback_direction.length_squared() <= 0.01:
		return Vector3.BACK
	return fallback_direction.normalized()


func _choose_camera_side(victim_position: Vector3, direction: Vector3) -> Vector3:
	var side: Vector3 = direction.cross(Vector3.UP)
	if side.length_squared() <= 0.01:
		return Vector3.RIGHT
	side = side.normalized()
	var look_target: Vector3 = _get_look_target(victim_position)
	var left_score: float = _score_camera_side(victim_position, look_target, -side)
	var right_score: float = _score_camera_side(victim_position, look_target, side)
	return -side if left_score > right_score else side


func _score_camera_side(victim_position: Vector3, look_target: Vector3, side: Vector3) -> float:
	var desired_position: Vector3 = victim_position + _camera_direction * CAMERA_BACK_DISTANCE + side * CAMERA_SIDE_DISTANCE + Vector3.UP * CAMERA_HEIGHT
	var solved_position: Vector3 = _solve_camera_collision(look_target, desired_position)
	var desired_distance: float = look_target.distance_to(desired_position)
	if desired_distance <= 0.01:
		return 0.0
	return look_target.distance_to(solved_position) / desired_distance


func _solve_camera_collision(focus_position: Vector3, desired_position: Vector3) -> Vector3:
	if _local_player == null or not is_instance_valid(_local_player) or _local_player.get_world_3d() == null:
		return desired_position

	var focus_to_camera: Vector3 = desired_position - focus_position
	var desired_distance: float = focus_to_camera.length()
	if desired_distance <= MIN_CLEAR_DISTANCE:
		return desired_position

	var query := PhysicsRayQueryParameters3D.create(focus_position, desired_position)
	query.exclude = _get_collision_exclusions()
	query.collision_mask = _local_player.collision_mask
	query.hit_from_inside = false

	var hit: Dictionary = _local_player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return desired_position

	var direction: Vector3 = focus_to_camera / desired_distance
	var hit_position: Vector3 = hit.get("position", desired_position)
	var hit_distance: float = focus_position.distance_to(hit_position)
	var safe_distance: float = hit_distance - COLLISION_MARGIN
	if safe_distance < MIN_CLEAR_DISTANCE:
		safe_distance = maxf(hit_distance * 0.5, 0.05)
	var corrected_distance: float = clampf(safe_distance, 0.05, desired_distance)
	return focus_position + direction * corrected_distance


func _get_collision_exclusions() -> Array[RID]:
	var exclusions: Array[RID] = []
	for node in [_local_player, _follow_target, _killer_target]:
		if node is CollisionObject3D:
			exclusions.append((node as CollisionObject3D).get_rid())
	return exclusions


func _teardown_camera() -> void:
	if _cinematic_camera != null and is_instance_valid(_cinematic_camera):
		_cinematic_camera.top_level = false
		_cinematic_camera.position = Vector3.ZERO
		_cinematic_camera.rotation = Vector3.ZERO
		_cinematic_camera.current = _local_player != null and is_instance_valid(_local_player) and _local_player.is_local_controlled()
		_cinematic_camera.reset_physics_interpolation()
	_cinematic_camera = null


func _finish_cinematic() -> void:
	set_process(false)
	_follow_target = null
	_killer_target = null
	_has_killer = false
	_teardown_camera()
	if _local_player != null and is_instance_valid(_local_player):
		_local_player.set_cinematic_view_active(false)
		_local_player.cancel_kill_cam()
