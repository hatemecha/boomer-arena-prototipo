class_name WeaponBase
extends Node3D

enum ReloadStyle {
	MAGAZINE,
	REVOLVER,
	SHOTGUN,
	LEVER,
}

signal ammo_changed(ammo_in_mag: int, reserve_ammo: int)
signal weapon_state_changed(state: String)
signal fired(weapon: WeaponBase)

@export var weapon_name: String = "Weapon"
@export_range(1, 200) var damage: int = 10
@export_range(0.05, 5.0) var fire_rate: float = 0.09
@export_range(1, 200) var mag_size: int = 24
@export_range(0, 999) var reserve_ammo: int = 96
@export_range(0.1, 5.0) var reload_time: float = 1.1
@export_range(0.0, 10.0) var recoil_degrees: float = 1.2
@export_range(0.0, 20.0) var spread_degrees: float = 1.0
@export_range(0.1, 1.0) var aim_spread_multiplier: float = 0.35
@export_range(1.0, 300.0) var weapon_range: float = 80.0
@export var fire_sound: AudioStream
@export var reload_sound: AudioStream
@export var no_ammo_sound: AudioStream
@export var aim_sight_path: NodePath = NodePath("WeaponModel/AimRearSight")
@export var aim_pose_path: NodePath = NodePath()
@export var reload_style: ReloadStyle = ReloadStyle.MAGAZINE
@export_range(0.0, 0.5) var reload_drop_distance: float = 0.18
@export_range(0.0, 60.0) var reload_tilt_degrees: float = 22.0

var ammo_in_mag: int = mag_size
var state: String = "Idle"
var is_aiming: bool = false
var reload_anim_position: Vector3 = Vector3.ZERO
var reload_anim_rotation: Vector3 = Vector3.ZERO
var _time_since_last_shot: float = 999.0
var _is_reloading: bool = false
var _audio_player: AudioStreamPlayer3D
var _reload_tween: Tween


func _ready() -> void:
	ammo_in_mag = clampi(ammo_in_mag, 0, mag_size)
	_audio_player = AudioStreamPlayer3D.new()
	_audio_player.name = "WeaponAudio"
	add_child(_audio_player)
	ammo_changed.emit(ammo_in_mag, reserve_ammo)
	_set_state("Idle")


func _process(delta: float) -> void:
	_time_since_last_shot += delta


func is_reloading() -> bool:
	return _is_reloading


func can_fire() -> bool:
	return not _is_reloading and ammo_in_mag > 0 and _time_since_last_shot >= fire_rate


func try_fire(_camera: Camera3D) -> bool:
	if _is_reloading:
		return false
	if ammo_in_mag <= 0:
		_set_state("NoAmmo")
		_play_sound(no_ammo_sound)
		return false
	if not can_fire():
		return false

	ammo_in_mag -= 1
	_time_since_last_shot = 0.0
	_set_state("Firing")
	ammo_changed.emit(ammo_in_mag, reserve_ammo)
	_play_sound(fire_sound)
	return true


func reload() -> bool:
	if _is_reloading or ammo_in_mag >= mag_size or reserve_ammo <= 0:
		return false

	_is_reloading = true
	_set_state("Reloading")
	_play_sound(reload_sound)
	await _animate_reload()

	var needed_ammo: int = mag_size - ammo_in_mag
	var ammo_to_load: int = min(needed_ammo, reserve_ammo)
	ammo_in_mag += ammo_to_load
	reserve_ammo -= ammo_to_load
	_is_reloading = false
	ammo_changed.emit(ammo_in_mag, reserve_ammo)
	_set_state("Idle")
	return true


