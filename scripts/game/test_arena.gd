class_name TestArena
extends Node3D

const WALL_MATERIAL: Material = preload("res://assets/materials/foxtex_concrete_wall.tres")
const CEILING_MATERIAL: Material = preload("res://assets/materials/foxtex_ceiling_panel.tres")
const DARK_PANEL_MATERIAL: Material = preload("res://assets/materials/foxtex_dark_panel.tres")
const RUST_MATERIAL: Material = preload("res://assets/materials/foxtex_rust_red_panel.tres")
const TRIM_MATERIAL: Material = preload("res://assets/materials/foxtex_metal_trim.tres")
const PIPES_SCENE: PackedScene = preload("res://assets/models/props/industrial/pipes.glb")
const WIRES_SCENE: PackedScene = preload("res://assets/models/props/industrial/wires.glb")
const TRANSFORMER_SCENE: PackedScene = preload("res://assets/models/props/industrial/transformer.glb")
const CIRCUIT_BREAKER_SCENE: PackedScene = preload("res://assets/models/props/industrial/circuit_breaker.glb")
const PIPE_VALVE_SCENE: PackedScene = preload("res://assets/models/props/industrial/pipe_valve.glb")

var _openings_configured: bool = false
var _props_configured: bool = false


func _ready() -> void:
	_configure_real_window_openings()
	_configure_exterior_views()
	_configure_aisle_fill_lights()
	_configure_industrial_props()
	_configure_gameplay_markers()
	_notify_visual_director_scene_changed()


func _configure_real_window_openings() -> void:
	if _openings_configured:
		return
	_openings_configured = true

	for blocked_node_name in ["UpperNorthWall", "UpperSouthWall", "UpperWestWall", "UpperEastWall", "Ceiling"]:
		_disable_static_body(blocked_node_name)

	_create_static_box("UpperNorthWall_LeftSegment", Vector3(-9.75, 7.0, -17.0), Vector3(14.5, 4.0, 0.8), WALL_MATERIAL)
	_create_static_box("UpperNorthWall_RightSegment", Vector3(9.75, 7.0, -17.0), Vector3(14.5, 4.0, 0.8), WALL_MATERIAL)
	_create_static_box("UpperNorthWall_Lintel", Vector3(0.0, 8.275, -17.0), Vector3(5.0, 1.45, 0.8), WALL_MATERIAL)
	_create_static_box("UpperNorthWall_Sill", Vector3(0.0, 5.35, -17.0), Vector3(5.0, 0.7, 0.8), WALL_MATERIAL)

	_create_static_box("UpperSouthWall_LeftSegment", Vector3(-9.75, 7.0, 17.0), Vector3(14.5, 4.0, 0.8), WALL_MATERIAL)
	_create_static_box("UpperSouthWall_RightSegment", Vector3(9.75, 7.0, 17.0), Vector3(14.5, 4.0, 0.8), WALL_MATERIAL)
	_create_static_box("UpperSouthWall_Lintel", Vector3(0.0, 8.275, 17.0), Vector3(5.0, 1.45, 0.8), WALL_MATERIAL)
	_create_static_box("UpperSouthWall_Sill", Vector3(0.0, 5.35, 17.0), Vector3(5.0, 0.7, 0.8), WALL_MATERIAL)

	_create_static_box("UpperWestWall_LeftSegment", Vector3(-17.0, 7.0, -9.75), Vector3(0.8, 4.0, 14.5), WALL_MATERIAL)
	_create_static_box("UpperWestWall_RightSegment", Vector3(-17.0, 7.0, 9.75), Vector3(0.8, 4.0, 14.5), WALL_MATERIAL)
	_create_static_box("UpperWestWall_Lintel", Vector3(-17.0, 8.275, 0.0), Vector3(0.8, 1.45, 5.0), WALL_MATERIAL)
	_create_static_box("UpperWestWall_Sill", Vector3(-17.0, 5.35, 0.0), Vector3(0.8, 0.7, 5.0), WALL_MATERIAL)

	_create_static_box("UpperEastWall_LeftSegment", Vector3(17.0, 7.0, -9.75), Vector3(0.8, 4.0, 14.5), WALL_MATERIAL)
	_create_static_box("UpperEastWall_RightSegment", Vector3(17.0, 7.0, 9.75), Vector3(0.8, 4.0, 14.5), WALL_MATERIAL)
	_create_static_box("UpperEastWall_Lintel", Vector3(17.0, 8.275, 0.0), Vector3(0.8, 1.45, 5.0), WALL_MATERIAL)
	_create_static_box("UpperEastWall_Sill", Vector3(17.0, 5.35, 0.0), Vector3(0.8, 0.7, 5.0), WALL_MATERIAL)

	_create_static_box("CeilingNorthPanel", Vector3(0.0, 9.25, -9.175), Vector3(34.0, 0.5, 15.65), CEILING_MATERIAL)
	_create_static_box("CeilingSouthPanel", Vector3(0.0, 9.25, 9.175), Vector3(34.0, 0.5, 15.65), CEILING_MATERIAL)
	_create_static_box("CeilingWestOuterPanel", Vector3(-13.85, 9.25, 0.0), Vector3(6.3, 0.5, 2.7), CEILING_MATERIAL)
	_create_static_box("CeilingCenterPanel", Vector3(0.0, 9.25, 0.0), Vector3(7.4, 0.5, 2.7), CEILING_MATERIAL)
	_create_static_box("CeilingEastOuterPanel", Vector3(13.85, 9.25, 0.0), Vector3(6.3, 0.5, 2.7), CEILING_MATERIAL)


