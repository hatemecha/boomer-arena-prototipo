class_name SpawnManager
extends Node

@export var use_safe_spawn_selection: bool = false

var spawn_points: Array[Transform3D] = [
	Transform3D(Basis().rotated(Vector3.UP, deg_to_rad(180.0)), Vector3(0.0, 1.2, 12.0)),
	Transform3D(Basis(), Vector3(0.0, 1.2, -12.0)),
	Transform3D(Basis().rotated(Vector3.UP, deg_to_rad(90.0)), Vector3(-12.0, 1.2, 0.0)),
	Transform3D(Basis().rotated(Vector3.UP, deg_to_rad(-90.0)), Vector3(12.0, 1.2, 0.0)),
]


func get_spawn_transform(players_to_avoid: Array[PlayerController] = []) -> Transform3D:
	if spawn_points.is_empty():
		push_warning("No spawn points configured. Falling back to origin.")
		return Transform3D(Basis(), Vector3(0.0, 1.2, 0.0))

	if use_safe_spawn_selection and not players_to_avoid.is_empty():
		return _get_safest_spawn_transform(players_to_avoid)

	return spawn_points.pick_random()


func get_spawn_positions() -> Array[Vector3]:
	var positions: Array[Vector3] = []
	for spawn_transform in spawn_points:
		positions.append(spawn_transform.origin)
	return positions


func _get_safest_spawn_transform(players_to_avoid: Array[PlayerController]) -> Transform3D:
	var best_spawn: Transform3D = spawn_points[0]
	var best_distance_squared: float = -1.0

	for spawn_transform in spawn_points:
		var closest_distance_squared: float = INF
		for player in players_to_avoid:
			if player == null or not is_instance_valid(player):
				continue
			var distance_squared: float = spawn_transform.origin.distance_squared_to(player.global_position)
			closest_distance_squared = minf(closest_distance_squared, distance_squared)

		if closest_distance_squared > best_distance_squared:
			best_distance_squared = closest_distance_squared
			best_spawn = spawn_transform

	return best_spawn
