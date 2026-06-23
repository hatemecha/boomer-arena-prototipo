class_name ArenaMarkersHelper
extends RefCounted

const DEFAULT_SPAWN_POSITIONS: Array[Vector3] = [
	Vector3(0.0, 0.0, 11.0),
	Vector3(0.0, 0.0, -11.0),
	Vector3(-11.0, 0.0, 0.0),
	Vector3(11.0, 0.0, 0.0),
]
const DEFAULT_SPAWN_YAWS: Array[float] = [PI, 0.0, PI * 0.5, -PI * 0.5]
const DEFAULT_CAMERA_CORNERS: Array[Vector3] = [
	Vector3(-13.0, 6.5, -13.0),
	Vector3(13.0, 6.5, -13.0),
	Vector3(-13.0, 6.5, 13.0),
	Vector3(13.0, 6.5, 13.0),
]


static func ensure_spawn_points(arena: Node3D) -> void:
	if arena.has_node("SpawnPoints"):
		return

	var spawn_root := Node3D.new()
	spawn_root.name = "SpawnPoints"
	arena.add_child(spawn_root)

	for index in range(DEFAULT_SPAWN_POSITIONS.size()):
		var marker := Marker3D.new()
		marker.name = "Spawn%d" % index
		marker.position = DEFAULT_SPAWN_POSITIONS[index]
		marker.rotation.y = DEFAULT_SPAWN_YAWS[index]
		marker.add_to_group("spawn_points")
		spawn_root.add_child(marker)


static func ensure_arena_cameras(arena: Node3D, look_at_position: Vector3 = Vector3(0.0, 1.2, 0.0)) -> void:
	if arena.has_node("ArenaCameras"):
		return

	var camera_root := Node3D.new()
	camera_root.name = "ArenaCameras"
	arena.add_child(camera_root)

	for index in range(DEFAULT_CAMERA_CORNERS.size()):
		var camera_marker := Marker3D.new()
		camera_marker.name = "ArenaCam%d" % index
		camera_marker.position = DEFAULT_CAMERA_CORNERS[index]
		camera_root.add_child(camera_marker)
		camera_marker.look_at(look_at_position, Vector3.UP)


static func get_best_corner_transform_for_action(arena: Node3D, action_position: Vector3) -> Transform3D:
	var camera_root: Node3D = arena.get_node_or_null("ArenaCameras") as Node3D
	if camera_root == null:
		return Transform3D(Basis(), action_position + Vector3(8.0, 5.0, 8.0))

	var best_transform: Transform3D = Transform3D(Basis(), action_position + Vector3(8.0, 5.0, 8.0))
	var best_distance: float = -1.0
	for child in camera_root.get_children():
		if not (child is Marker3D):
			continue
		var marker: Marker3D = child as Marker3D
		var distance_squared: float = marker.global_position.distance_squared_to(action_position)
		if distance_squared > best_distance:
			best_distance = distance_squared
			best_transform = marker.global_transform
	return best_transform


static func ensure_music_stereo_spawn(
	arena: Node3D,
	spawn_position: Vector3 = Vector3(-13.5, 0.0, 13.5),
	spawn_yaw_degrees: float = -135.0
) -> void:
	if arena.has_node("MusicStereoSpawn"):
		return

	var stereo_marker := Marker3D.new()
	stereo_marker.name = "MusicStereoSpawn"
	stereo_marker.position = spawn_position
	stereo_marker.rotation.y = deg_to_rad(spawn_yaw_degrees)
	arena.add_child(stereo_marker)


static func ensure_pickup_markers(arena: Node3D, pickup_defs: Array[Dictionary]) -> void:
	if arena.has_node("PickupSpawns"):
		return

	var pickup_root := Node3D.new()
	pickup_root.name = "PickupSpawns"
	arena.add_child(pickup_root)

	for index in range(pickup_defs.size()):
		var pickup_def: Dictionary = pickup_defs[index]
		var marker := Marker3D.new()
		marker.name = "Pickup%d" % index
		marker.position = pickup_def["position"]
		marker.set_meta("scene_key", pickup_def["scene_key"])
		marker.add_to_group("pickup_spawns")
		pickup_root.add_child(marker)


static func notify_visual_director_scene_changed(arena: Node3D) -> void:
	var game_root: Node = arena.get_parent()
	if game_root == null:
		return
	var visual_director: PSXVisualDirector = game_root.get_node_or_null("PSXVisualDirector") as PSXVisualDirector
	if visual_director != null:
		visual_director.invalidate_scene_cache()
		visual_director.refresh_visual_style()
