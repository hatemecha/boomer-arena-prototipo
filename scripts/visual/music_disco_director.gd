class_name MusicDiscoDirector
extends Node

@export var enabled: bool = true
@export_range(0.0, 1.0) var intensity: float = 1.0
@export_range(0.0, 4.0) var fade_in_duration: float = 1.5
@export_range(0.0, 2.0) var fade_out_duration: float = 0.8

# How strongly bass reinforces beat pulse (0 = BPM-only, 1 = full bass-reactive)
@export_range(0.0, 1.0) var bass_influence: float = 0.7

# Arena light energy: multiplier at trough vs peak of beat
@export_range(0.0, 1.0) var arena_energy_min: float = 0.62
@export_range(1.0, 8.0) var arena_energy_max: float = 4.2

# Window fill multipliers
@export_range(0.0, 1.0) var fill_energy_min: float = 0.58
@export_range(1.0, 6.0) var fill_energy_max: float = 2.2

# Panel emission energy multiplier at trough vs peak
@export_range(0.0, 1.0) var panel_energy_min: float = 0.55
@export_range(1.0, 10.0) var panel_energy_max: float = 5.5

# Beat decay sharpness — higher = snappier strobe flash
@export_range(4.0, 24.0) var beat_decay: float = 11.0

# Fog: most impactful — colors the entire atmospheric haze
@export_range(0.0, 1.0) var fog_color_intensity: float = 0.92

# Ambient light: bathes all surfaces in the beat color
@export_range(0.0, 1.0) var ambient_color_intensity: float = 0.78

# Sky portals horizon tint
@export_range(0.0, 1.0) var sky_color_intensity: float = 0.85

# Post-process screen tint strength on peak beat (1.0 = fully replaces PSX tint)
@export_range(0.0, 1.0) var screen_tint_intensity: float = 0.90

# How much to desaturate the PSX quantization on the beat peak
# (higher = more vivid disco colors punch through the palette filter)
@export_range(0.0, 1.0) var shader_bypass_intensity: float = 0.85

# Extra saturation multiplier applied to extracted palette colors
@export_range(1.0, 3.0) var palette_saturation_boost: float = 1.6

const BASS_LOW_HZ := 20.0
const BASS_HIGH_HZ := 180.0

var _music_stereo: MusicStereo
var _visual_director: PSXVisualDirector

# ── point lights ──────────────────────────────────────────────────────────────
var _arena_lights: Array[OmniLight3D] = []
var _window_fill_lights: Array[OmniLight3D] = []
var _light_panels: Array[MeshInstance3D] = []
var _panel_materials: Array[Material] = []

var _baseline_arena_colors: Array[Color] = []
var _baseline_arena_energies: Array[float] = []
var _baseline_fill_colors: Array[Color] = []
var _baseline_fill_energies: Array[float] = []
var _baseline_panel_emissions: Array[Color] = []

# ── environment (fog / ambient / bg / sky) ────────────────────────────────────
var _environment: Environment
var _sky_portals: Array[MeshInstance3D] = []
var _baseline_fog_color: Color
var _baseline_fog_density: float
var _baseline_ambient_color: Color
var _baseline_ambient_energy: float
var _baseline_bg_color: Color
var _baseline_sky_horizons: Array[Vector3] = []
var _baseline_sky_tops: Array[Vector3] = []

# ── state ─────────────────────────────────────────────────────────────────────
var _baseline_captured: bool = false
var _blend_factor: float = 0.0
var _is_active: bool = false

# Cached PSX defaults for the shader bypass interpolation
var color_levels: float = 6.0
var palette_mix: float = 0.55

var _palette_extractor: CoverPaletteExtractor
var _palette: PackedColorArray
var _last_beat_index: int = -1
var _current_color_index: int = 0
var _smoothed_bass: float = 0.0
var _current_beat_pulse: float = 0.0


func _ready() -> void:
	_palette_extractor = CoverPaletteExtractor.new()
	_palette = _palette_extractor.get_fallback_palette()


func bind(music_stereo: MusicStereo, visual_director: PSXVisualDirector) -> void:
	if _music_stereo != null:
		if _music_stereo.track_changed.is_connected(_on_track_changed):
			_music_stereo.track_changed.disconnect(_on_track_changed)

	_music_stereo = music_stereo
	_visual_director = visual_director

	if _visual_director != null:
		color_levels = _visual_director.color_levels
		palette_mix = _visual_director.palette_mix
		if not _visual_director.visual_style_refreshed.is_connected(_on_visual_style_refreshed):
			_visual_director.visual_style_refreshed.connect(_on_visual_style_refreshed)

	if _music_stereo != null:
		_music_stereo.track_changed.connect(_on_track_changed)
		_palette = _palette_extractor.extract(
			_music_stereo.get_current_cover(), _music_stereo.get_track_index()
		)


