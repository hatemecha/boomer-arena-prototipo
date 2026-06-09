class_name Game
extends Node3D

const NetworkManagerScript: GDScript = preload("res://scripts/game/network_manager.gd")

@export var player_scene: PackedScene = preload("res://scenes/player/Player.tscn")
@export var ammo_pickup_scene: PackedScene = preload("res://scenes/pickups/AmmoPickup.tscn")
@export var health_pickup_scene: PackedScene = preload("res://scenes/pickups/HealthPickup.tscn")
@export var target_scene: PackedScene = preload("res://scenes/game/DamageableTarget.tscn")
@export var hud_scene: PackedScene = preload("res://scenes/ui/HUD.tscn")
@export var options_menu_scene: PackedScene = preload("res://scenes/ui/OptionsMenu.tscn")
@export var lan_lobby_menu_scene: PackedScene = preload("res://scenes/ui/LanLobbyMenu.tscn")
@export_range(0.1, 10.0) var player_respawn_delay: float = 3.0
@export_range(1024, 65535) var lan_port: int = 24500
@export var default_lan_join_address: String = "127.0.0.1"
@export_range(2, 8) var max_lan_players: int = 2
@export_range(5.0, 60.0) var network_sync_rate: float = 20.0
@export_range(0.25, 5.0) var ping_interval: float = 1.0

var players: Array[PlayerController] = []

var _player: PlayerController
var _huds: Array[HUD] = []
var _hud_layer: CanvasLayer
var _options_layer: CanvasLayer
var _options_menu: OptionsMenu
var _lobby_layer: CanvasLayer
var _lobby_menu
var _visual_director: PSXVisualDirector
var _spawn_manager: SpawnManager
var _pickup_spawner: PickupSpawner
var _match_manager: MatchManager
var _debug_draw_manager: ArenaDebugDrawManager
var _network_manager: Node
var _peer_to_player_id: Dictionary = {}
var _player_id_to_peer: Dictionary = {}
var _next_player_id: int = 1
var _network_sync_accumulator: float = 0.0
var _ping_accumulator: float = 0.0
var _local_ping_ms: int = -1
var _peer_ping_ms: Dictionary = {}
var _network_status_text: String = "OFFLINE"
var _hud_player: PlayerController
var _has_spawned_pickups: bool = false
var _has_spawned_targets: bool = false
var _selected_time_of_day_preset: int = PSXVisualDirector.TimeOfDayPreset.NIGHT


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DefaultInputActions.ensure_default_actions()
	_visual_director = $PSXVisualDirector as PSXVisualDirector
	_setup_managers()
	_spawn_world_content()
	_setup_network_manager()
	_setup_lobby_menu()
	_debug_draw_manager.bind_context(_spawn_manager, _pickup_spawner, players)

	var started_from_args: bool = _network_manager.apply_startup_args()
	if started_from_args and _network_manager.is_host():
		_start_network_match_as_server()
	elif not started_from_args:
		_show_lobby("Select LAN mode.")


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


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
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


func request_network_damage(victim_player_id: int, amount: int, attacker_player_id: int) -> bool:
	if not _is_networked() or multiplayer.is_server():
		return false
	if victim_player_id <= 0 or attacker_player_id <= 0 or amount <= 0:
		push_warning("Ignoring invalid network damage request.")
		return true

	_server_request_damage.rpc_id(1, victim_player_id, amount, attacker_player_id)
	return true


func request_network_pickup(pickup_id: int, player_id: int) -> bool:
	if not _is_networked() or multiplayer.is_server():
		return false
	if pickup_id < 0 or player_id <= 0:
		push_warning("Ignoring invalid network pickup request.")
		return true

	_server_request_pickup.rpc_id(1, pickup_id, player_id)
	return true


func _setup_managers() -> void:
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

	_debug_draw_manager = ArenaDebugDrawManager.new()
	_debug_draw_manager.name = "ArenaDebugDrawManager"
	add_child(_debug_draw_manager)


func _setup_network_manager() -> void:
	_network_manager = NetworkManagerScript.new()
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
	_lobby_menu.host_requested.connect(_on_lobby_host_requested)
	_lobby_menu.join_requested.connect(_on_lobby_join_requested)
	_lobby_menu.practice_requested.connect(_on_lobby_practice_requested)
	_lobby_menu.disconnect_requested.connect(_on_lobby_disconnect_requested)
	_lobby_menu.visible = false


