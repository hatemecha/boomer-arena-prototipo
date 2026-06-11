class_name IronHangarGeometry
extends RefCounted

## Static arena content for Iron Hangar (baked into the .tscn).
## Layout simple: piso central, dos balcones con rampas laterales, poca decoracion.

const MAT_FLOOR: Material = preload("res://assets/materials/foxtex_concrete_floor.tres")
const MAT_WALL: Material = preload("res://assets/materials/foxtex_concrete_wall.tres")
const MAT_CEIL: Material = preload("res://assets/materials/foxtex_ceiling_panel.tres")
const MAT_DARK: Material = preload("res://assets/materials/foxtex_dark_panel.tres")
const MAT_LIGHT: Material = preload("res://assets/materials/foxtex_light_panel_emissive.tres")
const MAT_GRATE: Material = preload("res://assets/materials/foxtex_metal_grate.tres")
const MAT_PLATE: Material = preload("res://assets/materials/foxtex_metal_plate.tres")
const MAT_TRIM: Material = preload("res://assets/materials/foxtex_metal_trim.tres")
const MAT_WARNING: Material = preload("res://assets/materials/foxtex_warning_stripes.tres")

const RX: float = 15.0
const RZN: float = 17.0
const RZS: float = 17.0
const CEIL_Y: float = 5.5
const BAL_Y: float = 2.5
const BAL_HX: float = 10.0
const BAL_ZN: float = 9.0
const BAL_ZS: float = 9.0
const RAMP_CX: float = 10.0
const RAMP_W: float = 3.5

const PIL_OFFSETS: Array = [
	Vector2(-5.0, 0.0), Vector2(5.0, 0.0),
]


func build(parent: Node3D) -> void:
	_build_all(parent)


func _build_all(parent: Node3D) -> void:
	_build_floors(parent)
	_build_ceiling(parent)
	_build_outer_walls(parent)
	_build_north_balcony(parent)
	_build_south_balcony(parent)
	_build_center_pillars(parent)
	_build_cover_blocks(parent)
	_build_trim_and_decor(parent)
	_build_world_environment(parent)
	_build_lighting(parent)


func _build_floors(parent: Node3D) -> void:
	_sbox(parent, "Floor", Vector3(0, -0.1, 0), Vector3(RX * 2.0, 0.2, RZN + RZS), MAT_FLOOR)
	_sbox(parent, "NBalconyFloor", Vector3(0, BAL_Y - 0.1, -(RZN - 4.0)), Vector3(BAL_HX * 2.0, 0.2, 8.0), MAT_PLATE)
	_sbox(parent, "SBalconyFloor", Vector3(0, BAL_Y - 0.1, +(RZS - 4.0)), Vector3(BAL_HX * 2.0, 0.2, 8.0), MAT_PLATE)
	_vbox(parent, "WarnN", Vector3(0, 0.01, -BAL_ZN + 0.75), Vector3(RX * 2.0, 0.02, 1.5), MAT_WARNING)
	_vbox(parent, "WarnS", Vector3(0, 0.01, +BAL_ZS - 0.75), Vector3(RX * 2.0, 0.02, 1.5), MAT_WARNING)
	_vbox(parent, "GrateC", Vector3(0, 0.01, 0), Vector3(6.0, 0.02, 6.0), MAT_GRATE)


func _build_ceiling(parent: Node3D) -> void:
	_sbox(parent, "Ceiling", Vector3(0, CEIL_Y + 0.1, 0), Vector3(RX * 2.0, 0.2, RZN + RZS), MAT_CEIL)
	_vbox(parent, "LightC", Vector3(0, CEIL_Y - 0.05, 0), Vector3(6.0, 0.1, 6.0), MAT_LIGHT)
	_vbox(parent, "LightNW", Vector3(-8.0, CEIL_Y - 0.05, -5.0), Vector3(5.0, 0.1, 4.0), MAT_LIGHT)
	_vbox(parent, "LightNE", Vector3(8.0, CEIL_Y - 0.05, -5.0), Vector3(5.0, 0.1, 4.0), MAT_LIGHT)
	_vbox(parent, "LightSW", Vector3(-8.0, CEIL_Y - 0.05, 5.0), Vector3(5.0, 0.1, 4.0), MAT_LIGHT)
	_vbox(parent, "LightSE", Vector3(8.0, CEIL_Y - 0.05, 5.0), Vector3(5.0, 0.1, 4.0), MAT_LIGHT)
	_vbox(parent, "LightNBal", Vector3(0, CEIL_Y - 0.05, -13.0), Vector3(14.0, 0.1, 5.0), MAT_LIGHT)
	_vbox(parent, "LightSBal", Vector3(0, CEIL_Y - 0.05, 13.0), Vector3(14.0, 0.1, 5.0), MAT_LIGHT)


