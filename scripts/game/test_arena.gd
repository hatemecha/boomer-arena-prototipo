class_name TestArena
extends Node3D

const WALL_MATERIAL: Material = preload("res://assets/materials/foxtex_concrete_wall.tres")
const CEILING_MATERIAL: Material = preload("res://assets/materials/foxtex_ceiling_panel.tres")
const DARK_PANEL_MATERIAL: Material = preload("res://assets/materials/foxtex_dark_panel.tres")
const RUST_MATERIAL: Material = preload("res://assets/materials/foxtex_rust_red_panel.tres")

var _openings_configured: bool = false


func _ready() -> void:
	_configure_real_window_openings()
	_configure_exterior_views()


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