func _show_lobby(status: String) -> void:
	if _lobby_menu == null:
		return

	_lobby_menu.configure(default_lan_join_address, lan_port, _get_lan_addresses())
	_lobby_menu.set_busy(false)
	_lobby_menu.set_status(status)
	_lobby_menu.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	_lobby_menu.focus_default()


func _hide_lobby() -> void:
	if _lobby_menu == null:
		return

	_lobby_menu.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _is_lobby_visible() -> bool:
	return _lobby_menu != null and bool(_lobby_menu.visible)


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


func _spawn_world_content() -> void:
	if not _has_spawned_pickups:
		_pickup_spawner.spawn_pickups(self)
		_register_pickups()
		_has_spawned_pickups = true
	if not _has_spawned_targets:
		_spawn_targets()
		_has_spawned_targets = true


func _start_offline_match() -> void:
	_clear_players_and_interfaces()
	_reset_player_maps()
	_apply_time_of_day_preset(_selected_time_of_day_preset, true)
	_match_manager.start_match()
	_peer_to_player_id[1] = 1
	_player_id_to_peer[1] = 1
	_match_manager.ensure_player(1)

	var spawn_transform: Transform3D = _spawn_manager.get_spawn_transform(players)
	_spawn_or_update_player(1, 1, spawn_transform.origin, spawn_transform.basis.get_euler().y)
	_on_network_status_changed("OFFLINE")
	_hide_lobby()


func _start_network_match_as_server() -> void:
	if not _is_networked() or not multiplayer.is_server():
		push_error("Cannot start a network match without a LAN host.")
		return

	_clear_players_and_interfaces()
	_reset_player_maps()
	_apply_time_of_day_preset(_selected_time_of_day_preset, true)
	_match_manager.start_match()
	_register_network_peer(1)
	_network_apply_time_of_day_preset.rpc(_selected_time_of_day_preset)
	_sync_score_snapshot_to_peers()


func _prepare_client_match() -> void:
	_clear_players_and_interfaces()
	_reset_player_maps()
	_match_manager.apply_score_snapshot({}, true)
	_request_full_sync.rpc_id(1)


func _start_lan_host() -> void:
	if _network_manager.host_game(lan_port):
		_start_network_match_as_server()


func _start_lan_join() -> void:
	_clear_players_and_interfaces()
	_reset_player_maps()
	if not _network_manager.join_game(default_lan_join_address, lan_port):
		if _is_lobby_visible():
			_show_lobby("Could not join %s:%d." % [default_lan_join_address, lan_port])
		else:
			_start_offline_match()


func _disconnect_lan() -> void:
	_network_manager.disconnect_network()
	_clear_players_and_interfaces()
	_reset_player_maps()
	_peer_ping_ms.clear()
	_local_ping_ms = -1
	_match_manager.apply_score_snapshot({}, false)
	_show_lobby("Disconnected.")


func _apply_time_of_day_preset(time_of_day_preset: int, should_refresh: bool = true) -> void:
	_selected_time_of_day_preset = _sanitize_time_of_day_preset(time_of_day_preset)
	if _visual_director == null:
		return

	_visual_director.time_of_day_preset = _selected_time_of_day_preset
	if should_refresh:
		_visual_director.refresh_visual_style()


func _sanitize_time_of_day_preset(time_of_day_preset: int) -> int:
	return clampi(time_of_day_preset, 0, PSXVisualDirector.TimeOfDayPreset.size() - 1)


func _on_lobby_host_requested(port: int, time_of_day_preset: int) -> void:
	lan_port = port
	_selected_time_of_day_preset = _sanitize_time_of_day_preset(time_of_day_preset)
	_network_manager.configure(lan_port, default_lan_join_address, maxi(max_lan_players - 1, 1))
	_start_lan_host()


func _on_lobby_join_requested(address: String, port: int) -> void:
	default_lan_join_address = address.strip_edges()
	lan_port = port
	_network_manager.configure(lan_port, default_lan_join_address, maxi(max_lan_players - 1, 1))
	_start_lan_join()


func _on_lobby_practice_requested(time_of_day_preset: int) -> void:
	_selected_time_of_day_preset = _sanitize_time_of_day_preset(time_of_day_preset)
	_network_manager.disconnect_network(false)
	_start_offline_match()


