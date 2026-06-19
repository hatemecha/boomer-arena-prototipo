class_name Game
extends Node3D

const PlayerSettingsAccess = preload("res://scripts/game/player_settings_access.gd")
const ArenaMenuCameraScript: GDScript = preload("res://scripts/ui/arena_menu_camera.gd")
const MapManagerScript: GDScript = preload("res://scripts/game/map_manager.gd")
const WorldContentManagerScript: GDScript = preload("res://scripts/game/world_content_manager.gd")

@export var player_scene: PackedScene = preload("res://scenes/player/Player.tscn")
@export var ammo_pickup_scene: PackedScene = preload("res://scenes/pickups/AmmoPickup.tscn")
@export var health_pickup_scene: PackedScene = preload("res://scenes/pickups/HealthPickup.tscn")
@export var target_scene: PackedScene = preload("res://scenes/game/DamageableTarget.tscn")
@export var music_stereo_scene: PackedScene = preload("res://scenes/game/MusicStereo.tscn")
@export var hud_scene: PackedScene = preload("res://scenes/ui/HUD.tscn")
@export var options_menu_scene: PackedScene = preload("res://scenes/ui/OptionsMenu.tscn")
@export var lan_lobby_menu_scene: PackedScene = preload("res://scenes/ui/LanLobbyMenu.tscn")
@export var match_result_overlay_scene: PackedScene = preload("res://scenes/ui/MatchResultOverlay.tscn")
@export var player_corpse_scene: PackedScene = preload("res://scenes/player/PlayerCorpse.tscn")
@export_range(0.1, 10.0) var player_respawn_delay: float = 3.0
@export_range(1024, 65535) var lan_port: int = 24500
@export var default_lan_join_address: String = "127.0.0.1"
@export_range(2, 8) var max_lan_players: int = 2
@export_range(5.0, 60.0) var network_sync_rate: float = 20.0
@export_range(0.25, 5.0) var ping_interval: float = 1.0
@export_range(0, 12) var gameplay_render_warmup_frames: int = 4
@export_range(0, 32) var gameplay_effect_pool_warmup_size: int = 8

var players: Array[PlayerController] = []

var _player: PlayerController
var _huds: Array[HUD] = []
var _hud_layer: CanvasLayer
var _options_layer: CanvasLayer
var _options_menu: OptionsMenu
var _lobby_layer: CanvasLayer
var _lobby_menu: LanLobbyMenu
var _visual_director: PSXVisualDirector
var _disco_director: MusicDiscoDirector
var _map_manager: Node
var _world_content: Node
var _spawn_manager: SpawnManager
var _pickup_spawner: PickupSpawner
var _match_manager: MatchManager
var _debug_draw_manager: ArenaDebugDrawManager
var _network_manager: NetworkManager
var _peer_to_player_id: Dictionary = {}
var _player_id_to_peer: Dictionary = {}
var _next_player_id: int = 1
var _network_sync_accumulator: float = 0.0
var _ping_accumulator: float = 0.0
var _local_ping_ms: int = -1
var _peer_ping_ms: Dictionary = {}
var _network_status_text: String = "OFFLINE"
var _hud_player: PlayerController
var _menu_camera: Camera3D
var _lan_discovery: LanDiscovery
var _lobby_options_menu: OptionsMenu
var _match_result_overlay: MatchResultOverlay
var _match_result_layer: CanvasLayer
var _death_cinematic: DeathCinematicDirector
var _selected_map_id: String = MapManagerScript.DEFAULT_MAP_ID
var _pending_match_rules: Dictionary = {}
var _pending_match_result_winner_id: int = -1
var _pending_death_cinematic_match_end: bool = false
var _match_result_request_token: int = 0
var _latest_death_corpse: Node3D
var _selected_time_of_day_preset: int = PSXVisualDirector.TimeOfDayPreset.NIGHT
var _local_gameplay_warmup_token: int = 0


#region Ciclo de vida e input global
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DefaultInputActions.ensure_default_actions()
	_visual_director = $PSXVisualDirector as PSXVisualDirector
	_disco_director = $MusicDiscoDirector as MusicDiscoDirector
	_setup_managers()
	_activate_map(_selected_map_id, false)
	_setup_network_manager()
	_setup_lan_discovery()
	_setup_menu_camera()
	_setup_lobby_menu()
	_setup_lobby_options_menu()
	_setup_match_result_overlay()
	_setup_death_cinematic()
	if PlayerSettingsAccess.has_settings():
		PlayerSettingsAccess.apply_to_visual_director(_visual_director)
		PlayerSettingsAccess.connect_performance_profile_changed(_on_performance_profile_changed)
	_debug_draw_manager.bind_context(_spawn_manager, _pickup_spawner, players)

	var started_from_args: bool = _network_manager.apply_startup_args()
	if started_from_args and _network_manager.is_host():
		_start_network_match_as_server()
	elif not started_from_args:
		_show_lobby("Elegí cómo entrar a la arena.")


func _physics_process(delta: float) -> void:
	if not _is_networked():
		return

	_process_network_ping(delta)
	_network_sync_accumulator += delta
	var sync_interval: float = 1.0 / network_sync_rate
	if _network_sync_accumulator < sync_interval:
		return
	_network_sync_accumulator = 0.0
	_send_local_player_state()


func _on_performance_profile_changed(_profile: int) -> void:
	if PlayerSettingsAccess.has_settings():
		PlayerSettingsAccess.apply_to_visual_director(_visual_director)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return

	if event is InputEventKey and event.pressed and event.keycode == KEY_F11:
		_toggle_fullscreen()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("pause"):
		if _options_menu != null:
			_options_menu.toggle()
			get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("lan_host"):
		_start_lan_host()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("lan_join"):
		_start_lan_join()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("lan_disconnect"):
		_disconnect_lan()
		get_viewport().set_input_as_handled()
#endregion


#region API publica de red (armas/pickups llaman aca)
func request_network_damage(victim_player_id: int, amount: int, attacker_player_id: int, shot_id: int = 0) -> bool:
	if not _is_networked() or multiplayer.is_server():
		return false
	if victim_player_id <= 0 or attacker_player_id <= 0 or amount <= 0:
		push_warning("Ignoring invalid network damage request.")
		return true

	_server_request_damage.rpc_id(1, victim_player_id, amount, attacker_player_id, shot_id)
	return true


func request_network_pickup(pickup_id: int, player_id: int) -> bool:
	if not _is_networked() or multiplayer.is_server():
		return false
	if pickup_id < 0 or player_id <= 0:
		push_warning("Ignoring invalid network pickup request.")
		return true

	_server_request_pickup.rpc_id(1, pickup_id, player_id)
	return true
#endregion


#region Setup de managers, red y lobby
func _setup_managers() -> void:
	_map_manager = MapManagerScript.new()
	_map_manager.name = "MapManager"
	add_child(_map_manager)

	_spawn_manager = SpawnManager.new()
	_spawn_manager.name = "SpawnManager"
	_spawn_manager.use_safe_spawn_selection = true
	add_child(_spawn_manager)

	_pickup_spawner = PickupSpawner.new()
	_pickup_spawner.name = "PickupSpawner"
	_pickup_spawner.ammo_pickup_scene = ammo_pickup_scene
	_pickup_spawner.health_pickup_scene = health_pickup_scene
	add_child(_pickup_spawner)

	_match_manager = MatchManager.new()
	_match_manager.name = "MatchManager"
	add_child(_match_manager)
	_match_manager.score_changed.connect(_on_score_changed)
	_match_manager.match_finished.connect(_on_match_finished)
	_match_manager.kill_feed_event.connect(_on_kill_feed_event)

	_debug_draw_manager = ArenaDebugDrawManager.new()
	_debug_draw_manager.name = "ArenaDebugDrawManager"
	add_child(_debug_draw_manager)

	_world_content = WorldContentManagerScript.new()
	_world_content.name = "WorldContentManager"
	_world_content.configure(_pickup_spawner, target_scene, music_stereo_scene, _visual_director, _disco_director)
	add_child(_world_content)
	_world_content.pickups_spawned.connect(_register_pickups)
	_world_content.music_stereo_spawned.connect(_on_music_stereo_spawned)
	_world_content.music_stereo_playback_toggle_requested.connect(_on_music_stereo_playback_toggle_requested)
	_world_content.music_stereo_next_track_requested.connect(_on_music_stereo_next_track_requested)


func _setup_network_manager() -> void:
	_network_manager = NetworkManager.new()
	_network_manager.name = "NetworkManager"
	_network_manager.configure(lan_port, default_lan_join_address, maxi(max_lan_players - 1, 1))
	add_child(_network_manager)
	_network_manager.joined_server.connect(_on_joined_server)
	_network_manager.connection_failed.connect(_on_network_connection_failed)
	_network_manager.server_disconnected.connect(_on_server_disconnected)
	_network_manager.peer_connected.connect(_on_network_peer_connected)
	_network_manager.peer_disconnected.connect(_on_network_peer_disconnected)
	_network_manager.network_status_changed.connect(_on_network_status_changed)
	_on_network_status_changed(_network_manager.get_status_text())


