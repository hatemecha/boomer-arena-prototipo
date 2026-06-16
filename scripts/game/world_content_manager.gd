class_name WorldContentManager
extends Node

signal pickups_spawned
signal music_stereo_spawned(music_stereo: MusicStereo)
signal music_stereo_playback_toggle_requested
signal music_stereo_next_track_requested

const FloorSnapScript: GDScript = preload("res://scripts/game/floor_snap.gd")

var pickup_spawner: PickupSpawner
var target_scene: PackedScene
var music_stereo_scene: PackedScene
var visual_director: PSXVisualDirector
var disco_director: MusicDiscoDirector

var _spawned_targets: Array[Node3D] = []
var _music_stereo: MusicStereo
var _has_spawned_pickups: bool = false
var _has_spawned_targets: bool = false
var _has_spawned_music_stereo: bool = false


func configure(
	next_pickup_spawner: PickupSpawner,
	next_target_scene: PackedScene,
	next_music_stereo_scene: PackedScene,
	next_visual_director: PSXVisualDirector,
	next_disco_director: MusicDiscoDirector
) -> void:
	pickup_spawner = next_pickup_spawner
	target_scene = next_target_scene
	music_stereo_scene = next_music_stereo_scene
	visual_director = next_visual_director
	disco_director = next_disco_director


func spawn_for_arena(arena: Node3D, parent: Node3D) -> void:
	if parent == null:
		return

	if not _has_spawned_pickups and pickup_spawner != null:
		pickup_spawner.load_from_arena(arena)
		pickup_spawner.spawn_pickups(parent)
		_has_spawned_pickups = true
		pickups_spawned.emit()

	if not _has_spawned_targets:
		_spawn_targets(arena, parent)
		_has_spawned_targets = true

	if not _has_spawned_music_stereo:
		_spawn_music_stereo(arena, parent)
		_has_spawned_music_stereo = true


func clear() -> void:
	if pickup_spawner != null:
		pickup_spawner.clear_pickups()

	for target in _spawned_targets:
		if target != null and is_instance_valid(target):
			var target_parent: Node = target.get_parent()
			if target_parent != null:
				target_parent.remove_child(target)
			target.queue_free()
	_spawned_targets.clear()

	if _music_stereo != null and is_instance_valid(_music_stereo):
		var stereo_parent: Node = _music_stereo.get_parent()
		if stereo_parent != null:
			stereo_parent.remove_child(_music_stereo)
		_music_stereo.queue_free()
	_music_stereo = null

	_has_spawned_pickups = false
	_has_spawned_targets = false
	_has_spawned_music_stereo = false


func get_music_stereo() -> MusicStereo:
	if _music_stereo == null or not is_instance_valid(_music_stereo):
		return null
	return _music_stereo


func get_spawned_targets() -> Array[Node3D]:
	return _spawned_targets


func _spawn_targets(arena: Node3D, parent: Node3D) -> void:
	for target_position in _get_target_spawn_positions(arena):
		_spawn_target(parent, target_position)


func _spawn_target(parent: Node3D, spawn_position: Vector3) -> void:
	if target_scene == null:
		return

	var target: Node3D = target_scene.instantiate() as Node3D
	if target == null:
		push_error("Target scene must instantiate a Node3D.")
		return

	parent.add_child(target)
	target.global_position = _snap_world_position_to_floor(parent, spawn_position)
	_spawned_targets.append(target)


func _get_target_spawn_positions(arena: Node3D) -> Array[Vector3]:
	var target_positions: Array[Vector3] = []
	if arena != null:
		var target_root: Node = arena.get_node_or_null("TargetSpawns")
		if target_root != null:
			for child in target_root.get_children():
				if child is Node3D:
					target_positions.append((child as Node3D).global_position)

		if target_positions.is_empty():
			for marker_node in arena.find_children("*", "Node3D", true, false):
				var marker := marker_node as Node3D
				if marker != null and marker.is_in_group("target_spawns"):
					target_positions.append(marker.global_position)

	if not target_positions.is_empty():
		return target_positions

	return [
		Vector3(-7.0, 0.0, -8.0),
		Vector3(7.0, 0.0, 8.0),
		Vector3(0.0, 0.0, -5.5),
	]


func _spawn_music_stereo(arena: Node3D, parent: Node3D) -> void:
	if music_stereo_scene == null:
		return

	var music_stereo: MusicStereo = music_stereo_scene.instantiate() as MusicStereo
	if music_stereo == null:
		push_error("Music stereo scene must instantiate MusicStereo.")
		return

	parent.add_child(music_stereo)
	var stereo_spawn: Node3D = _get_music_stereo_spawn_marker(arena)
	if stereo_spawn != null:
		music_stereo.global_transform = stereo_spawn.global_transform
		music_stereo.global_position = _snap_world_position_to_floor(parent, stereo_spawn.global_position)
	else:
		music_stereo.global_position = _snap_world_position_to_floor(parent, Vector3(-13.5, 0.0, 13.5))
		music_stereo.rotation_degrees.y = -135.0

	music_stereo.playback_toggle_requested.connect(_on_music_stereo_playback_toggle_requested)
	music_stereo.next_track_requested.connect(_on_music_stereo_next_track_requested)
	_music_stereo = music_stereo
	if disco_director != null:
		disco_director.bind(_music_stereo, visual_director)
	music_stereo_spawned.emit(_music_stereo)


func _get_music_stereo_spawn_marker(arena: Node3D) -> Node3D:
	if arena == null:
		return null
	return arena.get_node_or_null("MusicStereoSpawn") as Node3D


func _snap_world_position_to_floor(parent: Node3D, spawn_position: Vector3) -> Vector3:
	return FloorSnapScript.snap_to_floor(spawn_position, parent.get_world_3d().direct_space_state)


func _on_music_stereo_playback_toggle_requested() -> void:
	music_stereo_playback_toggle_requested.emit()


func _on_music_stereo_next_track_requested() -> void:
	music_stereo_next_track_requested.emit()
