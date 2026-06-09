class_name PSXVisualDirector
extends Node

enum TimeOfDayPreset {
	MORNING,
	AFTERNOON,
	NIGHT,
}

enum LensPreset {
	OFF,
	GAMEPLAY,
	PSX_8MM,
	EXTREME_DEBUG,
}

const PSX_SHADER: Shader = preload("res://shaders/psx_palette_filter.gdshader")

signal lens_preset_changed(preset: LensPreset)

@export var enabled: bool = true
@export var time_of_day_preset: TimeOfDayPreset = TimeOfDayPreset.NIGHT
@export var lens_preset: LensPreset = LensPreset.PSX_8MM
@export var post_process_enabled: bool = true
@export var enforce_nearest_filtering: bool = true
@export var glow_enabled: bool = true
@export_range(0.0, 0.08, 0.005) var dither_strength: float = 0.025
@export_range(2.0, 16.0, 1.0) var color_levels: float = 6.0
@export_range(0.0, 1.0, 0.01) var palette_mix: float = 0.55
@export_range(0.0, 0.35, 0.001) var fisheye_strength: float = 0.018
@export_range(0.0, 1.0, 0.01) var fisheye_center_flatness: float = 0.45
@export_range(0.9, 1.2, 0.001) var lens_zoom_compensation: float = 1.015
@export_range(0.0, 0.02, 0.00025) var chromatic_aberration_strength: float = 0.0024
@export_range(0.0, 1.2, 0.01) var chromatic_edge_start: float = 0.70
@export_range(0.0, 1.0, 0.005) var vignette_strength: float = 0.035
@export_range(0.4, 1.8, 0.01) var vignette_radius: float = 1.35
@export_range(0.05, 1.0, 0.01) var vignette_softness: float = 0.35
@export_range(0.0, 1.0, 0.005) var circular_mask_strength: float = 0.0
@export_range(0.4, 1.8, 0.01) var circular_mask_radius: float = 1.20
@export_range(0.01, 0.8, 0.01) var circular_mask_softness: float = 0.25
@export_range(0.0, 0.12, 0.001) var film_grain_strength: float = 0.010
@export_range(0.0, 60.0, 0.1) var film_grain_speed: float = 14.0
@export_range(20.0, 500.0, 1.0) var film_grain_scale: float = 180.0
@export_range(0.0, 0.2, 0.005) var lens_dirt_strength: float = 0.0

var _post_process_layer: CanvasLayer
var _post_process_rect: ColorRect
var _post_process_material: ShaderMaterial
var _nearest_filtering_applied: bool = false


func _ready() -> void:
	_apply_lens_preset_values(lens_preset)
	call_deferred("refresh_visual_style")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F6:
		cycle_time_of_day_preset()


func cycle_time_of_day_preset() -> void:
	time_of_day_preset = ((time_of_day_preset + 1) % TimeOfDayPreset.size()) as TimeOfDayPreset
	refresh_visual_style()


func apply_lens_preset(preset: LensPreset) -> void:
	var safe_preset: int = clampi(int(preset), 0, LensPreset.size() - 1)
	lens_preset = safe_preset as LensPreset
	_apply_lens_preset_values(lens_preset)
	refresh_visual_style()
	lens_preset_changed.emit(lens_preset)


func refresh_visual_style() -> void:
	if not enabled:
		_set_post_process_visible(false)
		return

	_ensure_post_process()
	_apply_environment_preset()
	_apply_post_process_preset()

	if enforce_nearest_filtering and not _nearest_filtering_applied:
		_apply_nearest_filtering(get_tree().current_scene)
		_nearest_filtering_applied = true


func _ensure_post_process() -> void:
	if _post_process_layer != null:
		_set_post_process_visible(post_process_enabled)
		return

	_post_process_layer = CanvasLayer.new()
	_post_process_layer.name = "PSXPostProcess"
	_post_process_layer.layer = 128
	add_child(_post_process_layer)

	_post_process_rect = ColorRect.new()
	_post_process_rect.name = "PaletteFilter"
	_post_process_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_post_process_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_post_process_layer.add_child(_post_process_rect)

	_post_process_material = ShaderMaterial.new()
	_post_process_material.shader = PSX_SHADER
	_post_process_rect.material = _post_process_material
	_set_post_process_visible(post_process_enabled)


