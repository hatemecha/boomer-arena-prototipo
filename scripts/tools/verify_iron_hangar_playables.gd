extends SceneTree

func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var arena: Node3D = (load("res://scenes/maps/IronHangarArena.tscn") as PackedScene).instantiate() as Node3D
	get_root().add_child(arena)
	await process_frame

	var pickup_root: Node = arena.get_node_or_null("PickupSpawns")
	var spawn_root: Node = arena.get_node_or_null("SpawnPoints")
	var camera_root: Node = arena.get_node_or_null("ArenaCameras")
	var pickup_markers: int = pickup_root.get_child_count() if pickup_root != null else 0
	var spawn_markers: int = spawn_root.get_child_count() if spawn_root != null else 0
	var camera_markers: int = camera_root.get_child_count() if camera_root != null else 0
	var has_music: bool = arena.has_node("MusicStereoSpawn")

	print("VERIFY baked_pickup_markers=", pickup_markers)
	print("VERIFY runtime_spawn_markers=", spawn_markers)
	print("VERIFY runtime_camera_markers=", camera_markers)
	print("VERIFY runtime_music=", has_music)

	var pickup_spawner := PickupSpawner.new()
	pickup_spawner.name = "PickupSpawner"
	get_root().add_child(pickup_spawner)
	pickup_spawner.load_from_arena(arena)
	print("VERIFY loaded_pickups=", pickup_spawner.pickup_spawns.size())
	pickup_spawner.spawn_pickups(get_root())
	print("VERIFY spawned_pickups=", pickup_spawner.spawned_pickups.size())

	var spawn_manager := SpawnManager.new()
	spawn_manager.name = "SpawnManager"
	get_root().add_child(spawn_manager)
	spawn_manager.load_from_arena(arena)
	print("VERIFY loaded_spawns=", spawn_manager.spawn_points.size())

	if pickup_markers < 4 or spawn_markers < 4 or camera_markers < 4 or not has_music or pickup_spawner.spawned_pickups.size() < 4 or spawn_manager.spawn_points.size() < 4:
		push_error("Iron Hangar playables verification failed")
		quit(1)
		return

	print("VERIFY OK")
	quit()
