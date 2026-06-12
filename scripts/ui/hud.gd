class_name HUD
extends Control

const PlayerSettingsAccess = preload("res://scripts/game/player_settings_access.gd")

@export var hud_motion_enabled: bool = true
@export_range(0.0, 16.0) var hud_move_sway_px: float = 7.0
@export_range(0.0, 2.0) var hud_look_sway_px: float = 0.55
@export_range(1.0, 30.0) var hud_motion_smoothing: float = 15.0
@export_range(2.0, 18.0) var hud_max_offset_px: float = 9.5

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
@onready var pickup_interaction_panel: Control = get_node_or_null("PickupInteractionPanel") as Control
@onready var pickup_interaction_label: Label = get_node_or_null("PickupInteractionPanel/PromptLabel") as Label
@onready var pickup_interaction_track: ColorRect = get_node_or_null("PickupInteractionPanel/Track") as ColorRect
@onready var pickup_interaction_fill: ColorRect = get_node_or_null("PickupInteractionPanel/Track/Fill") as ColorRect
@onready var music_panel: Control = get_node_or_null("MusicPanel") as Control
@onready var music_cover: TextureRect = get_node_or_null("MusicPanel/Cover") as TextureRect
@onready var music_title_label: Label = get_node_or_null("MusicPanel/Metadata/TitleLabel") as Label
@onready var music_artist_label: Label = get_node_or_null("MusicPanel/Metadata/ArtistLabel") as Label
@onready var music_state_label: Label = get_node_or_null("MusicPanel/Metadata/StateLabel") as Label
@onready var interaction_hint: Label = get_node_or_null("InteractionHint") as Label
@onready var match_objective: Label = get_node_or_null("MatchObjective") as Label
@onready var match_objective_sub: Label = get_node_or_null("MatchObjectiveSub") as Label
@onready var scoreboard_panel: Control = get_node_or_null("ScoreboardPanel") as Control
@onready var scoreboard_title: Label = get_node_or_null("ScoreboardPanel/ScoreboardTitle") as Label
@onready var scoreboard_label: Label = get_node_or_null("ScoreboardPanel/ScoreboardLabel") as Label
@onready var kill_feed_panel: VBoxContainer = get_node_or_null("KillFeedPanel") as VBoxContainer