func _on_lobby_disconnect_requested() -> void:
	_disconnect_lan()


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

	var spawn_transform: Transform3D = _spawn_manager.get_spawn_transform(players)
	_network_spawn_player.rpc(peer_id, player_id, spawn_transform.origin, spawn_transform.basis.get_euler().y)
	_network_apply_time_of_day_preset.rpc_id(peer_id, _selected_time_of_day_preset)
	_sync_all_players_to_peer(peer_id)
	_sync_pickups_to_peer(peer_id)
	_sync_score_snapshot_to_peers()


func _allocate_player_id() -> int:
	for candidate_id in range(1, max_lan_players + 1):
		if not _player_id_to_peer.has(candidate_id):
			_next_player_id = candidate_id + 1
			return candidate_id
	while _next_player_id <= max_lan_players:
		if not _player_id_to_peer.has(_next_player_id):
			var allocated_id: int = _next_player_id
			_next_player_id += 1
			return allocated_id
		_next_player_id += 1
	return -1


func _spawn_targets() -> void:
	_spawn_target(Vector3(-7.0, 0.0, -8.0))
	_spawn_target(Vector3(7.0, 0.0, 8.0))
	_spawn_target(Vector3(0.0, 0.0, -5.5))


func _spawn_target(spawn_position: Vector3) -> void:
	var target: Node3D = target_scene.instantiate() as Node3D
	if target == null:
		push_error("Target scene must instantiate a Node3D.")
		return
	add_child(target)
	target.global_position = spawn_position


func _register_pickups() -> void:
	for pickup_index in range(_pickup_spawner.spawned_pickups.size()):
		var pickup: PickupBase = _pickup_spawner.spawned_pickups[pickup_index] as PickupBase
		if pickup == null:
			continue
		pickup.set_pickup_id(pickup_index)
		if not pickup.availability_changed.is_connected(_on_pickup_availability_changed):
			pickup.availability_changed.connect(_on_pickup_availability_changed)


func _spawn_or_update_player(peer_id: int, player_id: int, spawn_position: Vector3, yaw_radians: float) -> PlayerController:
	var player: PlayerController = _get_player_by_peer_id(peer_id)
	var is_new_player: bool = player == null
	if is_new_player:
		player = player_scene.instantiate() as PlayerController
		if player == null:
			push_error("Player scene must instantiate a PlayerController.")
			return null

		player.name = _get_player_node_name(peer_id)
		add_child(player)
		players.append(player)
		player.damaged.connect(_on_player_damaged.bind(player))
		player.died.connect(_on_player_died.bind(player))

	player.player_id = player_id
	player.display_name = "Player %d" % player_id
	player.input_prefix = ""
	player.mouse_look_enabled = true
	player.set_multiplayer_authority(peer_id)

	var is_local_player: bool = _is_local_peer(peer_id)
	player.set_local_control_enabled(is_local_player)
	if player.camera != null:
		player.camera.current = is_local_player
	if player_id == 2:
		player.set_body_color(Color(0.9, 0.1, 0.08))

	if is_new_player:
		player.respawn_at(spawn_position, yaw_radians)
	else:
		player.apply_network_state(spawn_position, yaw_radians, player.camera_pivot.rotation_degrees.x, player.velocity, player.health.is_dead, false)

	if is_local_player:
		_player = player
		_setup_local_hud(player)
		_setup_options_menu()
		_hide_lobby()

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
		_hud_layer.layer = 100
		add_child(_hud_layer)

	_hud_layer.add_child(hud)
	_huds.append(hud)
	hud.bind_player(player)
	hud.bind_match(_match_manager, player.player_id)
	_hud_player = player
	_refresh_network_hud()


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
	_options_menu.bind_context(_player, _huds[0], _visual_director, _debug_draw_manager)
	_options_menu.menu_visibility_changed.connect(_on_options_visibility_changed)
	_options_menu.respawn_requested.connect(_on_options_respawn_requested)


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
			_player.is_crouching()
		)


func _process_network_ping(delta: float) -> void:
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
		player.is_crouching()
	)


