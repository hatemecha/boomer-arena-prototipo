class_name PickupSpawner
extends Node

@export var ammo_pickup_scene: PackedScene = preload("res://scenes/pickups/AmmoPickup.tscn")
@export var health_pickup_scene: PackedScene = preload("res://scenes/pickups/HealthPickup.tscn")

var pickup_spawns: Array[Dictionary] = [
	{"scene_key": "ammo", "position": Vector3(-11.0, 1.0, -11.0)},
	{"scene_key": "ammo", "position": Vector3(11.0, 1.0, 11.0)},
	{"scene_key": "health", "position": Vector3(-11.0, 1.0, 11.0)},
	{"scene_key": "health", "position": Vector3(11.0, 1.0, -11.0)},
]

var spawned_pickups: Array[Node3D] = []


func spawn_pickups(parent: Node) -> void:
	if parent == null:
		push_error("PickupSpawner requires a valid parent node.")
		return

	for pickup_spawn in pickup_spawns:
		_spawn_pickup(parent, pickup_spawn)


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
	pickup.global_position = spawn_position if spawn_position is Vector3 else Vector3.ZERO
	spawned_pickups.append(pickup)


func _get_pickup_scene(scene_key: String) -> PackedScene:
	match scene_key:
		"ammo":
			return ammo_pickup_scene
		"health":
			return health_pickup_scene
		_:
			push_warning("Unknown pickup scene key: %s" % scene_key)
			return null