func _setup_lobby_menu() -> void:
	var lobby_menu = lan_lobby_menu_scene.instantiate()
	if lobby_menu == null:
		push_error("LAN lobby scene must instantiate a Control.")
		return

	_lobby_layer = CanvasLayer.new()
	_lobby_layer.name = "LanLobbyLayer"
	_lobby_layer.layer = 512
	_lobby_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_lobby_layer)
	_lobby_layer.add_child(lobby_menu)
	_lobby_menu = lobby_menu

	_lobby_menu.configure(default_lan_join_address, lan_port, _get_lan_addresses())
	if _lobby_menu.has_method("set_map_options"):
		_lobby_menu.call("set_map_options", _get_map_options(), _selected_map_id)
	_lobby_menu.host_requested.connect(_on_lobby_host_requested)
	_lobby_menu.join_requested.connect(_on_lobby_join_requested)
	_lobby_menu.practice_requested.connect(_on_lobby_practice_requested)
	_lobby_menu.disconnect_requested.connect(_on_lobby_disconnect_requested)
	_lobby_menu.options_requested.connect(_on_lobby_options_requested)
	_lobby_menu.quit_game_requested.connect(_on_quit_game_requested)
	_lobby_menu.browse_requested.connect(_on_lobby_browse_requested)
	_lobby_menu.browse_stopped.connect(_on_lobby_browse_stopped)
	_lobby_menu.visible = false


func _load_spawn_points_from_arena() -> void:
	var active_arena: Node3D = _get_active_arena()
	if active_arena == null:
		return
	_spawn_manager.load_from_arena(active_arena)
	_pickup_spawner.load_from_arena(active_arena)
	if _death_cinematic != null and _death_cinematic.has_method("setup"):
		_death_cinematic.call("setup", active_arena)


func _setup_death_cinematic() -> void:
	_death_cinematic = DeathCinematicDirector.new()
	_death_cinematic.name = "DeathCinematicDirector"
	add_child(_death_cinematic)
	var active_arena: Node3D = _get_active_arena()
	if active_arena != null and _death_cinematic.has_method("setup"):
		_death_cinematic.call("setup", active_arena)


func _setup_match_result_overlay() -> void:
	if match_result_overlay_scene == null:
		return
	var overlay: Control = match_result_overlay_scene.instantiate() as Control
	if overlay == null:
		push_error("Match result overlay must instantiate a Control.")
		return

	_match_result_layer = CanvasLayer.new()
	_match_result_layer.name = "MatchResultLayer"
	_match_result_layer.layer = 550
	_match_result_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_match_result_layer)
	_match_result_layer.add_child(overlay)
	_match_result_overlay = overlay
	if _match_result_overlay.has_signal("rematch_requested"):
		_match_result_overlay.rematch_requested.connect(_on_match_rematch_requested)
	if _match_result_overlay.has_signal("menu_requested"):
		_match_result_overlay.menu_requested.connect(_on_match_menu_requested)
	_match_result_overlay.visible = false


func _setup_lan_discovery() -> void:
	_lan_discovery = LanDiscovery.new()
	_lan_discovery.name = "LanDiscovery"
	add_child(_lan_discovery)
	_lan_discovery.session_list_changed.connect(_on_lan_sessions_changed)


func _setup_lobby_options_menu() -> void:
	var options_menu: OptionsMenu = options_menu_scene.instantiate() as OptionsMenu
	if options_menu == null:
		push_error("Options menu scene must instantiate OptionsMenu.")
		return

	var options_layer := CanvasLayer.new()
	options_layer.name = "LobbyOptionsLayer"
	options_layer.layer = 600
	options_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(options_layer)
	options_layer.add_child(options_menu)
	_lobby_options_menu = options_menu
	_lobby_options_menu.bind_context(null, null, _visual_director, null, false)
	_lobby_options_menu.menu_visibility_changed.connect(_on_lobby_options_visibility_changed)
	_lobby_options_menu.back_requested.connect(_on_lobby_options_back_requested)
	_lobby_options_menu.quit_game_requested.connect(_on_quit_game_requested)


func _show_lobby(status: String) -> void:
	if _lobby_menu == null:
		return

	_local_gameplay_warmup_token += 1
	_lobby_menu.configure(default_lan_join_address, lan_port, _get_lan_addresses())
	if _lobby_menu.has_method("set_map_options"):
		_lobby_menu.call("set_map_options", _get_map_options(), _selected_map_id)
	_lobby_menu.set_busy(false)
	_lobby_menu.set_status(status)
	_lobby_menu.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	_update_menu_presentation()
	_lobby_menu.focus_default()


func _hide_lobby() -> void:
	if _lobby_menu == null:
		return

	if _lobby_options_menu != null and _lobby_options_menu.visible:
		_lobby_options_menu.close()

	_lobby_menu.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_update_menu_presentation()
	_stabilize_local_player_camera()


func _is_lobby_visible() -> bool:
	return _lobby_menu != null and bool(_lobby_menu.visible)


func _begin_local_gameplay_warmup(player: PlayerController) -> void:
	if player == null or not is_instance_valid(player):
		return

	_local_gameplay_warmup_token += 1
	var token: int = _local_gameplay_warmup_token
	player.set_gameplay_input_enabled(false)
	if _lobby_menu != null and _lobby_menu.visible:
		_lobby_menu.set_busy(true)
		_lobby_menu.set_status("Preparando arena...")

	_run_local_gameplay_warmup(player, token)


func _run_local_gameplay_warmup(player: PlayerController, token: int) -> void:
	_warmup_local_gameplay_resources(player)

	var warmup_camera: Camera3D = _create_gameplay_warmup_camera(player)
	var frames_to_warm: int = gameplay_render_warmup_frames
	if warmup_camera == null:
		frames_to_warm = mini(frames_to_warm, 1)

	for frame_index in range(frames_to_warm):
		if token != _local_gameplay_warmup_token or player == null or not is_instance_valid(player):
			_free_gameplay_warmup_camera(warmup_camera)
			return
		_position_gameplay_warmup_camera(warmup_camera, player, frame_index)
		await _await_render_warmup_frame()

	_free_gameplay_warmup_camera(warmup_camera)
	if token != _local_gameplay_warmup_token or player == null or not is_instance_valid(player):
		return

	_hide_lobby()
	player.set_gameplay_input_enabled(true)


func _warmup_local_gameplay_resources(player: PlayerController) -> void:
	if player == null or not is_instance_valid(player):
		return
	if player.has_method("warmup_gameplay_resources"):
		player.call(
			"warmup_gameplay_resources",
			self,
			gameplay_effect_pool_warmup_size,
			gameplay_effect_pool_warmup_size
		)
	_warmup_death_presentation_resources()


func _warmup_death_presentation_resources() -> void:
	if player_corpse_scene != null:
		var corpse: Node3D = player_corpse_scene.instantiate() as Node3D
		if corpse != null:
			corpse.name = "WarmupCorpse"
			corpse.visible = false
			add_child(corpse)
			if corpse.has_method("setup"):
				corpse.call("setup", Color(0.78, 0.82, 0.88), Vector3.ZERO)
			corpse.queue_free()
	if _match_result_overlay != null:
		_match_result_overlay.visible = false


func _create_gameplay_warmup_camera(player: PlayerController) -> Camera3D:
	if player == null or not is_instance_valid(player) or player.camera == null:
		return null

	var source_camera: Camera3D = player.camera
	var warmup_camera := Camera3D.new()
	warmup_camera.name = "GameplayWarmupCamera"
	warmup_camera.fov = source_camera.fov
	warmup_camera.near = source_camera.near
	warmup_camera.far = source_camera.far
	warmup_camera.cull_mask = source_camera.cull_mask
	add_child(warmup_camera)
	warmup_camera.global_transform = source_camera.global_transform
	warmup_camera.current = true
	return warmup_camera


func _position_gameplay_warmup_camera(warmup_camera: Camera3D, player: PlayerController, frame_index: int) -> void:
	if warmup_camera == null or player == null or not is_instance_valid(player) or player.camera == null:
		return

	var yaw_offsets: Array[float] = [0.0, PI * 0.5, PI, PI * -0.5]
	var source_transform: Transform3D = player.camera.global_transform
	var yaw_offset: float = yaw_offsets[frame_index % yaw_offsets.size()]
	warmup_camera.global_transform = Transform3D(
		Basis(Vector3.UP, yaw_offset) * source_transform.basis,
		source_transform.origin
	)


func _await_render_warmup_frame() -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw


func _free_gameplay_warmup_camera(warmup_camera: Camera3D) -> void:
	if warmup_camera != null and is_instance_valid(warmup_camera):
		warmup_camera.queue_free()


func _setup_menu_camera() -> void:
	_menu_camera = ArenaMenuCameraScript.new() as Camera3D
	_menu_camera.name = "MenuCamera"
	add_child(_menu_camera)


func _is_menu_backdrop_visible() -> bool:
	if _lobby_options_menu != null and _lobby_options_menu.visible:
		return true
	if _is_lobby_visible():
		return true
	if _options_menu != null and _options_menu.visible:
		return true
	return false


func _stabilize_local_player_camera() -> void:
	if _player == null or _player.camera == null:
		return
	_player.camera.current = true
	_player.camera.reset_physics_interpolation()
	if _player.camera_pivot != null:
		_player.camera_pivot.reset_physics_interpolation()
	for hud in _huds:
		if hud != null and hud.has_method("reset_motion"):
			hud.call("reset_motion")


func _update_menu_presentation() -> void:
	var menu_open: bool = _is_menu_backdrop_visible()
	if _menu_camera != null and _menu_camera.has_method("set_menu_active"):
		_menu_camera.call("set_menu_active", menu_open)
	if _visual_director != null:
		_visual_director.set_menu_lens_boost(menu_open)
	if _hud_layer != null:
		_hud_layer.visible = not menu_open
	for player in players:
		if player == null or not is_instance_valid(player):
			continue
		if not _is_local_peer(_get_peer_id_for_player(player)):
			continue
		if player.camera != null:
			player.camera.current = not menu_open