const STATS_DEFAULT_OFFSET: Vector2 = Vector2(58.0, 44.0)
const STATS_DEFAULT_SIZE: Vector2 = Vector2(276.0, 100.0)
const STATS_EXTREME_DEBUG_OFFSET: Vector2 = Vector2(88.0, 58.0)
const STATS_EXTREME_DEBUG_SIZE: Vector2 = Vector2(220.0, 100.0)
const STATS_ULTRA_LOW_OFFSET: Vector2 = Vector2(12.0, 22.0)
const STATS_ULTRA_LOW_SIZE: Vector2 = Vector2(210.0, 84.0)
const MUSIC_PANEL_DEFAULT_TOP: float = 36.0
const MUSIC_PANEL_DEFAULT_RIGHT_INSET: float = 54.0
const MUSIC_PANEL_DEFAULT_WIDTH: float = 226.0
const MUSIC_PANEL_DEFAULT_HEIGHT: float = 40.0
const MUSIC_PANEL_EXTREME_DEBUG_TOP: float = 50.0
const MUSIC_PANEL_EXTREME_DEBUG_RIGHT_INSET: float = 76.0
const MUSIC_PANEL_ULTRA_LOW_TOP: float = 24.0
const MUSIC_PANEL_ULTRA_LOW_RIGHT_INSET: float = 8.0
const SCOREBOARD_DEFAULT_OFFSETS: Vector4 = Vector4(-238.0, -112.0, -54.0, -42.0)
const SCOREBOARD_ULTRA_LOW_OFFSETS: Vector4 = Vector4(-122.0, -76.0, -8.0, -20.0)
const KILL_FEED_DEFAULT_OFFSETS: Vector4 = Vector4(58.0, -132.0, 334.0, -16.0)
const KILL_FEED_ULTRA_LOW_OFFSETS: Vector4 = Vector4(12.0, -76.0, 210.0, -8.0)
const MATCH_OBJECTIVE_DEFAULT_OFFSETS: Vector4 = Vector4(-120.0, 18.0, 120.0, 40.0)
const MATCH_OBJECTIVE_ULTRA_LOW_OFFSETS: Vector4 = Vector4(-90.0, 6.0, 90.0, 24.0)
const MATCH_OBJECTIVE_SUB_DEFAULT_OFFSETS: Vector4 = Vector4(-120.0, 38.0, 120.0, 52.0)
const MATCH_OBJECTIVE_SUB_ULTRA_LOW_OFFSETS: Vector4 = Vector4(-90.0, 22.0, 90.0, 34.0)
const INTERACTION_HINT_DEFAULT_OFFSETS: Vector4 = Vector4(-92.0, 28.0, 92.0, 44.0)
const INTERACTION_HINT_ULTRA_LOW_OFFSETS: Vector4 = Vector4(-74.0, 20.0, 74.0, 34.0)
const PICKUP_PANEL_SIZE: Vector2 = Vector2(174.0, 31.0)
const PICKUP_PANEL_TOP_OFFSET: float = 28.0
const PICKUP_BAR_SIZE: Vector2 = Vector2(150.0, 5.0)
const DEFAULT_PANEL_SCALE: Vector2 = Vector2(0.68, 0.68)
const ULTRA_LOW_PANEL_SCALE: Vector2 = Vector2(0.48, 0.48)
const DEFAULT_MUSIC_SCALE: Vector2 = Vector2.ONE
const ULTRA_LOW_MUSIC_SCALE: Vector2 = Vector2(0.62, 0.62)
const DEFAULT_CENTER_TEXT_SCALE: Vector2 = Vector2.ONE
const ULTRA_LOW_CENTER_TEXT_SCALE: Vector2 = Vector2(0.72, 0.72)
const HEALTH_WARN_RATIO: float = 0.3
const DEBUG_LABEL_REFRESH_INTERVAL: float = 0.20

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
var _hud_motion_offset: Vector2 = Vector2.ZERO
var _stats_base_offsets: Vector4 = Vector4(
	STATS_DEFAULT_OFFSET.x,
	STATS_DEFAULT_OFFSET.y,
	STATS_DEFAULT_OFFSET.x + STATS_DEFAULT_SIZE.x,
	STATS_DEFAULT_OFFSET.y + STATS_DEFAULT_SIZE.y
)
var _music_base_offsets: Vector4 = Vector4.ZERO
var _scoreboard_base_offsets: Vector4 = Vector4.ZERO
var _music_stereo: MusicStereo
var _kill_feed_entries: Array[Control] = []
var _debug_refresh_timer: float = 0.0
var _crosshair_supports_set_aiming: bool = false
var _last_crosshair_aiming: bool = false
var _performance_profile: int = 0
const MAX_KILL_FEED_ENTRIES: int = 5
const KILL_FEED_LIFETIME: float = 4.0


func _ready() -> void:
	process_priority = 1
	_ensure_optional_labels()
	_ensure_pickup_interaction_widgets()
	_capture_hud_base_offsets()
	resized.connect(_center_crosshair)
	call_deferred("_center_crosshair")
	_apply_music_panel_layout(MUSIC_PANEL_DEFAULT_TOP, MUSIC_PANEL_DEFAULT_RIGHT_INSET)
	set_debug_visible(_debug_visible)
	_update_fps_label()
	if music_panel != null:
		music_panel.visible = false
	if scoreboard_panel != null:
		scoreboard_panel.visible = false
	if interaction_hint != null:
		interaction_hint.visible = false
	if aim_dot != null:
		aim_dot.visible = false
	if pickup_interaction_panel != null:
		pickup_interaction_panel.visible = false
	apply_accent_theme()
	_cache_crosshair_capabilities()
	if PlayerSettingsAccess.has_settings():
		PlayerSettingsAccess.connect_settings_changed(apply_accent_theme)
		PlayerSettingsAccess.connect_performance_profile_changed(_on_performance_profile_changed)
		apply_performance_profile(PlayerSettingsAccess.get_performance_profile())


func apply_accent_theme() -> void:
	var accent: Color = HudIcons.get_tag_tint()
	_tint_stat_tags(accent)
	if match_objective != null:
		match_objective.modulate = accent
	if scoreboard_title != null:
		scoreboard_title.modulate = accent
	if scoreboard_label != null:
		scoreboard_label.modulate = HudIcons.HUD_TINT
	if interaction_hint != null:
		interaction_hint.modulate = accent
	if aim_dot != null:
		aim_dot.color = Color(accent.r, accent.g, accent.b, 0.9)
	if pickup_interaction_label != null:
		pickup_interaction_label.modulate = accent
	if pickup_interaction_fill != null:
		pickup_interaction_fill.color = Color(accent.r, accent.g, accent.b, 0.95)
	if music_state_label != null:
		music_state_label.modulate = accent
	_update_health_tint()


