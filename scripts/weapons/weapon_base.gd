class_name WeaponBase
extends Node3D

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

var ammo_in_mag: int = mag_size
var state: String = "Idle"
var is_aiming: bool = false
var _time_since_last_shot: float = 999.0
var _is_reloading: bool = false
var _audio_player: AudioStreamPlayer3D


func _ready() -> void:
	ammo_in_mag = clampi(ammo_in_mag, 0, mag_size)
	_audio_player = AudioStreamPlayer3D.new()
	_audio_player.name = "WeaponAudio"
	add_child(_audio_player)
	ammo_changed.emit(ammo_in_mag, reserve_ammo)
	_set_state("Idle")


func _process(delta: float) -> void:
	_time_since_last_shot += delta


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
	fired.emit(self)
	return true


func reload() -> bool:
	if _is_reloading or ammo_in_mag >= mag_size or reserve_ammo <= 0:
		return false

	_is_reloading = true
	_set_state("Reloading")
	_play_sound(reload_sound)
	await get_tree().create_timer(reload_time).timeout

	var needed_ammo: int = mag_size - ammo_in_mag
	var ammo_to_load: int = min(needed_ammo, reserve_ammo)
	ammo_in_mag += ammo_to_load
	reserve_ammo -= ammo_to_load
	_is_reloading = false
	ammo_changed.emit(ammo_in_mag, reserve_ammo)
	_set_state("Idle")
	return true


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
