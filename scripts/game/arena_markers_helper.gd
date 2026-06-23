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


static func ensure_void_recovery(
	arena: Node3D,
	center: Vector3 = Vector3(0.0, -12.0, 0.0),
	size: Vector3 = Vector3(160.0, 24.0, 160.0)
) -> void:
	var void_area: Area3D
	if arena.has_node("VoidRecovery"):
		void_area = arena.get_node("VoidRecovery") as Area3D
	else:
		void_area = Area3D.new()
		void_area.name = "VoidRecovery"
		void_area.monitoring = true
		void_area.monitorable = false
		arena.add_child(void_area)
		var collider := CollisionShape3D.new()
		collider.name = "CollisionShape3D"
		void_area.add_child(collider)

	void_area.position = center
	var shape_node := void_area.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node == null:
		return

	var box := shape_node.shape as BoxShape3D
	if box == null:
		box = BoxShape3D.new()
		shape_node.shape = box
	box.size = size

	if arena.has_method("_on_void_recovery_body_entered"):
		var handler := Callable(arena, "_on_void_recovery_body_entered")
		if not void_area.body_entered.is_connected(handler):
			void_area.body_entered.connect(handler)
	elif not void_area.body_entered.is_connected(_on_void_recovery_body_entered):
		void_area.body_entered.connect(_on_void_recovery_body_entered.bind(arena))


static func _on_void_recovery_body_entered(arena: Node3D, body: Node3D) -> void:
	var player := body as PlayerController
	if player == null:
		return

	var game_root := arena.get_parent()
	if game_root == null or not game_root.has_method("recover_player_from_world_bounds"):
		push_error("%s requires a game root that can recover out-of-bounds players." % arena.name)
		return
	game_root.call_deferred("recover_player_from_world_bounds", player)


static func notify_visual_director_scene_changed(arena: Node3D) -> void:
	var game_root: Node = arena.get_parent()
	if game_root == null:
		return
	var visual_director: PSXVisualDirector = game_root.get_node_or_null("PSXVisualDirector") as PSXVisualDirector
	if visual_director != null:
		visual_director.invalidate_scene_cache()
		visual_director.refresh_visual_style()