func reset_motion() -> void:
	_hud_motion_offset = Vector2.ZERO
	_apply_hud_motion()


func apply_performance_profile(profile: int) -> void:
	_performance_profile = clampi(profile, 0, 2)
	_apply_lens_safe_layout(_visual_director.lens_preset if _visual_director != null else PSXVisualDirector.LensPreset.PSX_8MM)
	_apply_hud_motion()


func _tint_stat_tags(accent: Color) -> void:
	if stats == null:
		return
	for row in stats.get_children():
		if not (row is HBoxContainer):
			continue
		var tag: Label = row.get_node_or_null("Tag") as Label
		if tag != null:
			tag.modulate = accent


func bind_player(player: PlayerController) -> void:
	if player == null:
		push_error("HUD cannot bind a null player.")
		return

	_player = player
	process_priority = maxi(player.process_priority + 1, 1)
	_local_player_id = player.player_id
	if player_label != null:
		player_label.text = "%s  P%d" % [player.display_name.to_upper(), player.player_id]
	if player.health == null:
		push_error("HUD cannot bind because the player has no health component.")
		return

	player.health.health_changed.connect(_on_health_changed)
	player.debug_stats_changed.connect(_on_debug_stats_changed)
	player.active_weapon_changed.connect(_on_active_weapon_changed)
	if not player.pickup_interaction_changed.is_connected(_on_pickup_interaction_changed):
		player.pickup_interaction_changed.connect(_on_pickup_interaction_changed)
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
	if not _match_manager.time_changed.is_connected(_on_match_time_changed):
		_match_manager.time_changed.connect(_on_match_time_changed)
	if not _match_manager.kill_feed_event.is_connected(_on_kill_feed_event):
		_match_manager.kill_feed_event.connect(_on_kill_feed_event)
	if not _match_manager.match_started.is_connected(_on_match_started):
		_match_manager.match_started.connect(_on_match_started)
	_set_match_widgets_visible(_match_manager.match_running)
	_refresh_score_label()
	_refresh_match_objective()
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
	_debug_refresh_timer += delta
	if _debug_refresh_timer >= DEBUG_LABEL_REFRESH_INTERVAL:
		_debug_refresh_timer = 0.0
		_update_fps_label()
		if _debug_visible:
			_update_debug_labels()
	if crosshair != null and _crosshair_enabled:
		if not crosshair.visible:
			crosshair.visible = true
		var is_aiming_now: bool = _active_weapon != null and _active_weapon.is_aiming
		if _crosshair_supports_set_aiming and is_aiming_now != _last_crosshair_aiming:
			_last_crosshair_aiming = is_aiming_now
			crosshair.call("set_aiming", is_aiming_now)
	_update_hud_motion(delta)


func set_debug_visible(value: bool) -> void:
	_debug_visible = value
	_debug_refresh_timer = DEBUG_LABEL_REFRESH_INTERVAL
	if weapon_row != null:
		weapon_row.visible = value
	if score_row != null:
		score_row.visible = value
	if match_row != null:
		match_row.visible = value
	if network_row != null:
		network_row.visible = value
	if fps_row != null:
		fps_row.visible = true
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
	_refresh_match_objective()


func set_crosshair_style(index: int) -> void:
	if crosshair == null:
		return
	if crosshair.has_method("set_crosshair_index"):
		crosshair.call("set_crosshair_index", index)
	elif crosshair.has_method("set_crosshair_index"):
		crosshair.call("set_crosshair_index", index)


func rebuild_crosshair(use_sprite: bool, crosshair_index: int) -> void:
	if crosshair != null:
		crosshair.queue_free()
		crosshair = null

	var crosshair_script: Script
	if use_sprite and crosshair_index >= 0:
		crosshair_script = preload("res://scripts/ui/sprite_crosshair.gd")
	else:
		crosshair_script = preload("res://scripts/ui/circular_crosshair.gd")

	crosshair = Control.new()
	crosshair.name = "Crosshair"
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.offset_left = -16.0
	crosshair.offset_top = -16.0
	crosshair.offset_right = 16.0
	crosshair.offset_bottom = 16.0
	crosshair.set_script(crosshair_script)
	add_child(crosshair)
	_cache_crosshair_capabilities()
	call_deferred("_center_crosshair")
	if use_sprite and crosshair.has_method("set_crosshair_index"):
		crosshair.call("set_crosshair_index", crosshair_index)
	set_crosshair_enabled(_crosshair_enabled)


