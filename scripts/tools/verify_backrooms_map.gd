extends SceneTree

const MAP_SCENE := preload("res://scenes/maps/BackroomsArena.tscn")


func _init() -> void:
	call_deferred("_verify")


func _verify() -> void:
	var arena := MAP_SCENE.instantiate() as Node3D
	if arena == null:
		_fail("BackroomsArena must instantiate as Node3D.")
		return
	get_root().add_child(arena)
	await physics_frame
	await physics_frame

	var spawn_root := arena.get_node_or_null("SpawnPoints") as Node3D
	var pickup_root := arena.get_node_or_null("PickupSpawns") as Node3D
	if spawn_root == null or spawn_root.get_child_count() != 4:
		_fail("BackroomsArena requires exactly four spawn points.")
		return
	if pickup_root == null or pickup_root.get_child_count() != 6:
		_fail("BackroomsArena requires exactly six pickup spawns.")
		return

	var backface_collision_count := 0
	for collision_node in arena.find_children("*", "CollisionShape3D", true, false):
		var collision_shape := collision_node as CollisionShape3D
		if collision_shape != null and collision_shape.shape is ConcavePolygonShape3D:
			if (collision_shape.shape as ConcavePolygonShape3D).backface_collision:
				backface_collision_count += 1
	if backface_collision_count != 20:
		_fail("Expected backface collision on all 20 imported mesh shapes.")
		return

	var void_recovery := arena.get_node_or_null("VoidRecovery") as Area3D
	if void_recovery == null or not void_recovery.body_entered.is_connected(arena._on_void_recovery_body_entered):
		_fail("BackroomsArena requires a connected void recovery area.")
		return

	var space_state := arena.get_world_3d().direct_space_state
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.45
	capsule.height = 1.8
	var spawn_positions: Array[Vector3] = []
	for spawn_node in spawn_root.get_children():
		var spawn := spawn_node as Node3D
		if spawn == null or not _position_is_playable(spawn.global_position, space_state, capsule):
			_fail("Unsafe spawn point: %s" % spawn_node.name)
			return
		if not _view_is_clear(spawn, space_state):
			_fail("Spawn point faces a wall: %s" % spawn_node.name)
			return
		for existing_position in spawn_positions:
			if existing_position.distance_to(spawn.global_position) < 12.0:
				_fail("Spawn points are too close together: %s" % spawn_node.name)
				return
		spawn_positions.append(spawn.global_position)

	for pickup_node in pickup_root.get_children():
		var pickup := pickup_node as Node3D
		if pickup == null or not _position_has_floor(pickup.global_position, space_state):
			_fail("Pickup has no valid floor: %s" % pickup_node.name)
			return

	print("Backrooms map verification passed: 20 sealed meshes, 4 safe spawns, 6 pickups, closed ceiling.")
	quit(0)


func _position_is_playable(
	position: Vector3,
	space_state: PhysicsDirectSpaceState3D,
	capsule: CapsuleShape3D
) -> bool:
	if not _position_has_floor(position, space_state):
		return false
	var clearance := PhysicsShapeQueryParameters3D.new()
	clearance.shape = capsule
	clearance.transform = Transform3D(Basis(), position + Vector3.UP)
	clearance.margin = 0.01
	if not space_state.intersect_shape(clearance, 1).is_empty():
		return false
	var ceiling_ray := PhysicsRayQueryParameters3D.create(position + Vector3.UP * 1.8, position + Vector3.UP * 6.0)
	return not space_state.intersect_ray(ceiling_ray).is_empty()


func _position_has_floor(position: Vector3, space_state: PhysicsDirectSpaceState3D) -> bool:
	var floor_ray := PhysicsRayQueryParameters3D.create(position + Vector3.UP, position + Vector3.DOWN)
	var floor_hit := space_state.intersect_ray(floor_ray)
	if floor_hit.is_empty() or (floor_hit.get("normal", Vector3.ZERO) as Vector3).y < 0.7:
		return false
	return absf(float(floor_hit["position"].y) - position.y) < 0.2


func _view_is_clear(spawn: Node3D, space_state: PhysicsDirectSpaceState3D) -> bool:
	var camera_position := spawn.global_position + Vector3.UP * 1.55
	var forward := -spawn.global_basis.z
	for angle in [-0.35, 0.0, 0.35]:
		var direction := forward.rotated(Vector3.UP, angle)
		var view_ray := PhysicsRayQueryParameters3D.create(camera_position, camera_position + direction * 6.0)
		if not space_state.intersect_ray(view_ray).is_empty():
			return false
	return true


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