func _get_lan_addresses() -> PackedStringArray:
	var addresses: PackedStringArray = []
	for address in IP.get_local_addresses():
		if not _is_useful_lan_address(address):
			continue
		addresses.append(address)
	addresses.sort()
	return addresses


func _is_useful_lan_address(address: String) -> bool:
	if address.contains(":"):
		return false
	if address.begins_with("127.") or address.begins_with("169.254."):
		return false
	return true
#endregion


#region Contenido del mundo y ciclo de partida
func _get_map_options() -> Array[Dictionary]:
	return _map_manager.get_map_options()


func _sanitize_map_id(map_id: String) -> String:
	return _map_manager.sanitize_map_id(map_id)


func _get_map_scene(map_id: String) -> PackedScene:
	return _map_manager.get_map_scene(map_id)


func _get_map_label(map_id: String) -> String:
	return _map_manager.get_map_label(map_id)


func _activate_map(map_id: String, should_spawn_world_content: bool = true) -> void:
	var safe_map_id: String = _sanitize_map_id(map_id)
	_selected_map_id = safe_map_id

	if _map_manager.get_active_arena() != null and _map_manager.active_map_id == safe_map_id:
		_finish_arena_activation.call_deferred(should_spawn_world_content)
		return

	_clear_world_content()
	if not _map_manager.activate_map(self, safe_map_id):
		return

	_finish_arena_activation.call_deferred(should_spawn_world_content)


func _finish_arena_activation(should_spawn_world_content: bool) -> void:
	var active_arena: Node3D = _get_active_arena()
	if active_arena == null:
		return
	_load_spawn_points_from_arena()
	if should_spawn_world_content:
		_spawn_world_content(active_arena)
	_refresh_active_map_visuals()
	_update_menu_presentation()


func _refresh_active_map_visuals() -> void:
	if _visual_director != null:
		_visual_director.invalidate_scene_cache()
		_visual_director.refresh_visual_style()
	if _disco_director != null:
		_disco_director.invalidate_baseline()


func _clear_world_content() -> void:
	if _world_content != null:
		_world_content.clear()


func _spawn_world_content(active_arena: Node3D) -> void:
	if _world_content != null:
		_world_content.spawn_for_arena(active_arena, self)


func _get_active_arena() -> Node3D:
	if _map_manager == null:
		return null
	return _map_manager.get_active_arena()


func _get_music_stereo() -> MusicStereo:
	if _world_content == null:
		return null
	return _world_content.get_music_stereo()


## Limpia jugadores, HUD y mapeos peer<->player. Punto unico de reseteo de sesion.
func _reset_session() -> void:
	_local_gameplay_warmup_token += 1
	_match_result_request_token += 1
	_pending_death_cinematic_match_end = false
	_pending_match_result_winner_id = -1
	_latest_death_corpse = null
	_clear_world_content()
	_clear_players_and_interfaces()
	_reset_player_maps()


func _start_offline_match() -> void:
	_prepare_match_world()
	_stop_lan_discovery()
	_peer_to_player_id[1] = 1
	_player_id_to_peer[1] = 1
	_match_manager.ensure_player(1)
	_spawn_player_at_fresh_spawn(1, 1)
	_on_network_status_changed("OFFLINE")


func _start_network_match_as_server() -> void:
	if not _is_networked() or not multiplayer.is_server():
		push_error("Cannot start a network match without a LAN host.")
		return

	_prepare_match_world()
	_register_network_peer(1)
	_network_load_map.rpc(_selected_map_id)
	_network_apply_time_of_day_preset.rpc(_selected_time_of_day_preset)
	_network_sync_match_rules.rpc(_match_manager.get_rules_snapshot())
	_sync_score_snapshot_to_peers()
	_refresh_lan_discovery_host()


func _prepare_match_world() -> void:
	_reset_session()
	_activate_map(_selected_map_id, true)
	_apply_time_of_day_preset(_selected_time_of_day_preset, true)
	_apply_match_rules(_pending_match_rules)
	_match_manager.start_match()


func _spawn_player_at_fresh_spawn(peer_id: int, player_id: int) -> PlayerController:
	var spawn_transform: Transform3D = _get_fresh_spawn_transform()
	return _spawn_or_update_player(peer_id, player_id, spawn_transform.origin, spawn_transform.basis.get_euler().y)


func _get_fresh_spawn_transform() -> Transform3D:
	return _spawn_manager.get_spawn_transform(players)


func _prepare_client_match() -> void:
	_reset_session()
	_pending_match_rules = {}
	_match_manager.apply_score_snapshot({}, true)
	_request_full_sync.rpc_id(1)


func _start_lan_host() -> void:
	if _network_manager.host_game(lan_port):
		_start_network_match_as_server()


func _start_lan_join() -> void:
	_reset_session()
	if not _network_manager.join_game(default_lan_join_address, lan_port):
		if _is_lobby_visible():
			_show_lobby("No se pudo unir a %s:%d." % [default_lan_join_address, lan_port])
		else:
			_start_offline_match()


func _disconnect_lan() -> void:
	_network_manager.disconnect_network()
	_stop_lan_discovery()
	_reset_session()
	_peer_ping_ms.clear()
	_local_ping_ms = -1
	_match_manager.apply_score_snapshot({}, false)
	_show_lobby("Desconectado.")


func _apply_time_of_day_preset(time_of_day_preset: int, should_refresh: bool = true) -> void:
	_selected_time_of_day_preset = _sanitize_time_of_day_preset(time_of_day_preset)
	if _visual_director == null:
		return

	_visual_director.time_of_day_preset = _selected_time_of_day_preset
	if should_refresh:
		_visual_director.refresh_visual_style()
		if _disco_director != null:
			_disco_director.invalidate_baseline()


func _sanitize_time_of_day_preset(time_of_day_preset: int) -> int:
	return clampi(time_of_day_preset, 0, PSXVisualDirector.TimeOfDayPreset.size() - 1)


func _on_lobby_host_requested(port: int, map_id: String, time_of_day_preset: int, match_rules: Dictionary) -> void:
	lan_port = port
	_selected_map_id = _sanitize_map_id(map_id)
	_selected_time_of_day_preset = _sanitize_time_of_day_preset(time_of_day_preset)
	_pending_match_rules = match_rules
	_network_manager.configure(lan_port, default_lan_join_address, maxi(max_lan_players - 1, 1))
	_start_lan_host()


func _on_lobby_join_requested(address: String, port: int) -> void:
	default_lan_join_address = address.strip_edges()
	lan_port = port
	_pending_match_rules = {}
	_stop_lan_discovery()
	_network_manager.configure(lan_port, default_lan_join_address, maxi(max_lan_players - 1, 1))
	_start_lan_join()


func _on_lobby_practice_requested(map_id: String, time_of_day_preset: int, _match_rules: Dictionary) -> void:
	_selected_map_id = _sanitize_map_id(map_id)
	_selected_time_of_day_preset = _sanitize_time_of_day_preset(time_of_day_preset)
	_pending_match_rules = {
		"win_mode": MatchManager.WinMode.PRACTICE,
		"score_limit": 0,
		"time_limit_seconds": 0.0,
	}
	_network_manager.disconnect_network(false)
	_stop_lan_discovery()
	_start_offline_match()


func _on_lobby_disconnect_requested() -> void:
	_disconnect_lan()


func _on_lobby_options_requested() -> void:
	if _lobby_options_menu == null:
		return
	if _lobby_menu != null:
		_lobby_menu.visible = false
	_lobby_options_menu.open()
	_update_menu_presentation()


func _on_lobby_options_back_requested() -> void:
	_on_lobby_options_closed()


func _on_lobby_options_visibility_changed(is_visible: bool) -> void:
	_update_menu_presentation()
	if is_visible:
		return
	_on_lobby_options_closed()


func _on_lobby_options_closed() -> void:
	if _lobby_menu != null:
		_lobby_menu.visible = true
		_lobby_menu.focus_default()
	_update_menu_presentation()


func _on_quit_game_requested() -> void:
	get_tree().quit()


func _on_lan_sessions_changed(sessions: Array) -> void:
	if _lobby_menu != null:
		_lobby_menu.set_discovered_sessions(sessions)


func _on_lobby_browse_requested() -> void:
	if _lan_discovery != null and _lan_discovery.has_method("is_browsing") and _lan_discovery.is_browsing():
		_lan_discovery.refresh_browse()
		if _lobby_menu != null:
			_lobby_menu.set_status("Actualizando lista de partidas...")
		return

	if not _start_lan_discovery_browse():
		if _lobby_menu != null:
			_lobby_menu.set_status("No se pudo abrir el puerto de descubrimiento 24501.")


func _on_lobby_browse_stopped() -> void:
	_stop_lan_discovery()


func _stop_lan_discovery() -> void:
	if _lan_discovery != null:
		_lan_discovery.stop_all()


func _apply_match_rules(match_rules: Dictionary) -> void:
	if match_rules.is_empty():
		return
	var win_mode: int = int(match_rules.get("win_mode", MatchManager.WinMode.KILL_LIMIT))
	var kill_limit: int = int(match_rules.get("score_limit", 10))
	var time_seconds: float = float(match_rules.get("time_limit_seconds", 300.0))
	_match_manager.configure_rules(win_mode as MatchManager.WinMode, kill_limit, time_seconds)