func _cache_crosshair_capabilities() -> void:
	_crosshair_supports_set_aiming = crosshair != null and crosshair.has_method("set_aiming")
	_last_crosshair_aiming = false
	if _crosshair_supports_set_aiming:
		crosshair.call("set_aiming", false)


func _update_fps_label() -> void:
	if fps_label != null:
		fps_label.text = "%d FPS" % Engine.get_frames_per_second()


func _update_debug_labels() -> void:
	if position_label != null:
		position_label.text = "%.1f, %.1f, %.1f" % [_debug_position.x, _debug_position.y, _debug_position.z]
	if speed_label != null:
		speed_label.text = "%.1f u/s" % _debug_speed


func _center_crosshair() -> void:
	if crosshair == null:
		return

	var crosshair_size: Vector2 = crosshair.custom_minimum_size
	if crosshair_size.x <= 0.0 or crosshair_size.y <= 0.0:
		crosshair_size = crosshair.size
	if crosshair_size.x <= 0.0 or crosshair_size.y <= 0.0:
		crosshair_size = Vector2(32.0, 32.0)

	crosshair.set_anchors_preset(Control.PRESET_CENTER, false)
	crosshair.offset_left = -crosshair_size.x * 0.5
	crosshair.offset_top = -crosshair_size.y * 0.5
	crosshair.offset_right = crosshair_size.x * 0.5
	crosshair.offset_bottom = crosshair_size.y * 0.5
	_position_pickup_interaction_panel(crosshair_size)


func _position_pickup_interaction_panel(crosshair_size: Vector2 = Vector2(32.0, 32.0)) -> void:
	if pickup_interaction_panel == null:
		return

	pickup_interaction_panel.set_anchors_preset(Control.PRESET_CENTER, false)
	pickup_interaction_panel.offset_left = -PICKUP_PANEL_SIZE.x * 0.5
	pickup_interaction_panel.offset_top = crosshair_size.y * 0.5 + PICKUP_PANEL_TOP_OFFSET
	pickup_interaction_panel.offset_right = PICKUP_PANEL_SIZE.x * 0.5
	pickup_interaction_panel.offset_bottom = pickup_interaction_panel.offset_top + PICKUP_PANEL_SIZE.y


func _on_match_started() -> void:
	_set_match_widgets_visible(true)
	_refresh_match_objective()


func _on_match_finished(_winner_id: int) -> void:
	_set_match_widgets_visible(false)


func _set_match_widgets_visible(is_visible: bool) -> void:
	if match_objective != null:
		match_objective.visible = is_visible
	if match_objective_sub != null:
		match_objective_sub.visible = is_visible
	if scoreboard_panel != null:
		scoreboard_panel.visible = is_visible
	if match_label != null:
		match_label.visible = is_visible


func _on_match_time_changed(_remaining_seconds: float) -> void:
	_refresh_match_objective()


func _on_kill_feed_event(killer_name: String, victim_name: String, killer_id: int, _victim_id: int) -> void:
	add_kill_feed_entry(killer_name, victim_name, killer_id)


func add_kill_feed_entry(killer_name: String, victim_name: String, killer_id: int = 0) -> void:
	if kill_feed_panel == null:
		return

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)

	var tag := Label.new()
	tag.custom_minimum_size = Vector2(72.0, 16.0)
	tag.text = "KILL"
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tag.add_theme_font_size_override("font_size", 14)
	tag.modulate = HudIcons.get_tag_tint()

	var entry := Label.new()
	entry.text = "%s → %s" % [killer_name.to_upper(), victim_name.to_upper()]
	entry.add_theme_font_size_override("font_size", 14)
	entry.modulate = HudIcons.get_accent_color() if killer_id == _local_player_id else HudIcons.HUD_TINT

	row.add_child(tag)
	row.add_child(entry)
	kill_feed_panel.add_child(row)
	_kill_feed_entries.append(row)

	while _kill_feed_entries.size() > MAX_KILL_FEED_ENTRIES:
		var oldest: Control = _kill_feed_entries.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()

	var tween := create_tween()
	tween.tween_interval(KILL_FEED_LIFETIME)
	tween.tween_property(row, "modulate:a", 0.0, 0.35)
	tween.tween_callback(func() -> void:
		if is_instance_valid(row):
			_kill_feed_entries.erase(row)
			row.queue_free()
	)


