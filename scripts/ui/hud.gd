class_name HUD
extends Control

@export var hologram_lag_enabled: bool = true
@export_range(0.0, 40.0) var hologram_lag_amount: float = 0.018
@export_range(1.0, 30.0) var hologram_lag_smoothing: float = 10.0
@export_range(0.0, 20.0) var hologram_velocity_lag_amount: float = 0.15
@export_range(0.0, 12.0) var hologram_max_offset: float = 5.0

@onready var stats: VBoxContainer = get_node_or_null("Stats") as VBoxContainer
@onready var health_tag: Label = get_node_or_null("Stats/HealthRow/Tag") as Label
@onready var health_label: Label = get_node_or_null("Stats/HealthRow/HealthLabel") as Label
@onready var weapon_row: HBoxContainer = get_node_or_null("Stats/WeaponRow") as HBoxContainer
@onready var player_label: Label = get_node_or_null("Stats/PlayerRow/PlayerLabel") as Label
@onready var weapon_label: Label = get_node_or_null("Stats/WeaponRow/WeaponLabel") as Label
@onready var ammo_label: Label = get_node_or_null("Stats/AmmoRow/AmmoLabel") as Label
@onready var score_row: HBoxContainer = get_node_or_null("Stats/ScoreRow") as HBoxContainer
@onready var score_label: Label = get_node_or_null("Stats/ScoreRow/ScoreLabel") as Label
@onready var match_row: HBoxContainer = get_node_or_null("Stats/MatchRow") as HBoxContainer
@onready var match_label: Label = get_node_or_null("Stats/MatchRow/MatchLabel") as Label
@onready var network_row: HBoxContainer = get_node_or_null("Stats/NetworkRow") as HBoxContainer
@onready var network_label: Label = get_node_or_null("Stats/NetworkRow/NetworkLabel") as Label
@onready var ping_label: Label = get_node_or_null("Stats/PingRow/PingLabel") as Label
@onready var fps_row: HBoxContainer = get_node_or_null("Stats/FpsRow") as HBoxContainer
@onready var fps_label: Label = get_node_or_null("Stats/FpsRow/FpsLabel") as Label
@onready var position_row: HBoxContainer = get_node_or_null("Stats/PositionRow") as HBoxContainer
@onready var position_label: Label = get_node_or_null("Stats/PositionRow/PositionLabel") as Label
@onready var speed_row: HBoxContainer = get_node_or_null("Stats/SpeedRow") as HBoxContainer
@onready var speed_label: Label = get_node_or_null("Stats/SpeedRow/SpeedLabel") as Label
@onready var crosshair: Control = get_node_or_null("Crosshair") as Control
@onready var aim_dot: ColorRect = get_node_or_null("AimDot") as ColorRect
@onready var music_panel: Control = get_node_or_null("MusicPanel") as Control
@onready var music_cover: TextureRect = get_node_or_null("MusicPanel/Cover") as TextureRect
@onready var music_title_label: Label = get_node_or_null("MusicPanel/Metadata/TitleLabel") as Label
@onready var music_artist_label: Label = get_node_or_null("MusicPanel/Metadata/ArtistLabel") as Label
@onready var music_state_label: Label = get_node_or_null("MusicPanel/Metadata/StateLabel") as Label
@onready var interaction_hint: Label = get_node_or_null("InteractionHint") as Label

const STATS_DEFAULT_OFFSET: Vector2 = Vector2(54.0, 42.0)
const STATS_DEFAULT_SIZE: Vector2 = Vector2(276.0, 100.0)
const STATS_EXTREME_DEBUG_OFFSET: Vector2 = Vector2(104.0, 72.0)
const STATS_EXTREME_DEBUG_SIZE: Vector2 = Vector2(220.0, 100.0)
const MUSIC_PANEL_DEFAULT_TOP: float = 38.0
const MUSIC_PANEL_DEFAULT_RIGHT_INSET: float = 36.0
const MUSIC_PANEL_DEFAULT_WIDTH: float = 226.0
const MUSIC_PANEL_DEFAULT_HEIGHT: float = 40.0
const MUSIC_PANEL_EXTREME_DEBUG_TOP: float = 72.0
const MUSIC_PANEL_EXTREME_DEBUG_RIGHT_INSET: float = 86.0
const HEALTH_WARN_RATIO: float = 0.3

var _player: PlayerController
var _visual_director: PSXVisualDirector
var _active_weapon: WeaponBase
var _health: int = 100
var _max_health: int = 100
var _ammo_in_mag: int = 0
var _reserve_ammo: int = 0
var _debug_position: Vector3 = Vector3.ZERO
var _debug_speed: float = 0.0
var _debug_visible: bool = false
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
var _music_stereo: MusicStereo