func _process(delta: float) -> void:
	if not enabled or _music_stereo == null:
		_blend_out(delta)
		return

	if _music_stereo.is_playing():
		if not _is_active:
			_is_active = true
			_capture_baseline_if_needed()

		_blend_factor = minf(_blend_factor + delta / maxf(fade_in_duration, 0.01), 1.0)
		_tick_disco(delta)
	else:
		_blend_out(delta)


func _blend_out(delta: float) -> void:
	if _blend_factor <= 0.0:
		_is_active = false
		return

	_blend_factor = maxf(_blend_factor - delta / maxf(fade_out_duration, 0.01), 0.0)

	if not _baseline_captured:
		return

	var t := _blend_factor * intensity
	_apply_lights_blend(t, _current_beat_pulse)
	_apply_environment_blend(t, _current_beat_pulse)

	if _blend_factor <= 0.0:
		_is_active = false
		_restore_baseline()


func _tick_disco(delta: float) -> void:
	if not _baseline_captured:
		_capture_baseline_if_needed()
		if not _baseline_captured:
			return

	var bpm: float = _music_stereo.get_bpm()
	var offset: float = _music_stereo.get_beat_offset()
	var pos: float = _music_stereo.get_playback_position()

	var beat_duration := 60.0 / bpm
	var beat_index := floori((pos + offset) / beat_duration)
	var beat_phase := fmod(pos + offset, beat_duration) / beat_duration
	var beat_pulse := exp(-beat_phase * beat_decay)

	if beat_index != _last_beat_index:
		_last_beat_index = beat_index
		_current_color_index = beat_index % _palette.size()

	var bass_energy := _sample_bass_energy()
	_smoothed_bass = lerpf(_smoothed_bass, bass_energy, minf(delta * 18.0, 1.0))
	beat_pulse = lerpf(beat_pulse, beat_pulse * lerpf(0.7, 1.3, _smoothed_bass), bass_influence)
	beat_pulse = clampf(beat_pulse, 0.0, 1.0)
	_current_beat_pulse = beat_pulse

	var t := _blend_factor * intensity
	_apply_lights_blend(t, beat_pulse)
	_apply_environment_blend(t, beat_pulse)

	if _visual_director != null and _palette.size() > 0:
		var dominant := _boosted_color(_palette[_current_color_index])
		var tint_strength := t * screen_tint_intensity * lerpf(0.15, 1.0, beat_pulse)
		_visual_director.set_music_tint_override(dominant, tint_strength)

		# Open the PSX quantization gate on the beat so vivid colors punch through
		var bypass := t * shader_bypass_intensity * beat_pulse
		var effective_levels := lerpf(color_levels, 16.0, bypass)
		var effective_mix   := lerpf(palette_mix,   0.04, bypass)
		_visual_director.set_music_shader_override(effective_levels, effective_mix)


# ── point lights ──────────────────────────────────────────────────────────────

func _apply_lights_blend(blend: float, beat_pulse: float) -> void:
	if _palette.is_empty():
		return

	var arena_scale := lerpf(arena_energy_min, arena_energy_max, beat_pulse)
	var fill_scale := lerpf(fill_energy_min, fill_energy_max, beat_pulse)

	for i in _arena_lights.size():
		var light := _arena_lights[i]
		if light == null:
			continue
		var disco_color := _boosted_color(_palette[(_current_color_index + i) % _palette.size()])
		var base_color := _baseline_arena_colors[i] if i < _baseline_arena_colors.size() else Color.WHITE
		var base_energy := _baseline_arena_energies[i] if i < _baseline_arena_energies.size() else 1.0
		light.light_color = base_color.lerp(disco_color, blend)
		light.light_energy = base_energy * lerpf(1.0, arena_scale, blend)

	for i in _window_fill_lights.size():
		var light := _window_fill_lights[i]
		if light == null:
			continue
		var disco_color := _boosted_color(_palette[(_current_color_index + 2 + i) % _palette.size()])
		var base_color := _baseline_fill_colors[i] if i < _baseline_fill_colors.size() else Color.WHITE
		var base_energy := _baseline_fill_energies[i] if i < _baseline_fill_energies.size() else 1.0
		light.light_color = base_color.lerp(disco_color, blend)
		light.light_energy = base_energy * lerpf(1.0, fill_scale, blend)

	for i in _panel_materials.size():
		var mat := _panel_materials[i]
		if mat == null or not (mat is BaseMaterial3D):
			continue
		var bmat := mat as BaseMaterial3D
		var disco_emission := _boosted_color(_palette[_current_color_index % _palette.size()])
		var base_emission := _baseline_panel_emissions[i] if i < _baseline_panel_emissions.size() else Color(0.55, 0.85, 0.78)
		bmat.emission = base_emission.lerp(disco_emission, blend)
		bmat.emission_energy_multiplier = lerpf(
			1.45,
			lerpf(panel_energy_min, panel_energy_max, beat_pulse) * 1.45,
			blend
		)


