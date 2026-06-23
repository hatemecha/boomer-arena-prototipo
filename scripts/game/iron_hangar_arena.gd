class_name IronHangarArena
extends Node3D

## Runtime setup for Iron Hangar — geometry/lights live in IronHangarArena.tscn (TestArena format).

const IRON_HANGAR_PICKUP_DEFS: Array[Dictionary] = [
	{"position": Vector3(-3.0, 0.0, 0.0), "scene_key": "health"},
	{"position": Vector3(3.0, 0.0, 0.0), "scene_key": "ammo"},
	{"position": Vector3(0.0, 0.0, -3.5), "scene_key": "ammo"},
	{"position": Vector3(0.0, 0.0, 3.5), "scene_key": "health"},
]


func _ready() -> void:
	_configure_disco_lighting()
	_configure_aisle_fill_lights()
	_configure_gameplay_markers()
	ArenaMarkersHelper.notify_visual_director_scene_changed(self)


func _configure_disco_lighting() -> void:
	_rename_node_if_exists("Omni0", "ArenaLightCenter")
	_rename_node_if_exists("Omni1", "ArenaLightNW")
	_rename_node_if_exists("Omni2", "ArenaLightNE")
	_rename_node_if_exists("Omni3", "ArenaLightSW")
	_rename_node_if_exists("Omni4", "ArenaLightSE")
	_rename_node_if_exists("Omni5", "WindowFillNorth")
	_rename_node_if_exists("Omni6", "WindowFillSouth")
	_rename_node_if_exists("RampLight0", "WindowFillWest")
	_rename_node_if_exists("RampLight1", "WindowFillEast")
	_rename_node_if_exists("RampLight2", "WindowFillRampSW")
	_rename_node_if_exists("RampLight3", "WindowFillRampSE")

	_rename_node_if_exists("LightC", "LightPanelCenter")
	_rename_node_if_exists("LightNW", "LightPanelNW")
	_rename_node_if_exists("LightNE", "LightPanelNE")
	_rename_node_if_exists("LightSW", "LightPanelSW")
	_rename_node_if_exists("LightSE", "LightPanelSE")
	_rename_node_if_exists("LightNBal", "LightPanelNorth")
	_rename_node_if_exists("LightSBal", "LightPanelSouth")


func _rename_node_if_exists(old_name: String, new_name: String) -> void:
	var node: Node = get_node_or_null(old_name)
	if node == null or has_node(new_name):
		return
	node.name = new_name


func _configure_aisle_fill_lights() -> void:
	_create_aisle_fill_light("AisleFillCenter", Vector3(0.0, 3.2, 0.0))
	_create_aisle_fill_light("AisleFillWest", Vector3(-6.0, 2.8, 0.0))
	_create_aisle_fill_light("AisleFillEast", Vector3(6.0, 2.8, 0.0))
	_create_aisle_fill_light("AisleFillNorth", Vector3(0.0, 3.4, -8.0))
	_create_aisle_fill_light("AisleFillSouth", Vector3(0.0, 3.4, 8.0))
	_create_aisle_fill_light("AisleFillLowCenter", Vector3(0.0, 2.4, 0.0))


func _create_aisle_fill_light(light_name: String, light_position: Vector3) -> void:
	if has_node(light_name):
		return

	var aisle_light := OmniLight3D.new()
	aisle_light.name = light_name
	aisle_light.position = light_position
	aisle_light.shadow_enabled = false
	aisle_light.light_color = Color(0.5, 0.72, 0.82)
	aisle_light.light_energy = 1.35
	aisle_light.omni_range = 16.0
	aisle_light.light_indirect_energy = 0.2
	add_child(aisle_light)


func _configure_gameplay_markers() -> void:
	ArenaMarkersHelper.ensure_spawn_points(self)
	ArenaMarkersHelper.ensure_void_recovery(self)
	ArenaMarkersHelper.ensure_music_stereo_spawn(self)
	ArenaMarkersHelper.ensure_arena_cameras(self)
	ArenaMarkersHelper.ensure_pickup_markers(self, IRON_HANGAR_PICKUP_DEFS)