func _ready() -> void:
	_ensure_optional_labels()
	_capture_stats_base_offsets()
	_apply_music_panel_layout(MUSIC_PANEL_DEFAULT_TOP, MUSIC_PANEL_DEFAULT_RIGHT_INSET)
	set_debug_visible(_debug_visible)
	if music_panel != null:
		music_panel.visible = false
	if interaction_hint != null:
		interaction_hint.visible = false
	if aim_dot != null:
		aim_dot.visible = false


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
		match_label.text = "PRIMERO A %d BAJAS" % _match_manager.score_limit


func bind_music_stereo(music_stereo: MusicStereo) -> void:
	if music_stereo == null:
		return

	if _music_stereo != null:
		if _music_stereo.track_changed.is_connected(_on_music_track_changed):
			_music_stereo.track_changed.disconnect(_on_music_track_changed)
		if _music_stereo.proximity_changed.is_connected(_on_music_proximity_changed):
			_music_stereo.proximity_changed.disconnect(_on_music_proximity_changed)
		if _music_stereo.interaction_hint_changed.is_connected(_on_music_interaction_hint_changed):
			_music_stereo.interaction_hint_changed.disconnect(_on_music_interaction_hint_changed)

	_music_stereo = music_stereo
	_music_stereo.track_changed.connect(_on_music_track_changed)
	_music_stereo.proximity_changed.connect(_on_music_proximity_changed)
	_music_stereo.interaction_hint_changed.connect(_on_music_interaction_hint_changed)
	_on_music_track_changed(
		_music_stereo.get_current_title(),
		_music_stereo.get_current_artist(),
		_music_stereo.get_current_cover(),
		_music_stereo.is_playing()
	)


func _process(delta: float) -> void:
	# Las filas de debug solo se actualizan cuando estan visibles.
	if _debug_visible:
		if fps_label != null:
			fps_label.text = "%d FPS" % Engine.get_frames_per_second()
		if position_label != null:
			position_label.text = "%.1f, %.1f, %.1f" % [_debug_position.x, _debug_position.y, _debug_position.z]
		if speed_label != null:
			speed_label.text = "%.1f u/s" % _debug_speed
	if crosshair != null and _crosshair_enabled:
		if not crosshair.visible:
			crosshair.visible = true
		if crosshair.has_method("set_aiming"):
			crosshair.call("set_aiming", _active_weapon != null and _active_weapon.is_aiming)
	_update_hologram_lag(delta)


func set_debug_visible(value: bool) -> void:
	_debug_visible = value
	if weapon_row != null:
		weapon_row.visible = value
	if score_row != null:
		score_row.visible = value
	if match_row != null:
		match_row.visible = value
	if network_row != null:
		network_row.visible = value
	if fps_row != null:
		fps_row.visible = value
	if position_row != null:
		position_row.visible = value
	if speed_row != null:
		speed_row.visible = value


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
	network_label.text = status.to_upper()


func set_network_stats(status: String, ping_ms: int, peer_count: int) -> void:
	set_network_status(status)
	if ping_label == null:
		return

	var ping_text: String = "LOCAL" if ping_ms < 0 else "%d MS" % ping_ms
	var display_players: int = maxi(peer_count, 1)
	var player_text: String = "JUGADOR" if display_players == 1 else "JUGADORES"
	ping_label.text = "%s  ·  %d %s" % [ping_text, display_players, player_text]


func _on_health_changed(current_health: int, max_health: int) -> void:
	_health = current_health
	_max_health = max_health
	if health_label != null:
		health_label.text = "%d / %d" % [_health, _max_health]
	_update_health_tint()


func _on_ammo_changed(ammo_in_mag: int, reserve_ammo: int) -> void:
	_ammo_in_mag = ammo_in_mag
	_reserve_ammo = reserve_ammo
	if ammo_label != null:
		ammo_label.text = "%d / %d" % [_ammo_in_mag, _reserve_ammo]


func _on_weapon_state_changed(state: String) -> void:
	var weapon_name: String = "NONE"
	if _active_weapon != null:
		weapon_name = _active_weapon.weapon_name
	if weapon_label != null:
		weapon_label.text = "%s · %s" % [weapon_name, state]


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
	match_label.text = "P%d GANA" % winner_id


func _refresh_score_label() -> void:
	if score_label == null or _match_manager == null:
		return

	score_label.text = _match_manager.format_score_line()


func _on_lens_preset_changed(preset: PSXVisualDirector.LensPreset) -> void:
	_apply_lens_safe_layout(preset)


