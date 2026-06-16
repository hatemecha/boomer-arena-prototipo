class_name PlayerController
extends CharacterBody3D

const PlayerSettingsAccess = preload("res://scripts/game/player_settings_access.gd")
const PlayerWeaponMotionScript: GDScript = preload("res://scripts/player/player_weapon_motion.gd")
const PlayerBodyVisualScript: GDScript = preload("res://scripts/player/player_body_visual.gd")

enum DebugCameraMode {
	FIRST_PERSON,
	THIRD_PERSON_BACK,
	THIRD_PERSON_FRONT,
}

enum WeaponHoldMode {
	DEFAULT,
	DOOM,
}

const _DEBUG_CAMERA_PRIORITY_ACTIVE := 20
const _DEBUG_CAMERA_PRIORITY_INACTIVE := 0

signal debug_stats_changed(world_position: Vector3, speed: float)
signal active_weapon_changed(weapon: WeaponBase)
signal damaged(amount: int)
signal died
signal respawned
signal weapon_fired(weapon_name: String)
signal pickup_interaction_changed(prompt: String, progress: float, is_visible: bool, can_collect: bool)

@export_group("Movement")
@export_range(1.0, 30.0) var walk_speed: float = 7.5
@export_range(1.0, 40.0) var run_speed: float = 12.5
@export_range(1.0, 30.0) var jump_velocity: float = 7.8
@export_range(0.1, 80.0) var ground_acceleration: float = 52.0
@export_range(0.1, 40.0) var air_acceleration: float = 16.0
@export_range(0.1, 60.0) var friction: float = 24.0

@export_group("Look And Aim")
@export_range(0.01, 1.0) var mouse_sensitivity: float = 0.25
@export_range(60.0, 120.0) var fov: float = 90.0
@export_range(45.0, 100.0) var aim_fov: float = 60.0
@export_range(1.0, 40.0) var aim_enter_speed: float = 14.0
@export_range(1.0, 40.0) var aim_exit_speed: float = 10.0
@export_range(0.1, 1.0) var aim_mouse_sensitivity_multiplier: float = 0.55
@export_range(0.02, 0.25) var aim_sight_depth: float = 0.065
@export var aim_weapon_position: Vector3 = Vector3(0.0, -0.22, -0.4)
@export var aim_view_offset: Vector3 = Vector3.ZERO

@export_group("Jump")
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

@export_group("Identity And Network")
@export var player_id: int = 1
@export var display_name: String = "Player"
@export var input_prefix: String = ""
@export var mouse_look_enabled: bool = true
@export_range(0.2, 8.0) var gamepad_look_sensitivity: float = 3.0
@export_range(0.0, 5.0) var respawn_invulnerability_time: float = 1.0
@export_range(1.0, 40.0) var network_interpolation_speed: float = 18.0
@export_range(0.5, 20.0) var network_snap_distance: float = 6.0

@export_group("Crouch")
@export var crouch_enabled: bool = true
@export_range(0.2, 2.0) var crouch_height_multiplier: float = 0.55
@export_range(1.0, 20.0) var crouch_speed: float = 4.5
@export_range(1.0, 30.0) var crouch_transition_speed: float = 12.0
@export_range(0.0, 1.0) var crouch_camera_drop: float = 0.45

@export_group("Camera Motion")
@export var camera_motion_enabled: bool = true
@export_range(0.0, 0.2) var idle_breath_amount: float = 0.018
@export_range(0.1, 3.0) var idle_breath_frequency: float = 0.75
@export_range(0.0, 5.0) var idle_breath_roll_amount: float = 0.65
@export_range(0.0, 3.0) var walk_bob_amount: float = 0.066
@export_range(0.0, 3.0) var run_bob_amount: float = 0.108
@export_range(0.5, 4.0) var walk_stride_length: float = 2.15
@export_range(1.0, 5.0) var run_stride_length: float = 2.9
@export_range(0.5, 2.0) var bob_frequency_scale: float = 0.95
@export_range(0.0, 8.0) var bob_lateral_ratio: float = 0.5
@export_range(0.0, 8.0) var bob_forward_ratio: float = 0.2
@export_range(0.0, 1.0) var bob_entry_floor: float = 0.72
@export_range(1.0, 20.0) var bob_blend_speed: float = 6.5
@export_range(0.0, 12.0) var camera_roll_amount: float = 5.2
@export_range(0.0, 8.0) var camera_strafe_pitch_amount: float = 2.4
@export_range(0.0, 8.0) var camera_strafe_yaw_amount: float = 1.6
@export_range(0.0, 1.0) var camera_look_inertia: float = 0.12
@export_range(1.0, 40.0) var camera_look_return_speed: float = 9.0
@export_range(0.0, 1.0) var camera_aim_motion_multiplier: float = 0.42
@export_range(0.0, 20.0) var run_fov_boost: float = 5.0
@export_range(1.0, 30.0) var fov_transition_speed: float = 10.0
@export_range(0.0, 0.2) var landing_camera_dip: float = 0.09

@export_group("Weapon Motion")
@export var weapon_motion_enabled: bool = true
@export_range(0.0, 1.0) var weapon_sway_amount: float = 0.12
@export_range(0.0, 1.0) var weapon_rotation_sway_amount: float = 0.085
@export_range(0.0, 1.0) var weapon_movement_sway_amount: float = 0.098
@export_range(0.1, 4.0) var weapon_run_sway_multiplier: float = 1.82
@export_range(0.0, 1.0) var weapon_crouch_sway_multiplier: float = 0.45
@export_range(0.0, 1.0) var weapon_aim_sway_multiplier: float = 0.38
@export_range(0.0, 2.0) var weapon_aim_move_sway_multiplier: float = 0.72
@export_range(1.0, 30.0) var weapon_sway_smoothing: float = 10.0
@export_range(0.0, 0.2) var weapon_jump_drop: float = 0.065
@export_range(0.0, 0.2) var weapon_landing_kick: float = 0.08
@export var weapon_hold_mode: WeaponHoldMode = WeaponHoldMode.DEFAULT
@export var align_weapon_muzzle_to_crosshair: bool = false
@export_range(-0.25, 0.25) var weapon_crosshair_lateral_offset: float = 0.0