# ── environment (fog / ambient / bg / sky) ────────────────────────────────────

func _apply_environment_blend(blend: float, beat_pulse: float) -> void:
	if _environment == null or _palette.is_empty():
		return

	var color := _palette[_current_color_index]

	var boosted := _boosted_color(color)

	# Fog color: full room-fill effect — most impactful single change
	var fog_t := blend * fog_color_intensity * beat_pulse
	_environment.fog_light_color = _baseline_fog_color.lerp(boosted, fog_t)

	# Fog density: subtle pulse so gameplay visibility stays readable at night.
	_environment.fog_density = lerpf(
		_baseline_fog_density,
		_baseline_fog_density * lerpf(0.88, 1.35, beat_pulse),
		blend * 0.32
	)

	# Ambient light: bathes ALL surfaces in the beat color
	var ambient_t := blend * ambient_color_intensity * lerpf(0.25, 1.0, beat_pulse)
	_environment.ambient_light_color = _baseline_ambient_color.lerp(boosted, ambient_t)
	_environment.ambient_light_energy = lerpf(
		_baseline_ambient_energy,
		_baseline_ambient_energy * lerpf(0.78, 3.6, beat_pulse),
		blend
	)

	# Background color (the void / skybox color)
	var bg_t := blend * beat_pulse * 0.65
	_environment.background_color = _baseline_bg_color.lerp(color * 0.45, bg_t)

	# Sky portals: pulse horizon toward the beat color
	var sky_t := blend * sky_color_intensity * beat_pulse
	for i in _sky_portals.size():
		var portal := _sky_portals[i]
		if portal == null:
			continue
		var mat := portal.material_override as ShaderMaterial
		if mat == null:
			continue
		var baseline_h := _baseline_sky_horizons[i] if i < _baseline_sky_horizons.size() else Vector3(0.16, 0.19, 0.3)
		var disco_h := Vector3(color.r, color.g, color.b)
		mat.set_shader_parameter("horizon_color", baseline_h.lerp(disco_h, sky_t))

		# Top color: tint faintly toward next palette color for depth
		if i < _baseline_sky_tops.size():
			var next_color := _palette[(_current_color_index + 1) % _palette.size()]
			var disco_top := Vector3(next_color.r * 0.5, next_color.g * 0.5, next_color.b * 0.5)
			mat.set_shader_parameter("top_color", _baseline_sky_tops[i].lerp(disco_top, sky_t * 0.5))


# ── baseline capture & restore ────────────────────────────────────────────────

func _capture_baseline_if_needed() -> void:
	if _baseline_captured:
		return

	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return

	_arena_lights.clear()
	_window_fill_lights.clear()
	_light_panels.clear()
	_panel_materials.clear()
	_baseline_arena_colors.clear()
	_baseline_arena_energies.clear()
	_baseline_fill_colors.clear()
	_baseline_fill_energies.clear()
	_baseline_panel_emissions.clear()
	_sky_portals.clear()
	_baseline_sky_horizons.clear()
	_baseline_sky_tops.clear()

	_collect_omni_by_prefix(scene_root, "ArenaLight", _arena_lights)
	_collect_omni_by_prefix(scene_root, "WindowFill", _window_fill_lights)
	_collect_meshes_by_prefix(scene_root, "LightPanel", _light_panels)
	_collect_meshes_by_prefix(scene_root, "SkyPortal", _sky_portals)

	for light in _arena_lights:
		_baseline_arena_colors.append(light.light_color)
		_baseline_arena_energies.append(light.light_energy)

	for light in _window_fill_lights:
		_baseline_fill_colors.append(light.light_color)
		_baseline_fill_energies.append(light.light_energy)

	for mesh in _light_panels:
		var mat: Material = _get_active_material(mesh)
		_panel_materials.append(mat)
		if mat is BaseMaterial3D:
			_baseline_panel_emissions.append((mat as BaseMaterial3D).emission)
		else:
			_baseline_panel_emissions.append(Color(0.55, 0.85, 0.78))

	for portal in _sky_portals:
		var mat := portal.material_override as ShaderMaterial
		if mat != null:
			var h = mat.get_shader_parameter("horizon_color")
			var t = mat.get_shader_parameter("top_color")
			_baseline_sky_horizons.append(h if h is Vector3 else Vector3(0.16, 0.19, 0.3))
			_baseline_sky_tops.append(t if t is Vector3 else Vector3(0.035, 0.055, 0.13))
		else:
			_baseline_sky_horizons.append(Vector3(0.16, 0.19, 0.3))
			_baseline_sky_tops.append(Vector3(0.035, 0.055, 0.13))

	_environment = _find_environment(scene_root)
	if _environment != null:
		_baseline_fog_color    = _environment.fog_light_color
		_baseline_fog_density  = _environment.fog_density
		_baseline_ambient_color  = _environment.ambient_light_color
		_baseline_ambient_energy = _environment.ambient_light_energy
		_baseline_bg_color       = _environment.background_color

	_baseline_captured = true


