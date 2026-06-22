class_name BackroomsArena
extends Node3D

const BACKROOMS_LIGHT_PREFIX: String = "BackroomsLight"
const FLUORESCENT_COLOR: Color = Color(1.0, 0.9, 0.62)
const FLUORESCENT_AMBIENT: Color = Color(0.92, 0.86, 0.62)

@export var map_model_path: NodePath = ^"MapModel"

var _visual_director: PSXVisualDirector


func _ready() -> void:
	var map_model := get_node_or_null(map_model_path) as Node3D
	if map_model == null:
		push_error("BackroomsArena requires a valid MapModel node.")
		return

	var collision_mesh_count := 0
	for node in map_model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		mesh_instance.create_trimesh_collision()
		_enable_backface_collision(mesh_instance)
		collision_mesh_count += 1

	if collision_mesh_count == 0:
		push_error("BackroomsArena could not create collision because the model contains no meshes.")

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


func _enable_backface_collision(mesh_instance: MeshInstance3D) -> void:
	for child in mesh_instance.get_children():
		var static_body := child as StaticBody3D
		if static_body == null:
			continue
		for body_child in static_body.get_children():
			var collision_shape := body_child as CollisionShape3D
			if collision_shape != null and collision_shape.shape is ConcavePolygonShape3D:
				(collision_shape.shape as ConcavePolygonShape3D).backface_collision = true


func _on_void_recovery_body_entered(body: Node3D) -> void:
	var player := body as PlayerController
	if player == null:
		return
	var game_root := get_parent()
	if game_root == null or not game_root.has_method("recover_player_from_world_bounds"):
		push_error("BackroomsArena requires a game root that can recover out-of-bounds players.")
		return
	game_root.call_deferred("recover_player_from_world_bounds", player)
