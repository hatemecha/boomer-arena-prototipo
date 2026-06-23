class_name SpawnManager
extends Node

const FloorSnapScript: GDScript = preload("res://scripts/game/floor_snap.gd")

@export var use_safe_spawn_selection: bool = false

var spawn_points: Array[Transform3D] = []


func load_from_arena(arena: Node3D) -> void:
	spawn_points = []
	if arena == null:
		push_error("SpawnManager cannot load spawn points from a null arena.")
		return

	var loaded_markers: Array[Transform3D] = _collect_marker_transforms(arena)
	if loaded_markers.is_empty():
		push_error("Arena %s has no spawn markers." % arena.name)
		return

	var space_state: PhysicsDirectSpaceState3D = arena.get_world_3d().direct_space_state
	if space_state == null:
		push_error("Arena %s is not in the scene tree yet; spawn points were not validated." % arena.name)
		return

	for marker_transform in loaded_markers:
		var resolved: Transform3D = FloorSnapScript.resolve_spawn_transform(marker_transform, space_state)
		if FloorSnapScript.is_spawn_transform_safe(resolved, space_state):
			spawn_points.append(resolved)

	if not spawn_points.is_empty():
		return

	var emergency: Transform3D = FloorSnapScript.find_emergency_spawn_transform(
		_build_emergency_probe_positions(loaded_markers),
		space_state
	)
	if FloorSnapScript.is_spawn_transform_safe(emergency, space_state):
		spawn_points.append(emergency)
		push_warning("Arena %s is using an emergency fallback spawn." % arena.name)
		return

	push_error("Arena %s has no safe spawn points." % arena.name)


func get_spawn_transform(
	players_to_avoid: Array[PlayerController] = [],
	avoid_position: Vector3 = Vector3.ZERO,
	killer_weight: float = 2.5,
	exclude_player: PlayerController = null
) -> Transform3D:
	if spawn_points.is_empty():
		push_error("No safe spawn points configured.")
		return Transform3D(Basis(), Vector3(0.0, 2.0, 0.0))

	if use_safe_spawn_selection and (not players_to_avoid.is_empty() or avoid_position != Vector3.ZERO):
		return _get_safest_spawn_transform(players_to_avoid, avoid_position, killer_weight, exclude_player)

	return spawn_points.pick_random()


func get_spawn_positions() -> Array[Vector3]:
	var positions: Array[Vector3] = []
	for spawn_transform in spawn_points:
		positions.append(spawn_transform.origin)
	return positions


func _collect_marker_transforms(arena: Node3D) -> Array[Transform3D]:
	var loaded_points: Array[Transform3D] = []
	var spawn_root: Node = arena.get_node_or_null("SpawnPoints")
	if spawn_root != null:
		for child in spawn_root.get_children():
			if child is Node3D:
				loaded_points.append((child as Node3D).global_transform)

	if loaded_points.is_empty():
		for marker in arena.find_children("*", "Node3D", true, false):
			if marker is Node3D and marker.is_in_group("spawn_points"):
				loaded_points.append((marker as Node3D).global_transform)
	return loaded_points


func _build_emergency_probe_positions(marker_transforms: Array[Transform3D]) -> Array[Vector3]:
	var probes: Array[Vector3] = []
	for marker_transform in marker_transforms:
		probes.append(marker_transform.origin)
	probes.append(Vector3.ZERO)
	probes.append(Vector3(0.0, 0.0, 8.0))
	probes.append(Vector3(0.0, 0.0, -8.0))
	probes.append(Vector3(8.0, 0.0, 0.0))
	probes.append(Vector3(-8.0, 0.0, 0.0))
	return probes


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