func _restore_baseline() -> void:
	# Delegar cielo/ambiente/luces al preset actual del director visual en lugar de
	# restaurar valores viejos capturados en otra hora del dia.
	if _visual_director != null:
		_visual_director.clear_music_tint_override()
		_visual_director.clear_music_shader_override()
		_visual_director.refresh_visual_style()
	_baseline_captured = false


func invalidate_baseline() -> void:
	refresh_baselines_from_scene()


func refresh_baselines_from_scene() -> void:
	_baseline_captured = false
	if _visual_director != null and (not _is_active or _blend_factor <= 0.001):
		_visual_director.clear_music_tint_override()
		_visual_director.clear_music_shader_override()


func _on_visual_style_refreshed(_time_of_day_preset: PSXVisualDirector.TimeOfDayPreset) -> void:
	refresh_baselines_from_scene()
	if _is_active and _blend_factor > 0.001:
		_capture_baseline_if_needed()


# ── helpers ───────────────────────────────────────────────────────────────────

func _on_track_changed(
	_title: String, _artist: String, cover: Texture2D, _is_playing: bool
) -> void:
	if _music_stereo == null:
		return
	_palette = _palette_extractor.extract(cover, _music_stereo.get_track_index())
	_last_beat_index = -1
	_current_color_index = 0


func _sample_bass_energy() -> float:
	if _music_stereo == null:
		return 0.0
	var spectrum := _music_stereo.get_spectrum_instance()
	if spectrum == null:
		return 0.0
	var magnitude: float = spectrum.get_magnitude_for_frequency_range(
		BASS_LOW_HZ, BASS_HIGH_HZ, AudioEffectSpectrumAnalyzerInstance.MAGNITUDE_AVERAGE
	).length()
	return clampf((60.0 + linear_to_db(magnitude)) / 60.0, 0.0, 1.0)


func _get_active_material(mesh: MeshInstance3D) -> Material:
	if mesh.material_override != null:
		return mesh.material_override
	for i in mesh.get_surface_override_material_count():
		var m := mesh.get_surface_override_material(i)
		if m != null:
			return m
	if mesh.mesh != null and mesh.mesh.get_surface_count() > 0:
		return mesh.mesh.surface_get_material(0)
	return null


func _find_environment(root: Node) -> Environment:
	if root == null:
		return null
	if root is WorldEnvironment:
		return (root as WorldEnvironment).environment
	for child in root.get_children():
		var result := _find_environment(child)
		if result != null:
			return result
	return null


func _collect_omni_by_prefix(root: Node, prefix: String, output: Array[OmniLight3D]) -> void:
	if root == null:
		return
	if root is OmniLight3D and root.name.begins_with(prefix):
		output.append(root as OmniLight3D)
	for child in root.get_children():
		_collect_omni_by_prefix(child, prefix, output)


func _collect_meshes_by_prefix(root: Node, prefix: String, output: Array[MeshInstance3D]) -> void:
	if root == null:
		return
	if root is MeshInstance3D and root.name.begins_with(prefix):
		output.append(root as MeshInstance3D)
	for child in root.get_children():
		_collect_meshes_by_prefix(child, prefix, output)


func _boosted_color(c: Color) -> Color:
	return Color.from_hsv(c.h, clampf(c.s * palette_saturation_boost, 0.0, 1.0), c.v)
