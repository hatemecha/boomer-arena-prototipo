class_name IronHangarArena
extends Node3D

## Runtime setup for Iron Hangar — geometry/lights live in IronHangarArena.tscn (TestArena format).


func _ready() -> void:
	_configure_aisle_fill_lights()
	_configure_gameplay_markers()
	_configure_pickup_markers()
	_notify_visual_director_scene_changed()


func get_best_corner_transform_for_action(action_position: Vector3) -> Transform3D:
	var camera_root: Node3D = get_node_or_null("ArenaCameras") as Node3D
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


func _configure_aisle_fill_lights() -> void:
	_create_aisle_fill_light("AisleFillCenter", Vector3(0.0, 3.2, 0.0))
	_create_aisle_fill_light("AisleFillWest", Vector3(-6.0, 2.8, 0.0))
	_create_aisle_fill_light("AisleFillEast", Vector3(6.0, 2.8, 0.0))


func _create_aisle_fill_light(light_name: String, light_position: Vector3) -> void:
	if has_node(light_name):
		return

	var aisle_light := OmniLight3D.new()
	aisle_light.name = light_name
	aisle_light.position = light_position
	aisle_light.shadow_enabled = false
	aisle_light.light_color = Color(0.5, 0.72, 0.82)
	aisle_light.light_energy = 1.2
	aisle_light.omni_range = 14.0
	aisle_light.light_indirect_energy = 0.2
	add_child(aisle_light)


func _configure_gameplay_markers() -> void:
	if has_node("SpawnPoints"):
		return

	var spawn_root := Node3D.new()
	spawn_root.name = "SpawnPoints"
	add_child(spawn_root)

	var spawn_positions: Array[Vector3] = [
		Vector3(0.0, 0.0, 11.0),
		Vector3(0.0, 0.0, -11.0),
		Vector3(-11.0, 0.0, 0.0),
		Vector3(11.0, 0.0, 0.0),
	]
	var spawn_yaws: Array[float] = [PI, 0.0, PI * 0.5, -PI * 0.5]
	for index in range(spawn_positions.size()):
		var marker := Marker3D.new()
		marker.name = "Spawn%d" % index
		marker.position = spawn_positions[index]
		marker.rotation.y = spawn_yaws[index]
		marker.add_to_group("spawn_points")
		spawn_root.add_child(marker)

	var stereo_marker := Marker3D.new()
	stereo_marker.name = "MusicStereoSpawn"
	stereo_marker.position = Vector3(-13.5, 0.0, 13.5)
	stereo_marker.rotation.y = deg_to_rad(-135.0)
	add_child(stereo_marker)

	var camera_root := Node3D.new()
	camera_root.name = "ArenaCameras"
	add_child(camera_root)

	var corner_positions: Array[Vector3] = [
		Vector3(-13.0, 6.5, -13.0),
		Vector3(13.0, 6.5, -13.0),
		Vector3(-13.0, 6.5, 13.0),
		Vector3(13.0, 6.5, 13.0),
	]
	for index in range(corner_positions.size()):
		var camera_marker := Marker3D.new()
		camera_marker.name = "ArenaCam%d" % index
		camera_marker.position = corner_positions[index]
		camera_root.add_child(camera_marker)
		camera_marker.look_at(Vector3(0.0, 1.2, 0.0), Vector3.UP)


func _configure_pickup_markers() -> void:
	if has_node("PickupSpawns"):
		return

	var pickup_root := Node3D.new()
	pickup_root.name = "PickupSpawns"
	add_child(pickup_root)

	var pickup_defs: Array[Dictionary] = [
		{"position": Vector3(-3.0, 0.0, 0.0), "scene_key": "health"},
		{"position": Vector3(3.0, 0.0, 0.0), "scene_key": "ammo"},
		{"position": Vector3(0.0, 0.0, -3.5), "scene_key": "ammo"},
		{"position": Vector3(0.0, 0.0, 3.5), "scene_key": "health"},
	]
	for index in range(pickup_defs.size()):
		var pickup_def: Dictionary = pickup_defs[index]
		var marker := Marker3D.new()
		marker.name = "Pickup%d" % index
		marker.position = pickup_def["position"]
		marker.set_meta("scene_key", pickup_def["scene_key"])
		marker.add_to_group("pickup_spawns")
		pickup_root.add_child(marker)


func _notify_visual_director_scene_changed() -> void:
	var game_root: Node = get_parent()
	if game_root == null:
		return
	var visual_director: PSXVisualDirector = game_root.get_node_or_null("PSXVisualDirector") as PSXVisualDirector
	if visual_director != null:
		visual_director.invalidate_scene_cache()
