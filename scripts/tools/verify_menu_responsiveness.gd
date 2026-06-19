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

		var options_scroll := options.get_node("Center/Scroll") as ScrollContainer
		var tabs := options.get_node("Center/Scroll/Content/SectionTabs") as HBoxContainer
		assert(tabs.get_child_count() == 4)
		assert(options.get_node("Center/Scroll/Content/ProfileHeader").visible)
		assert(not options.get_node("Center/Scroll/Content/GameplayHeader").visible)
		options.call("_show_options_section", 2)
		assert(options.get_node("Center/Scroll/Content/VideoHeader").visible)
		assert(not options.get_node("Center/Scroll/Content/ProfileHeader").visible)

		var lobby_scroll := lobby.get_node("Center/ResponsiveScroll") as ScrollContainer
		assert(lobby.get_node_or_null("%PracticeButton") != null)
		assert(options_scroll.custom_minimum_size.x <= viewport_size.x)
		assert(options_scroll.custom_minimum_size.y <= viewport_size.y)
		assert(lobby_scroll.custom_minimum_size.x <= viewport_size.x)
		assert(lobby_scroll.custom_minimum_size.y <= viewport_size.y)
		assert(result.title_label.custom_minimum_size.x <= viewport_size.x)

		viewport.queue_free()
		await process_frame

	settings.set_performance_profile(PlayerSettings.PerformanceProfile.DEFAULT)
	print("VERIFY menu_responsiveness OK viewports=", VIEWPORTS)
	quit()
