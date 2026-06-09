class_name HUD
extends Control

@export var hologram_lag_enabled: bool = true
@export_range(0.0, 40.0) var hologram_lag_amount: float = 0.018
@export_range(1.0, 30.0) var hologram_lag_smoothing: float = 10.0
@export_range(0.0, 20.0) var hologram_velocity_lag_amount: float = 0.15
@export_range(0.0, 12.0) var hologram_max_offset: float = 5.0

@onready var stats: VBoxContainer = get_node_or_null("Stats") as VBoxContainer
@onready var health_label: Label = get_node_or_null("Stats/HealthLabel") as Label
@onready var player_label: Label = get_node_or_null("Stats/PlayerLabel") as Label
@onready var weapon_label: Label = get_node_or_null("Stats/WeaponLabel") as Label
@onready var ammo_label: Label = get_node_or_null("Stats/AmmoLabel") as Label
@onready var score_label: Label = get_node_or_null("Stats/ScoreLabel") as Label
@onready var match_label: Label = get_node_or_null("Stats/MatchLabel") as Label
@onready var network_label: Label = get_node_or_null("Stats/NetworkLabel") as Label
@onready var ping_label: Label = get_node_or_null("Stats/PingLabel") as Label
@onready var fps_label: Label = get_node_or_null("Stats/FpsLabel") as Label
@onready var position_label: Label = get_node_or_null("Stats/PositionLabel") as Label
@onready var speed_label: Label = get_node_or_null("Stats/SpeedLabel") as Label
@onready var crosshair: Control = get_node_or_null("Crosshair") as Control
@onready var aim_dot: ColorRect = get_node_or_null("AimDot") as ColorRect

const STATS_DEFAULT_OFFSET: Vector2 = Vector2(54.0, 42.0)
const STATS_DEFAULT_SIZE: Vector2 = Vector2(200.0, 100.0)
const STATS_EXTREME_DEBUG_OFFSET: Vector2 = Vector2(104.0, 72.0)
const STATS_EXTREME_DEBUG_SIZE: Vector2 = Vector2(200.0, 100.0)

var _player: PlayerController
var _visual_director: PSXVisualDirector
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
var _stats_lag_offset: Vector2 = Vector2.ZERO
var _stats_target_lag_offset: Vector2 = Vector2.ZERO
var _stats_base_offset_left: float = STATS_DEFAULT_OFFSET.x
var _stats_base_offset_top: float = STATS_DEFAULT_OFFSET.y
var _stats_base_offset_right: float = STATS_DEFAULT_OFFSET.x + STATS_DEFAULT_SIZE.x
var _stats_base_offset_bottom: float = STATS_DEFAULT_OFFSET.y + STATS_DEFAULT_SIZE.y
var _hologram_motion_sample_age: float = 999.0


func _ready() -> void:
	_ensure_optional_labels()
	_capture_stats_base_offsets()
	set_debug_visible(_debug_visible)


func bind_player(player: PlayerController) -> void:
	if player == null:
		push_error("HUD cannot bind a null player.")
		return

	if _player != null and _player.local_view_motion_changed.is_connected(_on_local_view_motion_changed):
		_player.local_view_motion_changed.disconnect(_on_local_view_motion_changed)

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
	if not player.local_view_motion_changed.is_connected(_on_local_view_motion_changed):
		player.local_view_motion_changed.connect(_on_local_view_motion_changed)
	_on_active_weapon_changed(player.weapon)

	if _active_weapon == null:
		_on_ammo_changed(0, 0)
		_on_weapon_state_changed("NoWeapon")
		_on_health_changed(player.health.current_health, player.health.max_health)
		return

	_on_health_changed(player.health.current_health, player.health.max_health)
	_on_ammo_changed(_active_weapon.ammo_in_mag, _active_weapon.reserve_ammo)
	_on_weapon_state_changed(_active_weapon.state)


func bind_visual_director(visual_director: PSXVisualDirector) -> void:
	if visual_director == null:
		return

	if _visual_director != null and _visual_director.lens_preset_changed.is_connected(_on_lens_preset_changed):
		_visual_director.lens_preset_changed.disconnect(_on_lens_preset_changed)

	_visual_director = visual_director
	if not _visual_director.lens_preset_changed.is_connected(_on_lens_preset_changed):
		_visual_director.lens_preset_changed.connect(_on_lens_preset_changed)
	_apply_lens_safe_layout(_visual_director.lens_preset)


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