func _animate_reload() -> void:
	_reset_reload_animation()
	var steps: Array = _build_reload_sequence()
	if steps.is_empty():
		return

	_reload_tween = create_tween()
	for step: Dictionary in steps:
		var duration: float = reload_time * float(step["weight"])
		var position: Vector3 = step["pos"] as Vector3
		var rotation: Vector3 = step["rot"] as Vector3
		_reload_tween.set_trans(step.get("trans", Tween.TRANS_CUBIC) as Tween.TransitionType)
		_reload_tween.set_ease(step.get("ease", Tween.EASE_IN_OUT) as Tween.EaseType)
		_reload_tween.tween_property(self, "reload_anim_position", position, duration)
		_reload_tween.parallel().tween_property(self, "reload_anim_rotation", rotation, duration)

	await _reload_tween.finished
	reload_anim_position = Vector3.ZERO
	reload_anim_rotation = Vector3.ZERO


func _reset_reload_animation() -> void:
	if _reload_tween != null and _reload_tween.is_valid():
		_reload_tween.kill()
	reload_anim_position = Vector3.ZERO
	reload_anim_rotation = Vector3.ZERO


func _build_reload_sequence() -> Array:
	match reload_style:
		ReloadStyle.REVOLVER:
			return _build_revolver_reload()
		ReloadStyle.SHOTGUN:
			return _build_shotgun_reload()
		ReloadStyle.LEVER:
			return _build_lever_reload()
		_:
			return _build_magazine_reload()


func _build_magazine_reload() -> Array:
	var drop := _pos_scale()
	var tilt := _tilt_scale()
	return [
		_step(0.07, Vector3(0.04, -0.05, 0.06) * drop, Vector3(14.0, -8.0, 10.0) * tilt, Tween.TRANS_QUAD, Tween.EASE_OUT),
		_step(0.13, Vector3(0.08, -0.34, 0.22) * drop, Vector3(52.0, -18.0, 24.0) * tilt, Tween.TRANS_CUBIC, Tween.EASE_OUT),
		_step(0.10, Vector3(0.11, -0.40, 0.26) * drop, Vector3(58.0, -24.0, 30.0) * tilt, Tween.TRANS_QUAD, Tween.EASE_IN_OUT),
		_step(0.16, Vector3(0.09, -0.32, 0.20) * drop, Vector3(46.0, -14.0, 20.0) * tilt, Tween.TRANS_SINE, Tween.EASE_IN_OUT),
		_step(0.14, Vector3(0.10, -0.36, 0.24) * drop, Vector3(50.0, -20.0, 26.0) * tilt, Tween.TRANS_SINE, Tween.EASE_IN_OUT),
		_step(0.12, Vector3(0.04, -0.14, 0.08) * drop, Vector3(22.0, 6.0, -8.0) * tilt, Tween.TRANS_QUAD, Tween.EASE_IN),
		_step(0.10, Vector3(-0.02, 0.05, -0.03) * drop, Vector3(-6.0, 3.0, -4.0) * tilt, Tween.TRANS_BACK, Tween.EASE_OUT),
		_step(0.08, Vector3.ZERO, Vector3.ZERO, Tween.TRANS_QUAD, Tween.EASE_OUT),
	]


func _build_revolver_reload() -> Array:
	var drop := _pos_scale()
	var tilt := _tilt_scale()
	return [
		_step(0.10, Vector3(0.10, -0.18, 0.12) * drop, Vector3(18.0, 28.0, -38.0) * tilt, Tween.TRANS_CUBIC, Tween.EASE_OUT),
		_step(0.12, Vector3(0.14, -0.26, 0.16) * drop, Vector3(24.0, 42.0, -52.0) * tilt, Tween.TRANS_QUAD, Tween.EASE_OUT),
		_step(0.18, Vector3(0.12, -0.24, 0.14) * drop, Vector3(20.0, 36.0, -46.0) * tilt, Tween.TRANS_SINE, Tween.EASE_IN_OUT),
		_step(0.14, Vector3(0.13, -0.28, 0.15) * drop, Vector3(22.0, 48.0, -58.0) * tilt, Tween.TRANS_SINE, Tween.EASE_IN_OUT),
		_step(0.12, Vector3(0.11, -0.22, 0.12) * drop, Vector3(18.0, 34.0, -44.0) * tilt, Tween.TRANS_SINE, Tween.EASE_IN_OUT),
		_step(0.14, Vector3(0.05, -0.10, 0.05) * drop, Vector3(10.0, 12.0, -14.0) * tilt, Tween.TRANS_QUAD, Tween.EASE_IN),
		_step(0.10, Vector3(-0.02, 0.04, -0.02) * drop, Vector3(-5.0, -4.0, 6.0) * tilt, Tween.TRANS_BACK, Tween.EASE_OUT),
		_step(0.10, Vector3.ZERO, Vector3.ZERO, Tween.TRANS_QUAD, Tween.EASE_OUT),
	]