func _refresh_match_objective() -> void:
	if _match_manager == null:
		return
	if match_objective == null:
		return

	match _match_manager.win_mode:
		MatchManager.WinMode.TIME_LIMIT:
			match_objective.text = _match_manager.format_time_remaining()
			if match_objective_sub != null:
				match_objective_sub.text = ""
		MatchManager.WinMode.PRACTICE:
			match_objective.text = "PRÁCTICA"
			if match_objective_sub != null:
				match_objective_sub.text = ""
		_:
			match_objective.text = "PRIMERO A %d" % _match_manager.score_limit
			if match_objective_sub != null:
				match_objective_sub.text = ""
	_refresh_scoreboard()


func _refresh_score_label() -> void:
	if score_label == null or _match_manager == null:
		return

	score_label.text = _match_manager.format_score_line()
	_refresh_scoreboard()


func _refresh_scoreboard() -> void:
	if scoreboard_label == null or _match_manager == null:
		return

	var player_ids: Array = _match_manager.scores.keys()
	player_ids.sort()
	var parts: Array[String] = []
	for raw_player_id in player_ids:
		var player_id: int = int(raw_player_id)
		var player_name: String = _match_manager.get_player_name(player_id).strip_edges()
		if player_name.is_empty():
			player_name = "P%d" % player_id
		var prefix: String = ">" if player_id == _local_player_id else " "
		parts.append("%s %s  %d" % [prefix, player_name.to_upper(), _match_manager.get_kills(player_id)])
	scoreboard_label.text = "\n".join(parts)


func _on_lens_preset_changed(preset: PSXVisualDirector.LensPreset) -> void:
	_apply_lens_safe_layout(preset)


func _on_performance_profile_changed(profile: int) -> void:
	apply_performance_profile(profile)


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
	var use_ultra_low_layout := _is_ultra_low_hud()
	if stats != null:
		if use_ultra_low_layout:
			stats.set_anchors_preset(Control.PRESET_TOP_LEFT)
			_set_stats_base_offsets(
				STATS_ULTRA_LOW_OFFSET.x,
				STATS_ULTRA_LOW_OFFSET.y,
				STATS_ULTRA_LOW_OFFSET.x + STATS_ULTRA_LOW_SIZE.x,
				STATS_ULTRA_LOW_OFFSET.y + STATS_ULTRA_LOW_SIZE.y
			)
		elif preset == PSXVisualDirector.LensPreset.EXTREME_DEBUG:
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

	if use_ultra_low_layout:
		_apply_music_panel_layout(MUSIC_PANEL_ULTRA_LOW_TOP, MUSIC_PANEL_ULTRA_LOW_RIGHT_INSET)
	elif preset == PSXVisualDirector.LensPreset.EXTREME_DEBUG:
		_apply_music_panel_layout(MUSIC_PANEL_EXTREME_DEBUG_TOP, MUSIC_PANEL_EXTREME_DEBUG_RIGHT_INSET)
	else:
		_apply_music_panel_layout(MUSIC_PANEL_DEFAULT_TOP, MUSIC_PANEL_DEFAULT_RIGHT_INSET)

	_apply_hud_profile_static_offsets()
	_apply_hud_profile_scale()


func _is_ultra_low_hud() -> bool:
	return _performance_profile == PlayerSettingsAccess.PERFORMANCE_PROFILE_ULTRA_LOW


func _apply_hud_profile_static_offsets() -> void:
	if _is_ultra_low_hud():
		_set_control_offsets(scoreboard_panel, SCOREBOARD_ULTRA_LOW_OFFSETS)
		_set_control_offsets(kill_feed_panel, KILL_FEED_ULTRA_LOW_OFFSETS)
		_set_control_offsets(match_objective, MATCH_OBJECTIVE_ULTRA_LOW_OFFSETS)
		_set_control_offsets(match_objective_sub, MATCH_OBJECTIVE_SUB_ULTRA_LOW_OFFSETS)
		_set_control_offsets(interaction_hint, INTERACTION_HINT_ULTRA_LOW_OFFSETS)
	else:
		_set_control_offsets(scoreboard_panel, SCOREBOARD_DEFAULT_OFFSETS)
		_set_control_offsets(kill_feed_panel, KILL_FEED_DEFAULT_OFFSETS)
		_set_control_offsets(match_objective, MATCH_OBJECTIVE_DEFAULT_OFFSETS)
		_set_control_offsets(match_objective_sub, MATCH_OBJECTIVE_SUB_DEFAULT_OFFSETS)
		_set_control_offsets(interaction_hint, INTERACTION_HINT_DEFAULT_OFFSETS)
	_scoreboard_base_offsets = _read_control_base_offsets(scoreboard_panel, _scoreboard_base_offsets)


