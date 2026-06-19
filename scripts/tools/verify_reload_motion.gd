extends SceneTree


func _initialize() -> void:
	var player := (load("res://scenes/player/Player.tscn") as PackedScene).instantiate() as PlayerController
	get_root().add_child(player)
	await process_frame
	for weapon_name in ["SMG", "SawnOff", "Revolver", "Repeater"]:
		var weapon := player.camera.get_node(weapon_name) as WeaponBase
		var sequence: Array = weapon.call("_build_reload_sequence")
		var peak_position: float = 0.0
		var peak_rotation: float = 0.0
		for step: Dictionary in sequence:
			peak_position = maxf(peak_position, (step["pos"] as Vector3).length())
			peak_rotation = maxf(peak_rotation, (step["rot"] as Vector3).length())
		assert(peak_position >= 0.35, "%s necesita más desplazamiento de recarga" % weapon_name)
		assert(peak_rotation >= 48.0, "%s necesita más rotación de recarga" % weapon_name)
	print("VERIFY reload_motion OK")
	quit()
