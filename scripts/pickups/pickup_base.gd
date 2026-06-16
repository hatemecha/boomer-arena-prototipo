class_name PickupBase
extends Area3D

signal availability_changed(pickup_id: int, is_available: bool)

const PlayerSettingsAccess = preload("res://scripts/game/player_settings_access.gd")
const OUTLINE_SHADER: Shader = preload("res://shaders/pickup_outline.gdshader")

@export_range(0.1, 120.0) var respawn_time: float = 15.0
@export_range(0.1, 10.0, 0.1) var hold_to_collect_time: float = 1.5
@export_range(1.0, 8.0, 0.1) var hold_release_decay_multiplier: float = 2.0
@export_range(0.75, 5.0, 0.05) var server_collect_max_distance: float = 3.25
@export_range(0.0, 10.0) var rotation_speed: float = 2.5
@export_range(0.005, 0.08, 0.001) var outline_width: float = 0.03
@export_range(0.5, 3.0, 0.05) var outline_brightness_min: float = 1.05
@export_range(0.5, 3.0, 0.05) var outline_brightness_max: float = 1.65
@export_range(0.0, 1.0, 0.01) var glow_light_energy_min: float = 0.18
@export_range(0.0, 1.0, 0.01) var glow_light_energy_max: float = 0.42
@export_range(0.5, 4.0, 0.1) var glow_light_range: float = 2.4
@export_range(0.0, 0.2, 0.005) var bob_height: float = 0.07
@export_range(0.5, 6.0, 0.1) var pulse_speed: float = 2.8
@export var pickup_sound: AudioStream

@onready var visual_root: Node3D = $VisualRoot
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var pickup_id: int = -1

var _is_available: bool = true
var _audio_player: AudioStreamPlayer3D
var _outline_material: ShaderMaterial
var _glow_light: OmniLight3D
var _visual_rest_y: float = 0.0
var _pulse_time: float = 0.0
var _presentation_update_hz: float = 60.0
var _presentation_accumulator: float = 0.0
var _dynamic_glow_enabled: bool = true
var _near_players: Array[PlayerController] = []
var _active_player: PlayerController
var _hold_progress: float = 0.0


func _ready() -> void:
	_audio_player = AudioStreamPlayer3D.new()
	_audio_player.name = "PickupAudio"
	add_child(_audio_player)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	if visual_root != null:
		_visual_rest_y = visual_root.position.y

	_setup_pickup_glow_light()
	_setup_pickup_outlines()
	_pulse_time = randf() * TAU

	if PlayerSettingsAccess.has_settings():
		PlayerSettingsAccess.connect_settings_changed(_update_accent_color)
		PlayerSettingsAccess.connect_performance_profile_changed(_on_performance_profile_changed)
		apply_performance_profile(PlayerSettingsAccess.get_performance_profile())


func _process(delta: float) -> void:
	if not _is_available:
		return

	_update_hold_interaction(delta)

	var step_delta: float = delta
	if _presentation_update_hz > 0.0 and _presentation_update_hz < 59.0:
		_presentation_accumulator += delta
		var interval: float = 1.0 / _presentation_update_hz
		if _presentation_accumulator < interval:
			return
		step_delta = _presentation_accumulator
		_presentation_accumulator = 0.0

	_pulse_time += step_delta * pulse_speed
	var pulse := 0.5 + 0.5 * sin(_pulse_time)

	if visual_root != null:
		visual_root.rotate_y(rotation_speed * step_delta)
		visual_root.position.y = _visual_rest_y + bob_height * pulse

	_update_pickup_presentation(pulse)


func apply_to_player(_player: PlayerController) -> bool:
	push_warning("PickupBase.apply_to_player must be overridden.")
	return false


func can_apply_to_player(_player: PlayerController) -> bool:
	return true


func get_interaction_prompt(_player: PlayerController) -> String:
	return "MANTENER E"


func set_pickup_id(next_pickup_id: int) -> void:
	pickup_id = next_pickup_id


