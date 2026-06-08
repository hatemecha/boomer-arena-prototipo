class_name MuzzleFlashVFX
extends Node3D

## Four-layer GPU muzzle flash. Attach this scene to a weapon muzzle and call trigger_shot().

const MAIN_FLASH_LAYER := "MuzzlePlanes"
const CONE_LAYER := "MuzzleCone"
const BEAM_LAYER := "BeamFlash"
const SPARKS_LAYER := "MuzzleSparks"

@export var flash_color: Color = Color(2.8, 1.45, 0.32, 1.0)
@export var spark_color: Color = Color(3.2, 1.85, 0.48, 1.0)
@export_range(0.05, 0.1, 0.005) var flash_lifetime: float = 0.065
@export_range(0.06, 0.14, 0.005) var spark_lifetime: float = 0.1
@export_range(10, 20, 1) var spark_count: int = 14
@export var forward_axis: Vector3 = Vector3.FORWARD

var _layers: Array[GPUParticles3D] = []
var _generated_textures: Array[Texture2D] = []


func _ready() -> void:
	_rebuild_layers()


func trigger_shot() -> void:
	for layer in _layers:
		if not is_instance_valid(layer):
			continue
		layer.restart()
		layer.emitting = true


func _rebuild_layers() -> void:
	for child in get_children():
		child.queue_free()

	_layers.clear()
	_generated_textures.clear()

	var direction := _get_forward_direction()
	_layers.append(_create_main_flash_layer(direction))
	_layers.append(_create_cone_layer(direction))
	_layers.append(_create_beam_layer())
	_layers.append(_create_sparks_layer(direction))

	for layer in _layers:
		add_child(layer)
		layer.owner = owner


func _create_main_flash_layer(direction: Vector3) -> GPUParticles3D:
	return _create_layer(
		MAIN_FLASH_LAYER,
		1,
		flash_lifetime,
		1.0,
		_create_cross_planes_mesh(0.62, 0.42, direction),
		_create_additive_material(flash_color, 1.2),
		_create_static_blast_process(direction, _create_main_scale_curve(), flash_color)
	)


func _create_cone_layer(direction: Vector3) -> GPUParticles3D:
	return _create_layer(
		CONE_LAYER,
		1,
		flash_lifetime,
		1.0,
		_create_open_cone_mesh(0.1, 0.44, 0.58, 12, direction),
		_create_additive_material(flash_color * Color(1.0, 0.78, 0.55, 1.0), 0.9, _create_fire_streak_texture()),
		_create_static_blast_process(direction, _create_cone_scale_curve(), flash_color)
	)


func _create_beam_layer() -> GPUParticles3D:
	var material := _create_additive_material(flash_color * Color(1.25, 1.12, 0.82, 1.0), 1.4, _create_soft_glow_texture())
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.billboard_keep_scale = true

	var process := _create_static_blast_process(Vector3.FORWARD, _create_main_scale_curve(), flash_color)
	process.scale_min = 0.5
	process.scale_max = 1.1

	return _create_layer(
		BEAM_LAYER,
		1,
		flash_lifetime,
		1.0,
		_create_quad_mesh(Vector2(0.72, 0.72)),
		material,
		process
	)


func _create_sparks_layer(direction: Vector3) -> GPUParticles3D:
	var process := ParticleProcessMaterial.new()
	process.direction = direction
	process.spread = 13.0
	process.initial_velocity_min = 5.0
	process.initial_velocity_max = 10.0
	process.gravity = Vector3(0.0, -1.8, 0.0)
	process.damping_min = 5.0
	process.damping_max = 9.0
	process.scale_min = 0.55
	process.scale_max = 1.0
	process.scale_curve = _create_spark_scale_curve()
	process.color = spark_color
	process.color_ramp = _create_spark_alpha_ramp()
	process.particle_flag_align_y = true

	return _create_layer(
		SPARKS_LAYER,
		spark_count,
		spark_lifetime,
		0.92,
		_create_quad_mesh(Vector2(0.05, 0.32)),
		_create_additive_material(spark_color, 1.6, _create_soft_glow_texture()),
		process
	)