func _build_shotgun_reload() -> Array:
	var drop := _pos_scale()
	var tilt := _tilt_scale()
	var shells_to_load: int = mini(mag_size - ammo_in_mag, reserve_ammo)
	var sequence: Array = [
		_step(0.11, Vector3(0.05, -0.22, 0.14) * drop, Vector3(34.0, -10.0, 18.0) * tilt, Tween.TRANS_CUBIC, Tween.EASE_OUT),
		_step(0.13, Vector3(0.08, -0.42, 0.28) * drop, Vector3(68.0, -14.0, 36.0) * tilt, Tween.TRANS_QUAD, Tween.EASE_OUT),
		_step(0.10, Vector3(0.10, -0.46, 0.30) * drop, Vector3(74.0, -18.0, 40.0) * tilt, Tween.TRANS_SINE, Tween.EASE_IN_OUT),
	]

	for shell_index in range(maxi(shells_to_load, 1)):
		var shell_bias: float = -1.0 if shell_index % 2 == 0 else 1.0
		sequence.append(_step(
			0.16 / float(maxi(shells_to_load, 1)),
			Vector3(0.07 + shell_bias * 0.02, -0.38, 0.24) * drop,
			Vector3(58.0 + shell_bias * 4.0, -12.0 + shell_bias * 6.0, 32.0 + shell_bias * 5.0) * tilt,
			Tween.TRANS_BACK,
			Tween.EASE_OUT
		))
		sequence.append(_step(
			0.10 / float(maxi(shells_to_load, 1)),
			Vector3(0.09, -0.44, 0.28) * drop,
			Vector3(66.0, -16.0, 36.0) * tilt,
			Tween.TRANS_QUAD,
			Tween.EASE_IN
		))

	sequence.append_array([
		_step(0.12, Vector3(0.04, -0.16, 0.10) * drop, Vector3(28.0, 4.0, -10.0) * tilt, Tween.TRANS_QUAD, Tween.EASE_IN),
		_step(0.10, Vector3(-0.02, 0.05, -0.03) * drop, Vector3(-8.0, 2.0, -5.0) * tilt, Tween.TRANS_BACK, Tween.EASE_OUT),
		_step(0.08, Vector3.ZERO, Vector3.ZERO, Tween.TRANS_QUAD, Tween.EASE_OUT),
	])
	return _normalize_reload_weights(sequence)


