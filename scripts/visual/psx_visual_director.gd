class_name PSXVisualDirector
extends Node

enum TimeOfDayPreset {
	MORNING,
	AFTERNOON,
	NIGHT,
}

const PSX_SHADER: Shader = preload("res://shaders/psx_palette_filter.gdshader")

@export var enabled: bool = true
@export var time_of_day_preset: TimeOfDayPreset = TimeOfDayPreset.NIGHT
@export var post_process_enabled: bool = true
@export var enforce_nearest_filtering: bool = true
@export_range(0.0, 0.08, 0.005) var dither_strength: float = 0.025
@export_range(2.0, 16.0, 1.0) var color_levels: float = 6.0
@export_range(0.0, 1.0, 0.01) var palette_mix: float = 0.42
@export_range(0.0, 0.2, 0.002) var fisheye_strength: float = 0.06
@export_range(0.0, 0.02, 0.0005) var chromatic_aberration_strength: float = 0.0018
@export_range(0.0, 1.0, 0.01) var vignette_strength: float = 0.18
@export_range(0.2, 1.5, 0.01) var vignette_radius: float = 1.08
@export_range(0.05, 1.0, 0.01) var vignette_softness: float = 0.72
@export_range(0.0, 0.5, 0.01) var lens_dirt_strength: float = 0.05

var _post_process_layer: CanvasLayer
var _post_process_rect: ColorRect
var _post_process_material: ShaderMaterial
var _nearest_filtering_applied: bool = false


func _ready() -> void:
	call_deferred("refresh_visual_style")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F6:
		cycle_time_of_day_preset()


func cycle_time_of_day_preset() -> void:
	time_of_day_preset = ((time_of_day_preset + 1) % TimeOfDayPreset.size()) as TimeOfDayPreset
	refresh_visual_style()


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


func _configure_environment(environment: Environment) -> void:
	environment.background_mode = Environment.BG_COLOR
	environment.fog_enabled = true
	environment.volumetric_fog_enabled = false
	environment.glow_enabled = false
	environment.ssao_enabled = false
	environment.ssil_enabled = false
	environment.sdfgi_enabled = false
	environment.adjustment_enabled = true

	match time_of_day_preset:
		TimeOfDayPreset.MORNING:
			environment.background_color = Color(0.47, 0.45, 0.4)
			environment.ambient_light_color = Color(0.78, 0.72, 0.58)
			environment.ambient_light_energy = 0.42
			environment.fog_light_color = Color(0.72, 0.68, 0.58)
			environment.fog_density = 0.018
			environment.adjustment_brightness = 0.96
			environment.adjustment_contrast = 1.05
			environment.adjustment_saturation = 0.58
		TimeOfDayPreset.AFTERNOON:
			environment.background_color = Color(0.18, 0.15, 0.13)
			environment.ambient_light_color = Color(0.66, 0.54, 0.44)
			environment.ambient_light_energy = 0.46
			environment.fog_light_color = Color(0.48, 0.38, 0.32)
			environment.fog_density = 0.02
			environment.adjustment_brightness = 0.98
			environment.adjustment_contrast = 1.08
			environment.adjustment_saturation = 0.56
		TimeOfDayPreset.NIGHT:
			environment.background_color = Color(0.055, 0.065, 0.085)
			environment.ambient_light_color = Color(0.46, 0.52, 0.66)
			environment.ambient_light_energy = 0.62
			environment.fog_light_color = Color(0.26, 0.3, 0.38)
			environment.fog_density = 0.022
			environment.adjustment_brightness = 1.04
			environment.adjustment_contrast = 1.08
			environment.adjustment_saturation = 0.62


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
	var danger_color: Color = Color(0.86, 0.05, 0.035)
	var contrast: float
	var brightness: float

	match time_of_day_preset:
		TimeOfDayPreset.MORNING:
			tint_color = Color(0.94, 0.9, 0.76)
			contrast = 1.04
			brightness = 0.015
		TimeOfDayPreset.AFTERNOON:
			tint_color = Color(0.9, 0.78, 0.66)
			contrast = 1.06
			brightness = 0.015
		TimeOfDayPreset.NIGHT:
			tint_color = Color(0.72, 0.78, 0.96)
			contrast = 1.08
			brightness = 0.035

	_post_process_material.set_shader_parameter("color_levels", color_levels)
	_post_process_material.set_shader_parameter("dither_strength", dither_strength)
	_post_process_material.set_shader_parameter("palette_mix", palette_mix)
	_post_process_material.set_shader_parameter("fisheye_strength", fisheye_strength)
	_post_process_material.set_shader_parameter("chromatic_aberration_strength", chromatic_aberration_strength)
	_post_process_material.set_shader_parameter("vignette_strength", vignette_strength)
	_post_process_material.set_shader_parameter("vignette_radius", vignette_radius)
	_post_process_material.set_shader_parameter("vignette_softness", vignette_softness)
	_post_process_material.set_shader_parameter("lens_dirt_strength", lens_dirt_strength)
	_post_process_material.set_shader_parameter("lens_aspect_ratio", _get_viewport_aspect_ratio())
	_post_process_material.set_shader_parameter("tint_color", Vector3(tint_color.r, tint_color.g, tint_color.b))
	_post_process_material.set_shader_parameter("danger_color", Vector3(danger_color.r, danger_color.g, danger_color.b))
	_post_process_material.set_shader_parameter("contrast", contrast)
	_post_process_material.set_shader_parameter("brightness", brightness)


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