func _configure_exterior_views() -> void:
	_configure_sky_portal("SkyPortalNorthWindow", Vector3(0.0, 6.65, -24.0), Vector3(3.0, 2.4, 1.0))
	_configure_sky_portal("SkyPortalSouthWindow", Vector3(0.0, 6.65, 24.0), Vector3(3.0, 2.4, 1.0))
	_configure_sky_portal("SkyPortalWestWindow", Vector3(-24.0, 6.65, 0.0), Vector3(3.0, 2.4, 1.0))
	_configure_sky_portal("SkyPortalEastWindow", Vector3(24.0, 6.65, 0.0), Vector3(3.0, 2.4, 1.0))
	_configure_sky_portal("SkyPortalRoofWest", Vector3(-7.2, 12.0, 0.0), Vector3(2.0, 2.0, 1.0))
	_configure_sky_portal("SkyPortalRoofEast", Vector3(7.2, 12.0, 0.0), Vector3(2.0, 2.0, 1.0))

	_create_visual_box("ExteriorNorthBlock_A", Vector3(-3.8, 4.0, -20.4), Vector3(2.0, 4.2, 1.2), DARK_PANEL_MATERIAL)
	_create_visual_box("ExteriorNorthBlock_B", Vector3(2.4, 4.6, -21.2), Vector3(1.5, 5.4, 1.0), RUST_MATERIAL)
	_create_visual_box("ExteriorSouthBlock_A", Vector3(-2.2, 4.4, 20.5), Vector3(1.6, 5.0, 1.2), DARK_PANEL_MATERIAL)
	_create_visual_box("ExteriorSouthBlock_B", Vector3(3.5, 3.8, 21.4), Vector3(2.2, 3.8, 1.0), RUST_MATERIAL)
	_create_visual_box("ExteriorWestBlock_A", Vector3(-20.7, 4.2, -3.2), Vector3(1.0, 4.6, 1.8), DARK_PANEL_MATERIAL)
	_create_visual_box("ExteriorWestBlock_B", Vector3(-21.5, 4.9, 2.6), Vector3(1.1, 5.8, 1.4), RUST_MATERIAL)
	_create_visual_box("ExteriorEastBlock_A", Vector3(20.6, 4.0, -2.8), Vector3(1.0, 4.2, 1.8), RUST_MATERIAL)
	_create_visual_box("ExteriorEastBlock_B", Vector3(21.5, 5.0, 3.1), Vector3(1.2, 6.0, 1.6), DARK_PANEL_MATERIAL)