@export_group("Body Visual")
@export var hide_body_for_local_player: bool = true
@export var hide_third_person_weapon_for_local_player: bool = true
@export_range(0.0, 0.18) var body_breath_amount: float = 0.025
@export_range(0.1, 3.0) var body_breath_frequency: float = 0.7
@export_range(0.0, 0.2) var body_walk_bob_amount: float = 0.055
@export_range(0.0, 12.0) var body_walk_roll_degrees: float = 3.5
@export_range(0.0, 1.0) var third_person_aim_offset: float = 0.16
@export_range(0.0, 45.0) var leg_swing_degrees: float = 24.0
@export_range(0.0, 45.0) var leg_jump_tuck_degrees: float = 18.0

@export_group("Debug Camera")
@export var debug_camera_enabled: bool = true
@export_range(1.8, 6.0) var debug_third_person_distance: float = 2.75
@export var debug_third_person_shoulder_offset: Vector3 = Vector3(0.42, 0.12, 0.0)
@export_range(0.5, 1.0) var debug_third_person_aim_distance_scale: float = 0.82
@export_range(0.2, 3.0) var third_person_target_height: float = 1.45
@export_range(0.2, 3.0) var third_person_min_distance: float = 0.65
@export_range(1.0, 40.0) var third_person_follow_smoothing: float = 18.0
@export_range(0.01, 0.5) var third_person_collision_margin: float = 0.18

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/PlayerCamera
@onready var _viewmodel_fill_light: OmniLight3D = $CameraPivot/PlayerCamera/ViewmodelFill
@onready var _phantom_camera_host: PhantomCameraHost = $CameraPivot/PlayerCamera/PhantomCameraHost
@onready var health: PlayerHealth = $PlayerHealth
@onready var body_mesh: Node3D = $BodyMesh
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var body_visual: Node3D = $BodyMesh/AmongUsPlayerModel
@onready var third_person_weapon_rig: Node3D = $BodyMesh/ThirdPersonWeaponRig
@onready var character_skeleton: Skeleton3D = $BodyMesh/AmongUsPlayerModel/Model/Sketchfab_model/root/GLTF_SceneRootNode/Armature_50/GLTF_created_2/Skeleton3D

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
var _cinematic_view_active: bool = false
var _is_invulnerable: bool = false
var last_damage_source_player_id: int = 0
var last_killer_position: Vector3 = Vector3.ZERO
var _body_color: Color = Color(0.78, 0.82, 0.88)
var _is_aiming: bool = false
var _aim_blend: float = 0.0
var _has_network_target: bool = false
var _network_target_position: Vector3 = Vector3.ZERO
var _network_target_yaw: float = 0.0
var _network_target_pitch_degrees: float = 0.0
var _network_target_velocity: Vector3 = Vector3.ZERO
var _network_target_is_crouching: bool = false
var _network_target_is_aiming: bool = false
var _network_target_active_weapon_index: int = 0
var _is_crouching: bool = false
var _crouch_blend: float = 0.0
var _standing_collision_height: float = 0.0
var _crouching_collision_height: float = 0.0
var _standing_collision_position: Vector3 = Vector3.ZERO
var _standing_clearance_shape: CapsuleShape3D
var _standing_clearance_query: PhysicsShapeQueryParameters3D
var _standing_camera_pivot_position: Vector3 = Vector3.ZERO
var _standing_body_position: Vector3 = Vector3.ZERO
var _standing_body_scale: Vector3 = Vector3.ONE
var _bob_time: float = 0.0
var _bob_blend: float = 0.0
var _smoothed_bob_offset: Vector3 = Vector3.ZERO
var _smoothed_strafe_factor: float = 0.0
var _smoothed_motion_speed: float = 0.0
var _breath_time: float = 0.0
var _camera_pitch_inertia: float = 0.0
var _camera_yaw_inertia: float = 0.0
var _camera_roll: float = 0.0
var _recoil_pitch_offset: float = 0.0
var _recoil_tween: Tween
var _camera_shake_tween: Tween
var _camera_shake_origin: Vector3 = Vector3.ZERO
var _previous_camera_yaw: float = 0.0
var _landing_offset: float = 0.0
var _respawn_invulnerability_token: int = 0
var _wall_jump_cooldown_timer: float = 0.0
var _wall_jump_air_control_lock_timer: float = 0.0
var _air_time: float = 0.0
var _last_wall_normal: Vector3 = Vector3.ZERO
var _last_wall_contact_time: float = -999.0
var _last_wall_jump_normal: Vector3 = Vector3.ZERO
var _has_left_wall_since_last_jump: bool = true
var _wall_jump_camera_kick_offset: Vector3 = Vector3.ZERO
var _weapon_motion = PlayerWeaponMotionScript.new()
var _last_view_delta: Vector2 = Vector2.ZERO
var _hud_motion_strafe: float = 0.0
var _hud_motion_forward: float = 0.0
var _hud_motion_look: Vector2 = Vector2.ZERO
var _prev_hud_sample_yaw: float = 0.0
var _prev_hud_sample_pitch: float = 0.0
var _body_visual_controller = PlayerBodyVisualScript.new()
var _debug_camera_mode: DebugCameraMode = DebugCameraMode.FIRST_PERSON
var _third_back_pcam: PhantomCamera3D
var _third_front_pcam: PhantomCamera3D
var _kill_cam_pcam: PhantomCamera3D
const _KILL_CAM_PRIORITY: int = 20
const _KILL_CAM_DURATION: float = 1.5
var _kill_cam_active: bool = false
var respawn_generation: int = 0
var _third_person_camera_initialized: bool = false
var _third_person_camera_position: Vector3 = Vector3.ZERO
var _motion_defaults_cached: bool = false
var _default_camera_motion_enabled: bool = true
var _default_weapon_motion_enabled: bool = true
var _default_idle_breath_amount: float = 0.0
var _default_walk_bob_amount: float = 0.0
var _default_run_bob_amount: float = 0.0
var _default_camera_roll_amount: float = 0.0
var _default_camera_strafe_pitch_amount: float = 0.0
var _default_camera_strafe_yaw_amount: float = 0.0
var _default_camera_look_inertia: float = 0.0
var _default_landing_camera_dip: float = 0.0
var _default_wall_jump_camera_kick: float = 0.0
var _default_weapon_sway_amount: float = 0.0
var _default_weapon_rotation_sway_amount: float = 0.0
var _default_weapon_movement_sway_amount: float = 0.0
var _default_weapon_jump_drop: float = 0.0
var _default_weapon_landing_kick: float = 0.0