func _start_lan_discovery_host() -> void:
	if _lan_discovery == null:
		return
	if not _is_networked() or not multiplayer.is_server():
		return
	var mode_text: String = "time" if _match_manager.win_mode == MatchManager.WinMode.TIME_LIMIT else "kills"
	var limit_value: int = int(_match_manager.time_limit_seconds / 60.0) if mode_text == "time" else _match_manager.score_limit
	var host_name: String = PlayerSettingsAccess.get_display_name("Host")
	var payload: Dictionary = {
		"name": "%s // BOOMER ARENA" % host_name,
		"port": lan_port,
		"map": _get_map_label(_selected_map_id),
		"mode": mode_text,
		"limit": limit_value,
		"players": _get_peer_count(),
		"max_players": max_lan_players,
	}
	if _lan_discovery.is_hosting():
		_lan_discovery.update_host_payload(payload)
	else:
		_lan_discovery.start_hosting(payload)


func _refresh_lan_discovery_host() -> void:
	if not _is_networked() or not multiplayer.is_server():
		return
	if _get_peer_count() >= max_lan_players:
		_stop_lan_discovery()
		return
	_start_lan_discovery_host()


func _start_lan_discovery_browse() -> bool:
	if _lan_discovery == null:
		return false
	return _lan_discovery.start_browsing()


func _reset_player_maps() -> void:
	_peer_to_player_id.clear()
	_player_id_to_peer.clear()
	_next_player_id = 1


func _register_network_peer(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	if _peer_to_player_id.has(peer_id):
		_sync_all_players_to_peer(peer_id)
		return
	if _peer_to_player_id.size() >= max_lan_players:
		push_warning("Rejecting peer %d because the LAN match is full." % peer_id)
		if peer_id != 1 and multiplayer.multiplayer_peer != null:
			multiplayer.multiplayer_peer.disconnect_peer(peer_id)
		return

	var player_id: int = _allocate_player_id()
	if player_id <= 0:
		push_warning("Could not allocate a player id for peer %d." % peer_id)
		return

	_peer_to_player_id[peer_id] = player_id
	_player_id_to_peer[player_id] = peer_id
	_match_manager.ensure_player(player_id)

	if peer_id != 1:
		_network_load_map.rpc_id(peer_id, _selected_map_id)
	var spawn_transform: Transform3D = _get_fresh_spawn_transform()
	_spawn_or_update_player(peer_id, player_id, spawn_transform.origin, spawn_transform.basis.get_euler().y)
	_network_spawn_player.rpc(peer_id, player_id, spawn_transform.origin, spawn_transform.basis.get_euler().y)
	_network_apply_time_of_day_preset.rpc_id(peer_id, _selected_time_of_day_preset)
	_sync_all_players_to_peer(peer_id)
	_sync_pickups_to_peer(peer_id)
	_sync_music_stereo_to_peer(peer_id)
	_sync_player_names_to_peer(peer_id)
	_sync_score_snapshot_to_peers()


func _sync_player_names_to_peer(peer_id: int) -> void:
	if peer_id == 1:
		return
	for player in players:
		if player == null:
			continue
		_network_sync_player_display_name.rpc_id(peer_id, player.player_id, player.display_name)


func _allocate_player_id() -> int:
	for candidate_id in range(1, max_lan_players + 1):
		if not _player_id_to_peer.has(candidate_id):
			_next_player_id = candidate_id + 1
			return candidate_id
	return -1


func _register_pickups() -> void:
	for pickup_index in range(_pickup_spawner.spawned_pickups.size()):
		var pickup: PickupBase = _pickup_spawner.spawned_pickups[pickup_index] as PickupBase
		if pickup == null:
			continue
		pickup.set_pickup_id(pickup_index)
		if not pickup.availability_changed.is_connected(_on_pickup_availability_changed):
			pickup.availability_changed.connect(_on_pickup_availability_changed)
#endregion


#region Spawn de jugadores, HUD y opciones
func _spawn_or_update_player(peer_id: int, player_id: int, spawn_position: Vector3, yaw_radians: float) -> PlayerController:
	var player: PlayerController = _get_player_by_peer_id(peer_id)
	var is_new_player: bool = player == null
	if is_new_player:
		player = player_scene.instantiate() as PlayerController
		if player == null:
			push_error("Player scene must instantiate a PlayerController.")
			return null

		player.name = _get_player_node_name(peer_id)
		# Authority must be assigned before _ready(). Otherwise every freshly
		# instanced player briefly looks local to the host (authority defaults to
		# peer 1) and its camera steals the viewport when a client joins.
		player.set_multiplayer_authority(peer_id)
		add_child(player)
		players.append(player)
		player.damaged.connect(_on_player_damaged.bind(player))
		player.died.connect(_on_player_died.bind(player))

	player.player_id = player_id
	var is_local_player: bool = _is_local_peer(peer_id)
	if is_local_player and not PlayerSettingsAccess.get_display_name("").is_empty():
		player.display_name = PlayerSettingsAccess.get_display_name("")
	else:
		player.display_name = "Player %d" % player_id
	_match_manager.set_player_name(player_id, player.display_name)
	if _is_networked() and multiplayer.is_server():
		_network_sync_player_display_name.rpc(player_id, player.display_name)
	if is_local_player and PlayerSettingsAccess.has_settings():
		PlayerSettingsAccess.apply_to_player(player)
	player.input_prefix = ""
	player.mouse_look_enabled = true
	player.set_multiplayer_authority(peer_id)
	player.set_local_control_enabled(is_local_player)
	if player.camera != null:
		player.camera.current = is_local_player and not _is_menu_backdrop_visible()
	if player_id == 2:
		player.set_body_color(Color(0.9, 0.1, 0.08))

	if is_new_player or (player.health != null and player.health.is_dead):
		player.respawn_at(spawn_position, yaw_radians)
	else:
		player.apply_network_state(spawn_position, yaw_radians, player.camera_pivot.rotation_degrees.x, player.velocity, player.health.is_dead, false)

	if is_local_player:
		_player = player
		if _death_cinematic != null and _death_cinematic.has_method("bind_local_player"):
			_death_cinematic.call("bind_local_player", player)
		_setup_local_hud(player)
		_setup_options_menu()
		_begin_local_gameplay_warmup(player)
		if _is_networked() and not multiplayer.is_server():
			_network_report_display_name.rpc_id(1, player_id, player.display_name)

	return player


func _setup_local_hud(player: PlayerController) -> void:
	if player == null:
		return
	if not _huds.is_empty():
		_refresh_network_hud()
		if _hud_player != player:
			push_warning("HUD is already bound to a different player. Recreate interfaces before rebinding.")
		return

	var hud: HUD = hud_scene.instantiate() as HUD
	if hud == null:
		push_error("HUD scene must instantiate HUD.")
		return

	if _hud_layer == null:
		_hud_layer = CanvasLayer.new()
		_hud_layer.name = "HUDLayer"
		_hud_layer.layer = 200
		add_child(_hud_layer)

	_hud_layer.add_child(hud)
	_huds.append(hud)
	hud.bind_player(player)
	hud.bind_match(_match_manager, player.player_id)
	var music_stereo: MusicStereo = _get_music_stereo()
	if music_stereo != null:
		hud.bind_music_stereo(music_stereo)
	if _visual_director != null:
		hud.bind_visual_director(_visual_director)
	_hud_player = player
	_refresh_network_hud()


func _toggle_fullscreen() -> void:
	var enable_fullscreen: bool = not _is_fullscreen_mode()
	var mode: int = (
		DisplayServer.WINDOW_MODE_FULLSCREEN
		if enable_fullscreen
		else DisplayServer.WINDOW_MODE_WINDOWED
	)
	DisplayServer.window_set_mode(mode)
	if _options_menu != null:
		_options_menu.sync_fullscreen_checkbox()


func _is_fullscreen_mode() -> bool:
	var mode: int = DisplayServer.window_get_mode()
	return (
		mode == DisplayServer.WINDOW_MODE_FULLSCREEN
		or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	)


func _setup_options_menu() -> void:
	if _options_menu != null or _player == null or _huds.is_empty():
		return

	var options_menu: OptionsMenu = options_menu_scene.instantiate() as OptionsMenu
	if options_menu == null:
		push_error("Options menu scene must instantiate OptionsMenu.")
		return

	_options_layer = CanvasLayer.new()
	_options_layer.name = "OptionsLayer"
	_options_layer.layer = 256
	_options_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_options_layer)
	_options_layer.add_child(options_menu)
	_options_menu = options_menu
	_options_menu.bind_context(_player, _huds[0], _visual_director, _debug_draw_manager, true)
	_options_menu.menu_visibility_changed.connect(_on_options_visibility_changed)
	_options_menu.respawn_requested.connect(_on_options_respawn_requested)
	_options_menu.leave_match_requested.connect(_on_leave_match_requested)
	_options_menu.quit_game_requested.connect(_on_quit_game_requested)
	if PlayerSettingsAccess.has_settings():
		var crosshair_index: int = PlayerSettingsAccess.get_int(&"crosshair_index", 0)
		_huds[0].rebuild_crosshair(crosshair_index >= 0, maxi(crosshair_index, 0))
		_huds[0].set_crosshair_enabled(PlayerSettingsAccess.get_bool(&"crosshair_enabled", true))


func _on_leave_match_requested() -> void:
	_disconnect_lan()