func _build_lever_reload() -> Array:
	var drop := _pos_scale()
	var tilt := _tilt_scale()
	return [
		_step(0.09, Vector3(-0.03, -0.12, 0.10) * drop, Vector3(20.0, 6.0, -10.0) * tilt, Tween.TRANS_QUAD, Tween.EASE_OUT),
		_step(0.12, Vector3(-0.06, -0.28, 0.18) * drop, Vector3(38.0, 10.0, -16.0) * tilt, Tween.TRANS_CUBIC, Tween.EASE_OUT),
		_step(0.14, Vector3(-0.08, -0.34, 0.22) * drop, Vector3(58.0, 14.0, -20.0) * tilt, Tween.TRANS_QUAD, Tween.EASE_IN),
		_step(0.12, Vector3(-0.05, -0.26, 0.16) * drop, Vector3(34.0, 8.0, -14.0) * tilt, Tween.TRANS_BACK, Tween.EASE_OUT),
		_step(0.16, Vector3(-0.04, -0.22, 0.14) * drop, Vector3(28.0, 6.0, -12.0) * tilt, Tween.TRANS_SINE, Tween.EASE_IN_OUT),
		_step(0.10, Vector3(0.02, -0.08, 0.04) * drop, Vector3(12.0, -4.0, 6.0) * tilt, Tween.TRANS_QUAD, Tween.EASE_IN),
		_step(0.09, Vector3(-0.02, 0.04, -0.02) * drop, Vector3(-5.0, 2.0, -3.0) * tilt, Tween.TRANS_BACK, Tween.EASE_OUT),
		_step(0.08, Vector3.ZERO, Vector3.ZERO, Tween.TRANS_QUAD, Tween.EASE_OUT),
	]


func _step(
	weight: float,
	position: Vector3,
	rotation: Vector3,
	trans: Tween.TransitionType = Tween.TRANS_CUBIC,
	ease: Tween.EaseType = Tween.EASE_IN_OUT
) -> Dictionary:
	return {
		"weight": weight,
		"pos": position,
		"rot": rotation,
		"trans": trans,
		"ease": ease,
	}


func _normalize_reload_weights(steps: Array) -> Array:
	var total_weight: float = 0.0
	for step: Dictionary in steps:
		total_weight += float(step["weight"])
	if total_weight <= 0.0001:
		return steps

	var normalized: Array = []
	for step: Dictionary in steps:
		var copy: Dictionary = step.duplicate()
		copy["weight"] = float(step["weight"]) / total_weight
		normalized.append(copy)
	return normalized


func _pos_scale() -> float:
	return reload_drop_distance / 0.22


func _tilt_scale() -> float:
	return reload_tilt_degrees / 40.0


func has_aim_pose() -> bool:
	return not aim_pose_path.is_empty() and get_node_or_null(aim_pose_path) is Node3D


func get_aim_pose_transform() -> Transform3D:
	var pose: Node3D = get_node_or_null(aim_pose_path) as Node3D
	if pose == null:
		return Transform3D.IDENTITY

	var camera: Node3D = get_parent() as Node3D
	if camera == null or pose.get_parent() == camera:
		return pose.transform

	return camera.global_transform.affine_inverse() * pose.global_transform


func get_aim_sight_local_offset() -> Vector3:
	if aim_sight_path.is_empty():
		return Vector3.ZERO

	var sight: Node3D = get_node_or_null(aim_sight_path) as Node3D
	if sight == null:
		return Vector3.ZERO

	return to_local(sight.global_transform.origin)


func has_aim_sight_alignment() -> bool:
	return get_aim_sight_local_offset().length_squared() > 0.0001


func bake_aim_pose_from_transform() -> void:
	if not has_aim_pose():
		push_warning("%s has no aim pose node configured." % name)
		return

	var pose: Node3D = get_node_or_null(aim_pose_path) as Node3D
	if pose == null:
		return

	var camera: Node3D = get_parent() as Node3D
	if camera == null or pose.get_parent() == camera:
		pose.transform = transform
	else:
		pose.global_transform = global_transform


func add_ammo(amount: int) -> bool:
	if amount <= 0:
		push_warning("Ammo amount must be greater than zero.")
		return false

	reserve_ammo += amount
	ammo_changed.emit(ammo_in_mag, reserve_ammo)
	return true


func _set_state(next_state: String) -> void:
	if state == next_state:
		return
	state = next_state
	weapon_state_changed.emit(state)


func _play_sound(sound: AudioStream) -> void:
	if sound == null or _audio_player == null:
		return
	_audio_player.stream = sound
	_audio_player.play()
