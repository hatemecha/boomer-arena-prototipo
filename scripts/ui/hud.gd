class_name HUD
extends Control

@onready var health_label: Label = $Stats/HealthLabel
@onready var player_label: Label = $Stats/PlayerLabel if has_node("Stats/PlayerLabel") else null
@onready var weapon_label: Label = $Stats/WeaponLabel
@onready var ammo_label: Label = $Stats/AmmoLabel
@onready var score_label: Label = $Stats/ScoreLabel if has_node("Stats/ScoreLabel") else null
@onready var match_label: Label = $Stats/MatchLabel if has_node("Stats/MatchLabel") else null
@onready var network_label: Label = $Stats/NetworkLabel if has_node("Stats/NetworkLabel") else null
@onready var ping_label: Label = $Stats/PingLabel if has_node("Stats/PingLabel") else null
@onready var fps_label: Label = $Stats/FpsLabel
@onready var position_label: Label = $Stats/PositionLabel
@onready var speed_label: Label = $Stats/SpeedLabel
@onready var crosshair: Label = $Crosshair
@onready var aim_dot: ColorRect = $AimDot

var _player: PlayerController
var _active_weapon: WeaponBase
var _health: int = 100
var _max_health: int = 100
var _ammo_in_mag: int = 0
var _reserve_ammo: int = 0
var _debug_position: Vector3 = Vector3.ZERO
var _debug_speed: float = 0.0
var _debug_visible: bool = true
var _crosshair_enabled: bool = true
var _match_manager: MatchManager
var _local_player_id: int = 0


func _ready() -> void:
	_ensure_optional_labels()
	set_debug_visible(_debug_visible)


func bind_player(player: PlayerController) -> void:
	if player == null:
		push_error("HUD cannot bind a null player.")
		return

	_player = player
	_local_player_id = player.player_id
	if player_label != null:
		player_label.text = "%s  P%d" % [player.display_name.to_upper(), player.player_id]
	if player.health == null:
		push_error("HUD cannot bind because the player has no health component.")
		return

	player.health.health_changed.connect(_on_health_changed)
	player.debug_stats_changed.connect(_on_debug_stats_changed)
	player.active_weapon_changed.connect(_on_active_weapon_changed)
	_on_active_weapon_changed(player.weapon)

	if _active_weapon == null:
		_on_ammo_changed(0, 0)
		_on_weapon_state_changed("NoWeapon")
		_on_health_changed(player.health.current_health, player.health.max_health)
		return

	_on_health_changed(player.health.current_health, player.health.max_health)
	_on_ammo_changed(_active_weapon.ammo_in_mag, _active_weapon.reserve_ammo)
	_on_weapon_state_changed(_active_weapon.state)


func bind_match(match_manager: MatchManager, local_player_id: int) -> void:
	if match_manager == null:
		push_error("HUD cannot bind a null match manager.")
		return

	_match_manager = match_manager
	_local_player_id = local_player_id
	if not _match_manager.score_changed.is_connected(_on_score_changed):
		_match_manager.score_changed.connect(_on_score_changed)
	if not _match_manager.match_finished.is_connected(_on_match_finished):
		_match_manager.match_finished.connect(_on_match_finished)
	_refresh_score_label()
	if match_label != null:
		match_label.text = "FIRST TO %d" % _match_manager.score_limit


func _process(_delta: float) -> void:
	if fps_label != null:
		fps_label.text = "DEBUG FPS: %d" % Engine.get_frames_per_second()
	if position_label != null:
		position_label.text = "DEBUG POS: %.1f, %.1f, %.1f" % [_debug_position.x, _debug_position.y, _debug_position.z]
	if speed_label != null:
		speed_label.text = "DEBUG SPEED: %.1f" % _debug_speed
	var is_aiming: bool = _active_weapon != null and _active_weapon.is_aiming
	if crosshair != null:
		crosshair.visible = _crosshair_enabled and not is_aiming
	if aim_dot != null:
		aim_dot.visible = _crosshair_enabled and is_aiming