#region Ciclo de vida e input
func _ready() -> void:
	DefaultInputActions.ensure_default_actions()
	camera.fov = fov
	_cache_standing_pose()
	_cache_motion_defaults()
	_body_visual_controller.setup(self)
	_collect_weapons()
	_set_active_weapon(0)
	_update_body_visibility()
	_update_first_person_weapon_visibility()
	_update_third_person_weapon_visibility()
	health.died.connect(_on_health_died)
	_weapon_motion.reset(rotation.y, _pitch_degrees)
	_previous_camera_yaw = rotation.y
	_prev_hud_sample_yaw = rotation.y
	_prev_hud_sample_pitch = _pitch_degrees
	if PlayerSettingsAccess.has_settings():
		PlayerSettingsAccess.connect_performance_profile_changed(_on_performance_profile_changed)
		apply_performance_profile(PlayerSettingsAccess.get_performance_profile())
	_setup_debug_cameras()


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

	if debug_camera_enabled and event.is_action_pressed("debug_camera_cycle"):
		_cycle_debug_camera_mode()


func _process(delta: float) -> void:
	if not _is_locally_controlled():
		_update_remote_interpolation(delta)
		_update_crouch_visual(delta)
		_update_third_person_visual(delta)
		return

	_ensure_first_person_camera_attached()
	_is_aiming = _gameplay_input_enabled and not _is_dead and weapon != null and Input.is_action_pressed(_action("aim"))
	if weapon != null:
		weapon.is_aiming = _is_aiming
	_update_aim_state(delta)
	_update_crouch_visual(delta)
	_update_debug_cameras()
	_update_camera_motion(delta)
	if _should_update_third_person_visual():
		_update_third_person_visual(delta)
	_update_hud_motion_sample(delta)


func _physics_process(delta: float) -> void:
	if not _is_locally_controlled():
		return

	if _is_dead:
		return

	_handle_gamepad_look(delta)
	_handle_movement(delta)
	if _gameplay_input_enabled:
		_handle_weapon_input()
	debug_stats_changed.emit(global_position, Vector2(velocity.x, velocity.z).length())
#endregion


#region API publica (HUD, pickups, Game y red)
func add_ammo(amount: int) -> bool:
	if weapon == null:
		push_error("Player has no active weapon to receive ammo.")
		return false
	return weapon.add_ammo(amount)


func heal(amount: int) -> bool:
	return health.heal(amount)


func is_crouching() -> bool:
	return _is_crouching


func is_aiming() -> bool:
	return _is_aiming


func is_local_controlled() -> bool:
	return _is_locally_controlled()


func is_debug_first_person_view() -> bool:
	return _is_debug_first_person_view()


func get_camera_pitch_degrees() -> float:
	return _pitch_degrees


func get_aim_blend() -> float:
	return _aim_blend


func get_bob_blend() -> float:
	return _bob_blend


func get_landing_offset() -> float:
	return _landing_offset


func is_gameplay_input_enabled() -> bool:
	return _gameplay_input_enabled


func get_horizontal_speed() -> float:
	return _get_horizontal_speed()


func should_use_run_fov() -> bool:
	return _should_use_run_fov()


func is_alive() -> bool:
	return not _is_dead


func is_interact_pressed() -> bool:
	return _is_locally_controlled() and _gameplay_input_enabled and not _is_dead and Input.is_action_pressed(_action("interact"))


func set_pickup_interaction(prompt: String, progress: float, is_visible: bool, can_collect: bool = true) -> void:
	if not _is_locally_controlled():
		return
	pickup_interaction_changed.emit(prompt, clampf(progress, 0.0, 1.0), is_visible, can_collect)


func apply_performance_profile(profile: int) -> void:
	var safe_profile := clampi(profile, 0, 2)
	_apply_visual_motion_profile(safe_profile)
	for weapon_node in _weapons:
		if weapon_node == null:
			continue
		if weapon_node.has_method("apply_performance_profile"):
			weapon_node.apply_performance_profile(safe_profile)
		var muzzle_flash: Node = weapon_node.get_node_or_null("MuzzleFlash")
		if muzzle_flash != null and muzzle_flash.has_method("apply_performance_profile"):
			muzzle_flash.apply_performance_profile(safe_profile)


func _apply_visual_motion_profile(profile: int) -> void:
	_cache_motion_defaults()
	match profile:
		PlayerSettingsAccess.PERFORMANCE_PROFILE_LOW:
			_restore_visual_motion_defaults()
			_scale_camera_motion(0.62)
			_scale_weapon_motion(0.58)
		PlayerSettingsAccess.PERFORMANCE_PROFILE_ULTRA_LOW:
			_restore_visual_motion_defaults()
			_scale_camera_motion(0.22)
			_scale_weapon_motion(0.18)
		_:
			_restore_visual_motion_defaults()


func _cache_motion_defaults() -> void:
	if _motion_defaults_cached:
		return
	_default_camera_motion_enabled = camera_motion_enabled
	_default_weapon_motion_enabled = weapon_motion_enabled
	_default_idle_breath_amount = idle_breath_amount
	_default_walk_bob_amount = walk_bob_amount
	_default_run_bob_amount = run_bob_amount
	_default_camera_roll_amount = camera_roll_amount
	_default_camera_strafe_pitch_amount = camera_strafe_pitch_amount
	_default_camera_strafe_yaw_amount = camera_strafe_yaw_amount
	_default_camera_look_inertia = camera_look_inertia
	_default_landing_camera_dip = landing_camera_dip
	_default_wall_jump_camera_kick = wall_jump_camera_kick
	_default_weapon_sway_amount = weapon_sway_amount
	_default_weapon_rotation_sway_amount = weapon_rotation_sway_amount
	_default_weapon_movement_sway_amount = weapon_movement_sway_amount
	_default_weapon_jump_drop = weapon_jump_drop
	_default_weapon_landing_kick = weapon_landing_kick
	_motion_defaults_cached = true


