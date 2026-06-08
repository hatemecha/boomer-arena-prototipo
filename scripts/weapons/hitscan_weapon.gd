class_name HitscanWeapon
extends WeaponBase

@export var hit_marker_duration: float = 0.08
@export var impact_lifetime: float = 0.45
@export_range(1, 24) var pellet_count: int = 1

@onready var muzzle_flash: Node = get_node_or_null("MuzzleFlash")

var _impact_material: StandardMaterial3D
var _impact_mesh: BoxMesh


func try_fire(camera: Camera3D) -> bool:
	if camera == null:
		push_error("HitscanWeapon requires a valid Camera3D to fire.")
		return false

	var did_fire: bool = super(camera)
	if not did_fire:
		return false

	for _pellet_index in range(pellet_count):
		_perform_hitscan(camera)
	_show_muzzle_flash()
	return true


func _perform_hitscan(camera: Camera3D) -> void:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return

	var center: Vector2 = viewport.get_visible_rect().size * 0.5
	var effective_spread_degrees: float = spread_degrees
	if is_aiming:
		effective_spread_degrees *= aim_spread_multiplier

	var spread_offset: Vector2 = Vector2(
		randf_range(-effective_spread_degrees, effective_spread_degrees),
		randf_range(-effective_spread_degrees, effective_spread_degrees)
	)
	var origin: Vector3 = camera.project_ray_origin(center)
	var direction: Vector3 = camera.project_ray_normal(center + spread_offset).normalized()
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, origin + direction * weapon_range)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var owner_body: CollisionObject3D = _get_owner_body()
	if owner_body != null:
		query.exclude = [owner_body.get_rid()]

	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return

	var damage_target: Object = _find_damage_target(hit.get("collider") as Object)
	if damage_target != null:
		damage_target.apply_damage(damage)

	var impact_position: Vector3 = hit.get("position", Vector3.ZERO)
	_spawn_impact_marker(impact_position)


func _show_muzzle_flash() -> void:
	if muzzle_flash == null:
		return
	if not muzzle_flash.has_method("trigger_shot"):
		push_warning("%s muzzle flash node does not implement trigger_shot()." % name)
		return
	muzzle_flash.trigger_shot()


func _spawn_impact_marker(world_position: Vector3) -> void:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return

	var impact: MeshInstance3D = MeshInstance3D.new()
	impact.name = "BulletImpact"
	impact.mesh = _get_impact_mesh()
	impact.material_override = _get_impact_material()

	scene_root.add_child(impact)
	impact.global_position = world_position
	await get_tree().create_timer(impact_lifetime).timeout
	if is_instance_valid(impact):
		impact.queue_free()


func _get_impact_material() -> StandardMaterial3D:
	if _impact_material != null:
		return _impact_material

	_impact_material = StandardMaterial3D.new()
	_impact_material.albedo_color = Color(1.0, 0.12, 0.03)
	_impact_material.emission_enabled = true
	_impact_material.emission = Color(1.0, 0.08, 0.02)
	_impact_material.emission_energy_multiplier = 0.8
	return _impact_material


func _get_impact_mesh() -> BoxMesh:
	if _impact_mesh != null:
		return _impact_mesh

	_impact_mesh = BoxMesh.new()
	_impact_mesh.size = Vector3(0.14, 0.14, 0.14)
	return _impact_mesh


func _get_owner_body() -> CollisionObject3D:
	var current: Node = get_parent()
	while current != null:
		if current is CollisionObject3D:
			return current
		current = current.get_parent()
	return null


func _find_damage_target(collider: Object) -> Object:
	var current: Object = collider
	while current != null:
		if current.has_method("apply_damage"):
			return current
		if not (current is Node):
			break
		current = (current as Node).get_parent()
	return null
