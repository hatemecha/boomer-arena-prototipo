class_name Dust2Arena
extends GlImportedArena

const DUST_LIGHT_PREFIX: String = "Dust2Light"
const DUST_SUN_COLOR: Color = Color(1.0, 0.82, 0.58)
const DUST_AMBIENT: Color = Color(0.72, 0.58, 0.38)

var _visual_director: PSXVisualDirector


func _ready() -> void:
	super._ready()
	_bind_visual_override()


func _exit_tree() -> void:
	_unbind_visual_override()


func _bind_visual_override() -> void:
	var game_root := get_parent()
	if game_root == null:
		return

	_visual_director = game_root.get_node_or_null("PSXVisualDirector") as PSXVisualDirector
	if _visual_director != null and not _visual_director.visual_style_refreshed.is_connected(_apply_dust2_visuals):
		_visual_director.visual_style_refreshed.connect(_apply_dust2_visuals)
	call_deferred("_apply_dust2_visuals", PSXVisualDirector.TimeOfDayPreset.AFTERNOON)


func _unbind_visual_override() -> void:
	if _visual_director != null and _visual_director.visual_style_refreshed.is_connected(_apply_dust2_visuals):
		_visual_director.visual_style_refreshed.disconnect(_apply_dust2_visuals)
	_visual_director = null


func _apply_dust2_visuals(_time_of_day_preset: PSXVisualDirector.TimeOfDayPreset) -> void:
	if not is_inside_tree():
		return

	var world_environment := get_node_or_null("WorldEnvironment") as WorldEnvironment
	if world_environment != null and world_environment.environment != null:
		_configure_dust2_environment(world_environment.environment)

	var directional := get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if directional != null:
		directional.light_color = DUST_SUN_COLOR
		directional.light_energy = 0.95
		directional.rotation_degrees = Vector3(-58.0, 32.0, 0.0)
		directional.shadow_enabled = false

	for child in get_children():
		if not (child is OmniLight3D) or not str(child.name).begins_with(DUST_LIGHT_PREFIX):
			continue
		var omni_light := child as OmniLight3D
		omni_light.light_color = DUST_SUN_COLOR
		omni_light.light_energy = 1.2
		omni_light.shadow_enabled = false
		omni_light.visible = true


func _configure_dust2_environment(environment: Environment) -> void:
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.55, 0.42, 0.28)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = DUST_AMBIENT
	environment.ambient_light_energy = 0.62
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.82, 0.62, 0.36)
	environment.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	environment.fog_density = 0.011
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 1.02
	environment.adjustment_contrast = 1.08
	environment.adjustment_saturation = 0.78