func _build_outer_walls(parent: Node3D) -> void:
	var mid_y: float = CEIL_Y * 0.5
	var total_d: float = RZN + RZS
	_sbox(parent, "WallN", Vector3(0, mid_y, -(RZN + 0.25)), Vector3(RX * 2.0, CEIL_Y, 0.5), MAT_WALL)
	_sbox(parent, "WallS", Vector3(0, mid_y, +(RZS + 0.25)), Vector3(RX * 2.0, CEIL_Y, 0.5), MAT_WALL)
	_sbox(parent, "WallW", Vector3(-(RX + 0.25), mid_y, 0), Vector3(0.5, CEIL_Y, total_d), MAT_WALL)
	_sbox(parent, "WallE", Vector3(+(RX + 0.25), mid_y, 0), Vector3(0.5, CEIL_Y, total_d), MAT_WALL)
	_vbox(parent, "TrimN", Vector3(0, 0.3, -RZN + 0.05), Vector3(RX * 2.0, 0.6, 0.1), MAT_TRIM)
	_vbox(parent, "TrimS", Vector3(0, 0.3, RZS - 0.05), Vector3(RX * 2.0, 0.6, 0.1), MAT_TRIM)
	_vbox(parent, "TrimW", Vector3(-RX + 0.05, 0.3, 0), Vector3(0.1, 0.6, total_d), MAT_TRIM)
	_vbox(parent, "TrimE", Vector3(RX - 0.05, 0.3, 0), Vector3(0.1, 0.6, total_d), MAT_TRIM)


func _build_north_balcony(parent: Node3D) -> void:
	_vbox(parent, "NBalconyRail", Vector3(0, BAL_Y + 0.45, -BAL_ZN + 0.25), Vector3(BAL_HX * 2.0, 0.9, 0.2), MAT_TRIM)
	_stairs_z(parent, "RampNW", -RAMP_CX, RAMP_W, -5.5, -10.0, 0.0, BAL_Y, 5)
	_stairs_z(parent, "RampNE", +RAMP_CX, RAMP_W, -5.5, -10.0, 0.0, BAL_Y, 5)


func _build_south_balcony(parent: Node3D) -> void:
	_vbox(parent, "SBalconyRail", Vector3(0, BAL_Y + 0.45, +BAL_ZS - 0.25), Vector3(BAL_HX * 2.0, 0.9, 0.2), MAT_TRIM)
	_stairs_z(parent, "RampSW", -RAMP_CX, RAMP_W, +5.5, +10.0, 0.0, BAL_Y, 5)
	_stairs_z(parent, "RampSE", +RAMP_CX, RAMP_W, +5.5, +10.0, 0.0, BAL_Y, 5)


func _build_center_pillars(parent: Node3D) -> void:
	for i in range(PIL_OFFSETS.size()):
		var pillar_offset: Vector2 = PIL_OFFSETS[i]
		var bx: float = pillar_offset.x
		var bz: float = pillar_offset.y
		_sbox(parent, "Pillar%d" % i, Vector3(bx, CEIL_Y * 0.5, bz), Vector3(1.6, CEIL_Y, 1.6), MAT_DARK)
		_vbox(parent, "PillarBase%d" % i, Vector3(bx, 0.2, bz), Vector3(2.0, 0.4, 2.0), MAT_TRIM)


func _build_cover_blocks(parent: Node3D) -> void:
	_sbox(parent, "CoverW", Vector3(-12.5, 0.8, -6.0), Vector3(1.5, 1.6, 2.5), MAT_PLATE)
	_sbox(parent, "CoverE", Vector3(+12.5, 0.8, 6.0), Vector3(1.5, 1.6, 2.5), MAT_PLATE)


func _build_trim_and_decor(parent: Node3D) -> void:
	_vbox(parent, "BeamZ1", Vector3(-7.0, CEIL_Y - 0.35, 0), Vector3(0.6, 0.7, RZN + RZS), MAT_DARK)
	_vbox(parent, "BeamZ2", Vector3(+7.0, CEIL_Y - 0.35, 0), Vector3(0.6, 0.7, RZN + RZS), MAT_DARK)


func _build_world_environment(parent: Node3D) -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.06, 0.06, 0.07, 1)
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.32, 0.32, 0.36, 1)
	environment.fog_density = 0.018
	world_environment.environment = environment
	parent.add_child(world_environment)


