class_name MusicStereo
extends Node3D

signal track_changed(title: String, artist: String, cover: Texture2D, is_playing: bool)
signal proximity_changed(is_near: bool)
signal playback_toggle_requested
signal next_track_requested
signal interaction_hint_changed(text: String, is_visible: bool)

const WAREHOUSE_BUS_NAME: StringName = &"WarehouseMusic"

@export var track_titles: PackedStringArray = ["Ulterior Motives - 1985 AOP Mix", "Funkytown"]
@export var track_artists: PackedStringArray = ["Who's Who; Christopher Saint", "Lipps Inc."]
@export var track_stream_paths: PackedStringArray = [
	"res://assets/music/ulterior_motives_1985_aop_mix.ogg",
	"res://assets/music/funkytown_lipps_inc.ogg",
]
@export var track_cover_paths: PackedStringArray = [
	"res://assets/music/covers/ulterior_motives.jpg",
	"res://assets/music/covers/funkytown_lipps_inc.jpg",
]
@export var track_bpms: PackedFloat32Array = [124.0, 122.0]
@export var track_beat_offsets: PackedFloat32Array = [0.0, 0.0]
@export_range(0.0, 1.5) var start_volume: float = 1.0
@export_range(0.5, 6.0) var model_scale: float = 2.5
@export_range(1.0, 8.0) var interaction_range: float = 4.0

@onready var player_3d: AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var body: StaticBody3D = $Body
@onready var body_shape: CollisionShape3D = $Body/CollisionShape3D
@onready var model: Node3D = $Model

var _track_index: int = 0
var _near_local_players: Array[PlayerController] = []
var _track_streams: Array[AudioStream] = []
var _track_covers: Array[Texture2D] = []
var _is_hovered: bool = false


func _ready() -> void:
	DefaultInputActions.ensure_default_actions()
	_ensure_warehouse_audio_bus()
	player_3d.bus = WAREHOUSE_BUS_NAME
	player_3d.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
	player_3d.panning_strength = 0.45
	player_3d.volume_db = linear_to_db(start_volume)
	call_deferred("_setup_model")
	_load_playlist_resources()
	_apply_track(0, false)


func _process(_delta: float) -> void:
	_update_hover_state()


func _unhandled_input(event: InputEvent) -> void:
	if not _is_hovered:
		return

	if event.is_action_pressed("interact"):
		playback_toggle_requested.emit()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("music_next"):
		next_track_requested.emit()
		get_viewport().set_input_as_handled()


func toggle_playback() -> void:
	if player_3d.playing and not player_3d.stream_paused:
		player_3d.stream_paused = true
	elif player_3d.playing and player_3d.stream_paused:
		player_3d.stream_paused = false
	else:
		player_3d.play()
	_emit_track_state()


func next_track() -> void:
	if _track_streams.is_empty():
		return

	var should_play: bool = player_3d.playing and not player_3d.stream_paused
	_apply_track((_track_index + 1) % _track_streams.size(), should_play)


func get_current_title() -> String:
	return _get_title(_track_index)


func get_current_artist() -> String:
	return _get_artist(_track_index)


func get_current_cover() -> Texture2D:
	return _get_cover(_track_index)


func is_playing() -> bool:
	return player_3d.playing and not player_3d.stream_paused


func get_track_index() -> int:
	return _track_index


func get_playback_position() -> float:
	if player_3d == null or not player_3d.playing:
		return 0.0
	return player_3d.get_playback_position()


func get_bpm() -> float:
	if _track_index >= 0 and _track_index < track_bpms.size():
		return maxf(track_bpms[_track_index], 1.0)
	return 120.0


func get_beat_offset() -> float:
	if _track_index >= 0 and _track_index < track_beat_offsets.size():
		return track_beat_offsets[_track_index]
	return 0.0