func _set_post_process_visible(value: bool) -> void:
	if _post_process_layer != null:
		_post_process_layer.visible = value


func _apply_environment_preset() -> void:
	var environment_node: WorldEnvironment = _find_world_environment(get_tree().current_scene)
	var directional_light: DirectionalLight3D = _find_directional_light(get_tree().current_scene)

	if environment_node == null:
		push_warning("PSXVisualDirector could not find a WorldEnvironment node.")
	else:
		if environment_node.environment == null:
			environment_node.environment = Environment.new()
		_configure_environment(environment_node.environment)

	if directional_light == null:
		push_warning("PSXVisualDirector could not find a DirectionalLight3D node.")
	else:
		_configure_directional_light(directional_light)

	_configure_exterior_light()
	_configure_window_fill_lights()
	_configure_sky_portals()
	_configure_ceiling_light_panels()


func _configure_environment(environment: Environment) -> void:
	environment.background_mode = Environment.BG_COLOR
	environment.fog_enabled = true
	environment.volumetric_fog_enabled = false
	environment.glow_enabled = glow_enabled
	if glow_enabled:
		environment.glow_intensity = 0.25
		environment.glow_strength = 0.45
		environment.glow_bloom = 0.08
		environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
		environment.glow_hdr_threshold = 1.05
		environment.glow_hdr_scale = 1.2
	environment.ssao_enabled = false
	environment.ssil_enabled = false
	environment.sdfgi_enabled = false
	environment.adjustment_enabled = true

	match time_of_day_preset:
		TimeOfDayPreset.MORNING:
			environment.background_color = Color(0.38, 0.42, 0.38)
			environment.ambient_light_color = Color(0.62, 0.72, 0.66)
			environment.ambient_light_energy = 0.44
			environment.fog_light_color = Color(0.50, 0.60, 0.55)
			environment.fog_density = 0.016
			environment.adjustment_brightness = 0.96
			environment.adjustment_contrast = 1.10
			environment.adjustment_saturation = 0.58
		TimeOfDayPreset.AFTERNOON:
			environment.background_color = Color(0.13, 0.10, 0.08)
			environment.ambient_light_color = Color(0.55, 0.42, 0.34)
			environment.ambient_light_energy = 0.40
			environment.fog_light_color = Color(0.40, 0.30, 0.26)
			environment.fog_density = 0.02
			environment.adjustment_brightness = 0.94
			environment.adjustment_contrast = 1.16
			environment.adjustment_saturation = 0.55
		TimeOfDayPreset.NIGHT:
			environment.background_color = Color(0.035, 0.045, 0.05)
			environment.ambient_light_color = Color(0.32, 0.48, 0.50)
			environment.ambient_light_energy = 0.42
			environment.fog_light_color = Color(0.20, 0.30, 0.32)
			environment.fog_density = 0.024
			environment.adjustment_brightness = 0.90
			environment.adjustment_contrast = 1.22
			environment.adjustment_saturation = 0.50


func _configure_directional_light(directional_light: DirectionalLight3D) -> void:
	directional_light.shadow_enabled = false

	match time_of_day_preset:
		TimeOfDayPreset.MORNING:
			directional_light.light_color = Color(1.0, 0.86, 0.58)
			directional_light.light_energy = 0.72
			directional_light.rotation_degrees = Vector3(-42.0, 36.0, 0.0)
		TimeOfDayPreset.AFTERNOON:
			directional_light.light_color = Color(0.95, 0.68, 0.46)
			directional_light.light_energy = 0.78
			directional_light.rotation_degrees = Vector3(-28.0, -46.0, 0.0)
		TimeOfDayPreset.NIGHT:
			directional_light.light_color = Color(0.34, 0.42, 0.7)
			directional_light.light_energy = 0.95
			directional_light.rotation_degrees = Vector3(-58.0, 28.0, 0.0)


