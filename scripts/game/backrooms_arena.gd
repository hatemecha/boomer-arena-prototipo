class_name BackroomsArena
extends GlImportedArena

const ARENA_LIGHT_PREFIX: String = "ArenaLight"
const LIGHT_PANEL_PREFIX: String = "LightPanel"
const FLUORESCENT_COLOR: Color = Color(1.0, 0.9, 0.62)
const FLUORESCENT_AMBIENT: Color = Color(0.92, 0.86, 0.62)
const FLUORESCENT_PANEL_EMISSION: Color = Color(1.0, 0.94, 0.28)
const FLUORESCENT_PANEL_ENERGY: float = 1.35
const EMISSIVE_LIGHT_THRESHOLD: float = 0.15

var _visual_director: PSXVisualDirector


func _ready() -> void:
	super._ready()
	_configure_disco_lighting()
	ArenaMarkersHelper.ensure_void_recovery(self)
	_bind_visual_override()
	ArenaMarkersHelper.notify_visual_director_scene_changed(self)


func _exit_tree() -> void:
	_unbind_visual_override()


func _configure_disco_lighting() -> void:
	_rename_node_if_exists("BackroomsLightNW", "ArenaLightNW")
	_rename_node_if_exists("BackroomsLightNE", "ArenaLightNE")
	_rename_node_if_exists("BackroomsLightSW", "ArenaLightSW")
	_rename_node_if_exists("BackroomsLightSE", "ArenaLightSE")
	_rename_node_if_exists("BackroomsLightHallwayA", "ArenaLightHallwayA")
	_rename_node_if_exists("BackroomsLightHallwayB", "ArenaLightHallwayB")
	_register_map_emissive_light_panels()


func _register_map_emissive_light_panels() -> void:
	var map_model := get_node_or_null("MapModel") as Node3D
	if map_model == null:
		return

	var panel_index := 0
	for node in map_model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance == null or str(mesh_instance.name).begins_with(LIGHT_PANEL_PREFIX):
			continue
		if not _mesh_has_emissive_light(mesh_instance):
			continue
		mesh_instance.name = "%sBackrooms%d" % [LIGHT_PANEL_PREFIX, panel_index]
		panel_index += 1


func _rename_node_if_exists(old_name: String, new_name: String) -> void:
	var node: Node = get_node_or_null(old_name)
	if node == null or has_node(new_name):
		return
	node.name = new_name


func _bind_visual_override() -> void:
	var game_root := get_parent()
	if game_root == null:
		return

	_visual_director = game_root.get_node_or_null("PSXVisualDirector") as PSXVisualDirector
	if _visual_director != null and not _visual_director.visual_style_refreshed.is_connected(_apply_backrooms_visuals):
		_visual_director.visual_style_refreshed.connect(_apply_backrooms_visuals)
	call_deferred("_apply_backrooms_visuals", PSXVisualDirector.TimeOfDayPreset.MORNING)


func _unbind_visual_override() -> void:
	if _visual_director != null and _visual_director.visual_style_refreshed.is_connected(_apply_backrooms_visuals):
		_visual_director.visual_style_refreshed.disconnect(_apply_backrooms_visuals)
	_visual_director = null


func _apply_backrooms_visuals(_time_of_day_preset: PSXVisualDirector.TimeOfDayPreset) -> void:
	if not is_inside_tree():
		return

	var world_environment := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world_environment != null and world_environment.environment != null:
		_configure_backrooms_environment(world_environment.environment)

	var directional := get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if directional != null:
		directional.light_color = FLUORESCENT_COLOR
		directional.light_energy = 0.42
		directional.rotation_degrees = Vector3(-82.0, 18.0, 0.0)
		directional.shadow_enabled = false

	for child in get_children():
		if not (child is OmniLight3D) or not str(child.name).begins_with(ARENA_LIGHT_PREFIX):
			continue
		var omni_light := child as OmniLight3D
		omni_light.light_color = FLUORESCENT_COLOR
		omni_light.light_energy = 1.75 if not str(omni_light.name).contains("Hallway") else 1.65
		omni_light.omni_range = 22.0
		omni_light.shadow_enabled = false
		omni_light.visible = true

	_apply_backrooms_fluorescent_panels()


func _apply_backrooms_fluorescent_panels() -> void:
	for node in find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance == null or not str(mesh_instance.name).begins_with(LIGHT_PANEL_PREFIX):
			continue
		_apply_fluorescent_panel_materials(mesh_instance)


func _apply_fluorescent_panel_materials(mesh_instance: MeshInstance3D) -> void:
	var mesh: Mesh = mesh_instance.mesh
	if mesh == null:
		return

	for surface_index in range(mesh.get_surface_count()):
		var panel_material := _ensure_panel_material_override(mesh_instance, surface_index)
		if panel_material == null:
			continue
		panel_material.emission_enabled = true
		panel_material.emission = FLUORESCENT_PANEL_EMISSION
		panel_material.emission_energy_multiplier = FLUORESCENT_PANEL_ENERGY


func _ensure_panel_material_override(mesh_instance: MeshInstance3D, surface_index: int) -> BaseMaterial3D:
	var override_material := mesh_instance.get_surface_override_material(surface_index)
	if override_material is BaseMaterial3D:
		return override_material as BaseMaterial3D

	var active_material := mesh_instance.get_active_material(surface_index)
	if active_material == null or not (active_material is BaseMaterial3D):
		return null

	var duplicated_material := active_material.duplicate() as BaseMaterial3D
	mesh_instance.set_surface_override_material(surface_index, duplicated_material)
	return duplicated_material


func _mesh_has_emissive_light(mesh_instance: MeshInstance3D) -> bool:
	var mesh: Mesh = mesh_instance.mesh
	if mesh == null:
		return false

	for surface_index in range(mesh.get_surface_count()):
		if _material_is_emissive_light(mesh_instance.get_active_material(surface_index)):
			return true
	return false


func _material_is_emissive_light(material: Material) -> bool:
	if material == null or not (material is BaseMaterial3D):
		return false

	var base_material := material as BaseMaterial3D
	if not base_material.emission_enabled:
		return false

	var material_name := str(base_material.resource_name).to_lower()
	if material_name.contains("light") or material_name.contains("ligt"):
		return true

	return _color_peak(base_material.emission) >= EMISSIVE_LIGHT_THRESHOLD


static func _color_peak(color: Color) -> float:
	return maxf(color.r, maxf(color.g, color.b))


func _configure_backrooms_environment(environment: Environment) -> void:
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.78, 0.72, 0.5)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = FLUORESCENT_AMBIENT
	environment.ambient_light_energy = 0.78
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.9, 0.84, 0.6)
	environment.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	environment.fog_density = 0.009
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 1.04
	environment.adjustment_contrast = 1.06
	environment.adjustment_saturation = 0.66
