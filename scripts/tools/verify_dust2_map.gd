extends SceneTree

const MAP_SCENE := preload("res://scenes/maps/Dust2Arena.tscn")


func _init() -> void:
	call_deferred("_verify")


func _verify() -> void:
	var arena := MAP_SCENE.instantiate() as Node3D
	if arena == null:
		_fail("Dust2Arena must instantiate as Node3D.")
		return
	get_root().add_child(arena)

	await physics_frame
	await physics_frame

	var spawn_root := arena.get_node_or_null("SpawnPoints")
	var pickup_root := arena.get_node_or_null("PickupSpawns")
	if spawn_root == null or spawn_root.get_child_count() != 4:
		_fail("Dust2Arena requires exactly four spawn points.")
		return
	if pickup_root == null or pickup_root.get_child_count() != 4:
		_fail("Dust2Arena requires exactly four pickup spawns.")
		return

	var collision_bodies := arena.find_children("*", "StaticBody3D", true, false)
	if collision_bodies.size() != 12:
		_fail("Expected 11 mesh bodies and one gameplay boundary body, found %d." % collision_bodies.size())
		return
	var gameplay_bounds := arena.get_node_or_null("GameplayBounds") as StaticBody3D
	if gameplay_bounds == null or gameplay_bounds.get_child_count() != 5:
		_fail("Dust2Arena requires four perimeter walls and one ceiling boundary.")
		return
	var visual_bounds := arena.get_node_or_null("VisualBounds") as Node3D
	if visual_bounds == null or visual_bounds.get_child_count() != 5:
		_fail("Dust2Arena requires a textured ground skirt and four visual boundary walls.")
		return
	for visual_node in visual_bounds.get_children():
		var visual_mesh := visual_node as MeshInstance3D
		if visual_mesh == null or visual_mesh.mesh == null or visual_mesh.mesh.material == null:
			_fail("Visual boundary is missing a textured mesh: %s" % visual_node.name)
			return
	var void_recovery := arena.get_node_or_null("VoidRecovery") as Area3D
	if void_recovery == null or not void_recovery.body_entered.is_connected(arena._on_void_recovery_body_entered):
		_fail("Dust2Arena requires a connected void recovery area.")
		return
	var backface_collision_count := 0
	for collision_node in arena.find_children("*", "CollisionShape3D", true, false):
		var collision_shape := collision_node as CollisionShape3D
		if collision_shape != null and collision_shape.shape is ConcavePolygonShape3D:
			if (collision_shape.shape as ConcavePolygonShape3D).backface_collision:
				backface_collision_count += 1
	if backface_collision_count != 11:
		_fail("Expected backface collision on all 11 imported mesh shapes.")
		return

	var space_state := arena.get_world_3d().direct_space_state
	if not _ray_hits_collider(space_state, Vector3(0.0, 8.0, 0.0), Vector3(0.0, 11.0, 0.0), gameplay_bounds):
		_fail("Ceiling boundary does not seal the playable space.")
		return
	if not _ray_hits_collider(space_state, Vector3(37.0, 8.0, 0.0), Vector3(40.0, 8.0, 0.0), gameplay_bounds):
		_fail("Perimeter boundary does not seal the playable space.")
		return
	var void_ray := PhysicsRayQueryParameters3D.create(Vector3(0.0, -4.5, 0.0), Vector3(0.0, -7.5, 0.0))
	void_ray.collide_with_areas = true
	void_ray.collide_with_bodies = false
	var void_hit := space_state.intersect_ray(void_ray)
	if void_hit.is_empty() or void_hit.get("collider") != void_recovery:
		_fail("Void recovery area does not cover the space below the map.")
		return
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.45
	capsule.height = 1.8
	for spawn_node in spawn_root.get_children():
		var spawn := spawn_node as Node3D
		if spawn != null and spawn.global_position.y > 1.0:
			_fail("Spawn point is above street level: %s" % spawn_node.name)
			return
		if spawn == null or not _spawn_has_floor_and_clearance(spawn, space_state, capsule):
			_fail("Unsafe or unsupported spawn point: %s" % spawn_node.name)
			return

	print("Dust II map verification passed: textured bounds, sealed collision, and 4 street-level spawns.")
	quit(0)


func _ray_hits_collider(
	space_state: PhysicsDirectSpaceState3D,
	from: Vector3,
	to: Vector3,
	expected_collider: CollisionObject3D
) -> bool:
	var hit := space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))
	return not hit.is_empty() and hit.get("collider") == expected_collider


func _spawn_has_floor_and_clearance(
	spawn: Node3D,
	space_state: PhysicsDirectSpaceState3D,
	capsule: CapsuleShape3D
) -> bool:
	var ray := PhysicsRayQueryParameters3D.create(
		spawn.global_position + Vector3.UP * 1.0,
		spawn.global_position - Vector3.UP * 1.0
	)
	var floor_hit := space_state.intersect_ray(ray)
	if floor_hit.is_empty() or (floor_hit.get("normal", Vector3.ZERO) as Vector3).y < 0.65:
		return false
	var spawn_snap_ray := PhysicsRayQueryParameters3D.create(
		spawn.global_position + Vector3.UP * 4.0,
		spawn.global_position + Vector3.DOWN * 8.0
	)
	var snapped_floor_hit := space_state.intersect_ray(spawn_snap_ray)
	if snapped_floor_hit.is_empty() or absf(float(snapped_floor_hit["position"].y) - spawn.global_position.y) > 0.2:
		return false
	var view_ray := PhysicsRayQueryParameters3D.create(
		spawn.global_position + Vector3.UP * 1.55,
		spawn.global_position + Vector3.UP * 1.55 - spawn.global_basis.z * 2.0
	)
	if not space_state.intersect_ray(view_ray).is_empty():
		return false

	var clearance := PhysicsShapeQueryParameters3D.new()
	clearance.shape = capsule
	clearance.transform = Transform3D(Basis(), spawn.global_position + Vector3.UP)
	clearance.margin = 0.01
	return space_state.intersect_shape(clearance, 1).is_empty()


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