func _apply_hud_profile_scale() -> void:
	var panel_scale: Vector2 = ULTRA_LOW_PANEL_SCALE if _is_ultra_low_hud() else DEFAULT_PANEL_SCALE
	var music_scale: Vector2 = ULTRA_LOW_MUSIC_SCALE if _is_ultra_low_hud() else DEFAULT_MUSIC_SCALE
	var center_text_scale: Vector2 = ULTRA_LOW_CENTER_TEXT_SCALE if _is_ultra_low_hud() else DEFAULT_CENTER_TEXT_SCALE

	_set_control_scale(stats, panel_scale)
	_set_control_scale(scoreboard_panel, panel_scale)
	_set_control_scale(kill_feed_panel, panel_scale)
	_set_control_scale(music_panel, music_scale)
	_set_control_scale(match_objective, center_text_scale, true)
	_set_control_scale(match_objective_sub, center_text_scale, true)
	_set_control_scale(interaction_hint, center_text_scale, true)


func _set_control_offsets(control: Control, offsets: Vector4) -> void:
	if control == null:
		return
	control.offset_left = offsets.x
	control.offset_top = offsets.y
	control.offset_right = offsets.z
	control.offset_bottom = offsets.w


func _set_control_scale(control: Control, next_scale: Vector2, use_center_pivot: bool = false) -> void:
	if control == null:
		return
	control.scale = next_scale
	control.pivot_offset = control.size * 0.5 if use_center_pivot else Vector2.ZERO


func _apply_music_panel_layout(top: float, right_inset: float) -> void:
	if music_panel == null:
		return

	music_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	music_panel.offset_top = top
	music_panel.offset_bottom = top + MUSIC_PANEL_DEFAULT_HEIGHT
	music_panel.offset_right = -right_inset
	music_panel.offset_left = -(right_inset + MUSIC_PANEL_DEFAULT_WIDTH)
	_music_base_offsets = _read_control_base_offsets(music_panel, _music_base_offsets)
	_apply_hud_motion()


func _set_stats_base_offsets(left: float, top: float, right: float, bottom: float) -> void:
	_stats_base_offsets = Vector4(left, top, right, bottom)
	_apply_hud_motion()


func _update_hud_motion(delta: float) -> void:
	if not hud_motion_enabled or _player == null:
		_hud_motion_offset = Vector2.ZERO
		_apply_hud_motion()
		return

	var sample: Dictionary = _player.get_hud_motion_sample()
	var strafe: float = sample.get("strafe", 0.0)
	var forward: float = sample.get("forward", 0.0)
	var look: Vector2 = sample.get("look", Vector2.ZERO)
	var target_offset := Vector2(
		strafe * hud_move_sway_px - look.x * hud_look_sway_px,
		-forward * hud_move_sway_px * 0.42 - look.y * hud_look_sway_px
	)
	if target_offset.length() > hud_max_offset_px:
		target_offset = target_offset.normalized() * hud_max_offset_px

	var smoothing_weight: float = 1.0 - exp(-hud_motion_smoothing * delta)
	_hud_motion_offset = _hud_motion_offset.lerp(target_offset, smoothing_weight)
	_apply_hud_motion()


func _capture_hud_base_offsets() -> void:
	_stats_base_offsets = _read_control_base_offsets(stats, _stats_base_offsets)
	_music_base_offsets = _read_control_base_offsets(music_panel, _music_base_offsets)
	_scoreboard_base_offsets = _read_control_base_offsets(scoreboard_panel, _scoreboard_base_offsets)


func _read_control_base_offsets(control: Control, fallback: Vector4) -> Vector4:
	if control == null:
		return fallback

	return Vector4(
		control.offset_left,
		control.offset_top,
		control.offset_right,
		control.offset_bottom
	)