func _clear_players_and_interfaces() -> void:
	for player in players:
		if player != null and is_instance_valid(player):
			player.queue_free()
	players.clear()
	_player = null

	for hud in _huds:
		if hud != null and is_instance_valid(hud):
			hud.queue_free()
	_huds.clear()
	_hud_player = null

	if _hud_layer != null and is_instance_valid(_hud_layer):
		_hud_layer.queue_free()
	_hud_layer = null

	if _options_layer != null and is_instance_valid(_options_layer):
		_options_layer.queue_free()
	_options_layer = null
	_options_menu = null
#endregion


#region Sincronizacion de estado y ping
func _send_local_player_state() -> void:
	if _player == null or not is_instance_valid(_player):
		return

	var peer_id: int = _get_peer_id_for_player(_player)
	if peer_id <= 0:
		return

	if multiplayer.is_server():
		_broadcast_player_state(_player)
	else:
		_server_receive_player_state.rpc_id(
			1,
			_player.player_id,
			_player.global_position,
			_player.rotation.y,
			_player.camera_pivot.rotation_degrees.x,
			_player.velocity,
			_player.health.is_dead,
			_player.is_crouching(),
			_player.get_active_weapon_index(),
			_player.is_aiming()
		)


func _process_network_ping(delta: float) -> void:
	if (
		not multiplayer.is_server()
		and multiplayer.multiplayer_peer != null
		and multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED
	):
		return

	_ping_accumulator += delta
	if _ping_accumulator < ping_interval:
		return
	_ping_accumulator = 0.0

	var now_msec: int = Time.get_ticks_msec()
	if multiplayer.is_server():
		for raw_peer_id in _peer_to_player_id.keys():
			var peer_id: int = int(raw_peer_id)
			if peer_id == 1:
				continue
			_network_ping_client.rpc_id(peer_id, now_msec)
	else:
		_network_ping_server.rpc_id(1, now_msec)


func _broadcast_player_state(player: PlayerController) -> void:
	if player == null or not is_instance_valid(player):
		return

	var peer_id: int = _get_peer_id_for_player(player)
	if peer_id <= 0:
		return

	_broadcast_player_state_values(
		peer_id,
		player.player_id,
		player.global_position,
		player.rotation.y,
		player.camera_pivot.rotation_degrees.x,
		player.velocity,
		player.health.is_dead,
		player.is_crouching(),
		player.get_active_weapon_index(),
		player.is_aiming()
	)


func _broadcast_player_state_values(
	peer_id: int,
	player_id: int,
	position: Vector3,
	yaw_radians: float,
	pitch_degrees: float,
	velocity: Vector3,
	is_dead_state: bool,
	is_crouching_state: bool,
	active_weapon_index: int,
	is_aiming_state: bool
) -> void:
	_network_receive_player_state.rpc(
		peer_id,
		player_id,
		position,
		yaw_radians,
		pitch_degrees,
		velocity,
		is_dead_state,
		is_crouching_state,
		active_weapon_index,
		is_aiming_state
	)


func _sync_all_players_to_peer(peer_id: int) -> void:
	if peer_id == 1:
		return

	for raw_peer_id in _peer_to_player_id.keys():
		var synced_peer_id: int = int(raw_peer_id)
		var synced_player_id: int = int(_peer_to_player_id[synced_peer_id])
		var player: PlayerController = _get_player_by_peer_id(synced_peer_id)
		if player == null:
			continue
		_network_spawn_player.rpc_id(
			peer_id,
			synced_peer_id,
			synced_player_id,
			player.global_position,
			player.rotation.y
		)


func _sync_pickups_to_peer(peer_id: int) -> void:
	if peer_id == 1:
		return

	for pickup_node in _pickup_spawner.spawned_pickups:
		var pickup: PickupBase = pickup_node as PickupBase
		if pickup == null:
			continue
		_network_set_pickup_available.rpc_id(peer_id, pickup.pickup_id, pickup.is_available())


func _sync_score_snapshot_to_peers() -> void:
	if not _is_networked() or not multiplayer.is_server():
		return
	_network_sync_score_snapshot.rpc(_match_manager.get_score_snapshot(), _match_manager.match_running)


func _sync_music_stereo_to_peer(peer_id: int) -> void:
	var music_stereo: MusicStereo = _get_music_stereo()
	if music_stereo == null or not _is_networked() or not multiplayer.is_server() or peer_id == 1:
		return

	_network_apply_music_stereo_state.rpc_id(
		peer_id,
		music_stereo.get_track_index(),
		music_stereo.is_playing(),
		music_stereo.get_playback_position()
	)


func _sync_player_health_to_peers(player: PlayerController) -> void:
	if player == null or not _is_networked() or not multiplayer.is_server():
		return
	_network_sync_player_health.rpc(
		player.player_id,
		player.health.current_health,
		player.health.max_health,
		player.health.is_dead,
		player.last_damage_source_player_id,
		player.respawn_generation
	)


func _apply_player_damage(victim_player_id: int, amount: int, attacker_player_id: int, shot_id: int = 0) -> void:
	if amount <= 0:
		push_warning("Damage amount must be greater than zero.")
		return

	var victim: PlayerController = _get_player_by_player_id(victim_player_id)
	if victim == null:
		push_warning("Cannot apply damage because player %d does not exist." % victim_player_id)
		return
	victim.apply_damage(amount, attacker_player_id, shot_id)


func _apply_player_pickup(pickup_id: int, player_id: int, requesting_peer_id: int = 0) -> void:
	if requesting_peer_id > 0 and int(_peer_to_player_id.get(requesting_peer_id, 0)) != player_id:
		push_warning("Rejected pickup request from peer %d." % requesting_peer_id)
		return

	var pickup: PickupBase = _get_pickup_by_id(pickup_id)
	if pickup == null or not pickup.is_available():
		return

	var player: PlayerController = _get_player_by_player_id(player_id)
	if player == null:
		return
	if not pickup.can_player_collect_now(player):
		return

	if pickup.collect_for_player(player):
		var owner_peer_id: int = _get_peer_id_for_player(player)
		if _is_networked() and multiplayer.is_server() and owner_peer_id > 1:
			_network_confirm_pickup_collected.rpc_id(owner_peer_id, pickup_id, player_id)
		_sync_player_health_to_peers(player)
#endregion


#region Callbacks de juego y red
func _on_pickup_availability_changed(pickup_id: int, is_available: bool) -> void:
	if _is_networked() and multiplayer.is_server():
		_network_set_pickup_available.rpc(pickup_id, is_available)


func _on_music_stereo_spawned(music_stereo: MusicStereo) -> void:
	if music_stereo == null:
		return
	for hud in _huds:
		if hud != null:
			hud.bind_music_stereo(music_stereo)


func _on_player_damaged(amount: int, attacker_player_id: int, shot_id: int, player: PlayerController) -> void:
	if attacker_player_id > 0 and attacker_player_id != player.player_id:
		_deliver_damage_feedback(attacker_player_id, player.player_id, amount, shot_id)
	if _is_networked() and multiplayer.is_server():
		_sync_player_health_to_peers(player)


func _deliver_damage_feedback(attacker_player_id: int, victim_player_id: int, amount: int, shot_id: int) -> void:
	var attacker: PlayerController = _get_player_by_player_id(attacker_player_id)
	if attacker == null:
		return
	var attacker_peer_id: int = _get_peer_id_for_player(attacker)
	if _is_networked() and multiplayer.is_server() and attacker_peer_id > 1:
		_network_confirm_damage.rpc_id(attacker_peer_id, victim_player_id, amount, shot_id)
		return
	_show_local_damage_feedback(victim_player_id, amount, shot_id)


func _show_local_damage_feedback(victim_player_id: int, amount: int, shot_id: int) -> void:
	var victim: PlayerController = _get_player_by_player_id(victim_player_id)
	if victim == null or amount <= 0:
		return
	for hud in _huds:
		if hud != null and is_instance_valid(hud):
			hud.show_damage_feedback(victim, amount, shot_id)


func _on_player_died(player: PlayerController) -> void:
	if _is_networked() and not multiplayer.is_server():
		return

	var killer_position: Vector3 = Vector3.ZERO
	var match_ended_from_kill: bool = false
	if player != null:
		var death_context: Dictionary = _build_death_context(player)
		var killer_id: int = int(death_context["killer_id"])
		killer_position = death_context["killer_position"]
		if bool(death_context["has_killer"]):
			_register_player_kill(player, killer_id)
		else:
			_match_manager.register_death(player.player_id)
		match_ended_from_kill = not _match_manager.match_running
		_sync_player_health_to_peers(player)
		var corpse: Node3D = _spawn_corpse(player, killer_position)
		_broadcast_corpse_spawn(player, killer_position)
		if bool(death_context["has_killer"]):
			_play_death_cinematic(player.global_position, match_ended_from_kill, corpse, killer_id, killer_position)
		if match_ended_from_kill:
			_queue_match_result_overlay(killer_id if killer_id > 0 else _pending_match_result_winner_id)

	if match_ended_from_kill:
		return

	await get_tree().create_timer(player_respawn_delay).timeout
	if player != null and is_instance_valid(player) and _match_manager.match_running:
		_respawn_player(player, killer_position)


func _build_death_context(player: PlayerController) -> Dictionary:
	var killer_id: int = player.last_damage_source_player_id
	var has_killer: bool = killer_id > 0 and killer_id != player.player_id
	var killer_position: Vector3 = Vector3.ZERO
	if has_killer:
		var killer: PlayerController = _get_player_by_player_id(killer_id)
		if killer != null:
			killer_position = killer.global_position
			player.last_killer_position = killer_position
	return {
		"killer_id": killer_id,
		"has_killer": has_killer,
		"killer_position": killer_position,
	}