func _disable_static_body(node_name: String) -> void:
	var static_body: Node3D = get_node_or_null(node_name) as Node3D
	if static_body == null:
		return

	static_body.visible = false
	for child in static_body.get_children():
		if child is CollisionShape3D:
			(child as CollisionShape3D).disabled = true


func _create_static_box(node_name: String, box_position: Vector3, box_size: Vector3, material: Material) -> void:
	if has_node(node_name):
		return

	var static_body := StaticBody3D.new()
	static_body.name = node_name
	static_body.position = box_position
	add_child(static_body)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "MeshInstance3D"
	var box_mesh := BoxMesh.new()
	box_mesh.size = box_size
	mesh_instance.mesh = box_mesh
	mesh_instance.set_surface_override_material(0, material)
	static_body.add_child(mesh_instance)

	var collision_shape := CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	var box_shape := BoxShape3D.new()
	box_shape.size = box_size
	collision_shape.shape = box_shape
	static_body.add_child(collision_shape)


func _create_visual_box(node_name: String, box_position: Vector3, box_size: Vector3, material: Material) -> void:
	if has_node(node_name):
		return

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = box_position
	var box_mesh := BoxMesh.new()
	box_mesh.size = box_size
	mesh_instance.mesh = box_mesh
	mesh_instance.set_surface_override_material(0, material)
	add_child(mesh_instance)


func _configure_sky_portal(node_name: String, portal_position: Vector3, portal_scale: Vector3) -> void:
	var sky_portal: Node3D = get_node_or_null(node_name) as Node3D
	if sky_portal == null:
		return
	sky_portal.position = portal_position
	sky_portal.scale = portal_scale


func _configure_aisle_fill_lights() -> void:
	_create_aisle_fill_light("AisleFillCenter", Vector3(0.0, 4.2, 0.0))
	_create_aisle_fill_light("AisleFillWest", Vector3(-6.0, 3.6, -5.0))
	_create_aisle_fill_light("AisleFillEast", Vector3(6.0, 3.6, 5.0))
	_create_aisle_fill_light("AisleFillNorth", Vector3(0.0, 3.8, -8.0))
	_create_aisle_fill_light("AisleFillSouth", Vector3(0.0, 3.8, 8.0))
	_create_aisle_fill_light("AisleFillLowCenter", Vector3(0.0, 2.6, 0.0))


func _create_aisle_fill_light(light_name: String, light_position: Vector3) -> void:
	if has_node(light_name):
		return

	var aisle_light := OmniLight3D.new()
	aisle_light.name = light_name
	aisle_light.position = light_position
	aisle_light.shadow_enabled = false
	aisle_light.light_color = Color(0.5, 0.72, 0.82)
	aisle_light.light_energy = 1.35
	aisle_light.omni_range = 16.0
	aisle_light.light_indirect_energy = 0.22
	add_child(aisle_light)


func _configure_industrial_props() -> void:
	if _props_configured:
		return
	_props_configured = true

	_spawn_prop_scene(PIPES_SCENE, "PropCeilingPipes", Vector3(-2.0, 8.35, -6.0), Vector3(1.15, 1.15, 1.15), Vector3(0.0, 1.5708, 0.0))
	_spawn_prop_scene(WIRES_SCENE, "PropCeilingWires", Vector3(6.5, 8.1, -1.5), Vector3(0.9, 0.9, 0.9), Vector3(0.0, -0.35, 0.0))
	_spawn_prop_scene(TRANSFORMER_SCENE, "PropWestTransformer", Vector3(-15.2, 1.1, -11.0), Vector3(0.75, 0.75, 0.75), Vector3(0.0, 1.5708, 0.0))
	_spawn_prop_scene(CIRCUIT_BREAKER_SCENE, "PropEastBreaker", Vector3(15.85, 2.0, -5.5), Vector3(0.55, 0.55, 0.55), Vector3(0.0, -1.5708, 0.0))
	_spawn_prop_scene(PIPE_VALVE_SCENE, "PropNorthValve", Vector3(3.2, 3.55, -16.35), Vector3(0.45, 0.45, 0.45), Vector3(0.0, 3.14159, 0.0))