func _restore_visual_motion_defaults() -> void:
	camera_motion_enabled = _default_camera_motion_enabled
	weapon_motion_enabled = _default_weapon_motion_enabled
	idle_breath_amount = _default_idle_breath_amount
	walk_bob_amount = _default_walk_bob_amount
	run_bob_amount = _default_run_bob_amount
	camera_roll_amount = _default_camera_roll_amount
	camera_strafe_pitch_amount = _default_camera_strafe_pitch_amount
	camera_strafe_yaw_amount = _default_camera_strafe_yaw_amount
	camera_look_inertia = _default_camera_look_inertia
	landing_camera_dip = _default_landing_camera_dip
	wall_jump_camera_kick = _default_wall_jump_camera_kick
	weapon_sway_amount = _default_weapon_sway_amount
	weapon_rotation_sway_amount = _default_weapon_rotation_sway_amount
	weapon_movement_sway_amount = _default_weapon_movement_sway_amount
	weapon_jump_drop = _default_weapon_jump_drop
	weapon_landing_kick = _default_weapon_landing_kick


func _scale_camera_motion(scale: float) -> void:
	camera_motion_enabled = _default_camera_motion_enabled
	idle_breath_amount = _default_idle_breath_amount * scale
	walk_bob_amount = _default_walk_bob_amount * scale
	run_bob_amount = _default_run_bob_amount * scale
	camera_roll_amount = _default_camera_roll_amount * scale
	camera_strafe_pitch_amount = _default_camera_strafe_pitch_amount * scale
	camera_strafe_yaw_amount = _default_camera_strafe_yaw_amount * scale
	camera_look_inertia = _default_camera_look_inertia * scale
	landing_camera_dip = _default_landing_camera_dip * scale
	wall_jump_camera_kick = _default_wall_jump_camera_kick * scale


func _scale_weapon_motion(scale: float) -> void:
	weapon_motion_enabled = _default_weapon_motion_enabled
	weapon_sway_amount = _default_weapon_sway_amount * scale
	weapon_rotation_sway_amount = _default_weapon_rotation_sway_amount * scale
	weapon_movement_sway_amount = _default_weapon_movement_sway_amount * scale
	weapon_jump_drop = _default_weapon_jump_drop * scale
	weapon_landing_kick = _default_weapon_landing_kick * scale


func warmup_gameplay_resources(scene_root: Node, bullet_pool_size: int = 8, decal_pool_size: int = 8) -> void:
	if scene_root == null:
		return
	for weapon_node in _weapons:
		if weapon_node == null:
			continue
		if weapon_node.has_method("warmup_runtime_effects"):
			weapon_node.call("warmup_runtime_effects", scene_root, bullet_pool_size, decal_pool_size)


func get_active_weapon_index() -> int:
	return _active_weapon_index


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
	if _viewmodel_fill_light != null:
		_viewmodel_fill_light.visible = value
	_update_body_visibility()
	_update_first_person_weapon_visibility()
	_update_third_person_weapon_visibility()
	set_gameplay_input_enabled(value)


func respawn_at(spawn_position: Vector3, yaw_radians: float = 0.0) -> void:
	cancel_kill_cam()
	respawn_generation += 1
	global_position = _snap_spawn_position(spawn_position)
	rotation.y = yaw_radians
	velocity = Vector3.ZERO
	_pitch_degrees = 0.0
	camera_pivot.rotation_degrees.x = 0.0
	camera_pivot.position = _standing_camera_pivot_position
	camera.position = Vector3.ZERO
	camera.rotation_degrees = Vector3.ZERO
	_restore_first_person_camera()
	set_dead(false)
	last_damage_source_player_id = 0
	last_killer_position = Vector3.ZERO
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
	_weapon_motion.reset(rotation.y, _pitch_degrees)
	_body_visual_controller.reset_motion()
	_previous_camera_yaw = rotation.y
	_breath_time = 0.0
	_bob_blend = 0.0
	_smoothed_bob_offset = Vector3.ZERO
	_smoothed_strafe_factor = 0.0
	_smoothed_motion_speed = 0.0
	_camera_pitch_inertia = 0.0
	_camera_yaw_inertia = 0.0
	_camera_roll = 0.0
	_recoil_pitch_offset = 0.0
	_last_view_delta = Vector2.ZERO
	_hud_motion_strafe = 0.0
	_hud_motion_forward = 0.0
	_hud_motion_look = Vector2.ZERO
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
	damage_source_player_id: int = 0,
	network_respawn_generation: int = -1
) -> void:
	if health == null:
		return
	if network_respawn_generation >= 0 and network_respawn_generation < respawn_generation:
		return
	if (
		is_dead_state
		and _is_locally_controlled()
		and not _is_dead
		and current_health > 0
	):
		return

	health.max_health = maxi(max_health, 1)
	health.current_health = clampi(current_health, 0, health.max_health)
	health.is_dead = is_dead_state
	last_damage_source_player_id = damage_source_player_id
	if _is_dead != is_dead_state:
		set_dead(is_dead_state)
	health.health_changed.emit(health.current_health, health.max_health)


func apply_network_combat_state(active_weapon_index: int, is_aiming_state: bool) -> void:
	_network_target_active_weapon_index = clampi(active_weapon_index, 0, maxi(_weapons.size() - 1, 0))
	_network_target_is_aiming = is_aiming_state and not _is_dead
	if _is_locally_controlled():
		return

	_set_active_weapon(_network_target_active_weapon_index)
	_is_aiming = _network_target_is_aiming
	if weapon != null:
		weapon.is_aiming = _is_aiming
	_update_third_person_weapon_visibility()


func set_dead(value: bool) -> void:
	_is_dead = value
	_is_aiming = false
	_aim_blend = 0.0
	if weapon != null:
		weapon.is_aiming = false
	velocity = Vector3.ZERO
	if collision_shape != null:
		collision_shape.disabled = value
	_update_body_visibility()
	if _is_locally_controlled():
		_update_first_person_weapon_visibility()


func get_body_color() -> Color:
	return _body_color


func cancel_kill_cam() -> void:
	_kill_cam_active = false
	if _kill_cam_pcam != null:
		_kill_cam_pcam.set_priority(0)
		_kill_cam_pcam.visible = false
		_kill_cam_pcam.follow_target = null
	if _phantom_camera_host != null:
		_phantom_camera_host.process_mode = Node.PROCESS_MODE_DISABLED
	_restore_first_person_camera()
	_update_first_person_weapon_visibility()