func is_available() -> bool:
	return _is_available


func can_player_collect_now(player: PlayerController) -> bool:
	if not _is_available or player == null:
		return false
	if player.health != null and player.health.is_dead:
		return false
	return global_position.distance_to(player.global_position) <= server_collect_max_distance


func apply_performance_profile(profile: int) -> void:
	var safe_profile := clampi(profile, 0, 2)
	match safe_profile:
		PlayerSettingsAccess.PERFORMANCE_PROFILE_LOW:
			_presentation_update_hz = 15.0
			_dynamic_glow_enabled = false
		PlayerSettingsAccess.PERFORMANCE_PROFILE_ULTRA_LOW:
			_presentation_update_hz = 8.0
			_dynamic_glow_enabled = false
		_:
			_presentation_update_hz = 60.0
			_dynamic_glow_enabled = true
	_update_pickup_glow_visibility()


func collect_for_player(player: PlayerController) -> bool:
	if not _is_available or player == null:
		return false

	if not apply_to_player(player):
		return false

	_play_pickup_sound()
	_disable_temporarily()
	return true


func set_network_available(is_next_available: bool) -> void:
	_set_available(is_next_available, false)


func apply_confirmed_network_collect(player: PlayerController) -> bool:
	if player == null:
		return false

	var was_applied: bool = apply_to_player(player)
	_play_pickup_sound()
	_set_available(false, false)
	return was_applied


func _on_body_entered(body: Node3D) -> void:
	if not _is_available or not (body is PlayerController):
		return

	var player: PlayerController = body as PlayerController
	if not _near_players.has(player):
		_near_players.append(player)


func _on_body_exited(body: Node3D) -> void:
	var player: PlayerController = body as PlayerController
	if player == null:
		return

	_near_players.erase(player)
	if _active_player == player:
		_clear_player_pickup_interaction(_active_player)
		_active_player = null
		_hold_progress = 0.0


func _update_hold_interaction(delta: float) -> void:
	_sync_overlapping_players()
	var candidate := _select_interacting_player()
	var can_apply: bool = candidate != null and can_apply_to_player(candidate)
	var is_holding: bool = can_apply and candidate.is_interact_pressed()
	if candidate != null:
		_active_player = candidate
	elif _hold_progress <= 0.0:
		_clear_player_pickup_interaction(_active_player)
		_active_player = null

	if is_holding:
		_hold_progress = minf(_hold_progress + delta / hold_to_collect_time, 1.0)
	elif _hold_progress > 0.0:
		_hold_progress = maxf(_hold_progress - (delta * hold_release_decay_multiplier) / hold_to_collect_time, 0.0)

	_update_pickup_interaction_hud(can_apply)

	if _hold_progress < 1.0 or _active_player == null:
		return

	var collector := _active_player
	_hold_progress = 0.0
	_active_player = null
	_clear_player_pickup_interaction(collector)
	if _request_network_pickup(collector):
		return
	collect_for_player(collector)


func _select_interacting_player() -> PlayerController:
	_prune_invalid_players()
	if _near_players.is_empty():
		return null

	if _active_player != null and _near_players.has(_active_player) and _can_drive_pickup_hold(_active_player):
		return _active_player

	for player in _near_players:
		if _can_drive_pickup_hold(player):
			return player

	return null


func _sync_overlapping_players() -> void:
	var overlapping_players: Array[PlayerController] = []
	for body in get_overlapping_bodies():
		var player: PlayerController = body as PlayerController
		if player == null:
			continue
		overlapping_players.append(player)
		if not _near_players.has(player):
			_near_players.append(player)

	for index in range(_near_players.size() - 1, -1, -1):
		var player: PlayerController = _near_players[index]
		if player == null or not is_instance_valid(player) or not overlapping_players.has(player):
			_near_players.remove_at(index)
			if _active_player == player:
				_clear_player_pickup_interaction(_active_player)
				_active_player = null
				_hold_progress = 0.0


func _can_drive_pickup_hold(player: PlayerController) -> bool:
	return player != null and player.is_local_controlled() and player.is_alive()


