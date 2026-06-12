class_name BulletImpactVFX
extends RefCounted

const DECAL_SIZE: float = 0.16

static var _decal_texture: ImageTexture
static var _decal_material: StandardMaterial3D
static var _active_decals: Array[MeshInstance3D] = []
static var _decal_pool: Array[MeshInstance3D] = []
static var _decal_material_pool: Array[StandardMaterial3D] = []
static var _decal_mesh: QuadMesh


static func spawn_decal(
	scene_root: Node,
	world_position: Vector3,
	surface_normal: Vector3,
	lifetime: float = 5.0,
	max_decals: int = 64
) -> void:
	if scene_root == null or lifetime <= 0.0 or max_decals <= 0:
		return

	var normal: Vector3 = surface_normal.normalized()
	if normal.length_squared() <= 0.0001:
		normal = Vector3.UP

	_cleanup_invalid_decals()
	while _active_decals.size() >= max_decals:
		_release_decal(_active_decals.pop_front())

	var decal: MeshInstance3D = _acquire_decal(scene_root)
	if decal == null:
		return

	var up_axis: Vector3 = Vector3.UP
	if absf(normal.dot(up_axis)) > 0.92:
		up_axis = Vector3.FORWARD

	decal.visible = true
	decal.global_basis = Basis.looking_at(normal, up_axis)
	decal.rotate_object_local(Vector3.FORWARD, deg_to_rad(randf_range(-18.0, 18.0)))
	var size_jitter: float = randf_range(0.82, 1.18)
	decal.scale = Vector3.ONE * size_jitter
	decal.global_position = world_position + normal * 0.014

	var material := _acquire_decal_material()
	var base_alpha: float = material.albedo_color.a
	decal.material_override = material
	_active_decals.append(decal)

	var fade_tween: Tween = decal.create_tween()
	decal.set_meta(&"fade_tween", fade_tween)
	fade_tween.tween_interval(maxf(lifetime - 0.35, 0.05))
	fade_tween.tween_method(
		func(alpha: float) -> void:
			material.albedo_color.a = alpha,
		base_alpha,
		0.0,
		0.35
	).set_trans(Tween.TRANS_LINEAR)
	fade_tween.finished.connect(_on_decal_fade_finished.bind(decal), CONNECT_ONE_SHOT)


static func warmup(scene_root: Node, pool_size: int = 8) -> void:
	if scene_root == null or pool_size <= 0:
		return

	_get_decal_texture()
	_get_decal_mesh()
	_get_decal_material()
	_cleanup_invalid_decals()

	while _get_pooled_decal_count(scene_root) < pool_size:
		var decal := _create_decal(scene_root)
		decal.visible = false
		_decal_pool.append(decal)

	while _decal_material_pool.size() < pool_size:
		var material := _get_decal_material().duplicate() as StandardMaterial3D
		_reset_decal_material(material)
		_decal_material_pool.append(material)


static func _on_decal_fade_finished(decal: MeshInstance3D) -> void:
	if decal == null or not is_instance_valid(decal):
		return
	if decal.has_meta(&"fade_tween"):
		decal.remove_meta(&"fade_tween")
	if _active_decals.has(decal):
		_active_decals.erase(decal)
	_release_decal(decal)


static func _acquire_decal(scene_root: Node) -> MeshInstance3D:
	while not _decal_pool.is_empty():
		var pooled: MeshInstance3D = _decal_pool.pop_back()
		if pooled != null and is_instance_valid(pooled) and pooled.get_parent() == scene_root:
			return pooled
		if pooled != null and is_instance_valid(pooled):
			pooled.queue_free()

	return _create_decal(scene_root)


static func _create_decal(scene_root: Node) -> MeshInstance3D:
	var decal := MeshInstance3D.new()
	decal.name = "BulletImpactDecal"
	decal.mesh = _get_decal_mesh()
	decal.material_override = _get_decal_material()
	decal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	decal.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	scene_root.add_child(decal)
	return decal


static func _get_pooled_decal_count(scene_root: Node) -> int:
	var count: int = 0
	for decal in _decal_pool:
		if decal != null and is_instance_valid(decal) and decal.get_parent() == scene_root:
			count += 1
	return count


static func _release_decal(decal: MeshInstance3D) -> void:
	if decal == null or not is_instance_valid(decal):
		return
	if decal.has_meta(&"fade_tween"):
		var fade_tween: Variant = decal.get_meta(&"fade_tween")
		if fade_tween is Tween and (fade_tween as Tween).is_valid():
			(fade_tween as Tween).kill()
		decal.remove_meta(&"fade_tween")
	decal.visible = false
	_release_decal_material(decal.material_override as StandardMaterial3D)
	decal.material_override = _get_decal_material()
	_decal_pool.append(decal)


static func _cleanup_invalid_decals() -> void:
	for decal_index in range(_active_decals.size() - 1, -1, -1):
		var decal: MeshInstance3D = _active_decals[decal_index]
		if decal == null or not is_instance_valid(decal):
			_active_decals.remove_at(decal_index)


static func _get_decal_mesh() -> QuadMesh:
	if _decal_mesh != null:
		return _decal_mesh

	_decal_mesh = QuadMesh.new()
	_decal_mesh.size = Vector2(DECAL_SIZE, DECAL_SIZE)
	return _decal_mesh


static func _get_decal_material() -> StandardMaterial3D:
	if _decal_material != null:
		return _decal_material

	_decal_material = StandardMaterial3D.new()
	_decal_material.albedo_color = Color(0.12, 0.11, 0.1, 0.92)
	_decal_material.albedo_texture = _get_decal_texture()
	_decal_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_decal_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_decal_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_decal_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return _decal_material


static func _acquire_decal_material() -> StandardMaterial3D:
	while not _decal_material_pool.is_empty():
		var pooled: StandardMaterial3D = _decal_material_pool.pop_back()
		if pooled != null:
			_reset_decal_material(pooled)
			return pooled

	var material := _get_decal_material().duplicate() as StandardMaterial3D
	_reset_decal_material(material)
	return material


static func _release_decal_material(material: StandardMaterial3D) -> void:
	if material == null or material == _get_decal_material():
		return
	_reset_decal_material(material)
	_decal_material_pool.append(material)


static func _reset_decal_material(material: StandardMaterial3D) -> void:
	var base_material := _get_decal_material()
	material.albedo_color = base_material.albedo_color
	material.albedo_texture = base_material.albedo_texture
	material.texture_filter = base_material.texture_filter
	material.transparency = base_material.transparency
	material.cull_mode = base_material.cull_mode
	material.shading_mode = base_material.shading_mode


static func _get_decal_texture() -> ImageTexture:
	if _decal_texture != null:
		return _decal_texture

	var image := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var center := Vector2(7.5, 7.5)
	for y in range(16):
		for x in range(16):
			var offset := Vector2(float(x), float(y)) - center
			var distance := offset.length() / 7.5
			if distance > 1.0:
				continue
			var noise := randf()
			var edge := 1.0 - smoothstep(0.35, 1.0, distance)
			var alpha := clampf(edge * (0.45 + noise * 0.55), 0.0, 1.0)
			var tone := 0.05 + noise * 0.12
			image.set_pixel(x, y, Color(tone, tone * 0.95, tone * 0.88, alpha))

	_decal_texture = ImageTexture.create_from_image(image)
	return _decal_texture