func set_cinematic_view_active(active: bool) -> void:
	if active:
		cancel_kill_cam()
		_cinematic_view_active = true
		for weapon_node in _weapons:
			if weapon_node != null:
				weapon_node.visible = false
		if _viewmodel_fill_light != null:
			_viewmodel_fill_light.visible = false
	else:
		_cinematic_view_active = false
		cancel_kill_cam()
		_update_first_person_weapon_visibility()


func restore_match_control() -> void:
	cancel_kill_cam()
	set_cinematic_view_active(false)
	set_dead(false)
	set_gameplay_input_enabled(true)
	if _is_locally_controlled():
		_restore_first_person_camera()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _snap_spawn_position(spawn_position: Vector3) -> Vector3:
	var snapped_position: Vector3 = spawn_position
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	if space_state == null:
		return snapped_position

	var query := PhysicsRayQueryParameters3D.create(
		spawn_position + Vector3.UP * 4.0,
		spawn_position + Vector3.DOWN * 8.0
	)
	query.exclude = [self]
	query.hit_back_faces = false
	var hit: Dictionary = space_state.intersect_ray(query)
	if not hit.is_empty():
		snapped_position.y = float(hit.position.y)
	return snapped_position


func set_body_color(color: Color) -> void:
	_body_color = color
	if body_mesh == null:
		return

	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_body_visual_controller.apply_body_material(body_visual if body_visual != null else body_mesh, material)


func _on_performance_profile_changed(profile: int) -> void:
	apply_performance_profile(int(profile))
#endregion


#region Movimiento, wall jump y crouch
func _handle_movement(delta: float) -> void:
	var was_on_floor_before_move: bool = is_on_floor()
	var input_direction: Vector2 = _get_move_input()
	_update_wall_jump_timers(delta, was_on_floor_before_move)
	var wall_normal: Vector3 = Vector3.ZERO
	var wants_jump: bool = Input.is_action_just_pressed(_action("jump"))
	if not was_on_floor_before_move or wants_jump:
		wall_normal = _find_wall_normal()
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

	if wants_jump:
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
	if (
		collision_shape == null
		or not (collision_shape.shape is CapsuleShape3D)
		or _standing_clearance_shape == null
		or _standing_clearance_query == null
	):
		return true

	_standing_clearance_shape.height = _standing_collision_height
	var clearance_position: Vector3 = _standing_collision_position + Vector3.UP * 0.04

	_standing_clearance_query.transform = global_transform * Transform3D(Basis.IDENTITY, clearance_position)
	_standing_clearance_query.exclude = [get_rid()]
	_standing_clearance_query.collision_mask = collision_mask

	var hits: Array[Dictionary] = get_world_3d().direct_space_state.intersect_shape(_standing_clearance_query, 1)
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
#endregion


#region Camaras de debug (tercera persona)
func _setup_debug_cameras() -> void:
	_third_back_pcam = get_node_or_null("ThirdPersonBackDebugPCam") as PhantomCamera3D
	_third_front_pcam = get_node_or_null("ThirdPersonFrontDebugPCam") as PhantomCamera3D
	_kill_cam_pcam = get_node_or_null("KillCamPCam") as PhantomCamera3D
	if _kill_cam_pcam != null:
		_kill_cam_pcam.visible = false
		_kill_cam_pcam.set_priority(0)
	if not debug_camera_enabled:
		_restore_first_person_camera()
		return
	if _third_back_pcam == null:
		return

	for pcam: PhantomCamera3D in [_third_back_pcam, _third_front_pcam]:
		if pcam == null:
			continue
		pcam.visible = false
		pcam.set_priority(_DEBUG_CAMERA_PRIORITY_INACTIVE)
		pcam.follow_damping = true

	_apply_debug_camera_mode()


func _cycle_debug_camera_mode() -> void:
	if not _is_locally_controlled() or _third_back_pcam == null:
		return

	_debug_camera_mode = ((_debug_camera_mode as int + 1) % DebugCameraMode.size()) as DebugCameraMode
	_apply_debug_camera_mode()


func _apply_debug_camera_mode() -> void:
	if not debug_camera_enabled or _third_back_pcam == null:
		_restore_first_person_camera()
		return

	match _debug_camera_mode:
		DebugCameraMode.FIRST_PERSON:
			_restore_first_person_camera()
		DebugCameraMode.THIRD_PERSON_BACK:
			_activate_debug_third_person_camera(_third_back_pcam, false)
		DebugCameraMode.THIRD_PERSON_FRONT:
			_activate_debug_third_person_camera(_third_front_pcam, true)

	_update_body_visibility()
	_update_first_person_weapon_visibility()
	_update_third_person_weapon_visibility()


func _restore_first_person_camera() -> void:
	if _third_back_pcam != null:
		_third_back_pcam.visible = false
		_third_back_pcam.set_priority(_DEBUG_CAMERA_PRIORITY_INACTIVE)
	if _third_front_pcam != null:
		_third_front_pcam.visible = false
		_third_front_pcam.set_priority(_DEBUG_CAMERA_PRIORITY_INACTIVE)

	if _phantom_camera_host != null:
		_phantom_camera_host.process_mode = Node.PROCESS_MODE_DISABLED

	if camera == null:
		return

	_third_person_camera_initialized = false
	camera.top_level = false
	camera.position = Vector3.ZERO
	camera.rotation = Vector3.ZERO
	camera.current = _is_locally_controlled()
	camera.reset_physics_interpolation()


func _ensure_first_person_camera_attached() -> void:
	if _cinematic_view_active or camera == null:
		return
	if not camera.top_level:
		return
	if _debug_camera_mode != DebugCameraMode.FIRST_PERSON:
		return
	_restore_first_person_camera()


func _activate_debug_third_person_camera(pcam: PhantomCamera3D, front: bool) -> void:
	if pcam == null:
		_restore_first_person_camera()
		return

	_restore_first_person_camera()
	pcam.visible = true
	_apply_debug_third_person_combat_settings(pcam)
	pcam.set_priority(_DEBUG_CAMERA_PRIORITY_ACTIVE)
	_sync_debug_third_person_rotation(pcam, front)

	if _phantom_camera_host != null:
		_phantom_camera_host.process_mode = Node.PROCESS_MODE_DISABLED
	camera.top_level = true
	camera.current = _is_locally_controlled()
	_third_person_camera_initialized = false


