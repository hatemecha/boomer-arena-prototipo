class_name SpawnManager
extends Node

@export var use_safe_spawn_selection: bool = false

var spawn_points: Array[Transform3D] = [
	Transform3D(Basis().rotated(Vector3.UP, deg_to_rad(180.0)), Vector3(0.0, 0.0, 11.0)),
	Transform3D(Basis(), Vector3(0.0, 0.0, -11.0)),
	Transform3D(Basis().rotated(Vector3.UP, deg_to_rad(90.0)), Vector3(-11.0, 0.0, 0.0)),
	Transform3D(Basis().rotated(Vector3.UP, deg_to_rad(-90.0)), Vector3(11.0, 0.0, 0.0)),
]


func load_from_arena(arena: Node3D) -> void:
	if arena == null:
		return

	var loaded_points: Array[Transform3D] = []
	for marker in arena.get_tree().get_nodes_in_group("spawn_points"):
		if marker is Node3D:
			loaded_points.append((marker as Node3D).global_transform)

	if loaded_points.is_empty():
		var spawn_root: Node = arena.get_node_or_null("SpawnPoints")
		if spawn_root != null:
			for child in spawn_root.get_children():
				if child is Node3D:
					loaded_points.append((child as Node3D).global_transform)

	if loaded_points.is_empty():
		return

	spawn_points = loaded_points


func get_spawn_transform(
	players_to_avoid: Array[PlayerController] = [],
	avoid_position: Vector3 = Vector3.ZERO,
	killer_weight: float = 2.5,
	exclude_player: PlayerController = null
) -> Transform3D:
	if spawn_points.is_empty():
		push_warning("No spawn points configured. Falling back to origin.")
		return Transform3D(Basis(), Vector3(0.0, 0.0, 0.0))

	if use_safe_spawn_selection and (not players_to_avoid.is_empty() or avoid_position != Vector3.ZERO):
		return _get_safest_spawn_transform(players_to_avoid, avoid_position, killer_weight, exclude_player)

	return spawn_points.pick_random()


func get_spawn_positions() -> Array[Vector3]:
	var positions: Array[Vector3] = []
	for spawn_transform in spawn_points:
		positions.append(spawn_transform.origin)
	return positions


func _get_safest_spawn_transform(
	players_to_avoid: Array[PlayerController],
	avoid_position: Vector3 = Vector3.ZERO,
	killer_weight: float = 2.5,
	exclude_player: PlayerController = null
) -> Transform3D:
	var best_candidates: Array[Transform3D] = []
	var best_score: float = -1.0

	for spawn_transform in spawn_points:
		var min_distance_squared: float = INF
		for player in players_to_avoid:
			if player == null or not is_instance_valid(player) or player == exclude_player:
				continue
			if player.health != null and player.health.is_dead:
				continue
			var distance_squared: float = spawn_transform.origin.distance_squared_to(player.global_position)
			min_distance_squared = minf(min_distance_squared, distance_squared)

		var score: float = min_distance_squared
		if avoid_position != Vector3.ZERO:
			var killer_distance_squared: float = spawn_transform.origin.distance_squared_to(avoid_position)
			score = minf(score, killer_distance_squared * killer_weight)

		if score > best_score:
			best_score = score
			best_candidates = [spawn_transform]
		elif is_equal_approx(score, best_score):
			best_candidates.append(spawn_transform)

	if best_candidates.is_empty():
		return spawn_points.pick_random()
	return best_candidates.pick_random()