func _register_player_kill(player: PlayerController, killer_id: int) -> void:
	if _match_manager.kill_would_end_match(killer_id):
		_pending_death_cinematic_match_end = true
		_pending_match_result_winner_id = killer_id
	_match_manager.register_kill(killer_id, player.player_id)


func _broadcast_corpse_spawn(player: PlayerController, killer_position: Vector3) -> void:
	if not _is_networked() or not multiplayer.is_server():
		return
	_network_spawn_corpse.rpc(
		player.global_position,
		player.rotation,
		player.get_body_color(),
		killer_position - player.global_position
	)


func _on_options_respawn_requested() -> void:
	if _is_networked() and not multiplayer.is_server():
		_server_request_respawn.rpc_id(1)
		return
	_respawn_player(_player)


func _on_options_visibility_changed(is_visible: bool) -> void:
	if _player != null:
		_player.set_gameplay_input_enabled(not is_visible)
	_update_menu_presentation()


func _on_music_stereo_playback_toggle_requested() -> void:
	if _is_networked() and not multiplayer.is_server():
		_server_request_music_stereo_toggle.rpc_id(1)
		return
	_apply_music_stereo_toggle()


func _on_music_stereo_next_track_requested() -> void:
	if _is_networked() and not multiplayer.is_server():
		_server_request_music_stereo_next.rpc_id(1)
		return
	_apply_music_stereo_next()


func _apply_music_stereo_toggle() -> void:
	var music_stereo: MusicStereo = _get_music_stereo()
	if music_stereo == null:
		return

	music_stereo.toggle_playback()
	_broadcast_music_stereo_state()


func _apply_music_stereo_next() -> void:
	var music_stereo: MusicStereo = _get_music_stereo()
	if music_stereo == null:
		return

	music_stereo.next_track()
	_broadcast_music_stereo_state()


func _broadcast_music_stereo_state() -> void:
	var music_stereo: MusicStereo = _get_music_stereo()
	if music_stereo == null or not _is_networked() or not multiplayer.is_server():
		return

	_network_apply_music_stereo_state.rpc(
		music_stereo.get_track_index(),
		music_stereo.is_playing(),
		music_stereo.get_playback_position()
	)


func _on_score_changed(_player_id: int, _kills: int, _deaths: int) -> void:
	_sync_score_snapshot_to_peers()


func _on_kill_feed_event(killer_name: String, victim_name: String, killer_id: int, victim_id: int) -> void:
	if _is_networked() and multiplayer.is_server():
		_network_kill_feed_event.rpc(killer_name, victim_name, killer_id, victim_id)


func _on_match_finished(winner_id: int) -> void:
	for player in players:
		if player == null:
			continue
		player.set_gameplay_input_enabled(false)

	if _options_menu != null and _options_menu.visible:
		_options_menu.close()

	_pending_match_result_winner_id = winner_id
	if _is_networked() and multiplayer.is_server():
		_network_match_finished.rpc(winner_id)

	if not _match_end_uses_death_cinematic():
		_queue_match_result_overlay(winner_id)


func _match_end_uses_death_cinematic() -> bool:
	return _pending_death_cinematic_match_end


func _play_death_cinematic(victim_position: Vector3, is_match_ending: bool, follow_target: Node3D = null, killer_id: int = -1, killer_position: Vector3 = Vector3.ZERO) -> void:
	if _is_networked() and multiplayer.is_server():
		_network_play_death_cinematic.rpc(victim_position, is_match_ending, killer_id, killer_position)
	else:
		_run_death_cinematic(victim_position, is_match_ending, follow_target, killer_id, killer_position)


func _run_death_cinematic(victim_position: Vector3, is_match_ending: bool, follow_target: Node3D = null, killer_id: int = -1, killer_position: Vector3 = Vector3.ZERO) -> void:
	if is_match_ending:
		_pending_death_cinematic_match_end = true
		if killer_id > 0:
			_pending_match_result_winner_id = killer_id
	var corpse_target: Node3D = follow_target
	if corpse_target == null and _latest_death_corpse != null and is_instance_valid(_latest_death_corpse):
		corpse_target = _latest_death_corpse
	if _death_cinematic == null:
		if is_match_ending:
			_queue_match_result_overlay(_pending_match_result_winner_id)
		return
	if _player != null and _death_cinematic.has_method("bind_local_player"):
		_death_cinematic.call("bind_local_player", _player)
	if is_match_ending and _death_cinematic.has_signal("finished"):
		if not _death_cinematic.finished.is_connected(_on_death_cinematic_finished_show_result):
			_death_cinematic.finished.connect(_on_death_cinematic_finished_show_result, CONNECT_ONE_SHOT)
	if _death_cinematic.has_method("play"):
		_death_cinematic.call("play", victim_position, is_match_ending, corpse_target, killer_id, killer_position, _get_player_by_player_id(killer_id))


func _queue_match_result_overlay(winner_id: int) -> void:
	_pending_match_result_winner_id = winner_id
	_match_result_request_token += 1
	var request_token: int = _match_result_request_token
	var cinematic_playing: bool = _is_death_cinematic_playing()
	if cinematic_playing:
		if _death_cinematic.has_signal("finished") and not _death_cinematic.finished.is_connected(_on_death_cinematic_finished_show_result):
			_death_cinematic.finished.connect(_on_death_cinematic_finished_show_result, CONNECT_ONE_SHOT)
		return
	_show_match_result_overlay_after_delay(winner_id, request_token)


func _on_death_cinematic_finished_show_result() -> void:
	var winner_id: int = _pending_match_result_winner_id
	_pending_death_cinematic_match_end = false
	if winner_id < 0:
		return
	_show_match_result_overlay_after_delay(winner_id)


func _show_match_result_overlay_after_delay(winner_id: int, request_token: int = -1) -> void:
	var token: int = request_token if request_token >= 0 else _match_result_request_token
	_show_match_result_overlay_deferred(winner_id, token)


func _show_match_result_overlay_deferred(winner_id: int, request_token: int) -> void:
	await get_tree().create_timer(0.35, true).timeout
	if request_token != _match_result_request_token:
		return
	if _is_death_cinematic_playing():
		if _death_cinematic.has_signal("finished") and not _death_cinematic.finished.is_connected(_on_death_cinematic_finished_show_result):
			_death_cinematic.finished.connect(_on_death_cinematic_finished_show_result, CONNECT_ONE_SHOT)
		return
	_show_match_result_overlay(winner_id)


func _is_death_cinematic_playing() -> bool:
	return (
		_death_cinematic != null
		and _death_cinematic.has_method("is_playing")
		and bool(_death_cinematic.call("is_playing"))
	)


func _show_match_result_overlay(winner_id: int) -> void:
	if _match_result_overlay == null:
		return

	_pending_death_cinematic_match_end = false
	if _death_cinematic != null and _death_cinematic.has_method("cancel"):
		_death_cinematic.call("cancel")
	if _options_menu != null and _options_menu.visible:
		_options_menu.close()
	if _player != null:
		_player.cancel_kill_cam()
		_player.set_cinematic_view_active(false)

	var local_player_id: int = _player.player_id if _player != null else 0
	var is_host: bool = not _is_networked() or multiplayer.is_server()
	var winner_name: String = _resolve_player_display_name(winner_id)
	if _match_result_overlay.has_method("show_result"):
		_match_result_overlay.call(
			"show_result",
			winner_id,
			local_player_id,
			_match_manager,
			is_host,
			_is_networked(),
			winner_name
		)


func _resolve_player_display_name(player_id: int) -> String:
	if player_id <= 0:
		return "Nadie"
	var player: PlayerController = _get_player_by_player_id(player_id)
	if player != null:
		var player_name: String = player.display_name.strip_edges()
		if not player_name.is_empty():
			return player_name
	var manager_name: String = _match_manager.get_player_name(player_id).strip_edges()
	if not manager_name.is_empty():
		return manager_name
	return "P%d" % player_id


func _on_match_rematch_requested() -> void:
	if _is_networked() and not multiplayer.is_server():
		return
	if _is_networked() and multiplayer.is_server():
		_network_rematch.rpc()
	else:
		_execute_rematch()


func _on_match_menu_requested() -> void:
	_match_result_request_token += 1
	if _match_result_overlay != null and _match_result_overlay.has_method("hide_overlay"):
		_match_result_overlay.call("hide_overlay")
	if _death_cinematic != null and _death_cinematic.has_method("cancel"):
		_death_cinematic.call("cancel")
	Engine.time_scale = 1.0
	if _is_networked():
		_disconnect_lan()
	else:
		_reset_session()
		_match_manager.apply_score_snapshot({}, false)
	_show_lobby("Elegí cómo entrar a la arena.")


func _execute_rematch() -> void:
	_match_result_request_token += 1
	if _match_result_overlay != null and _match_result_overlay.has_method("hide_overlay"):
		_match_result_overlay.call("hide_overlay")
	if _options_menu != null and _options_menu.visible:
		_options_menu.close()
	if _death_cinematic != null and _death_cinematic.has_method("cancel"):
		_death_cinematic.call("cancel")
	_pending_death_cinematic_match_end = false
	_pending_match_result_winner_id = -1
	_latest_death_corpse = null
	Engine.time_scale = 1.0
	get_tree().paused = false
	_match_manager.start_match()

	if _is_networked():
		if multiplayer.is_server():
			for player in players:
				_respawn_player_for_rematch(player, true)
			_sync_score_snapshot_to_peers()
			_network_sync_match_rules.rpc(_match_manager.get_rules_snapshot())
	else:
		for player in players:
			_respawn_player_for_rematch(player, false)


