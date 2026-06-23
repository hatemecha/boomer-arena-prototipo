class_name PickupSpawner
extends Node

const FloorSnapScript: GDScript = preload("res://scripts/game/floor_snap.gd")

@export var ammo_pickup_scene: PackedScene = preload("res://scenes/pickups/AmmoPickup.tscn")
@export var health_pickup_scene: PackedScene = preload("res://scenes/pickups/HealthPickup.tscn")

const DEFAULT_PICKUP_SPAWNS: Array[Dictionary] = [
	{"scene_key": "ammo", "position": Vector3(-11.0, 1.0, -11.0)},
	{"scene_key": "ammo", "position": Vector3(11.0, 1.0, 11.0)},
	{"scene_key": "health", "position": Vector3(-11.0, 1.0, 11.0)},
	{"scene_key": "health", "position": Vector3(11.0, 1.0, -11.0)},
]

var pickup_spawns: Array[Dictionary] = DEFAULT_PICKUP_SPAWNS.duplicate(true)
var spawned_pickups: Array[Node3D] = []


func load_from_arena(arena: Node3D) -> void:
	if arena == null:
		pickup_spawns = DEFAULT_PICKUP_SPAWNS.duplicate(true)
		return

	var loaded_spawns: Array[Dictionary] = []
	var pickup_root: Node = arena.get_node_or_null("PickupSpawns")
	if pickup_root != null:
		for child in pickup_root.get_children():
			if not (child is Node3D):
				continue
			var marker := child as Node3D
			loaded_spawns.append({
				"scene_key": str(marker.get_meta("scene_key", "ammo")),
				"position": marker.global_position,
			})

	if loaded_spawns.is_empty():
		for marker_node in arena.find_children("*", "Node3D", true, false):
			var marker := marker_node as Node3D
			if marker == null or not marker.is_in_group("pickup_spawns"):
				continue
			loaded_spawns.append({
				"scene_key": str(marker.get_meta("scene_key", "ammo")),
				"position": marker.global_position,
			})

	pickup_spawns = loaded_spawns if not loaded_spawns.is_empty() else _use_default_pickup_spawns(arena)


func _use_default_pickup_spawns(arena: Node3D) -> Array[Dictionary]:
	push_warning(
		"PickupSpawner: arena '%s' has no PickupSpawns markers; using default layout." % arena.name
	)
	return DEFAULT_PICKUP_SPAWNS.duplicate(true)


func spawn_pickups(parent: Node) -> void:
	if parent == null:
		push_error("PickupSpawner requires a valid parent node.")
		return

	clear_pickups()
	for pickup_spawn in pickup_spawns:
		_spawn_pickup(parent, pickup_spawn)


func clear_pickups() -> void:
	for pickup in spawned_pickups:
		if pickup != null and is_instance_valid(pickup):
			var parent: Node = pickup.get_parent()
			if parent != null:
				parent.remove_child(pickup)
			pickup.queue_free()
	spawned_pickups.clear()


func get_pickup_positions() -> Array[Vector3]:
	var positions: Array[Vector3] = []
	for pickup_spawn in pickup_spawns:
		var spawn_position: Variant = pickup_spawn.get("position", Vector3.ZERO)
		if spawn_position is Vector3:
			positions.append(spawn_position)
	return positions


func _spawn_pickup(parent: Node, pickup_spawn: Dictionary) -> void:
	var scene: PackedScene = _get_pickup_scene(str(pickup_spawn.get("scene_key", "")))
	if scene == null:
		push_error("PickupSpawner cannot spawn pickup because scene is missing.")
		return

	var pickup: Node3D = scene.instantiate() as Node3D
	if pickup == null:
		push_error("Pickup scene must instantiate a Node3D.")
		return

	parent.add_child(pickup)
	var spawn_position: Variant = pickup_spawn.get("position", Vector3.ZERO)
	pickup.global_position = _resolve_pickup_position(parent, spawn_position if spawn_position is Vector3 else Vector3.ZERO)
	spawned_pickups.append(pickup)


func _resolve_pickup_position(parent: Node, spawn_position: Vector3) -> Vector3:
	if not (parent is Node3D):
		return spawn_position + Vector3(0.0, FloorSnapScript.PICKUP_FLOAT, 0.0)

	var space_state: PhysicsDirectSpaceState3D = (parent as Node3D).get_world_3d().direct_space_state
	return FloorSnapScript.pickup_position(spawn_position, space_state)


func _get_pickup_scene(scene_key: String) -> PackedScene:
	match scene_key:
		"ammo":
			return ammo_pickup_scene
		"health":
			return health_pickup_scene
		_:
			push_warning("Unknown pickup scene key: %s" % scene_key)
			return null