func _process(delta: float) -> void:
	if fps_label != null:
		fps_label.text = "DEBUG FPS: %d" % Engine.get_frames_per_second()
	if position_label != null:
		position_label.text = "DEBUG POS: %.1f, %.1f, %.1f" % [_debug_position.x, _debug_position.y, _debug_position.z]
	if speed_label != null:
		speed_label.text = "DEBUG SPEED: %.1f" % _debug_speed
	var is_aiming: bool = _active_weapon != null and _active_weapon.is_aiming
	if crosshair != null:
		crosshair.visible = _crosshair_enabled
		if crosshair.has_method("set_aiming"):
			crosshair.call("set_aiming", is_aiming)
	if aim_dot != null:
		aim_dot.visible = false
	_update_hologram_lag(delta)


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
	if health_label != null:
		health_label.text = "HEALTH: %d / %d" % [_health, _max_health]


func _on_ammo_changed(ammo_in_mag: int, reserve_ammo: int) -> void:
	_ammo_in_mag = ammo_in_mag
	_reserve_ammo = reserve_ammo
	if ammo_label != null:
		ammo_label.text = "AMMO: %d / %d" % [_ammo_in_mag, _reserve_ammo]


func _on_weapon_state_changed(state: String) -> void:
	var weapon_name: String = "NONE"
	if _active_weapon != null:
		weapon_name = _active_weapon.weapon_name
	if weapon_label != null:
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


func _on_lens_preset_changed(preset: PSXVisualDirector.LensPreset) -> void:
	_apply_lens_safe_layout(preset)


func _apply_lens_safe_layout(preset: PSXVisualDirector.LensPreset) -> void:
	if stats == null:
		return

	if preset == PSXVisualDirector.LensPreset.EXTREME_DEBUG:
		stats.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_set_stats_base_offsets(
			STATS_EXTREME_DEBUG_OFFSET.x,
			STATS_EXTREME_DEBUG_OFFSET.y,
			STATS_EXTREME_DEBUG_OFFSET.x + STATS_EXTREME_DEBUG_SIZE.x,
			STATS_EXTREME_DEBUG_OFFSET.y + STATS_EXTREME_DEBUG_SIZE.y
		)
		return

	stats.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_set_stats_base_offsets(
		STATS_DEFAULT_OFFSET.x,
		STATS_DEFAULT_OFFSET.y,
		STATS_DEFAULT_OFFSET.x + STATS_DEFAULT_SIZE.x,
		STATS_DEFAULT_OFFSET.y + STATS_DEFAULT_SIZE.y
	)


func _capture_stats_base_offsets() -> void:
	if stats == null:
		return

	_stats_base_offset_left = stats.offset_left
	_stats_base_offset_top = stats.offset_top
	_stats_base_offset_right = stats.offset_right
	_stats_base_offset_bottom = stats.offset_bottom


func _set_stats_base_offsets(left: float, top: float, right: float, bottom: float) -> void:
	_stats_base_offset_left = left
	_stats_base_offset_top = top
	_stats_base_offset_right = right
	_stats_base_offset_bottom = bottom
	_apply_stats_lag_offset()


func _on_local_view_motion_changed(view_delta: Vector2, local_velocity: Vector2) -> void:
	_hologram_motion_sample_age = 0.0
	if not hologram_lag_enabled:
		_stats_target_lag_offset = Vector2.ZERO
		return

	var target_offset: Vector2 = -view_delta * hologram_lag_amount
	target_offset += local_velocity * hologram_velocity_lag_amount
	if target_offset.length() > hologram_max_offset:
		target_offset = target_offset.normalized() * hologram_max_offset
	_stats_target_lag_offset = target_offset


func _update_hologram_lag(delta: float) -> void:
	if stats == null:
		return

	_hologram_motion_sample_age += delta
	var target_offset: Vector2 = _stats_target_lag_offset
	if not hologram_lag_enabled or _hologram_motion_sample_age > 0.15:
		target_offset = Vector2.ZERO

	var smoothing_weight: float = 1.0 - exp(-hologram_lag_smoothing * delta)
	_stats_lag_offset = _stats_lag_offset.lerp(target_offset, smoothing_weight)
	_apply_stats_lag_offset()


func _apply_stats_lag_offset() -> void:
	if stats == null:
		return

	stats.offset_left = _stats_base_offset_left + _stats_lag_offset.x
	stats.offset_top = _stats_base_offset_top + _stats_lag_offset.y
	stats.offset_right = _stats_base_offset_right + _stats_lag_offset.x
	stats.offset_bottom = _stats_base_offset_bottom + _stats_lag_offset.y


func _ensure_optional_labels() -> void:
	if stats == null:
		return

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
