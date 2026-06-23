class_name BackroomsArena
extends GlImportedArena

const BACKROOMS_LIGHT_PREFIX: String = "BackroomsLight"
const FLUORESCENT_COLOR: Color = Color(1.0, 0.9, 0.62)
const FLUORESCENT_AMBIENT: Color = Color(0.92, 0.86, 0.62)

var _visual_director: PSXVisualDirector


func _ready() -> void:
	super._ready()
	ArenaMarkersHelper.ensure_void_recovery(self)
	_bind_visual_override()


func _exit_tree() -> void:
	_unbind_visual_override()


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
		if not (child is OmniLight3D) or not str(child.name).begins_with(BACKROOMS_LIGHT_PREFIX):
			continue
		var omni_light := child as OmniLight3D
		omni_light.light_color = FLUORESCENT_COLOR
		omni_light.light_energy = 1.75
		omni_light.omni_range = 22.0
		omni_light.shadow_enabled = false
		omni_light.visible = true


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