func _apply_post_process_preset() -> void:
	if _post_process_material == null:
		return

	var tint_color: Color
	var danger_color: Color = Color(0.74, 0.025, 0.02)
	var contrast: float
	var brightness: float

	match time_of_day_preset:
		TimeOfDayPreset.MORNING:
			tint_color = Color(0.70, 0.86, 0.78)
			contrast = 1.10
			brightness = -0.03
		TimeOfDayPreset.AFTERNOON:
			tint_color = Color(0.82, 0.72, 0.62)
			contrast = 1.16
			brightness = -0.04
		TimeOfDayPreset.NIGHT:
			tint_color = Color(0.62, 0.78, 0.82)
			contrast = 1.22
			brightness = -0.06

	_post_process_material.set_shader_parameter("color_levels", color_levels)
	_post_process_material.set_shader_parameter("dither_strength", dither_strength)
	_post_process_material.set_shader_parameter("palette_mix", palette_mix)
	_apply_lens_shader_parameters()
	_post_process_material.set_shader_parameter("tint_color", Vector3(tint_color.r, tint_color.g, tint_color.b))
	_post_process_material.set_shader_parameter("danger_color", Vector3(danger_color.r, danger_color.g, danger_color.b))
	_post_process_material.set_shader_parameter("contrast", contrast)
	_post_process_material.set_shader_parameter("brightness", brightness)


func _apply_lens_preset_values(preset: LensPreset) -> void:
	match preset:
		LensPreset.OFF:
			fisheye_strength = 0.0
			fisheye_center_flatness = 1.0
			lens_zoom_compensation = 1.0
			chromatic_aberration_strength = 0.0
			chromatic_edge_start = 1.2
			vignette_strength = 0.0
			vignette_radius = 1.35
			vignette_softness = 0.35
			circular_mask_strength = 0.0
			circular_mask_radius = 1.20
			circular_mask_softness = 0.25
			film_grain_strength = 0.0
			film_grain_speed = 14.0
			film_grain_scale = 180.0
			lens_dirt_strength = 0.0
		LensPreset.GAMEPLAY:
			fisheye_strength = 0.018
			fisheye_center_flatness = 0.45
			lens_zoom_compensation = 1.015
			chromatic_aberration_strength = 0.0006
			chromatic_edge_start = 0.65
			vignette_strength = 0.035
			vignette_radius = 1.35
			vignette_softness = 0.35
			circular_mask_strength = 0.0
			circular_mask_radius = 1.20
			circular_mask_softness = 0.25
			film_grain_strength = 0.010
			film_grain_speed = 14.0
			film_grain_scale = 180.0
			lens_dirt_strength = 0.0
		LensPreset.PSX_8MM:
			fisheye_strength = 0.075
			fisheye_center_flatness = 0.35
			lens_zoom_compensation = 1.035
			chromatic_aberration_strength = 0.0024
			chromatic_edge_start = 0.45
			vignette_strength = 0.08
			vignette_radius = 1.12
			vignette_softness = 0.38
			circular_mask_strength = 0.20
			circular_mask_radius = 1.20
			circular_mask_softness = 0.22
			film_grain_strength = 0.022
			film_grain_speed = 18.0
			film_grain_scale = 160.0
			lens_dirt_strength = 0.01
		LensPreset.EXTREME_DEBUG:
			fisheye_strength = 0.16
			fisheye_center_flatness = 0.25
			lens_zoom_compensation = 1.06
			chromatic_aberration_strength = 0.0053
			chromatic_edge_start = 0.30
			vignette_strength = 0.11
			vignette_radius = 0.96
			vignette_softness = 0.35
			circular_mask_strength = 0.45
			circular_mask_radius = 1.05
			circular_mask_softness = 0.18
			film_grain_strength = 0.035
			film_grain_speed = 22.0
			film_grain_scale = 140.0
			lens_dirt_strength = 0.03


func _apply_lens_shader_parameters() -> void:
	if _post_process_material == null:
		return

	_post_process_material.set_shader_parameter("fisheye_strength", fisheye_strength)
	_post_process_material.set_shader_parameter("fisheye_center_flatness", fisheye_center_flatness)
	_post_process_material.set_shader_parameter("lens_zoom_compensation", lens_zoom_compensation)
	_post_process_material.set_shader_parameter("chromatic_aberration_strength", chromatic_aberration_strength)
	_post_process_material.set_shader_parameter("chromatic_edge_start", chromatic_edge_start)
	_post_process_material.set_shader_parameter("vignette_strength", vignette_strength)
	_post_process_material.set_shader_parameter("vignette_radius", vignette_radius)
	_post_process_material.set_shader_parameter("vignette_softness", vignette_softness)
	_post_process_material.set_shader_parameter("circular_mask_strength", circular_mask_strength)
	_post_process_material.set_shader_parameter("circular_mask_radius", circular_mask_radius)
	_post_process_material.set_shader_parameter("circular_mask_softness", circular_mask_softness)
	_post_process_material.set_shader_parameter("film_grain_strength", film_grain_strength)
	_post_process_material.set_shader_parameter("film_grain_speed", film_grain_speed)
	_post_process_material.set_shader_parameter("film_grain_scale", film_grain_scale)
	_post_process_material.set_shader_parameter("lens_dirt_strength", lens_dirt_strength)
	_post_process_material.set_shader_parameter("lens_aspect_ratio", _get_viewport_aspect_ratio())