func get_spectrum_instance() -> AudioEffectSpectrumAnalyzerInstance:
	var bus_index: int = AudioServer.get_bus_index(WAREHOUSE_BUS_NAME)
	if bus_index == -1:
		return null
	for effect_index in AudioServer.get_bus_effect_count(bus_index):
		var instance = AudioServer.get_bus_effect_instance(bus_index, effect_index)
		if instance is AudioEffectSpectrumAnalyzerInstance:
			return instance as AudioEffectSpectrumAnalyzerInstance
	return null


func apply_remote_state(track_index: int, should_play: bool, playback_position: float) -> void:
	_apply_track(track_index, false)
	if player_3d.stream == null:
		return

	if should_play:
		player_3d.play(maxf(playback_position, 0.0))
	else:
		player_3d.play(maxf(playback_position, 0.0))
		player_3d.stream_paused = true
	_emit_track_state()


func _apply_track(next_index: int, should_play: bool) -> void:
	if _track_streams.is_empty():
		return

	_track_index = clampi(next_index, 0, _track_streams.size() - 1)
	player_3d.stream = _track_streams[_track_index]
	player_3d.stream_paused = false
	if should_play:
		player_3d.play()
	_emit_track_state()


func _emit_track_state() -> void:
	track_changed.emit(get_current_title(), get_current_artist(), get_current_cover(), is_playing())


func _get_title(index: int) -> String:
	if index >= 0 and index < track_titles.size():
		return track_titles[index]
	return "PISTA %02d" % (index + 1)


func _get_artist(index: int) -> String:
	if index >= 0 and index < track_artists.size():
		return track_artists[index]
	return "ARTISTA DESCONOCIDO"


func _get_cover(index: int) -> Texture2D:
	if index >= 0 and index < _track_covers.size():
		return _track_covers[index]
	return null


func _load_playlist_resources() -> void:
	_track_streams.clear()
	_track_covers.clear()

	for stream_path in track_stream_paths:
		var stream: AudioStream = _load_audio_stream(stream_path)
		if stream == null:
			push_warning("Could not load music track: %s" % stream_path)
			continue
		_track_streams.append(stream)

	for cover_path in track_cover_paths:
		var cover: Texture2D = ResourceLoader.load(cover_path) as Texture2D
		_track_covers.append(cover)


func _setup_model() -> void:
	if model == null:
		return

	model.scale = Vector3.ONE * model_scale
	model.rotation_degrees.y = 35.0
	_apply_nearest_materials(model)
	await get_tree().process_frame

	var bounds: AABB = _get_model_bounds_in_stereo_space(model)
	if bounds.size == Vector3.ZERO:
		push_warning("MusicStereo model has no visible meshes.")
		return

	model.position.y = -bounds.position.y
	bounds = _get_model_bounds_in_stereo_space(model)
	_fit_body_collision(bounds)
	player_3d.position = Vector3(0.0, bounds.position.y + bounds.size.y * 0.55, 0.0)


func _get_model_bounds_in_stereo_space(model_root: Node3D) -> AABB:
	var stereo: Node3D = model_root.get_parent() as Node3D
	if stereo == null:
		return AABB()

	var stereo_inverse: Transform3D = stereo.global_transform.affine_inverse()
	var combined := AABB()
	var has_bounds := false

	for mesh_instance in model_root.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := mesh_instance as MeshInstance3D
		var local_aabb: AABB = stereo_inverse * mesh_node.global_transform * mesh_node.get_aabb()
		combined = local_aabb if not has_bounds else combined.merge(local_aabb)
		has_bounds = true

	return combined if has_bounds else AABB()


func _fit_body_collision(bounds: AABB) -> void:
	if body_shape == null:
		return

	var collision_shape := body_shape.shape as BoxShape3D
	if collision_shape == null:
		return

	collision_shape.size = Vector3(
		maxf(bounds.size.x, 0.35),
		maxf(bounds.size.y, 0.35),
		maxf(bounds.size.z, 0.35)
	)
	body_shape.position = bounds.position + bounds.size * 0.5


