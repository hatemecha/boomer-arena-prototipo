class_name DeathCinematicDirector
extends Node

signal finished

const NORMAL_DURATION: float = 1.9
const MATCH_END_DURATION: float = 2.35
const SLOW_MO_SCALE: float = 0.28
const CAMERA_DISTANCE: float = 4.2
const CAMERA_HEIGHT: float = 1.25
const CAMERA_END_LIFT: float = 0.55
const FOCUS_HEIGHT: float = 0.72
const FOLLOW_SMOOTHING: float = 24.0

var _arena: TestArena
var _local_player: PlayerController
var _cinematic_camera: Camera3D
var _playing: bool = false
var _follow_target: Node3D
var _fallback_position: Vector3 = Vector3.ZERO
var _smoothed_focus_position: Vector3 = Vector3.ZERO
var _camera_direction: Vector3 = Vector3.BACK
var _elapsed: float = 0.0
var _duration: float = 0.0


func setup(arena: TestArena) -> void:
	_arena = arena


func bind_local_player(player: PlayerController) -> void:
	_local_player = player


func is_playing() -> bool:
	return _playing


func play(action_position: Vector3, is_match_ending: bool, follow_target: Node3D = null) -> void:
	if _playing:
		return
	_play_async(action_position, is_match_ending, follow_target)


func cancel() -> void:
	if not _playing:
		_finish_cinematic()
		return
	_playing = false
	_finish_cinematic()
	Engine.time_scale = 1.0
	set_process(false)
	finished.emit()


func _play_async(action_position: Vector3, is_match_ending: bool, follow_target: Node3D) -> void:
	_playing = true
	_duration = MATCH_END_DURATION if is_match_ending else NORMAL_DURATION
	_elapsed = 0.0
	_fallback_position = action_position
	_smoothed_focus_position = action_position
	_follow_target = follow_target
	_camera_direction = _choose_camera_direction(action_position)
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
	var focus_position: Vector3 = _fallback_position
	if _follow_target != null and is_instance_valid(_follow_target):
		focus_position = _follow_target.global_position
	elif _local_player != null and is_instance_valid(_local_player) and _local_player.health.is_dead:
		focus_position = _local_player.global_position

	var desired_focus: Vector3 = focus_position + Vector3.UP * FOCUS_HEIGHT
	var follow_weight: float = 1.0 - exp(-FOLLOW_SMOOTHING * delta)
	_smoothed_focus_position = _smoothed_focus_position.lerp(desired_focus, follow_weight)

	var eased_progress: float = progress * progress * (3.0 - 2.0 * progress)
	var camera_position: Vector3 = _smoothed_focus_position
	camera_position += _camera_direction * CAMERA_DISTANCE
	camera_position.y = focus_position.y + CAMERA_HEIGHT + eased_progress * CAMERA_END_LIFT
	_cinematic_camera.global_position = camera_position
	_cinematic_camera.look_at(_smoothed_focus_position, Vector3.UP)


func _setup_topdown_camera() -> void:
	_teardown_camera()

	if _local_player == null or not is_instance_valid(_local_player):
		return

	_cinematic_camera = _local_player.camera
	if _cinematic_camera == null:
		return

	_cinematic_camera.top_level = true
	_cinematic_camera.current = true
	_update_ragdoll_camera(1.0, 0.0)


func _choose_camera_direction(action_position: Vector3) -> Vector3:
	if _local_player != null and is_instance_valid(_local_player):
		var from_action_to_player: Vector3 = _local_player.global_position - action_position
		from_action_to_player.y = 0.0
		if from_action_to_player.length_squared() > 0.25:
			return from_action_to_player.normalized()

	var fallback_direction: Vector3 = Vector3.BACK
	if _local_player != null and is_instance_valid(_local_player):
		fallback_direction = _local_player.global_transform.basis.z
	fallback_direction.y = 0.0
	if fallback_direction.length_squared() <= 0.01:
		return Vector3.BACK
	return fallback_direction.normalized()


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
	_teardown_camera()
	if _local_player != null and is_instance_valid(_local_player):
		_local_player.set_cinematic_view_active(false)
		_local_player.cancel_kill_cam()