func _apply_hud_motion() -> void:
	_apply_panel_offset(stats, _stats_base_offsets)
	_apply_panel_offset(music_panel, _music_base_offsets)
	_apply_panel_offset(scoreboard_panel, _scoreboard_base_offsets)


func _apply_panel_offset(control: Control, base_offsets: Vector4) -> void:
	if control == null:
		return

	control.offset_left = base_offsets.x + _hud_motion_offset.x
	control.offset_top = base_offsets.y + _hud_motion_offset.y
	control.offset_right = base_offsets.z + _hud_motion_offset.x
	control.offset_bottom = base_offsets.w + _hud_motion_offset.y
	control.rotation = 0.0


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


func _ensure_pickup_interaction_widgets() -> void:
	if pickup_interaction_panel != null:
		return

	pickup_interaction_panel = Control.new()
	pickup_interaction_panel.name = "PickupInteractionPanel"
	pickup_interaction_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pickup_interaction_panel.custom_minimum_size = PICKUP_PANEL_SIZE
	add_child(pickup_interaction_panel)

	pickup_interaction_label = Label.new()
	pickup_interaction_label.name = "PromptLabel"
	pickup_interaction_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pickup_interaction_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	pickup_interaction_label.offset_left = 0.0
	pickup_interaction_label.offset_top = 0.0
	pickup_interaction_label.offset_right = 0.0
	pickup_interaction_label.offset_bottom = 18.0
	pickup_interaction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pickup_interaction_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pickup_interaction_label.add_theme_font_size_override("font_size", 12)
	pickup_interaction_panel.add_child(pickup_interaction_label)

	pickup_interaction_track = ColorRect.new()
	pickup_interaction_track.name = "Track"
	pickup_interaction_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pickup_interaction_track.color = Color(0.02, 0.02, 0.02, 0.78)
	pickup_interaction_track.set_anchors_preset(Control.PRESET_TOP_LEFT)
	pickup_interaction_track.offset_left = (PICKUP_PANEL_SIZE.x - PICKUP_BAR_SIZE.x) * 0.5
	pickup_interaction_track.offset_top = 23.0
	pickup_interaction_track.offset_right = pickup_interaction_track.offset_left + PICKUP_BAR_SIZE.x
	pickup_interaction_track.offset_bottom = pickup_interaction_track.offset_top + PICKUP_BAR_SIZE.y
	pickup_interaction_panel.add_child(pickup_interaction_track)

	pickup_interaction_fill = ColorRect.new()
	pickup_interaction_fill.name = "Fill"
	pickup_interaction_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pickup_interaction_fill.color = HudIcons.get_tag_tint()
	pickup_interaction_fill.set_anchors_preset(Control.PRESET_TOP_LEFT)
	pickup_interaction_fill.offset_left = 0.0
	pickup_interaction_fill.offset_top = 0.0
	pickup_interaction_fill.offset_right = 0.0
	pickup_interaction_fill.offset_bottom = PICKUP_BAR_SIZE.y
	pickup_interaction_track.add_child(pickup_interaction_fill)
	_position_pickup_interaction_panel()


func _on_pickup_interaction_changed(prompt: String, progress: float, is_visible: bool, can_collect: bool) -> void:
	if pickup_interaction_panel == null:
		return

	pickup_interaction_panel.visible = is_visible
	if not is_visible:
		return

	if pickup_interaction_label != null:
		pickup_interaction_label.text = prompt.to_upper()
		pickup_interaction_label.modulate = HudIcons.get_tag_tint() if can_collect else HudIcons.HUD_WARN_TINT
	if pickup_interaction_fill != null:
		pickup_interaction_fill.color = HudIcons.get_tag_tint() if can_collect else HudIcons.HUD_WARN_TINT
		pickup_interaction_fill.offset_right = PICKUP_BAR_SIZE.x * clampf(progress, 0.0, 1.0)


func _update_health_tint() -> void:
	if health_tag == null or _max_health <= 0:
		return

	var health_ratio: float = float(_health) / float(_max_health)
	health_tag.modulate = HudIcons.HUD_WARN_TINT if health_ratio <= HEALTH_WARN_RATIO else HudIcons.get_tag_tint()
	if health_label != null:
		health_label.modulate = HudIcons.HUD_WARN_TINT if health_ratio <= HEALTH_WARN_RATIO else HudIcons.HUD_TINT