func _apply_nearest_materials(root: Node) -> void:
	for mesh_instance in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := mesh_instance as MeshInstance3D
		var mesh: Mesh = mesh_node.mesh
		if mesh == null:
			continue

		for surface_index in mesh.get_surface_count():
			var material: Material = mesh_node.get_active_material(surface_index)
			if material == null:
				continue
			var duplicated: Material = material.duplicate()
			_set_nearest_filter(duplicated)
			mesh_node.set_surface_override_material(surface_index, duplicated)


func _set_nearest_filter(material: Material) -> void:
	if material is BaseMaterial3D:
		(material as BaseMaterial3D).texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	elif material is StandardMaterial3D:
		(material as StandardMaterial3D).texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST


func _load_audio_stream(stream_path: String) -> AudioStream:
	if stream_path.get_extension().to_lower() == "mp3":
		var file_bytes: PackedByteArray = FileAccess.get_file_as_bytes(stream_path)
		if file_bytes.is_empty():
			return null

		var mp3_stream := AudioStreamMP3.new()
		mp3_stream.data = file_bytes
		return mp3_stream

	return ResourceLoader.load(stream_path) as AudioStream


func _on_interaction_area_body_entered(body: Node3D) -> void:
	var player: PlayerController = body as PlayerController
	if player == null or not player.is_local_controlled():
		return

	if not _near_local_players.has(player):
		_near_local_players.append(player)
		proximity_changed.emit(true)


func _on_interaction_area_body_exited(body: Node3D) -> void:
	var player: PlayerController = body as PlayerController
	if player == null:
		return

	_near_local_players.erase(player)
	proximity_changed.emit(not _near_local_players.is_empty())
	if _near_local_players.is_empty():
		_set_hovered(false)


func _update_hover_state() -> void:
	if _near_local_players.is_empty() or get_world_3d() == null:
		_set_hovered(false)
		return

	for player in _near_local_players:
		if player == null or not is_instance_valid(player) or player.camera == null:
			continue
		if _camera_hits_stereo(player.camera, player):
			_set_hovered(true)
			return

	_set_hovered(false)


func _camera_hits_stereo(camera: Camera3D, player: PlayerController) -> bool:
	var origin: Vector3 = camera.global_position
	var target: Vector3 = origin + (-camera.global_transform.basis.z * interaction_range)
	var query := PhysicsRayQueryParameters3D.create(origin, target)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.hit_from_inside = true
	query.exclude = [player.get_rid()]

	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false

	var collider: Object = hit.get("collider")
	return collider == body


func _set_hovered(value: bool) -> void:
	if _is_hovered == value:
		return

	_is_hovered = value
	interaction_hint_changed.emit("E PLAY/PAUSA  F SIGUIENTE", _is_hovered)


func _ensure_warehouse_audio_bus() -> void:
	var bus_index: int = AudioServer.get_bus_index(WAREHOUSE_BUS_NAME)
	if bus_index == -1:
		AudioServer.add_bus()
		bus_index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus_index, WAREHOUSE_BUS_NAME)
		AudioServer.set_bus_send(bus_index, &"Master")

	if AudioServer.get_bus_effect_count(bus_index) > 0:
		return

	var reverb := AudioEffectReverb.new()
	reverb.room_size = 0.72
	reverb.damping = 0.38
	reverb.wet = 0.24
	reverb.dry = 0.86
	AudioServer.add_bus_effect(bus_index, reverb)

	var low_pass := AudioEffectLowPassFilter.new()
	low_pass.cutoff_hz = 9500.0
	low_pass.resonance = 0.18
	AudioServer.add_bus_effect(bus_index, low_pass)

	var spectrum := AudioEffectSpectrumAnalyzer.new()
	spectrum.fft_size = AudioEffectSpectrumAnalyzer.FFT_SIZE_1024
	spectrum.buffer_length = 0.1
	AudioServer.add_bus_effect(bus_index, spectrum)
