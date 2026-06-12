class_name PickupBase
extends Area3D

signal availability_changed(pickup_id: int, is_available: bool)

const OUTLINE_SHADER: Shader = preload("res://shaders/pickup_outline.gdshader")

@export_range(0.1, 120.0) var respawn_time: float = 15.0
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


func _ready() -> void:
	_audio_player = AudioStreamPlayer3D.new()
	_audio_player.name = "PickupAudio"
	add_child(_audio_player)
	body_entered.connect(_on_body_entered)

	if visual_root != null:
		_visual_rest_y = visual_root.position.y

	_setup_pickup_glow_light()
	_setup_pickup_outlines()
	_pulse_time = randf() * TAU

	if PlayerSettings != null and not PlayerSettings.settings_changed.is_connected(_update_accent_color):
		PlayerSettings.settings_changed.connect(_update_accent_color)
	if PlayerSettings != null:
		if not PlayerSettings.performance_profile_changed.is_connected(_on_performance_profile_changed):
			PlayerSettings.performance_profile_changed.connect(_on_performance_profile_changed)
		apply_performance_profile(int(PlayerSettings.performance_profile))


func _process(delta: float) -> void:
	if not _is_available:
		return

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


func set_pickup_id(next_pickup_id: int) -> void:
	pickup_id = next_pickup_id


func is_available() -> bool:
	return _is_available


func apply_performance_profile(profile: int) -> void:
	var safe_profile := clampi(profile, 0, 2)
	match safe_profile:
		PlayerSettings.PerformanceProfile.LOW:
			_presentation_update_hz = 20.0
			_dynamic_glow_enabled = true
		PlayerSettings.PerformanceProfile.ULTRA_LOW:
			_presentation_update_hz = 10.0
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


func _on_body_entered(body: Node3D) -> void:
	if not _is_available or not (body is PlayerController):
		return

	var player: PlayerController = body as PlayerController
	if collect_for_player(player):
		_request_network_pickup(player)


func _disable_temporarily() -> void:
	_set_available(false, true)

	await get_tree().create_timer(respawn_time).timeout

	_set_available(true, true)


func _set_available(is_next_available: bool, should_emit_signal: bool) -> void:
	_is_available = is_next_available
	visible = is_next_available
	set_process(is_next_available)
	set_deferred("monitoring", is_next_available)
	if collision_shape != null:
		collision_shape.set_deferred("disabled", not is_next_available)
	_update_pickup_glow_visibility()
	if should_emit_signal:
		availability_changed.emit(pickup_id, _is_available)


func _request_network_pickup(player: PlayerController) -> void:
	if player == null or pickup_id < 0:
		return

	var scene_root: Node = get_tree().current_scene
	if scene_root == null or not scene_root.has_method("request_network_pickup"):
		return
	scene_root.call("request_network_pickup", pickup_id, player.player_id)


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