func _prune_invalid_players() -> void:
	for index in range(_near_players.size() - 1, -1, -1):
		var player: PlayerController = _near_players[index]
		if player == null or not is_instance_valid(player):
			_near_players.remove_at(index)


func _update_pickup_interaction_hud(can_apply: bool) -> void:
	if _active_player == null:
		return
	_active_player.set_pickup_interaction(get_interaction_prompt(_active_player), _hold_progress, true, can_apply)


func _clear_player_pickup_interaction(player: PlayerController) -> void:
	if player == null:
		return
	player.set_pickup_interaction("", 0.0, false, false)


func _disable_temporarily() -> void:
	_set_available(false, true)

	await get_tree().create_timer(respawn_time).timeout

	_set_available(true, true)


func _set_available(is_next_available: bool, should_emit_signal: bool) -> void:
	_is_available = is_next_available
	visible = is_next_available
	set_process(is_next_available)
	set_deferred("monitoring", is_next_available)
	if not is_next_available:
		_near_players.clear()
		_clear_player_pickup_interaction(_active_player)
		_active_player = null
		_hold_progress = 0.0
	if collision_shape != null:
		collision_shape.set_deferred("disabled", not is_next_available)
	_update_pickup_glow_visibility()
	if should_emit_signal:
		availability_changed.emit(pickup_id, _is_available)


func _request_network_pickup(player: PlayerController) -> bool:
	if player == null or pickup_id < 0:
		return false

	var scene_root: Node = get_tree().current_scene
	if scene_root == null or not scene_root.has_method("request_network_pickup"):
		return false
	return bool(scene_root.call("request_network_pickup", pickup_id, player.player_id))


func _play_pickup_sound() -> void:
	if pickup_sound == null or _audio_player == null:
		return
	_audio_player.stream = pickup_sound
	_audio_player.play()


func _setup_pickup_glow_light() -> void:
	if visual_root == null:
		return

	_glow_light = OmniLight3D.new()
	_glow_light.name = "PickupGlow"
	_glow_light.shadow_enabled = false
	_glow_light.omni_range = glow_light_range
	_glow_light.light_indirect_energy = 0.0
	_glow_light.position = Vector3(0.0, 0.35, 0.0)
	visual_root.add_child(_glow_light)
	_update_accent_color()


func _setup_pickup_outlines() -> void:
	if visual_root == null:
		return

	_outline_material = ShaderMaterial.new()
	_outline_material.shader = OUTLINE_SHADER
	_update_accent_color()
	_apply_outlines_recursive(visual_root)


func _apply_outlines_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance.mesh != null and mesh_instance.name != "PickupOutline":
			var outline := MeshInstance3D.new()
			outline.name = "PickupOutline"
			outline.mesh = mesh_instance.mesh
			outline.material_override = _outline_material
			outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mesh_instance.add_child(outline)

	for child: Node in node.get_children():
		if child.name == "PickupOutline":
			continue
		_apply_outlines_recursive(child)


func _update_pickup_presentation(pulse: float) -> void:
	if _outline_material != null:
		_outline_material.set_shader_parameter(
			"outline_brightness",
			lerpf(outline_brightness_min, outline_brightness_max, pulse)
		)
	if _glow_light != null and _dynamic_glow_enabled:
		_glow_light.light_energy = lerpf(glow_light_energy_min, glow_light_energy_max, pulse)


func _update_accent_color() -> void:
	var accent: Color = HudIcons.get_accent_color()
	if _outline_material != null:
		_outline_material.set_shader_parameter("outline_color", accent)
		_outline_material.set_shader_parameter("outline_width", outline_width)
	if _glow_light != null:
		_glow_light.light_color = accent


func _update_pickup_glow_visibility() -> void:
	if _glow_light == null:
		return
	_glow_light.visible = _is_available and _dynamic_glow_enabled


func _on_performance_profile_changed(profile: int) -> void:
	apply_performance_profile(profile)