func _get_viewport_aspect_ratio() -> float:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if viewport_size.y <= 0.0:
		return 1.7778
	return viewport_size.x / viewport_size.y


func _configure_exterior_light() -> void:
	var exterior_light: DirectionalLight3D = _find_directional_light_by_name(get_tree().current_scene, "ExteriorSunLight")
	if exterior_light == null:
		return

	exterior_light.shadow_enabled = false

	match time_of_day_preset:
		TimeOfDayPreset.MORNING:
			exterior_light.light_color = Color(0.88, 0.92, 1.0)
			exterior_light.light_energy = 1.15
			exterior_light.rotation_degrees = Vector3(-68.0, 34.0, 0.0)
		TimeOfDayPreset.AFTERNOON:
			exterior_light.light_color = Color(0.98, 0.78, 0.56)
			exterior_light.light_energy = 0.95
			exterior_light.rotation_degrees = Vector3(-38.0, -48.0, 0.0)
		TimeOfDayPreset.NIGHT:
			exterior_light.light_color = Color(0.48, 0.56, 0.86)
			exterior_light.light_energy = 0.42
			exterior_light.rotation_degrees = Vector3(-72.0, 16.0, 0.0)


func _configure_window_fill_lights() -> void:
	var fill_lights: Array[OmniLight3D] = []
	_collect_omni_lights_by_prefix(get_tree().current_scene, "WindowFill", fill_lights)

	for fill_light in fill_lights:
		fill_light.shadow_enabled = false
		match time_of_day_preset:
			TimeOfDayPreset.MORNING:
				fill_light.light_color = Color(0.72, 0.82, 1.0)
				fill_light.light_energy = 1.35
				fill_light.omni_range = 15.0
			TimeOfDayPreset.AFTERNOON:
				fill_light.light_color = Color(0.94, 0.72, 0.52)
				fill_light.light_energy = 1.05
				fill_light.omni_range = 14.0
			TimeOfDayPreset.NIGHT:
				fill_light.light_color = Color(0.42, 0.5, 0.86)
				fill_light.light_energy = 0.48
				fill_light.omni_range = 12.0


func _configure_sky_portals() -> void:
	var sky_portals: Array[MeshInstance3D] = []
	_collect_meshes_by_prefix(get_tree().current_scene, "SkyPortal", sky_portals)

	for sky_portal in sky_portals:
		var sky_material: ShaderMaterial = sky_portal.material_override as ShaderMaterial
		if sky_material == null:
			continue

		match time_of_day_preset:
			TimeOfDayPreset.MORNING:
				_set_sky_material(
					sky_material,
					Color(0.35, 0.54, 0.82),
					Color(0.82, 0.88, 0.9),
					Color(0.92, 0.92, 0.86),
					0.52,
					0.0,
					1.08
				)
			TimeOfDayPreset.AFTERNOON:
				_set_sky_material(
					sky_material,
					Color(0.46, 0.45, 0.62),
					Color(0.86, 0.68, 0.48),
					Color(0.84, 0.75, 0.64),
					0.38,
					0.0,
					0.96
				)
			TimeOfDayPreset.NIGHT:
				_set_sky_material(
					sky_material,
					Color(0.035, 0.055, 0.13),
					Color(0.16, 0.19, 0.3),
					Color(0.22, 0.26, 0.4),
					0.18,
					0.65,
					0.72
				)


func _configure_ceiling_light_panels() -> void:
	var light_panels: Array[MeshInstance3D] = []
	_collect_meshes_by_prefix(get_tree().current_scene, "LightPanel", light_panels)

	for light_panel in light_panels:
		if light_panel.material_override != null:
			_configure_light_panel_material(light_panel.material_override)

		for surface_index in range(light_panel.get_surface_override_material_count()):
			var surface_override: Material = light_panel.get_surface_override_material(surface_index)
			if surface_override != null:
				_configure_light_panel_material(surface_override)

		var mesh: Mesh = light_panel.mesh
		if mesh == null:
			continue

		for surface_index in range(mesh.get_surface_count()):
			var surface_material: Material = mesh.surface_get_material(surface_index)
			if surface_material != null:
				_configure_light_panel_material(surface_material)