func _on_music_track_changed(title: String, artist: String, cover: Texture2D, is_playing: bool) -> void:
	if music_panel != null:
		music_panel.visible = is_playing
	if music_cover != null:
		music_cover.texture = cover
	if music_title_label != null:
		music_title_label.text = title.to_upper()
	if music_artist_label != null:
		music_artist_label.text = artist.to_upper()
	if music_state_label != null:
		music_state_label.text = "REPRODUCIENDO" if is_playing else "PAUSADO"


func _on_music_proximity_changed(_is_near: bool) -> void:
	if music_state_label == null or _music_stereo == null:
		return

	music_state_label.text = "REPRODUCIENDO" if _music_stereo.is_playing() else "PAUSADO"


func _on_music_interaction_hint_changed(text: String, is_visible: bool) -> void:
	if interaction_hint == null:
		return

	interaction_hint.text = text
	interaction_hint.visible = is_visible


func _apply_lens_safe_layout(preset: PSXVisualDirector.LensPreset) -> void:
	if stats != null:
		if preset == PSXVisualDirector.LensPreset.EXTREME_DEBUG:
			stats.set_anchors_preset(Control.PRESET_TOP_LEFT)
			_set_stats_base_offsets(
				STATS_EXTREME_DEBUG_OFFSET.x,
				STATS_EXTREME_DEBUG_OFFSET.y,
				STATS_EXTREME_DEBUG_OFFSET.x + STATS_EXTREME_DEBUG_SIZE.x,
				STATS_EXTREME_DEBUG_OFFSET.y + STATS_EXTREME_DEBUG_SIZE.y
			)
		else:
			stats.set_anchors_preset(Control.PRESET_TOP_LEFT)
			_set_stats_base_offsets(
				STATS_DEFAULT_OFFSET.x,
				STATS_DEFAULT_OFFSET.y,
				STATS_DEFAULT_OFFSET.x + STATS_DEFAULT_SIZE.x,
				STATS_DEFAULT_OFFSET.y + STATS_DEFAULT_SIZE.y
			)

	if preset == PSXVisualDirector.LensPreset.EXTREME_DEBUG:
		_apply_music_panel_layout(MUSIC_PANEL_EXTREME_DEBUG_TOP, MUSIC_PANEL_EXTREME_DEBUG_RIGHT_INSET)
	else:
		_apply_music_panel_layout(MUSIC_PANEL_DEFAULT_TOP, MUSIC_PANEL_DEFAULT_RIGHT_INSET)


func _apply_music_panel_layout(top: float, right_inset: float) -> void:
	if music_panel == null:
		return

	music_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	music_panel.offset_top = top
	music_panel.offset_bottom = top + MUSIC_PANEL_DEFAULT_HEIGHT
	music_panel.offset_right = -right_inset
	music_panel.offset_left = -(right_inset + MUSIC_PANEL_DEFAULT_WIDTH)


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
		var player_row_data: Dictionary = HudIcons.make_stat_row("PlayerRow", "PlayerLabel", HudIcons.PLAYER)
		stats.add_child(player_row_data["row"])
		stats.move_child(player_row_data["row"], 0)
		player_label = player_row_data["label"] as Label
	if score_label == null:
		var score_row_data: Dictionary = HudIcons.make_stat_row("ScoreRow", "ScoreLabel", HudIcons.SCORE)
		score_row = score_row_data["row"] as HBoxContainer
		stats.add_child(score_row)
		score_label = score_row_data["label"] as Label
	if match_label == null:
		var match_row_data: Dictionary = HudIcons.make_stat_row("MatchRow", "MatchLabel", HudIcons.MATCH)
		match_row = match_row_data["row"] as HBoxContainer
		stats.add_child(match_row)
		match_label = match_row_data["label"] as Label
	if network_label == null:
		var network_row_data: Dictionary = HudIcons.make_stat_row("NetworkRow", "NetworkLabel", HudIcons.NETWORK)
		network_row = network_row_data["row"] as HBoxContainer
		stats.add_child(network_row)
		network_label = network_row_data["label"] as Label
	if ping_label == null:
		var ping_row_data: Dictionary = HudIcons.make_stat_row("PingRow", "PingLabel", HudIcons.PING)
		stats.add_child(ping_row_data["row"])
		ping_label = ping_row_data["label"] as Label


func _update_health_tint() -> void:
	if health_tag == null or _max_health <= 0:
		return

	var health_ratio: float = float(_health) / float(_max_health)
	health_tag.modulate = HudIcons.HUD_WARN_TINT if health_ratio <= HEALTH_WARN_RATIO else HudIcons.HUD_TAG_TINT
	if health_label != null:
		health_label.modulate = HudIcons.HUD_WARN_TINT if health_ratio <= HEALTH_WARN_RATIO else HudIcons.HUD_TINT
