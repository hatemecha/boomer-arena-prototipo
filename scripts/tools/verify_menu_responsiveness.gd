extends SceneTree

const VIEWPORTS: Array[Vector2i] = [
	Vector2i(800, 450),
	Vector2i(640, 360),
	Vector2i(426, 240),
]


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var settings := get_root().get_node("PlayerSettings")
	for viewport_size in VIEWPORTS:
		settings.set_performance_profile(
			PlayerSettings.PerformanceProfile.ULTRA_LOW
			if viewport_size == Vector2i(426, 240)
			else PlayerSettings.PerformanceProfile.DEFAULT
		)

		var viewport := SubViewport.new()
		viewport.size = viewport_size
		get_root().add_child(viewport)

		var options := (load("res://scenes/ui/OptionsMenu.tscn") as PackedScene).instantiate() as OptionsMenu
		viewport.add_child(options)
		var lobby := (load("res://scenes/ui/LanLobbyMenu.tscn") as PackedScene).instantiate() as LanLobbyMenu
		viewport.add_child(lobby)
		var result := (load("res://scenes/ui/MatchResultOverlay.tscn") as PackedScene).instantiate() as MatchResultOverlay
		viewport.add_child(result)
		await process_frame

		assert(options.get_node("Center/MenuShell") != null)
		var options_scroll := options.find_child("Scroll", true, false) as ScrollContainer
		assert(options_scroll != null)
		assert(options.find_child("ProfileHeader", true, false).visible)
		assert(not options.find_child("GameplayHeader", true, false).visible)
		options.call("_show_options_section", 2)
		assert(options.find_child("VideoHeader", true, false).visible)
		assert(not options.find_child("ProfileHeader", true, false).visible)

		assert(lobby.get_node("Center/MenuShell") != null)
		assert(lobby.practice_button != null)
		assert(options_scroll != null)
		assert(options_scroll.custom_minimum_size.y > 0.0)
		assert(lobby.content.custom_minimum_size.x > 0.0)
		assert(result.title_label.custom_minimum_size.x <= viewport_size.x)

		viewport.queue_free()
		await process_frame

	settings.set_performance_profile(PlayerSettings.PerformanceProfile.DEFAULT)
	print("VERIFY menu_responsiveness OK viewports=", VIEWPORTS)
	quit()
