extends SceneTree

const OUTPUT_PATH: String = "res://scenes/maps/IronHangarArena.tscn"
const ARENA_SCRIPT: Script = preload("res://scripts/game/iron_hangar_arena.gd")
const IronHangarGeometry = preload("res://scripts/tools/iron_hangar_geometry.gd")


func _init() -> void:
	var arena_root := Node3D.new()
	arena_root.name = "IronHangarArena"
	arena_root.set_script(ARENA_SCRIPT)
	get_root().add_child(arena_root)

	IronHangarGeometry.new().build(arena_root)
	_set_owner_recursive(arena_root, arena_root)

	var packed_scene := PackedScene.new()
	var pack_error: Error = packed_scene.pack(arena_root)
	if pack_error != OK:
		push_error("Failed to pack Iron Hangar arena: %s" % str(pack_error))
		quit(1)
		return

	var save_error: Error = ResourceSaver.save(packed_scene, OUTPUT_PATH)
	if save_error != OK:
		push_error("Failed to save Iron Hangar arena: %s" % str(save_error))
		quit(1)
		return

	print("Baked Iron Hangar arena to %s" % OUTPUT_PATH)
	quit()


func _set_owner_recursive(node: Node, scene_root: Node) -> void:
	for child in node.get_children():
		child.owner = scene_root
		_set_owner_recursive(child, scene_root)