func _create_layer(
	layer_name: String,
	amount: int,
	lifetime: float,
	explosiveness: float,
	mesh: Mesh,
	material: StandardMaterial3D,
	process: ParticleProcessMaterial
) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = layer_name
	particles.amount = amount
	particles.lifetime = lifetime
	particles.one_shot = true
	particles.explosiveness = explosiveness
	particles.randomness = 0.25
	particles.fixed_fps = 0
	particles.interpolate = false
	particles.fract_delta = true
	particles.local_coords = true
	particles.process_material = process
	particles.draw_pass_1 = mesh
	particles.material_override = material
	particles.emitting = false
	return particles


func _create_additive_material(
	tint: Color,
	emission_energy: float,
	albedo_texture: Texture2D = null
) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.vertex_color_use_as_albedo = true
	material.albedo_color = tint
	material.emission_enabled = true
	material.emission = tint
	material.emission_energy_multiplier = emission_energy
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST

	if albedo_texture != null:
		material.albedo_texture = albedo_texture

	return material


func _create_static_blast_process(
	direction: Vector3,
	scale_curve: CurveTexture,
	color: Color
) -> ParticleProcessMaterial:
	var process := ParticleProcessMaterial.new()
	process.direction = direction
	process.spread = 0.0
	process.initial_velocity_min = 0.0
	process.initial_velocity_max = 0.0
	process.gravity = Vector3.ZERO
	process.damping_min = 0.0
	process.damping_max = 0.0
	process.scale_min = 0.15
	process.scale_max = 1.0
	process.scale_curve = scale_curve
	process.color = color
	return process


func _create_cross_planes_mesh(depth: float, height: float, direction: Vector3) -> ArrayMesh:
	var basis := _basis_from_direction(direction)
	var half_height := height * 0.5
	var rear_width := height * 0.08
	var front_width := height * 0.95
	var mesh := ArrayMesh.new()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)

	_add_flame_plane(surface, basis, rear_width, front_width, half_height, depth, 0.0, Color(1.0, 0.95, 0.65, 1.0))
	_add_flame_plane(surface, basis, rear_width, front_width, half_height, depth, 90.0, Color(1.0, 0.72, 0.35, 0.85))

	surface.generate_normals()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface.commit_to_arrays())
	return mesh


func _add_flame_plane(
	surface: SurfaceTool,
	basis: Basis,
	rear_width: float,
	front_width: float,
	half_height: float,
	depth: float,
	roll_degrees: float,
	color: Color
) -> void:
	var roll_basis := basis * Basis(Vector3(0.0, 0.0, 1.0), deg_to_rad(roll_degrees))
	var right := roll_basis.x
	var up := roll_basis.y
	var forward := roll_basis.z
	var rear_left := (-right * rear_width) - (up * half_height * 0.18)
	var rear_right := (right * rear_width) + (up * half_height * 0.18)
	var front_left := forward * depth - right * front_width - up * half_height
	var front_right := forward * depth + right * front_width + up * half_height

	_add_textured_triangle(surface, rear_left, front_left, front_right, color, color * Color(1.0, 0.9, 0.7, 0.0))
	_add_textured_triangle(surface, rear_left, front_right, rear_right, color, color * Color(1.0, 0.9, 0.7, 0.0))


func _create_open_cone_mesh(
	rear_radius: float,
	front_radius: float,
	depth: float,
	segments: int,
	direction: Vector3
) -> ArrayMesh:
	var basis := _basis_from_direction(direction)
	var mesh := ArrayMesh.new()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)

	for index in range(segments):
		var angle_a := float(index) / float(segments) * TAU
		var angle_b := float(index + 1) / float(segments) * TAU
		var rear_a := basis.x * cos(angle_a) * rear_radius + basis.y * sin(angle_a) * rear_radius
		var rear_b := basis.x * cos(angle_b) * rear_radius + basis.y * sin(angle_b) * rear_radius
		var front_a := basis.z * depth + basis.x * cos(angle_a) * front_radius + basis.y * sin(angle_a) * front_radius
		var front_b := basis.z * depth + basis.x * cos(angle_b) * front_radius + basis.y * sin(angle_b) * front_radius
		var hot := Color(1.0, 0.86, 0.42, 0.9)
		var fade := Color(1.0, 0.35, 0.08, 0.05)

		_add_colored_vertex(surface, rear_a, hot, Vector2(0.0, 0.0))
		_add_colored_vertex(surface, front_a, fade, Vector2(0.0, 1.0))
		_add_colored_vertex(surface, front_b, fade, Vector2(1.0, 1.0))
		_add_colored_vertex(surface, rear_a, hot, Vector2(0.0, 0.0))
		_add_colored_vertex(surface, front_b, fade, Vector2(1.0, 1.0))
		_add_colored_vertex(surface, rear_b, hot, Vector2(1.0, 0.0))

	surface.generate_normals()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface.commit_to_arrays())
	return mesh


