class_name FloorSnap
extends RefCounted

## Raycast corto bajo el techo para encontrar suelo walkable (evita pegar en el ceiling).
const RAY_START_HEIGHT: float = 2.25
const RAY_DEPTH: float = 5.75
const PICKUP_FLOAT: float = 0.85


static func snap_to_floor(world_position: Vector3, space_state: PhysicsDirectSpaceState3D) -> Vector3:
	if space_state == null:
		return world_position

	var ray_origin: Vector3 = world_position + Vector3(0.0, RAY_START_HEIGHT, 0.0)
	var ray_target: Vector3 = world_position - Vector3(0.0, RAY_DEPTH - RAY_START_HEIGHT, 0.0)
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_target)
	query.hit_back_faces = false
	var hit: Dictionary = space_state.intersect_ray(query)
	if hit.is_empty():
		return world_position

	return Vector3(world_position.x, float(hit.position.y), world_position.z)


static func pickup_position(world_position: Vector3, space_state: PhysicsDirectSpaceState3D) -> Vector3:
	var snapped: Vector3 = snap_to_floor(world_position, space_state)
	return snapped + Vector3(0.0, PICKUP_FLOAT, 0.0)