func _configure_light_panel_material(material: Material) -> void:
	if material is BaseMaterial3D:
		var base_material: BaseMaterial3D = material as BaseMaterial3D
		base_material.emission_enabled = true
		base_material.emission = Color(0.55, 0.85, 0.78)
		base_material.emission_energy_multiplier = 1.5 if glow_enabled else 1.0
		base_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST


func _set_sky_material(
	sky_material: ShaderMaterial,
	top_color: Color,
	horizon_color: Color,
	cloud_color: Color,
	cloud_amount: float,
	star_amount: float,
	brightness: float
) -> void:
	sky_material.set_shader_parameter("top_color", Vector3(top_color.r, top_color.g, top_color.b))
	sky_material.set_shader_parameter("horizon_color", Vector3(horizon_color.r, horizon_color.g, horizon_color.b))
	sky_material.set_shader_parameter("cloud_color", Vector3(cloud_color.r, cloud_color.g, cloud_color.b))
	sky_material.set_shader_parameter("star_color", Vector3(0.68, 0.76, 1.0))
	sky_material.set_shader_parameter("cloud_amount", cloud_amount)
	sky_material.set_shader_parameter("star_amount", star_amount)
	sky_material.set_shader_parameter("brightness", brightness)


func _apply_nearest_filtering(root: Node) -> void:
	if root == null:
		push_warning("PSXVisualDirector cannot apply material filtering without a scene root.")
		return

	if root is MeshInstance3D:
		_configure_mesh_materials(root as MeshInstance3D)

	for child in root.get_children():
		_apply_nearest_filtering(child)


func _configure_mesh_materials(mesh_instance: MeshInstance3D) -> void:
	if mesh_instance.material_override != null:
		_configure_material(mesh_instance.material_override)

	for surface_index in range(mesh_instance.get_surface_override_material_count()):
		var surface_override: Material = mesh_instance.get_surface_override_material(surface_index)
		if surface_override != null:
			_configure_material(surface_override)

	var mesh: Mesh = mesh_instance.mesh
	if mesh == null:
		return

	for surface_index in range(mesh.get_surface_count()):
		var surface_material: Material = mesh.surface_get_material(surface_index)
		if surface_material != null:
			_configure_material(surface_material)


func _configure_material(material: Material) -> void:
	if material is BaseMaterial3D:
		var base_material: BaseMaterial3D = material as BaseMaterial3D
		base_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		base_material.roughness = 1.0
		base_material.metallic = 0.0


func _find_world_environment(root: Node) -> WorldEnvironment:
	if root == null:
		return null
	if root is WorldEnvironment:
		return root

	for child in root.get_children():
		var match_node: WorldEnvironment = _find_world_environment(child)
		if match_node != null:
			return match_node

	return null


func _find_directional_light(root: Node) -> DirectionalLight3D:
	if root == null:
		return null
	if root is DirectionalLight3D:
		return root

	for child in root.get_children():
		var match_node: DirectionalLight3D = _find_directional_light(child)
		if match_node != null:
			return match_node

	return null


func _find_directional_light_by_name(root: Node, target_name: String) -> DirectionalLight3D:
	if root == null:
		return null
	if root is DirectionalLight3D and root.name == target_name:
		return root

	for child in root.get_children():
		var match_node: DirectionalLight3D = _find_directional_light_by_name(child, target_name)
		if match_node != null:
			return match_node

	return null


func _collect_omni_lights_by_prefix(root: Node, name_prefix: String, output: Array[OmniLight3D]) -> void:
	if root == null:
		return
	if root is OmniLight3D and root.name.begins_with(name_prefix):
		output.append(root)

	for child in root.get_children():
		_collect_omni_lights_by_prefix(child, name_prefix, output)


func _collect_meshes_by_prefix(root: Node, name_prefix: String, output: Array[MeshInstance3D]) -> void:
	if root == null:
		return
	if root is MeshInstance3D and root.name.begins_with(name_prefix):
		output.append(root)

	for child in root.get_children():
		_collect_meshes_by_prefix(child, name_prefix, output)