func _respawn_player_for_rematch(player: PlayerController, should_sync_network: bool) -> void:
	if player == null:
		return

	var spawn_transform: Transform3D = _spawn_manager.get_spawn_transform(players, Vector3.ZERO, 2.5, player)
	if should_sync_network:
		var peer_id: int = _get_peer_id_for_player(player)
		_apply_network_respawn_player(
			peer_id,
			player.player_id,
			spawn_transform.origin,
			spawn_transform.basis.get_euler().y
		)
		_network_respawn_player.rpc(
			peer_id,
			player.player_id,
			spawn_transform.origin,
			spawn_transform.basis.get_euler().y
		)
		_sync_player_health_to_peers(player)
		return

	player.respawn_at(spawn_transform.origin, spawn_transform.basis.get_euler().y)
	if player.has_method("restore_match_control"):
		player.restore_match_control()


func _on_joined_server() -> void:
	if _lobby_menu != null:
		_lobby_menu.set_status("Connected. Waiting for sync...")
	_prepare_client_match()


func _on_network_connection_failed(message: String) -> void:
	push_warning(message)
	_reset_session()
	_show_lobby(message)


func _on_server_disconnected() -> void:
	_reset_session()
	_show_lobby("Server disconnected.")


func _on_network_peer_connected(peer_id: int) -> void:
	if multiplayer.is_server():
		_register_network_peer(peer_id)
		_refresh_lan_discovery_host()
	_refresh_network_hud()


func _on_network_peer_disconnected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return

	_peer_ping_ms.erase(peer_id)
	var player_id: int = int(_peer_to_player_id.get(peer_id, 0))
	if player_id <= 0:
		return
	_network_remove_player.rpc(peer_id, player_id)
	_sync_score_snapshot_to_peers()
	_refresh_lan_discovery_host()
	_refresh_network_hud()


func _on_network_status_changed(status: String) -> void:
	_network_status_text = status
	if _lobby_menu != null and _lobby_menu.visible:
		_lobby_menu.set_status(status)
	_refresh_network_hud()


func _refresh_network_hud() -> void:
	for hud in _huds:
		if hud != null and is_instance_valid(hud):
			hud.set_network_stats(_network_status_text, _get_display_ping_ms(), _get_peer_count())


func _get_display_ping_ms() -> int:
	if not _is_networked():
		return -1
	if multiplayer.is_server():
		return _get_average_peer_ping_ms()
	return _local_ping_ms


func _get_average_peer_ping_ms() -> int:
	if _peer_ping_ms.is_empty():
		return -1

	var total_ping: int = 0
	var ping_count: int = 0
	for raw_ping in _peer_ping_ms.values():
		total_ping += int(raw_ping)
		ping_count += 1
	if ping_count <= 0:
		return -1
	return int(round(float(total_ping) / float(ping_count)))


func _get_peer_count() -> int:
	if not _is_networked():
		return 0
	return _peer_to_player_id.size()


func _spawn_corpse(player: PlayerController, killer_position: Vector3) -> Node3D:
	if player == null or player_corpse_scene == null:
		return null
	var corpse: Node = player_corpse_scene.instantiate()
	if corpse == null:
		return null
	add_child(corpse)
	corpse.global_position = player.global_position
	corpse.rotation = player.rotation
	var impulse_strength: float = float(corpse.get("impulse_strength")) if corpse.get("impulse_strength") != null else 8.0
	var impulse: Vector3 = Vector3.UP * 0.65
	if killer_position != Vector3.ZERO:
		var direction: Vector3 = (player.global_position - killer_position).normalized()
		impulse += direction * (impulse_strength * 0.72) + Vector3.UP * 0.85
	if corpse.has_method("setup"):
		corpse.call("setup", player.get_body_color(), impulse)
	_latest_death_corpse = corpse as Node3D
	return _latest_death_corpse


func _respawn_player(player: PlayerController = null, avoid_position: Vector3 = Vector3.ZERO) -> void:
	var player_to_respawn: PlayerController = player if player != null else _player
	if player_to_respawn == null:
		push_error("Cannot respawn because no player exists.")
		return

	if avoid_position == Vector3.ZERO and player_to_respawn.last_killer_position != Vector3.ZERO:
		avoid_position = player_to_respawn.last_killer_position

	var spawn_transform: Transform3D = _spawn_manager.get_spawn_transform(
		players,
		avoid_position,
		2.5,
		player_to_respawn
	)
	var peer_id: int = _get_peer_id_for_player(player_to_respawn)
	if _is_networked() and multiplayer.is_server():
		_apply_network_respawn_player(
			peer_id,
			player_to_respawn.player_id,
			spawn_transform.origin,
			spawn_transform.basis.get_euler().y
		)
		_network_respawn_player.rpc(
			peer_id,
			player_to_respawn.player_id,
			spawn_transform.origin,
			spawn_transform.basis.get_euler().y
		)
		_sync_player_health_to_peers(player_to_respawn)
	else:
		player_to_respawn.respawn_at(spawn_transform.origin, spawn_transform.basis.get_euler().y)


func _get_player_by_peer_id(peer_id: int) -> PlayerController:
	return get_node_or_null(_get_player_node_name(peer_id)) as PlayerController


func _get_player_by_player_id(player_id: int) -> PlayerController:
	var peer_id: int = int(_player_id_to_peer.get(player_id, 0))
	if peer_id <= 0:
		return null
	return _get_player_by_peer_id(peer_id)


func _get_pickup_by_id(pickup_id: int) -> PickupBase:
	if pickup_id < 0 or pickup_id >= _pickup_spawner.spawned_pickups.size():
		return null
	return _pickup_spawner.spawned_pickups[pickup_id] as PickupBase


func _get_peer_id_for_player(player: PlayerController) -> int:
	if player == null:
		return 0
	return int(_player_id_to_peer.get(player.player_id, 0))


func _get_player_node_name(peer_id: int) -> String:
	return "Player_%d" % peer_id


func _is_networked() -> bool:
	return _network_manager != null and _network_manager.is_networked()


func _is_match_active() -> bool:
	return _match_manager != null and _match_manager.match_running


func _is_local_peer(peer_id: int) -> bool:
	if not _is_networked():
		return peer_id == 1
	return peer_id == multiplayer.get_unique_id()


func _apply_network_respawn_player(peer_id: int, player_id: int, spawn_position: Vector3, yaw_radians: float) -> PlayerController:
	_peer_to_player_id[peer_id] = player_id
	_player_id_to_peer[player_id] = peer_id
	_match_manager.ensure_player(player_id)

	var player: PlayerController = _get_player_by_peer_id(peer_id)
	if player == null:
		return _spawn_or_update_player(peer_id, player_id, spawn_position, yaw_radians)

	player.player_id = player_id
	player.respawn_at(spawn_position, yaw_radians)
	if player.has_method("restore_match_control"):
		player.restore_match_control()
	return player
#endregion


#region RPCs
@rpc("authority", "call_local", "reliable")
func _network_load_map(map_id: String) -> void:
	_activate_map(map_id, true)


@rpc("authority", "call_local", "reliable")
func _network_spawn_player(peer_id: int, player_id: int, spawn_position: Vector3, yaw_radians: float) -> void:
	_peer_to_player_id[peer_id] = player_id
	_player_id_to_peer[player_id] = peer_id
	_match_manager.ensure_player(player_id)
	_spawn_or_update_player(peer_id, player_id, spawn_position, yaw_radians)


@rpc("authority", "reliable")
func _network_respawn_player(peer_id: int, player_id: int, spawn_position: Vector3, yaw_radians: float) -> void:
	_apply_network_respawn_player(peer_id, player_id, spawn_position, yaw_radians)


@rpc("authority", "call_local", "reliable")
func _network_remove_player(peer_id: int, player_id: int) -> void:
	var player: PlayerController = _get_player_by_peer_id(peer_id)
	if player != null:
		players.erase(player)
		if player == _player:
			_player = null
		player.queue_free()

	_peer_to_player_id.erase(peer_id)
	_player_id_to_peer.erase(player_id)


@rpc("authority", "unreliable_ordered")
func _network_receive_player_state(
	peer_id: int,
	_player_id: int,
	position: Vector3,
	yaw_radians: float,
	pitch_degrees: float,
	velocity: Vector3,
	is_dead_state: bool,
	is_crouching_state: bool,
	active_weapon_index: int = 0,
	is_aiming_state: bool = false
) -> void:
	if _is_local_peer(peer_id):
		return

	var player: PlayerController = _get_player_by_peer_id(peer_id)
	if player == null:
		return
	player.apply_network_state(position, yaw_radians, pitch_degrees, velocity, is_dead_state, is_crouching_state)
	player.apply_network_combat_state(active_weapon_index, is_aiming_state)


@rpc("authority", "reliable")
func _network_sync_player_health(
	player_id: int,
	current_health: int,
	max_health: int,
	is_dead_state: bool,
	damage_source_player_id: int,
	network_respawn_generation: int = 0
) -> void:
	var player: PlayerController = _get_player_by_player_id(player_id)
	if player == null:
		return
	player.apply_network_health(
		current_health,
		max_health,
		is_dead_state,
		damage_source_player_id,
		network_respawn_generation
	)


