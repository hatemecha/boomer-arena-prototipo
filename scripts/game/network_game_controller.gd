class_name NetworkGameController
extends Node

var game: Game


func bind_game(next_game: Game) -> void:
	game = next_game


@rpc("authority", "call_local", "reliable")
func network_load_map(map_id: String) -> void:
	if game != null:
		game.handle_network_load_map(map_id)


@rpc("authority", "call_local", "reliable")
func network_spawn_player(peer_id: int, player_id: int, spawn_position: Vector3, yaw_radians: float) -> void:
	if game != null:
		game.handle_network_spawn_player(peer_id, player_id, spawn_position, yaw_radians)


@rpc("authority", "reliable")
func network_respawn_player(peer_id: int, player_id: int, spawn_position: Vector3, yaw_radians: float) -> void:
	if game != null:
		game.handle_network_respawn_player(peer_id, player_id, spawn_position, yaw_radians)


@rpc("authority", "call_local", "reliable")
func network_remove_player(peer_id: int, player_id: int) -> void:
	if game != null:
		game.handle_network_remove_player(peer_id, player_id)


@rpc("authority", "unreliable_ordered")
func network_receive_player_state(
	peer_id: int,
	player_id: int,
	position: Vector3,
	yaw_radians: float,
	pitch_degrees: float,
	velocity: Vector3,
	is_dead_state: bool,
	is_crouching_state: bool,
	active_weapon_index: int = 0,
	is_aiming_state: bool = false
) -> void:
	if game != null:
		game.handle_network_receive_player_state(
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


@rpc("authority", "reliable")
func network_sync_player_health(
	player_id: int,
	current_health: int,
	max_health: int,
	is_dead_state: bool,
	damage_source_player_id: int,
	network_respawn_generation: int = 0
) -> void:
	if game != null:
		game.handle_network_sync_player_health(
			player_id,
			current_health,
			max_health,
			is_dead_state,
			damage_source_player_id,
			network_respawn_generation
		)


@rpc("authority", "reliable")
func network_sync_player_ammo(
	player_id: int,
	active_weapon_index: int,
	ammo_in_mag: int,
	reserve_ammo: int
) -> void:
	if game != null:
		game.handle_network_sync_player_ammo(player_id, active_weapon_index, ammo_in_mag, reserve_ammo)


@rpc("authority", "reliable")
func network_sync_score_snapshot(snapshot: Dictionary, is_match_running: bool) -> void:
	if game != null:
		game.handle_network_sync_score_snapshot(snapshot, is_match_running)


@rpc("authority", "call_local", "reliable")
func network_apply_time_of_day_preset(time_of_day_preset: int) -> void:
	if game != null:
		game.handle_network_apply_time_of_day_preset(time_of_day_preset)


@rpc("authority", "reliable")
func network_apply_music_stereo_state(track_index: int, should_play: bool, playback_position: float) -> void:
	if game != null:
		game.handle_network_apply_music_stereo_state(track_index, should_play, playback_position)


@rpc("authority", "reliable")
func network_set_pickup_available(pickup_id: int, is_available: bool) -> void:
	if game != null:
		game.handle_network_set_pickup_available(pickup_id, is_available)


@rpc("authority", "reliable")
func network_confirm_pickup_collected(pickup_id: int, player_id: int) -> void:
	if game != null:
		game.handle_network_confirm_pickup_collected(pickup_id, player_id)


@rpc("authority", "reliable")
func network_match_finished(winner_id: int) -> void:
	if game != null:
		game.handle_network_match_finished(winner_id)


@rpc("authority", "call_local", "reliable")
func network_play_death_cinematic(
	victim_position: Vector3,
	is_match_ending: bool,
	killer_id: int = -1,
	killer_position: Vector3 = Vector3.ZERO
) -> void:
	if game != null:
		game.handle_network_play_death_cinematic(victim_position, is_match_ending, killer_id, killer_position)


@rpc("authority", "call_local", "reliable")
func network_rematch() -> void:
	if game != null:
		game.handle_network_rematch()


@rpc("any_peer", "reliable")
func network_report_display_name(player_id: int, display_name: String) -> void:
	if game != null:
		game.handle_network_report_display_name(player_id, display_name)


@rpc("authority", "reliable")
func network_sync_player_display_name(player_id: int, display_name: String) -> void:
	if game != null:
		game.handle_network_sync_player_display_name(player_id, display_name)


@rpc("authority", "unreliable")
func network_ping_client(sent_at_msec: int) -> void:
	if game != null:
		game.handle_network_ping_client(sent_at_msec)


@rpc("any_peer", "unreliable")
func network_pong_from_client(sent_at_msec: int) -> void:
	if game != null:
		game.handle_network_pong_from_client(sent_at_msec)


@rpc("any_peer", "unreliable")
func network_ping_server(sent_at_msec: int) -> void:
	if game != null:
		game.handle_network_ping_server(sent_at_msec)


@rpc("authority", "unreliable")
func network_pong_from_server(sent_at_msec: int) -> void:
	if game != null:
		game.handle_network_pong_from_server(sent_at_msec)


@rpc("any_peer", "unreliable_ordered")
func server_receive_player_state(
	player_id: int,
	position: Vector3,
	yaw_radians: float,
	pitch_degrees: float,
	velocity: Vector3,
	is_dead_state: bool,
	is_crouching_state: bool,
	active_weapon_index: int = 0,
	is_aiming_state: bool = false
) -> void:
	if game != null:
		game.handle_server_receive_player_state(
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


@rpc("any_peer", "reliable")
func server_request_damage(victim_player_id: int, amount: int, attacker_player_id: int, shot_id: int = 0) -> void:
	if game != null:
		game.handle_server_request_damage(victim_player_id, amount, attacker_player_id, shot_id)


@rpc("authority", "reliable")
func network_confirm_damage(victim_player_id: int, amount: int, shot_id: int) -> void:
	if game != null:
		game.handle_network_confirm_damage(victim_player_id, amount, shot_id)


@rpc("any_peer", "reliable")
func server_request_pickup(pickup_id: int, player_id: int) -> void:
	if game != null:
		game.handle_server_request_pickup(pickup_id, player_id)


@rpc("any_peer", "reliable")
func server_request_respawn() -> void:
	if game != null:
		game.handle_server_request_respawn()


@rpc("any_peer", "reliable")
func server_request_void_recovery(player_id: int) -> void:
	if game != null:
		game.handle_server_request_void_recovery(player_id)


@rpc("any_peer", "reliable")
func server_request_music_stereo_toggle() -> void:
	if game != null:
		game.handle_server_request_music_stereo_toggle()


@rpc("any_peer", "reliable")
func server_request_music_stereo_next() -> void:
	if game != null:
		game.handle_server_request_music_stereo_next()


@rpc("any_peer", "reliable")
func request_full_sync() -> void:
	if game != null:
		game.handle_request_full_sync()


@rpc("authority", "reliable")
func network_sync_match_rules(rules_snapshot: Dictionary) -> void:
	if game != null:
		game.handle_network_sync_match_rules(rules_snapshot)


@rpc("authority", "reliable")
func network_kill_feed_event(killer_name: String, victim_name: String, killer_id: int, victim_id: int) -> void:
	if game != null:
		game.handle_network_kill_feed_event(killer_name, victim_name, killer_id, victim_id)


@rpc("authority", "reliable")
func network_spawn_corpse(
	spawn_position: Vector3,
	spawn_rotation: Vector3,
	body_color: Color,
	impulse_direction: Vector3
) -> void:
	if game != null:
		game.handle_network_spawn_corpse(spawn_position, spawn_rotation, body_color, impulse_direction)