func _create_quad_mesh(size: Vector2) -> QuadMesh:
	var quad := QuadMesh.new()
	quad.size = size
	return quad


func _add_textured_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, hot: Color, fade: Color) -> void:
	_add_colored_vertex(surface, a, hot, Vector2(0.0, 0.5))
	_add_colored_vertex(surface, b, fade, Vector2(0.5, 1.0))
	_add_colored_vertex(surface, c, fade, Vector2(1.0, 0.5))


func _add_colored_vertex(surface: SurfaceTool, position: Vector3, color: Color, uv: Vector2) -> void:
	surface.set_color(color)
	surface.set_uv(uv)
	surface.add_vertex(position)


func _create_main_scale_curve() -> CurveTexture:
	return _create_curve_texture([
		Vector2(0.0, 0.0),
		Vector2(0.08, 1.0),
		Vector2(0.28, 0.82),
		Vector2(1.0, 0.0),
	])


func _create_cone_scale_curve() -> CurveTexture:
	return _create_curve_texture([
		Vector2(0.0, 0.12),
		Vector2(0.14, 1.0),
		Vector2(0.45, 0.68),
		Vector2(1.0, 0.0),
	])


func _create_spark_scale_curve() -> CurveTexture:
	return _create_curve_texture([
		Vector2(0.0, 1.0),
		Vector2(0.42, 0.72),
		Vector2(0.78, 0.18),
		Vector2(1.0, 0.0),
	])


func _create_curve_texture(points: Array[Vector2]) -> CurveTexture:
	var curve := Curve.new()
	for point in points:
		curve.add_point(point)

	var texture := CurveTexture.new()
	texture.curve = curve
	return texture


func _create_spark_alpha_ramp() -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 0.9, 0.55, 1.0))
	gradient.set_offset(0, 0.0)
	gradient.set_color(1, Color(1.0, 0.22, 0.06, 0.0))
	gradient.set_offset(1, 1.0)
	gradient.add_point(0.58, Color(1.0, 0.68, 0.22, 0.82))
	gradient.add_point(0.82, Color(1.0, 0.32, 0.08, 0.12))

	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	return texture


func _create_soft_glow_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	gradient.set_offset(0, 0.0)
	gradient.set_color(1, Color(1.0, 0.25, 0.02, 0.0))
	gradient.set_offset(1, 1.0)
	gradient.add_point(0.36, Color(1.0, 0.78, 0.35, 0.72))
	gradient.add_point(0.72, Color(1.0, 0.38, 0.08, 0.16))

	var texture := GradientTexture2D.new()
	texture.width = 64
	texture.height = 64
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.gradient = gradient
	_generated_textures.append(texture)
	return texture


func _create_fire_streak_texture() -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.22
	noise.fractal_octaves = 3
	noise.fractal_lacunarity = 2.4

	var texture := NoiseTexture2D.new()
	texture.width = 64
	texture.height = 64
	texture.seamless = true
	texture.noise = noise
	_generated_textures.append(texture)
	return texture


func _get_forward_direction() -> Vector3:
	if forward_axis.length_squared() <= 0.001:
		push_warning("Muzzle flash forward_axis cannot be zero. Falling back to Vector3.FORWARD.")
		return Vector3.FORWARD
	return forward_axis.normalized()


func _basis_from_direction(direction: Vector3) -> Basis:
	var forward := direction.normalized()
	var up := Vector3.UP
	if abs(forward.dot(up)) > 0.98:
		up = Vector3.RIGHT

	var right := up.cross(forward).normalized()
	var corrected_up := forward.cross(right).normalized()
	return Basis(right, corrected_up, forward)