func _build_lighting(parent: Node3D) -> void:
	var key := DirectionalLight3D.new()
	key.name = "KeyLight"
	key.shadow_enabled = false
	key.light_energy = 1.6
	key.light_color = Color(0.95, 0.92, 0.84)
	key.rotation_degrees = Vector3(-75.0, 30.0, 0.0)
	parent.add_child(key)

	var fill := DirectionalLight3D.new()
	fill.name = "FillLight"
	fill.shadow_enabled = false
	fill.light_energy = 0.45
	fill.light_color = Color(0.55, 0.65, 0.80)
	fill.rotation_degrees = Vector3(25.0, -150.0, 0.0)
	parent.add_child(fill)

	var ceil_drop: float = CEIL_Y - 0.6
	var omni_data: Array[Dictionary] = [
		{"pos": Vector3(0.0, ceil_drop, 0.0), "e": 2.0, "r": 18.0, "c": Color(0.82, 0.88, 0.95)},
		{"pos": Vector3(-8.0, ceil_drop, -6.0), "e": 1.6, "r": 16.0, "c": Color(0.82, 0.88, 0.95)},
		{"pos": Vector3(+8.0, ceil_drop, -6.0), "e": 1.6, "r": 16.0, "c": Color(0.82, 0.88, 0.95)},
		{"pos": Vector3(-8.0, ceil_drop, +6.0), "e": 1.6, "r": 16.0, "c": Color(0.82, 0.88, 0.95)},
		{"pos": Vector3(+8.0, ceil_drop, +6.0), "e": 1.6, "r": 16.0, "c": Color(0.82, 0.88, 0.95)},
		{"pos": Vector3(0.0, ceil_drop, -13.5), "e": 1.8, "r": 12.0, "c": Color(0.95, 0.85, 0.70)},
		{"pos": Vector3(0.0, ceil_drop, +13.5), "e": 1.8, "r": 12.0, "c": Color(0.95, 0.85, 0.70)},
	]
	for i in range(omni_data.size()):
		var data: Dictionary = omni_data[i]
		var omni := OmniLight3D.new()
		omni.name = "Omni%d" % i
		omni.position = data["pos"]
		omni.shadow_enabled = false
		omni.light_color = data["c"]
		omni.light_energy = data["e"]
		omni.omni_range = data["r"]
		omni.light_indirect_energy = 0.4
		parent.add_child(omni)

	var ramp_lights: Array[Vector3] = [
		Vector3(-RAMP_CX, 2.0, -7.5),
		Vector3(+RAMP_CX, 2.0, -7.5),
		Vector3(-RAMP_CX, 2.0, +7.5),
		Vector3(+RAMP_CX, 2.0, +7.5),
	]
	for i in range(ramp_lights.size()):
		var ramp_light := OmniLight3D.new()
		ramp_light.name = "RampLight%d" % i
		ramp_light.position = ramp_lights[i]
		ramp_light.shadow_enabled = false
		ramp_light.light_color = Color(1.0, 0.15, 0.10)
		ramp_light.light_energy = 1.6
		ramp_light.omni_range = 7.0
		ramp_light.light_indirect_energy = 0.2
		parent.add_child(ramp_light)


func _stairs_z(
	parent: Node3D,
	stair_id: String,
	center_x: float,
	width: float,
	z_start: float,
	z_end: float,
	y_floor: float,
	y_top: float,
	step_count: int
) -> void:
	var dz: float = (z_end - z_start) / float(step_count)
	var dy: float = (y_top - y_floor) / float(step_count)
	for i in range(step_count):
		var surface_y: float = y_floor + dy * float(i + 1)
		var center_z: float = z_start + dz * (float(i) + 0.5)
		var height: float = surface_y - y_floor
		_sbox(
			parent,
			"%s_%d" % [stair_id, i],
			Vector3(center_x, y_floor + height * 0.5, center_z),
			Vector3(width, height, absf(dz)),
			MAT_TRIM
		)


func _sbox(parent: Node3D, node_name: String, box_position: Vector3, box_size: Vector3, material: Material) -> void:
	var static_body := StaticBody3D.new()
	static_body.name = node_name
	static_body.position = box_position
	parent.add_child(static_body)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "MeshInstance3D"
	var box_mesh := BoxMesh.new()
	box_mesh.size = box_size
	mesh_instance.mesh = box_mesh
	mesh_instance.set_surface_override_material(0, material)
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	static_body.add_child(mesh_instance)

	var collision_shape := CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	var box_shape := BoxShape3D.new()
	box_shape.size = box_size
	collision_shape.shape = box_shape
	static_body.add_child(collision_shape)


func _vbox(parent: Node3D, node_name: String, box_position: Vector3, box_size: Vector3, material: Material) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	mesh_instance.position = box_position
	var box_mesh := BoxMesh.new()
	box_mesh.size = box_size
	mesh_instance.mesh = box_mesh
	mesh_instance.set_surface_override_material(0, material)
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh_instance)