func _apply_debug_third_person_combat_settings(pcam: PhantomCamera3D) -> void:
	var aim_scale: float = lerpf(1.0, debug_third_person_aim_distance_scale, _aim_blend)
	var distance: float = debug_third_person_distance * aim_scale
	var shoulder_offset: Vector3 = debug_third_person_shoulder_offset
	if _is_aiming:
		shoulder_offset.x *= 1.18
		shoulder_offset.y -= 0.04

	pcam.follow_distance = distance
	pcam.spring_length = distance
	pcam.follow_offset = shoulder_offset


func _update_debug_cameras() -> void:
	if not debug_camera_enabled or not _is_locally_controlled() or _third_back_pcam == null:
		return

	if _debug_camera_mode == DebugCameraMode.FIRST_PERSON:
		return

	var active_pcam: PhantomCamera3D = _third_back_pcam
	var is_front: bool = false
	if _debug_camera_mode == DebugCameraMode.THIRD_PERSON_FRONT and _third_front_pcam != null:
		active_pcam = _third_front_pcam
		is_front = true

	_apply_debug_third_person_combat_settings(active_pcam)
	_sync_debug_third_person_rotation(active_pcam, is_front)
	_update_manual_third_person_camera(get_process_delta_time(), is_front)


func _sync_debug_third_person_rotation(pcam: PhantomCamera3D, front: bool) -> void:
	var yaw_offset: float = 180.0 if front else 0.0
	pcam.set_third_person_rotation_degrees(Vector3(_pitch_degrees, yaw_offset, 0.0))


func _is_debug_first_person_view() -> bool:
	return not debug_camera_enabled or _debug_camera_mode == DebugCameraMode.FIRST_PERSON


func _update_manual_third_person_camera(delta: float, front: bool) -> void:
	if camera == null:
		return

	var aim_scale: float = lerpf(1.0, debug_third_person_aim_distance_scale, _aim_blend)
	var distance: float = debug_third_person_distance * aim_scale
	var shoulder_offset: Vector3 = debug_third_person_shoulder_offset
	if _is_aiming:
		shoulder_offset.x *= 1.18
		shoulder_offset.y -= 0.04

	var yaw_basis := Basis(Vector3.UP, rotation.y)
	var target_position: Vector3 = global_position + Vector3.UP * third_person_target_height
	target_position += yaw_basis.x * shoulder_offset.x
	target_position += Vector3.UP * shoulder_offset.y

	var pitch_radians: float = deg_to_rad(clampf(_pitch_degrees, -72.0, 72.0))
	var horizontal_distance: float = cos(pitch_radians) * distance
	var vertical_distance: float = sin(pitch_radians) * distance
	var view_sign: float = -1.0 if front else 1.0
	var camera_direction: Vector3 = (yaw_basis.z * view_sign * horizontal_distance) + Vector3.UP * vertical_distance
	var desired_position: Vector3 = target_position + camera_direction
	var solved_position: Vector3 = _solve_third_person_camera_collision(target_position, desired_position)
	var follow_weight: float = 1.0 if not _third_person_camera_initialized else 1.0 - exp(-third_person_follow_smoothing * delta)
	_third_person_camera_position = _third_person_camera_position.lerp(solved_position, follow_weight)
	_third_person_camera_initialized = true

	camera.global_position = _third_person_camera_position
	camera.look_at(target_position, Vector3.UP)
	camera.rotate_object_local(Vector3.RIGHT, deg_to_rad(_recoil_pitch_offset))


func _solve_third_person_camera_collision(target_position: Vector3, desired_position: Vector3) -> Vector3:
	if get_world_3d() == null:
		return desired_position

	var target_to_camera: Vector3 = desired_position - target_position
	var desired_distance: float = target_to_camera.length()
	if desired_distance <= third_person_min_distance:
		return desired_position

	var query := PhysicsRayQueryParameters3D.create(target_position, desired_position)
	query.exclude = [get_rid()]
	query.collision_mask = collision_mask
	query.hit_from_inside = false

	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return desired_position

	var hit_position: Vector3 = hit.get("position", desired_position)
	var direction: Vector3 = target_to_camera / desired_distance
	var corrected_distance: float = clampf(
		target_position.distance_to(hit_position) - third_person_collision_margin,
		third_person_min_distance,
		desired_distance
	)
	return target_position + direction * corrected_distance
#endregion


#region Camara inmersiva (bob, tilt, inercia)
func _update_camera_motion(delta: float) -> void:
	if camera_pivot == null or camera == null or not _is_debug_first_person_view():
		return

	var crouch_offset: float = crouch_camera_drop * _crouch_blend

	if camera_motion_enabled:
		var motion_intensity: float = lerpf(1.0, camera_aim_motion_multiplier, _aim_blend)
		var blend_weight: float = 1.0 - exp(-bob_blend_speed * delta)
		var is_on_ground: bool = is_on_floor() and _gameplay_input_enabled and not _is_dead
		_update_bob_offset(delta, blend_weight, is_on_ground, motion_intensity)
		var strafe_tilt: Vector2 = _update_camera_tilt(delta, blend_weight, is_on_ground, motion_intensity)
		_update_look_inertia(delta)

		camera.rotation_degrees = Vector3(
			_camera_pitch_inertia + strafe_tilt.x + _recoil_pitch_offset,
			_camera_yaw_inertia + strafe_tilt.y,
			_camera_roll
		)
	else:
		_bob_blend = 0.0
		_smoothed_bob_offset = Vector3.ZERO
		_smoothed_motion_speed = 0.0
		camera.rotation_degrees = Vector3(_recoil_pitch_offset, 0.0, 0.0)

	_landing_offset = move_toward(_landing_offset, 0.0, delta * 0.45)
	_wall_jump_camera_kick_offset = _wall_jump_camera_kick_offset.move_toward(Vector3.ZERO, delta * maxf(wall_jump_camera_kick * 12.0, 0.05))
	camera_pivot.position = _standing_camera_pivot_position + _smoothed_bob_offset + _wall_jump_camera_kick_offset - Vector3(0.0, crouch_offset + _landing_offset, 0.0)


