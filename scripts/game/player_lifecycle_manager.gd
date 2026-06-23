class_name PlayerLifecycleManager
extends Node

var _owner: Game
var _spawn_manager: SpawnManager
var _match_manager: MatchManager
var _player_corpse_scene: PackedScene

var latest_death_corpse: Node3D


func configure(
	owner: Game,
	spawn_manager: SpawnManager,
	match_manager: MatchManager,
	corpse_scene: PackedScene
) -> void:
	_owner = owner
	_spawn_manager = spawn_manager
	_match_manager = match_manager
	_player_corpse_scene = corpse_scene


func spawn_corpse(player: PlayerController, killer_position: Vector3) -> Node3D:
	if player == null or _player_corpse_scene == null or _owner == null:
		return null

	var corpse: Node = _player_corpse_scene.instantiate()
	if corpse == null:
		return null

	_owner.add_child(corpse)
	corpse.global_position = player.global_position
	corpse.rotation = player.rotation

	var impulse_strength: float = float(corpse.get("impulse_strength")) if corpse.get("impulse_strength") != null else 8.0
	var impulse: Vector3 = Vector3.UP * 0.65
	if killer_position != Vector3.ZERO:
		var direction: Vector3 = (player.global_position - killer_position).normalized()
		impulse += direction * (impulse_strength * 0.72) + Vector3.UP * 0.85
	if corpse.has_method("setup"):
		corpse.call("setup", player.get_body_color(), impulse)

	latest_death_corpse = corpse as Node3D
	return latest_death_corpse


func spawn_network_corpse(
	spawn_position: Vector3,
	spawn_rotation: Vector3,
	body_color: Color,
	impulse_direction: Vector3
) -> void:
	if _player_corpse_scene == null or _owner == null:
		return

	var corpse: Node = _player_corpse_scene.instantiate()
	if corpse == null:
		return

	_owner.add_child(corpse)
	corpse.global_position = spawn_position
	corpse.rotation = spawn_rotation

	var impulse_strength: float = float(corpse.get("impulse_strength")) if corpse.get("impulse_strength") != null else 8.0
	var impulse: Vector3 = (
		impulse_direction.normalized() * (impulse_strength * 0.72) + Vector3.UP * 0.85
		if impulse_direction.length_squared() > 0.01
		else Vector3.UP * 0.65
	)
	if corpse.has_method("setup"):
		corpse.call("setup", body_color, impulse)
	latest_death_corpse = corpse as Node3D


func get_spawn_transform(
	player: PlayerController,
	avoid_position: Vector3 = Vector3.ZERO
) -> Transform3D:
	if player == null or _spawn_manager == null or _owner == null:
		return Transform3D.IDENTITY

	if avoid_position == Vector3.ZERO and player.last_killer_position != Vector3.ZERO:
		avoid_position = player.last_killer_position

	return _spawn_manager.get_spawn_transform(_owner.players, avoid_position, 2.5, player)


func apply_network_respawn(
	peer_id: int,
	player_id: int,
	spawn_position: Vector3,
	yaw_radians: float
) -> PlayerController:
	if _owner == null or _match_manager == null:
		return null

	_owner.register_network_player_mapping(peer_id, player_id)
	_match_manager.ensure_player(player_id)

	var player: PlayerController = _owner.get_player_by_peer_id(peer_id)
	if player == null:
		return _owner.spawn_or_update_player(peer_id, player_id, spawn_position, yaw_radians)

	player.player_id = player_id
	player.respawn_at(spawn_position, yaw_radians)
	if player.has_method("restore_match_control"):
		player.restore_match_control()
	return player
