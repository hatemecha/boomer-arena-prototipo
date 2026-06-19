extends SceneTree

const MenuCameraScript = preload("res://scripts/ui/arena_menu_camera.gd")
const DeathCinematicScript = preload("res://scripts/game/death_cinematic_director.gd")


func _initialize() -> void:
	var player := (load("res://scenes/player/Player.tscn") as PackedScene).instantiate() as PlayerController
	get_root().add_child(player)
	await process_frame
	assert(player.get_node_or_null("ThirdPersonBackDebugPCam") == null)
	assert(player.get_node_or_null("CameraPivot/PlayerCamera/PhantomCameraHost") == null)
	player.call("_cycle_debug_camera_mode")
	assert(player.camera.top_level, "La tercera persona manual debe seguir disponible")
	player.call("_cycle_debug_camera_mode")
	player.call("_cycle_debug_camera_mode")
	assert(not player.camera.top_level, "La primera persona debe restaurar la cámara")

	var menu_camera := MenuCameraScript.new()
	get_root().add_child(menu_camera)
	assert(not menu_camera.is_processing())
	menu_camera.set_menu_active(true)
	assert(menu_camera.is_processing())

	var death_cinematic := DeathCinematicScript.new()
	get_root().add_child(death_cinematic)
	assert(not death_cinematic.is_processing())
	assert(Engine.max_fps == 60, "El perfil default debe iniciar limitado a 60 FPS")

	print("VERIFY runtime_optimization OK")
	quit()