func _update_bob_offset(delta: float, blend_weight: float, is_on_ground: bool, motion_intensity: float) -> void:
	var horizontal_speed: float = _get_horizontal_speed()
	var is_running: bool = Input.is_action_pressed(_action("sprint")) and not _is_crouching and horizontal_speed > walk_speed + 0.25
	var target_bob_offset := Vector3.ZERO

	var target_motion_speed: float = horizontal_speed if is_on_ground else 0.0
	_smoothed_motion_speed = lerpf(_smoothed_motion_speed, target_motion_speed, blend_weight)

	var speed_blend: float = clampf((_smoothed_motion_speed - 0.35) / maxf(walk_speed, 0.001), 0.0, 1.0)
	var target_bob_blend: float = speed_blend if is_on_ground else 0.0
	_bob_blend = lerpf(_bob_blend, target_bob_blend, blend_weight)

	var entry_blend: float = lerpf(bob_entry_floor, 1.0, _bob_blend)

	if _bob_blend > 0.01:
		var run_blend: float = clampf((_smoothed_motion_speed - walk_speed) / maxf(run_speed - walk_speed, 0.001), 0.0, 1.0)
		var stride_length: float = lerpf(walk_stride_length, run_stride_length, run_blend if is_running else run_blend * 0.65)
		var stride_frequency: float = (_smoothed_motion_speed / maxf(stride_length, 0.001)) * bob_frequency_scale
		_bob_time += delta * stride_frequency

		var bob_amount: float = lerpf(walk_bob_amount, run_bob_amount, run_blend) * motion_intensity * entry_blend
		var stride_wave: float = sin(_bob_time * TAU)
		target_bob_offset.y = stride_wave * bob_amount
		target_bob_offset.x = stride_wave * bob_amount * bob_lateral_ratio
		target_bob_offset.z = cos(_bob_time * TAU) * bob_amount * bob_forward_ratio
	elif is_on_ground:
		_breath_time += delta * idle_breath_frequency
		var breath_wave: float = sin(_breath_time * TAU)
		var breath_amount: float = idle_breath_amount * motion_intensity
		target_bob_offset.y = breath_wave * breath_amount
		target_bob_offset.x = sin(_breath_time * TAU * 0.5) * breath_amount * 0.35
		target_bob_offset.z = cos(_breath_time * TAU * 0.33) * breath_amount * 0.2

	var bob_follow_weight: float = lerpf(blend_weight, minf(blend_weight * 1.65, 1.0), _bob_blend)
	_smoothed_bob_offset = _smoothed_bob_offset.lerp(target_bob_offset, bob_follow_weight)


func _update_camera_tilt(delta: float, blend_weight: float, is_on_ground: bool, motion_intensity: float) -> Vector2:
	var local_velocity: Vector3 = global_transform.basis.inverse() * velocity
	var raw_strafe_factor: float = clampf(local_velocity.x / maxf(run_speed * 0.85, 0.001), -1.0, 1.0)
	_smoothed_strafe_factor = lerpf(_smoothed_strafe_factor, raw_strafe_factor, blend_weight)
	var tilt_strength: float = lerpf(0.45, 1.0, _bob_blend) * motion_intensity
	var target_roll: float = -_smoothed_strafe_factor * camera_roll_amount * tilt_strength
	var strafe_pitch: float = _smoothed_strafe_factor * camera_strafe_pitch_amount * tilt_strength
	var strafe_yaw: float = _smoothed_strafe_factor * camera_strafe_yaw_amount * tilt_strength
	if is_on_ground and _bob_blend < 0.05:
		target_roll += sin(_breath_time * TAU * 0.5) * idle_breath_roll_amount * motion_intensity
	var roll_weight: float = 1.0 - exp(-camera_look_return_speed * delta)
	_camera_roll = lerpf(_camera_roll, target_roll, roll_weight)
	return Vector2(strafe_pitch, strafe_yaw)


func _update_look_inertia(delta: float) -> void:
	var yaw_delta_degrees: float = rad_to_deg(wrapf(rotation.y - _previous_camera_yaw, -PI, PI))
	_previous_camera_yaw = rotation.y
	var look_kick := Vector2(
		_last_view_delta.y * camera_look_inertia * 0.07,
		-_last_view_delta.x * camera_look_inertia * 0.05 - yaw_delta_degrees * camera_look_inertia * 0.32
	)
	var return_weight: float = 1.0 - exp(-camera_look_return_speed * delta)
	_camera_pitch_inertia = lerpf(_camera_pitch_inertia + look_kick.x, 0.0, return_weight)
	_camera_yaw_inertia = lerpf(_camera_yaw_inertia + look_kick.y, 0.0, return_weight)
	_camera_pitch_inertia = clampf(_camera_pitch_inertia, -2.6, 2.6)
	_camera_yaw_inertia = clampf(_camera_yaw_inertia, -2.2, 2.2)


func _get_horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func get_hud_motion_sample() -> Dictionary:
	return {
		"strafe": _hud_motion_strafe,
		"forward": _hud_motion_forward,
		"look": _hud_motion_look,
	}


func _update_hud_motion_sample(delta: float) -> void:
	var decay_weight: float = 1.0 - exp(-14.0 * delta)
	if not _is_locally_controlled() or _is_dead or not _gameplay_input_enabled:
		_hud_motion_strafe = lerpf(_hud_motion_strafe, 0.0, decay_weight)
		_hud_motion_forward = lerpf(_hud_motion_forward, 0.0, decay_weight)
		_hud_motion_look = _hud_motion_look.lerp(Vector2.ZERO, decay_weight)
		return

	var blend_weight: float = 1.0 - exp(-12.0 * delta)
	var local_velocity: Vector3 = global_transform.basis.inverse() * velocity
	var max_speed: float = maxf(run_speed, 0.001)
	var on_ground: bool = is_on_floor()
	var target_strafe: float = clampf(local_velocity.x / max_speed, -1.0, 1.0) if on_ground else 0.0
	var target_forward: float = clampf(-local_velocity.z / max_speed, -1.0, 1.0) if on_ground else 0.0
	_hud_motion_strafe = lerpf(_hud_motion_strafe, target_strafe, blend_weight)
	_hud_motion_forward = lerpf(_hud_motion_forward, target_forward, blend_weight)

	var yaw_delta_degrees: float = rad_to_deg(wrapf(rotation.y - _prev_hud_sample_yaw, -PI, PI))
	var pitch_delta_degrees: float = _pitch_degrees - _prev_hud_sample_pitch
	_prev_hud_sample_yaw = rotation.y
	_prev_hud_sample_pitch = _pitch_degrees
	if absf(yaw_delta_degrees) > 0.001 or absf(pitch_delta_degrees) > 0.001:
		_hud_motion_look += Vector2(-yaw_delta_degrees, pitch_delta_degrees)

	var look_decay: float = 1.0 - exp(-13.0 * delta)
	_hud_motion_look = _hud_motion_look.lerp(Vector2.ZERO, look_decay)