func _spawn_prop_scene(
	prop_scene: PackedScene,
	node_name: String,
	prop_position: Vector3,
	prop_scale: Vector3,
	prop_rotation: Vector3
) -> void:
	if has_node(node_name) or prop_scene == null:
		return

	var prop_root: Node3D = prop_scene.instantiate() as Node3D
	if prop_root == null:
		push_warning("Industrial prop %s did not instantiate as Node3D." % node_name)
		return

	prop_root.name = node_name
	prop_root.position = prop_position
	prop_root.rotation = prop_rotation
	prop_root.scale = prop_scale
	add_child(prop_root)
	_apply_psx_materials(prop_root, TRIM_MATERIAL)


func _configure_gameplay_markers() -> void:
	if has_node("SpawnPoints"):
		return

	var spawn_root := Node3D.new()
	spawn_root.name = "SpawnPoints"
	add_child(spawn_root)

	var spawn_positions: Array[Vector3] = [
		Vector3(0.0, 0.0, 11.0),
		Vector3(0.0, 0.0, -11.0),
		Vector3(-11.0, 0.0, 0.0),
		Vector3(11.0, 0.0, 0.0),
	]
	var spawn_yaws: Array[float] = [PI, 0.0, PI * 0.5, -PI * 0.5]
	for index in range(spawn_positions.size()):
		var marker := Marker3D.new()
		marker.name = "Spawn%d" % index
		marker.position = spawn_positions[index]
		marker.rotation.y = spawn_yaws[index]
		marker.add_to_group("spawn_points")
		spawn_root.add_child(marker)

	var camera_root := Node3D.new()
	camera_root.name = "ArenaCameras"
	add_child(camera_root)

	var corner_positions: Array[Vector3] = [
		Vector3(-13.0, 6.5, -13.0),
		Vector3(13.0, 6.5, -13.0),
		Vector3(-13.0, 6.5, 13.0),
		Vector3(13.0, 6.5, 13.0),
	]
	for index in range(corner_positions.size()):
		var camera_marker := Marker3D.new()
		camera_marker.name = "ArenaCam%d" % index
		camera_marker.position = corner_positions[index]
		camera_root.add_child(camera_marker)
		camera_marker.look_at(Vector3(0.0, 1.2, 0.0), Vector3.UP)


func get_best_corner_transform_for_action(action_position: Vector3) -> Transform3D:
	var camera_root: Node3D = get_node_or_null("ArenaCameras") as Node3D
	if camera_root == null:
		return Transform3D(Basis(), action_position + Vector3(8.0, 5.0, 8.0))

	var best_transform: Transform3D = Transform3D(Basis(), action_position + Vector3(8.0, 5.0, 8.0))
	var best_distance: float = -1.0
	for child in camera_root.get_children():
		if not (child is Marker3D):
			continue
		var marker: Marker3D = child as Marker3D
		var distance_squared: float = marker.global_position.distance_squared_to(action_position)
		if distance_squared > best_distance:
			best_distance = distance_squared
			best_transform = marker.global_transform
	return best_transform


func _notify_visual_director_scene_changed() -> void:
	var game_root: Node = get_parent()
	if game_root == null:
		return
	var visual_director: PSXVisualDirector = game_root.get_node_or_null("PSXVisualDirector") as PSXVisualDirector
	if visual_director != null:
		visual_director.invalidate_scene_cache()
		visual_director.refresh_visual_style()


func _apply_psx_materials(root: Node, material: Material) -> void:
	if material == null:
		return
	for mesh_instance in root.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := mesh_instance as MeshInstance3D
		var mesh: Mesh = mesh_node.mesh
		if mesh == null:
			continue
		for surface_index in range(mesh.get_surface_count()):
			var surface_material: Material = material.duplicate()
			if surface_material is BaseMaterial3D:
				(surface_material as BaseMaterial3D).texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			mesh_node.set_surface_override_material(surface_index, surface_material)
