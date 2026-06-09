class_name HitscanWeapon
extends WeaponBase

@export var hit_marker_duration: float = 0.08
@export var impact_lifetime: float = 0.45
@export_range(0, 128) var max_active_impacts: int = 48
@export_range(1, 24) var pellet_count: int = 1

@onready var muzzle_flash: Node = get_node_or_null("MuzzleFlash")

static var _active_impact_markers: Array[MeshInstance3D] = []

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
	var end_position: Vector3 = origin + direction * weapon_range
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, end_position)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var owner_body: CollisionObject3D = _get_owner_body()
	if owner_body != null:
		query.exclude = [owner_body.get_rid()]

	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		_debug_draw_shot_ray(origin, end_position, end_position, false)
		return

	var damage_target: Object = _find_damage_target(hit.get("collider") as Object)
	if damage_target != null:
		if damage_target is PlayerController:
			var victim: PlayerController = damage_target as PlayerController
			var attacker_player_id: int = _get_owner_player_id()
			if not _request_network_player_damage(victim.player_id, damage, attacker_player_id):
				victim.apply_damage(damage, attacker_player_id)
		else:
			damage_target.apply_damage(damage)

	var impact_position: Vector3 = hit.get("position", Vector3.ZERO)
	_debug_draw_shot_ray(origin, end_position, impact_position, true)
	_spawn_impact_marker(impact_position)


func _show_muzzle_flash() -> void:
	if muzzle_flash == null:
		return
	if not muzzle_flash.has_method("trigger_shot"):
		push_warning("%s muzzle flash node does not implement trigger_shot()." % name)
		return
	muzzle_flash.trigger_shot()


func _spawn_impact_marker(world_position: Vector3) -> void:
	if max_active_impacts <= 0:
		return

	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return

	_cleanup_invalid_impacts()
	while _active_impact_markers.size() >= max_active_impacts:
		var oldest_impact: MeshInstance3D = _active_impact_markers.pop_front()
		if oldest_impact != null and is_instance_valid(oldest_impact):
			oldest_impact.queue_free()

	var impact: MeshInstance3D = MeshInstance3D.new()
	impact.name = "BulletImpact"
	impact.mesh = _get_impact_mesh()
	impact.material_override = _get_impact_material()

	scene_root.add_child(impact)
	impact.global_position = world_position
	_active_impact_markers.append(impact)
	await get_tree().create_timer(impact_lifetime).timeout
	if is_instance_valid(impact):
		impact.queue_free()
	_active_impact_markers.erase(impact)


func _cleanup_invalid_impacts() -> void:
	for impact_index in range(_active_impact_markers.size() - 1, -1, -1):
		var impact: MeshInstance3D = _active_impact_markers[impact_index]
		if impact == null or not is_instance_valid(impact):
			_active_impact_markers.remove_at(impact_index)


func _debug_draw_shot_ray(origin: Vector3, end_position: Vector3, hit_position: Vector3, did_hit: bool) -> void:
	var scene_tree: SceneTree = get_tree()
	if scene_tree == null:
		return
	scene_tree.call_group("arena_debug_draw", "draw_shot_ray", origin, end_position, hit_position, did_hit)


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


func _get_owner_player_id() -> int:
	var owner_body: CollisionObject3D = _get_owner_body()
	if owner_body is PlayerController:
		return (owner_body as PlayerController).player_id
	return 0


func _request_network_player_damage(victim_player_id: int, amount: int, attacker_player_id: int) -> bool:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null or not scene_root.has_method("request_network_damage"):
		return false
	return bool(scene_root.call("request_network_damage", victim_player_id, amount, attacker_player_id))


func _find_damage_target(collider: Object) -> Object:
	var current: Object = collider
	while current != null:
		if current.has_method("apply_damage"):
			return current
		if not (current is Node):
			break
		current = (current as Node).get_parent()
	return null