func _broadcast_player_state_values(
	peer_id: int,
	player_id: int,
	position: Vector3,
	yaw_radians: float,
	pitch_degrees: float,
	velocity: Vector3,
	is_dead_state: bool,
	is_crouching_state: bool
) -> void:
	_network_receive_player_state.rpc(
		peer_id,
		player_id,
		position,
		yaw_radians,
		pitch_degrees,
		velocity,
		is_dead_state,
		is_crouching_state
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


func _sync_player_health_to_peers(player: PlayerController) -> void:
	if player == null or not _is_networked() or not multiplayer.is_server():
		return
	_network_sync_player_health.rpc(
		player.player_id,
		player.health.current_health,
		player.health.max_health,
		player.health.is_dead,
		player.last_damage_source_player_id
	)


func _apply_player_damage(victim_player_id: int, amount: int, attacker_player_id: int) -> void:
	if amount <= 0:
		push_warning("Damage amount must be greater than zero.")
		return

	var victim: PlayerController = _get_player_by_player_id(victim_player_id)
	if victim == null:
		push_warning("Cannot apply damage because player %d does not exist." % victim_player_id)
		return
	victim.apply_damage(amount, attacker_player_id)


func _apply_player_pickup(pickup_id: int, player_id: int) -> void:
	var pickup: PickupBase = _get_pickup_by_id(pickup_id)
	if pickup == null or not pickup.is_available():
		return

	var player: PlayerController = _get_player_by_player_id(player_id)
	if player == null:
		return

	if pickup.collect_for_player(player):
		_sync_player_health_to_peers(player)


func _on_pickup_availability_changed(pickup_id: int, is_available: bool) -> void:
	if _is_networked() and multiplayer.is_server():
		_network_set_pickup_available.rpc(pickup_id, is_available)


func _on_player_damaged(_amount: int, player: PlayerController) -> void:
	if _is_networked() and multiplayer.is_server():
		_sync_player_health_to_peers(player)


func _on_player_died(player: PlayerController) -> void:
	if _is_networked() and not multiplayer.is_server():
		return

	if player != null:
		var killer_id: int = player.last_damage_source_player_id
		if killer_id > 0 and killer_id != player.player_id:
			_match_manager.register_kill(killer_id, player.player_id)
		else:
			_match_manager.register_death(player.player_id)
		_sync_player_health_to_peers(player)

	await get_tree().create_timer(player_respawn_delay).timeout
	if player != null and is_instance_valid(player) and _match_manager.match_running:
		_respawn_player(player)


func _on_options_respawn_requested() -> void:
	if _is_networked() and not multiplayer.is_server():
		_server_request_respawn.rpc_id(1)
		return
	_respawn_player(_player)


func _on_options_visibility_changed(is_visible: bool) -> void:
	if _player != null:
		_player.set_gameplay_input_enabled(not is_visible)


func _on_score_changed(_player_id: int, _kills: int, _deaths: int) -> void:
	_sync_score_snapshot_to_peers()


func _on_match_finished(winner_id: int) -> void:
	for player in players:
		if player == null:
			continue
		player.set_gameplay_input_enabled(false)

	if _is_networked() and multiplayer.is_server():
		_network_match_finished.rpc(winner_id)


func _on_joined_server() -> void:
	if _lobby_menu != null:
		_lobby_menu.set_status("Connected. Waiting for sync...")
	_prepare_client_match()


func _on_network_connection_failed(message: String) -> void:
	push_warning(message)
	_clear_players_and_interfaces()
	_reset_player_maps()
	_show_lobby(message)


func _on_server_disconnected() -> void:
	_clear_players_and_interfaces()
	_reset_player_maps()
	_show_lobby("Server disconnected.")


func _on_network_peer_connected(peer_id: int) -> void:
	if multiplayer.is_server():
		_register_network_peer(peer_id)
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


func _respawn_player(player: PlayerController = null) -> void:
	var player_to_respawn: PlayerController = player if player != null else _player
	if player_to_respawn == null:
		push_error("Cannot respawn because no player exists.")
		return

	var spawn_transform: Transform3D = _spawn_manager.get_spawn_transform(players)
	var peer_id: int = _get_peer_id_for_player(player_to_respawn)
	if _is_networked() and multiplayer.is_server():
		_network_respawn_player.rpc(
			peer_id,
			player_to_respawn.player_id,
			spawn_transform.origin,
			spawn_transform.basis.get_euler().y
		)
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


func _is_local_peer(peer_id: int) -> bool:
	if not _is_networked():
		return peer_id == 1
	return peer_id == multiplayer.get_unique_id()


@rpc("authority", "call_local", "reliable")
func _network_spawn_player(peer_id: int, player_id: int, spawn_position: Vector3, yaw_radians: float) -> void:
	_peer_to_player_id[peer_id] = player_id
	_player_id_to_peer[player_id] = peer_id
	_match_manager.ensure_player(player_id)
	_spawn_or_update_player(peer_id, player_id, spawn_position, yaw_radians)


@rpc("authority", "call_local", "reliable")
func _network_respawn_player(peer_id: int, player_id: int, spawn_position: Vector3, yaw_radians: float) -> void:
	var player: PlayerController = _get_player_by_peer_id(peer_id)
	if player == null:
		_network_spawn_player(peer_id, player_id, spawn_position, yaw_radians)
		return
	player.respawn_at(spawn_position, yaw_radians)


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
	is_crouching_state: bool
) -> void:
	if _is_local_peer(peer_id):
		return

	var player: PlayerController = _get_player_by_peer_id(peer_id)
	if player == null:
		return
	player.apply_network_state(position, yaw_radians, pitch_degrees, velocity, is_dead_state, is_crouching_state)