func set_debug_visible(value: bool) -> void:
	_debug_visible = value
	if fps_label != null:
		fps_label.visible = value
	if position_label != null:
		position_label.visible = value
	if speed_label != null:
		speed_label.visible = value


func is_debug_visible() -> bool:
	return _debug_visible


func set_crosshair_enabled(value: bool) -> void:
	_crosshair_enabled = value
	if not value:
		if crosshair != null:
			crosshair.visible = false
		if aim_dot != null:
			aim_dot.visible = false


func is_crosshair_enabled() -> bool:
	return _crosshair_enabled


func set_network_status(status: String) -> void:
	if network_label == null:
		return
	network_label.text = "NET: %s" % status


func set_network_stats(status: String, ping_ms: int, peer_count: int) -> void:
	set_network_status(status)
	if ping_label == null:
		return

	var ping_text: String = "LOCAL" if ping_ms < 0 else "%d MS" % ping_ms
	ping_label.text = "PING: %s  PEERS: %d" % [ping_text, peer_count]


func _on_health_changed(current_health: int, max_health: int) -> void:
	_health = current_health
	_max_health = max_health
	health_label.text = "HEALTH: %d / %d" % [_health, _max_health]


func _on_ammo_changed(ammo_in_mag: int, reserve_ammo: int) -> void:
	_ammo_in_mag = ammo_in_mag
	_reserve_ammo = reserve_ammo
	ammo_label.text = "AMMO: %d / %d" % [_ammo_in_mag, _reserve_ammo]


func _on_weapon_state_changed(state: String) -> void:
	var weapon_name: String = "NONE"
	if _active_weapon != null:
		weapon_name = _active_weapon.weapon_name
	weapon_label.text = "WEAPON: %s (%s)" % [weapon_name, state]


func _on_active_weapon_changed(next_weapon: WeaponBase) -> void:
	if next_weapon == null:
		return

	if _active_weapon != null:
		if _active_weapon.ammo_changed.is_connected(_on_ammo_changed):
			_active_weapon.ammo_changed.disconnect(_on_ammo_changed)
		if _active_weapon.weapon_state_changed.is_connected(_on_weapon_state_changed):
			_active_weapon.weapon_state_changed.disconnect(_on_weapon_state_changed)

	_active_weapon = next_weapon
	_active_weapon.ammo_changed.connect(_on_ammo_changed)
	_active_weapon.weapon_state_changed.connect(_on_weapon_state_changed)
	_on_ammo_changed(_active_weapon.ammo_in_mag, _active_weapon.reserve_ammo)
	_on_weapon_state_changed(_active_weapon.state)


func _on_debug_stats_changed(world_position: Vector3, speed: float) -> void:
	_debug_position = world_position
	_debug_speed = speed


func _on_score_changed(_player_id: int, _kills: int, _deaths: int) -> void:
	_refresh_score_label()


func _on_match_finished(winner_id: int) -> void:
	if match_label == null:
		return
	match_label.text = "P%d WINS" % winner_id


func _refresh_score_label() -> void:
	if score_label == null or _match_manager == null:
		return

	score_label.text = "SCORE: %s" % _match_manager.format_score_line()


func _ensure_optional_labels() -> void:
	var stats: VBoxContainer = $Stats
	if player_label == null:
		player_label = Label.new()
		player_label.name = "PlayerLabel"
		stats.add_child(player_label)
		stats.move_child(player_label, 0)
	if score_label == null:
		score_label = Label.new()
		score_label.name = "ScoreLabel"
		stats.add_child(score_label)
	if match_label == null:
		match_label = Label.new()
		match_label.name = "MatchLabel"
		stats.add_child(match_label)
	if network_label == null:
		network_label = Label.new()
		network_label.name = "NetworkLabel"
		stats.add_child(network_label)
	if ping_label == null:
		ping_label = Label.new()
		ping_label.name = "PingLabel"
		stats.add_child(ping_label)
