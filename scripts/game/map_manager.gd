class_name MapManager
extends Node

signal active_map_changed(map_id: String, arena: Node3D)

const MAP_TEST_ARENA: String = "test_arena"
const MAP_DUST2: String = "dust2"
const MAP_BACKROOMS: String = "backrooms"
const MAP_IRON_HANGAR: String = "iron_hangar"
const LEGACY_MAP_DOOM_E1M1: String = "doom_e1m1"
const DEFAULT_MAP_ID: String = MAP_IRON_HANGAR
const MAP_SCENE_PATHS: Dictionary = {
	MAP_IRON_HANGAR: "res://scenes/maps/IronHangarArena.tscn",
	MAP_TEST_ARENA: "res://scenes/maps/TestArena.tscn",
	MAP_DUST2: "res://scenes/maps/Dust2Arena.tscn",
	MAP_BACKROOMS: "res://scenes/maps/BackroomsArena.tscn",
}
const MAP_LABELS: Dictionary = {
	MAP_IRON_HANGAR: "IRON HANGAR",
	MAP_TEST_ARENA: "TEST ARENA",
	MAP_DUST2: "DE_DUST2",
	MAP_BACKROOMS: "BACKROOMS",
}
const LEGACY_MAP_ALIASES: Dictionary = {
	LEGACY_MAP_DOOM_E1M1: MAP_IRON_HANGAR,
}

var selected_map_id: String = DEFAULT_MAP_ID
var active_map_id: String = ""
var active_arena: Node3D


func activate_map(parent: Node, map_id: String) -> bool:
	var safe_map_id: String = sanitize_map_id(map_id)
	selected_map_id = safe_map_id

	if active_arena != null and is_instance_valid(active_arena) and active_map_id == safe_map_id:
		return false

	clear_active_map()
	var map_scene: PackedScene = get_map_scene(safe_map_id)
	if map_scene == null:
		push_error("Map scene could not be loaded: %s" % safe_map_id)
		active_map_id = ""
		return false
	active_arena = map_scene.instantiate() as Node3D
	if active_arena == null:
		push_error("Map %s must instantiate as Node3D." % safe_map_id)
		active_map_id = ""
		return false

	active_map_id = safe_map_id
	active_arena.name = "ActiveArena"
	parent.add_child(active_arena)
	parent.move_child(active_arena, 0)
	active_map_changed.emit(active_map_id, active_arena)
	return true


func clear_active_map() -> void:
	if active_arena != null and is_instance_valid(active_arena):
		var arena_parent: Node = active_arena.get_parent()
		if arena_parent != null:
			arena_parent.remove_child(active_arena)
		active_arena.queue_free()
	active_arena = null
	active_map_id = ""


func get_active_arena() -> Node3D:
	if active_arena == null or not is_instance_valid(active_arena):
		return null
	return active_arena


func get_map_options() -> Array[Dictionary]:
	return [
		{"id": MAP_IRON_HANGAR, "label": str(MAP_LABELS[MAP_IRON_HANGAR])},
		{"id": MAP_DUST2, "label": str(MAP_LABELS[MAP_DUST2])},
		{"id": MAP_BACKROOMS, "label": str(MAP_LABELS[MAP_BACKROOMS])},
		{"id": MAP_TEST_ARENA, "label": str(MAP_LABELS[MAP_TEST_ARENA])},
	]


func sanitize_map_id(map_id: String) -> String:
	var clean_id: String = map_id.strip_edges().to_lower()
	if LEGACY_MAP_ALIASES.has(clean_id):
		clean_id = str(LEGACY_MAP_ALIASES[clean_id])
	if MAP_SCENE_PATHS.has(clean_id):
		return clean_id
	return DEFAULT_MAP_ID


func get_map_scene(map_id: String) -> PackedScene:
	return load(MAP_SCENE_PATHS[sanitize_map_id(map_id)]) as PackedScene


func get_map_label(map_id: String) -> String:
	var safe_map_id: String = sanitize_map_id(map_id)
	return str(MAP_LABELS.get(safe_map_id, safe_map_id))