@rpc("authority", "reliable")
func _network_sync_player_health(
	player_id: int,
	current_health: int,
	max_health: int,
	is_dead_state: bool,
	damage_source_player_id: int
) -> void:
	var player: PlayerController = _get_player_by_player_id(player_id)
	if player == null:
		return
	player.apply_network_health(current_health, max_health, is_dead_state, damage_source_player_id)


@rpc("authority", "reliable")
func _network_sync_score_snapshot(snapshot: Dictionary, is_match_running: bool) -> void:
	_match_manager.apply_score_snapshot(snapshot, is_match_running)


@rpc("authority", "call_local", "reliable")
func _network_apply_time_of_day_preset(time_of_day_preset: int) -> void:
	_apply_time_of_day_preset(time_of_day_preset, true)


@rpc("authority", "reliable")
func _network_set_pickup_available(pickup_id: int, is_available: bool) -> void:
	var pickup: PickupBase = _get_pickup_by_id(pickup_id)
	if pickup == null:
		return
	pickup.set_network_available(is_available)


@rpc("authority", "reliable")
func _network_match_finished(winner_id: int) -> void:
	_match_manager.apply_match_finished(winner_id)


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
	is_crouching_state: bool
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
	_broadcast_player_state_values(sender_peer_id, player_id, position, yaw_radians, pitch_degrees, velocity, player.health.is_dead, is_crouching_state)


@rpc("any_peer", "reliable")
func _server_request_damage(victim_player_id: int, amount: int, attacker_player_id: int) -> void:
	if not multiplayer.is_server():
		return

	var sender_peer_id: int = multiplayer.get_remote_sender_id()
	var expected_attacker_id: int = int(_peer_to_player_id.get(sender_peer_id, 0))
	if expected_attacker_id <= 0 or expected_attacker_id != attacker_player_id:
		push_warning("Rejected damage request from peer %d." % sender_peer_id)
		return
	_apply_player_damage(victim_player_id, amount, attacker_player_id)


@rpc("any_peer", "reliable")
func _server_request_pickup(pickup_id: int, player_id: int) -> void:
	if not multiplayer.is_server():
		return

	var sender_peer_id: int = multiplayer.get_remote_sender_id()
	var expected_player_id: int = int(_peer_to_player_id.get(sender_peer_id, 0))
	if expected_player_id <= 0 or expected_player_id != player_id:
		push_warning("Rejected pickup request from peer %d." % sender_peer_id)
		return
	_apply_player_pickup(pickup_id, player_id)


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
func _request_full_sync() -> void:
	if not multiplayer.is_server():
		return

	var sender_peer_id: int = multiplayer.get_remote_sender_id()
	_network_apply_time_of_day_preset.rpc_id(sender_peer_id, _selected_time_of_day_preset)
	_sync_all_players_to_peer(sender_peer_id)
	_sync_pickups_to_peer(sender_peer_id)
	_network_sync_score_snapshot.rpc_id(sender_peer_id, _match_manager.get_score_snapshot(), _match_manager.match_running)