@rpc("authority", "reliable")
func _network_sync_score_snapshot(snapshot: Dictionary, is_match_running: bool) -> void:
	_match_manager.apply_score_snapshot(snapshot, is_match_running)


@rpc("authority", "call_local", "reliable")
func _network_apply_time_of_day_preset(time_of_day_preset: int) -> void:
	_apply_time_of_day_preset(time_of_day_preset, true)


@rpc("authority", "reliable")
func _network_apply_music_stereo_state(track_index: int, should_play: bool, playback_position: float) -> void:
	var music_stereo: MusicStereo = _get_music_stereo()
	if music_stereo == null:
		return
	music_stereo.apply_remote_state(track_index, should_play, playback_position)


@rpc("authority", "reliable")
func _network_set_pickup_available(pickup_id: int, is_available: bool) -> void:
	var pickup: PickupBase = _get_pickup_by_id(pickup_id)
	if pickup == null:
		return
	pickup.set_network_available(is_available)


@rpc("authority", "reliable")
func _network_confirm_pickup_collected(pickup_id: int, player_id: int) -> void:
	var player: PlayerController = _get_player_by_player_id(player_id)
	if player == null or not _is_local_peer(_get_peer_id_for_player(player)):
		return

	var pickup: PickupBase = _get_pickup_by_id(pickup_id)
	if pickup == null:
		return
	pickup.apply_confirmed_network_collect(player)


@rpc("authority", "reliable")
func _network_match_finished(winner_id: int) -> void:
	_pending_match_result_winner_id = winner_id
	_match_manager.apply_match_finished(winner_id)


@rpc("authority", "call_local", "reliable")
func _network_play_death_cinematic(victim_position: Vector3, is_match_ending: bool, killer_id: int = -1, killer_position: Vector3 = Vector3.ZERO) -> void:
	_run_death_cinematic(victim_position, is_match_ending, null, killer_id, killer_position)


@rpc("authority", "call_local", "reliable")
func _network_rematch() -> void:
	_execute_rematch()


@rpc("any_peer", "reliable")
func _network_report_display_name(player_id: int, display_name: String) -> void:
	if not multiplayer.is_server():
		return
	var sender_peer_id: int = multiplayer.get_remote_sender_id()
	if int(_peer_to_player_id.get(sender_peer_id, 0)) != player_id:
		return
	_apply_player_display_name(player_id, display_name)


@rpc("authority", "reliable")
func _network_sync_player_display_name(player_id: int, display_name: String) -> void:
	_apply_player_display_name(player_id, display_name, false)


func _apply_player_display_name(player_id: int, display_name: String, broadcast: bool = true) -> void:
	var clean_name: String = display_name.strip_edges()
	if clean_name.is_empty():
		return
	var player: PlayerController = _get_player_by_player_id(player_id)
	if player != null:
		player.display_name = clean_name
	_match_manager.set_player_name(player_id, clean_name)
	_refresh_network_hud()
	if broadcast and _is_networked() and multiplayer.is_server():
		_network_sync_player_display_name.rpc(player_id, clean_name)


@rpc("authority", "unreliable")
func _network_ping_client(sent_at_msec: int) -> void:
	_network_pong_from_client.rpc_id(1, sent_at_msec)


@rpc("any_peer", "unreliable")
func _network_pong_from_client(sent_at_msec: int) -> void:
	if not multiplayer.is_server():
		return

	var sender_peer_id: int = multiplayer.get_remote_sender_id()
	_peer_ping_ms[sender_peer_id] = maxi(Time.get_ticks_msec() - sent_at_msec, 0)
	_refresh_network_hud()


@rpc("any_peer", "unreliable")
func _network_ping_server(sent_at_msec: int) -> void:
	if not multiplayer.is_server():
		return

	var sender_peer_id: int = multiplayer.get_remote_sender_id()
	_network_pong_from_server.rpc_id(sender_peer_id, sent_at_msec)


@rpc("authority", "unreliable")
func _network_pong_from_server(sent_at_msec: int) -> void:
	_local_ping_ms = maxi(Time.get_ticks_msec() - sent_at_msec, 0)
	_refresh_network_hud()


@rpc("any_peer", "unreliable_ordered")
func _server_receive_player_state(
	player_id: int,
	position: Vector3,
	yaw_radians: float,
	pitch_degrees: float,
	velocity: Vector3,
	_is_dead_state: bool,
	is_crouching_state: bool,
	active_weapon_index: int = 0,
	is_aiming_state: bool = false
) -> void:
	if not multiplayer.is_server():
		return

	var sender_peer_id: int = multiplayer.get_remote_sender_id()
	var expected_player_id: int = int(_peer_to_player_id.get(sender_peer_id, 0))
	if expected_player_id <= 0 or expected_player_id != player_id:
		return

	var player: PlayerController = _get_player_by_peer_id(sender_peer_id)
	if player == null:
		return
	player.apply_network_state(position, yaw_radians, pitch_degrees, velocity, player.health.is_dead, is_crouching_state)
	player.apply_network_combat_state(active_weapon_index, is_aiming_state)
	_broadcast_player_state_values(sender_peer_id, player_id, position, yaw_radians, pitch_degrees, velocity, player.health.is_dead, is_crouching_state, active_weapon_index, is_aiming_state)


@rpc("any_peer", "reliable")
func _server_request_damage(victim_player_id: int, amount: int, attacker_player_id: int, shot_id: int = 0) -> void:
	if not multiplayer.is_server():
		return

	var sender_peer_id: int = multiplayer.get_remote_sender_id()
	var expected_attacker_id: int = int(_peer_to_player_id.get(sender_peer_id, 0))
	if expected_attacker_id <= 0 or expected_attacker_id != attacker_player_id:
		push_warning("Rejected damage request from peer %d." % sender_peer_id)
		return
	_apply_player_damage(victim_player_id, amount, attacker_player_id, shot_id)


@rpc("authority", "reliable")
func _network_confirm_damage(victim_player_id: int, amount: int, shot_id: int) -> void:
	_show_local_damage_feedback(victim_player_id, amount, shot_id)


@rpc("any_peer", "reliable")
func _server_request_pickup(pickup_id: int, player_id: int) -> void:
	if not multiplayer.is_server():
		return

	var sender_peer_id: int = multiplayer.get_remote_sender_id()
	var expected_player_id: int = int(_peer_to_player_id.get(sender_peer_id, 0))
	if expected_player_id <= 0 or expected_player_id != player_id:
		push_warning("Rejected pickup request from peer %d." % sender_peer_id)
		return
	_apply_player_pickup(pickup_id, player_id, sender_peer_id)


@rpc("any_peer", "reliable")
func _server_request_respawn() -> void:
	if not multiplayer.is_server():
		return

	var sender_peer_id: int = multiplayer.get_remote_sender_id()
	var player_id: int = int(_peer_to_player_id.get(sender_peer_id, 0))
	var player: PlayerController = _get_player_by_player_id(player_id)
	if player != null:
		_respawn_player(player)


@rpc("any_peer", "reliable")
func _server_request_music_stereo_toggle() -> void:
	if not multiplayer.is_server():
		return
	_apply_music_stereo_toggle()


@rpc("any_peer", "reliable")
func _server_request_music_stereo_next() -> void:
	if not multiplayer.is_server():
		return
	_apply_music_stereo_next()


@rpc("any_peer", "reliable")
func _request_full_sync() -> void:
	if not multiplayer.is_server():
		return

	var sender_peer_id: int = multiplayer.get_remote_sender_id()
	_network_load_map.rpc_id(sender_peer_id, _selected_map_id)
	_network_apply_time_of_day_preset.rpc_id(sender_peer_id, _selected_time_of_day_preset)
	_sync_all_players_to_peer(sender_peer_id)
	_sync_pickups_to_peer(sender_peer_id)
	_sync_music_stereo_to_peer(sender_peer_id)
	_sync_player_names_to_peer(sender_peer_id)
	_network_sync_score_snapshot.rpc_id(sender_peer_id, _match_manager.get_score_snapshot(), _match_manager.match_running)
	_network_sync_match_rules.rpc_id(sender_peer_id, _match_manager.get_rules_snapshot())


@rpc("authority", "reliable")
func _network_sync_match_rules(rules_snapshot: Dictionary) -> void:
	_match_manager.apply_rules_snapshot(rules_snapshot)


@rpc("authority", "reliable")
func _network_kill_feed_event(killer_name: String, victim_name: String, killer_id: int, victim_id: int) -> void:
	for hud in _huds:
		if hud != null:
			hud.add_kill_feed_entry(killer_name, victim_name, killer_id)


@rpc("authority", "reliable")
func _network_spawn_corpse(
	spawn_position: Vector3,
	spawn_rotation: Vector3,
	body_color: Color,
	impulse_direction: Vector3
) -> void:
	if player_corpse_scene == null:
		return
	var corpse: Node = player_corpse_scene.instantiate()
	if corpse == null:
		return
	add_child(corpse)
	corpse.global_position = spawn_position
	corpse.rotation = spawn_rotation
	var impulse_strength: float = float(corpse.get("impulse_strength")) if corpse.get("impulse_strength") != null else 8.0
	var impulse: Vector3 = impulse_direction.normalized() * (impulse_strength * 0.72) + Vector3.UP * 0.85 if impulse_direction.length_squared() > 0.01 else Vector3.UP * 0.65
	if corpse.has_method("setup"):
		corpse.call("setup", body_color, impulse)
	_latest_death_corpse = corpse as Node3D
#endregion
