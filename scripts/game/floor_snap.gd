class_name FloorSnap
extends RefCounted

## Raycast corto bajo el techo para encontrar suelo walkable (evita pegar en el ceiling).
const RAY_START_HEIGHT: float = 2.25
const RAY_DEPTH: float = 5.75
const PICKUP_FLOAT: float = 0.85

const SPAWN_RAY_START_OFFSET: float = 1.75
const SPAWN_SEARCH_DEPTH: float = 12.0
const SPAWN_PROBE_SEARCH_DEPTH: float = 24.0
const MIN_FLOOR_NORMAL_Y: float = 0.65
const MAX_MARKER_HEIGHT_DRIFT: float = 0.35
const MAX_SNAP_ABOVE_REFERENCE: float = 0.2
const PLAYER_CAPSULE_RADIUS: float = 0.45
const PLAYER_CAPSULE_HEIGHT: float = 1.8
const SPAWN_CLEARANCE_MARGIN: float = 0.02


static func snap_to_floor(world_position: Vector3, space_state: PhysicsDirectSpaceState3D) -> Vector3:
	var floor_hit: Dictionary = _find_walkable_floor_below(
		world_position,
		space_state,
		SPAWN_SEARCH_DEPTH
	)
	if floor_hit.is_empty():
		return world_position
	return Vector3(world_position.x, float(floor_hit.position.y), world_position.z)


static func snap_spawn_position(world_position: Vector3, space_state: PhysicsDirectSpaceState3D) -> Vector3:
	return snap_to_floor(world_position, space_state)


static func resolve_spawn_transform(
	marker_transform: Transform3D,
	space_state: PhysicsDirectSpaceState3D
) -> Transform3D:
	if space_state == null:
		return marker_transform

	var marker_position: Vector3 = marker_transform.origin
	var floor_hit: Dictionary = _find_walkable_floor_below(marker_position, space_state, SPAWN_SEARCH_DEPTH)
	if floor_hit.is_empty():
		floor_hit = _find_walkable_floor_below(marker_position, space_state, SPAWN_PROBE_SEARCH_DEPTH)
	if floor_hit.is_empty():
		return marker_transform

	var snapped_y: float = float(floor_hit.position.y)
	var resolved := marker_transform
	resolved.origin = Vector3(marker_position.x, snapped_y, marker_position.z)
	if absf(snapped_y - marker_position.y) > MAX_MARKER_HEIGHT_DRIFT:
		if not _has_spawn_clearance(resolved, space_state):
			return marker_transform
		return resolved
	if not _has_spawn_clearance(resolved, space_state):
		return marker_transform
	return resolved


static func is_spawn_transform_safe(spawn_transform: Transform3D, space_state: PhysicsDirectSpaceState3D) -> bool:
	if space_state == null:
		return false

	var spawn_position: Vector3 = spawn_transform.origin
	var floor_hit: Dictionary = _find_walkable_floor_below(spawn_position, space_state, SPAWN_SEARCH_DEPTH)
	if floor_hit.is_empty():
		return false

	var floor_normal: Vector3 = floor_hit.get("normal", Vector3.UP)
	if floor_normal.y < MIN_FLOOR_NORMAL_Y:
		return false
	if absf(float(floor_hit.position.y) - spawn_position.y) > 0.05:
		return false
	return _has_spawn_clearance(spawn_transform, space_state)


static func find_emergency_spawn_transform(
	probe_positions: Array[Vector3],
	space_state: PhysicsDirectSpaceState3D
) -> Transform3D:
	if space_state == null:
		return Transform3D(Basis(), Vector3.ZERO)

	for probe_position in probe_positions:
		var floor_hit: Dictionary = _find_walkable_floor_below(
			probe_position,
			space_state,
			SPAWN_PROBE_SEARCH_DEPTH
		)
		if floor_hit.is_empty():
			continue

		var emergency := Transform3D(Basis(), Vector3(probe_position.x, float(floor_hit.position.y), probe_position.z))
		if _has_spawn_clearance(emergency, space_state):
			return emergency

	return Transform3D(Basis(), Vector3.ZERO)


static func pickup_position(world_position: Vector3, space_state: PhysicsDirectSpaceState3D) -> Vector3:
	var snapped: Vector3 = snap_to_floor(world_position, space_state)
	return snapped + Vector3(0.0, PICKUP_FLOAT, 0.0)


static func _find_walkable_floor_below(
	reference_position: Vector3,
	space_state: PhysicsDirectSpaceState3D,
	search_depth: float
) -> Dictionary:
	if space_state == null:
		return {}

	var ray_start: Vector3 = reference_position + Vector3.UP * SPAWN_RAY_START_OFFSET
	var ray_end: Vector3 = reference_position - Vector3.UP * search_depth
	var exclude: Array[RID] = []
	var best_hit: Dictionary = {}
	var best_height: float = -INF

	while true:
		var query := PhysicsRayQueryParameters3D.create(ray_start, ray_end)
		query.exclude = exclude
		query.hit_back_faces = false
		var hit: Dictionary = space_state.intersect_ray(query)
		if hit.is_empty():
			break

		var hit_y: float = float(hit.position.y)
		var normal: Vector3 = hit.get("normal", Vector3.ZERO)
		var collider: Object = hit.get("collider")
		var is_walkable_floor: bool = (
			normal.y >= MIN_FLOOR_NORMAL_Y
			and hit_y <= reference_position.y + MAX_SNAP_ABOVE_REFERENCE
		)
		if is_walkable_floor and hit_y > best_height:
			best_height = hit_y
			best_hit = hit

		if collider is CollisionObject3D:
			exclude.append((collider as CollisionObject3D).get_rid())
		else:
			break

	return best_hit


static func _has_spawn_clearance(spawn_transform: Transform3D, space_state: PhysicsDirectSpaceState3D) -> bool:
	var capsule := CapsuleShape3D.new()
	capsule.radius = PLAYER_CAPSULE_RADIUS
	capsule.height = PLAYER_CAPSULE_HEIGHT

	var clearance := PhysicsShapeQueryParameters3D.new()
	clearance.shape = capsule
	clearance.transform = Transform3D(Basis(), spawn_transform.origin + Vector3.UP * (PLAYER_CAPSULE_HEIGHT * 0.5))
	clearance.margin = SPAWN_CLEARANCE_MARGIN
	return space_state.intersect_shape(clearance, 1).is_empty()