#endregion


#region Input de armas y mira de gamepad
func _handle_weapon_input() -> void:
	if Input.is_action_just_pressed(_action("weapon_1")):
		_set_active_weapon(0)
	if Input.is_action_just_pressed(_action("weapon_2")):
		_set_active_weapon(1)
	if Input.is_action_just_pressed(_action("weapon_3")):
		_set_active_weapon(2)
	if Input.is_action_just_pressed(_action("weapon_4")):
		_set_active_weapon(3)
	if Input.is_action_just_pressed(_action("weapon_5")):
		_set_active_weapon(4)

	if _weapons.size() > 1:
		if Input.is_action_just_pressed(_action("weapon_next")):
			_set_active_weapon((_active_weapon_index + 1) % _weapons.size())
		if Input.is_action_just_pressed(_action("weapon_prev")):
			_set_active_weapon((_active_weapon_index - 1 + _weapons.size()) % _weapons.size())

	if weapon == null:
		return

	if Input.is_action_pressed(_action("fire")):
		weapon.try_fire(camera)
	if Input.is_action_just_pressed(_action("reload")):
		weapon.reload()


func _handle_gamepad_look(delta: float) -> void:
	if not _gameplay_input_enabled:
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
#endregion


#region Caches de armas, esqueleto y pose
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
	_standing_clearance_shape = CapsuleShape3D.new()
	_standing_clearance_shape.radius = capsule_shape.radius
	_standing_clearance_shape.height = _standing_collision_height
	_standing_clearance_query = PhysicsShapeQueryParameters3D.new()
	_standing_clearance_query.shape = _standing_clearance_shape
	_standing_clearance_query.margin = 0.0
#endregion


#region Visual de cuerpo en tercera persona
func _update_body_visibility() -> void:
	_body_visual_controller.update_body_visibility(self)


func _update_first_person_weapon_visibility() -> void:
	_body_visual_controller.update_first_person_weapon_visibility(self, _weapons, _active_weapon_index, _viewmodel_fill_light)


func _update_third_person_weapon_visibility() -> void:
	_body_visual_controller.update_third_person_weapon_visibility(self)


func _should_update_third_person_visual() -> bool:
	return _body_visual_controller.should_update_third_person_visual(self)


func _update_third_person_visual(delta: float) -> void:
	_body_visual_controller.update_third_person_visual(self, delta)
#endregion


#region Arma activa, aim y weapon sway
func _set_active_weapon(index: int) -> void:
	if index < 0 or index >= _weapons.size() or index == _active_weapon_index:
		return

	if weapon != null and weapon.fired.is_connected(_on_weapon_fired):
		weapon.fired.disconnect(_on_weapon_fired)
		weapon.is_aiming = false
		if _weapon_default_transforms.has(weapon):
			weapon.transform = _weapon_default_transforms[weapon]

	_aim_blend = 0.0
	_weapon_motion.reset(rotation.y, _pitch_degrees)
	_previous_camera_yaw = rotation.y
	_active_weapon_index = index
	weapon = _weapons[index]
	_update_first_person_weapon_visibility()
	_update_third_person_weapon_visibility()

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
	var motion_transform: Transform3D = _weapon_motion.apply_motion(self, weapon, base_transform, delta)
	weapon.transform = _weapon_motion.align_muzzle_lateral_to_crosshair(self, motion_transform, weapon)


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


#endregion


#region Recoil, daño, muerte y red
func _on_weapon_fired(fired_weapon: WeaponBase) -> void:
	if fired_weapon == null:
		return

	# Un solo tween de recoil activo; con cadencia alta evitamos apilar decenas de tweens.
	if _recoil_tween != null and _recoil_tween.is_valid():
		_recoil_tween.kill()
	_recoil_pitch_offset = -fired_weapon.recoil_degrees
	_recoil_tween = create_tween()
	_recoil_tween.tween_method(_set_recoil_pitch_offset, _recoil_pitch_offset, 0.0, 0.11)
	weapon_fired.emit(fired_weapon.weapon_name)


func _set_recoil_pitch_offset(value: float) -> void:
	_recoil_pitch_offset = value
	if camera != null:
		camera.rotation_degrees.x = _camera_pitch_inertia + _recoil_pitch_offset


func _on_health_died() -> void:
	set_dead(true)
	_shake_camera(0.2, 0.25)
	died.emit()


func _shake_camera(strength: float, duration: float) -> void:
	if not _is_locally_controlled():
		return

	# Si hay un shake en curso lo cortamos y volvemos al origen real para no acumular deriva.
	if _camera_shake_tween != null and _camera_shake_tween.is_valid():
		_camera_shake_tween.kill()
		camera.position = _camera_shake_origin
	else:
		_camera_shake_origin = camera.position

	_camera_shake_tween = create_tween()
	_camera_shake_tween.tween_property(camera, "position", _camera_shake_origin + Vector3(randf_range(-strength, strength), randf_range(-strength, strength), 0.0), duration * 0.35)
	_camera_shake_tween.tween_property(camera, "position", _camera_shake_origin, duration * 0.65)


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

	# Token para que un timer viejo (de un respawn anterior) no corte la invulnerabilidad nueva.
	_respawn_invulnerability_token += 1
	var token: int = _respawn_invulnerability_token
	await get_tree().create_timer(respawn_invulnerability_time).timeout
	if token == _respawn_invulnerability_token:
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
#endregion
