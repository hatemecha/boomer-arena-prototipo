class_name HUD
extends Control

@onready var health_label: Label = $Stats/HealthLabel
@onready var weapon_label: Label = $Stats/WeaponLabel
@onready var ammo_label: Label = $Stats/AmmoLabel
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


func _ready() -> void:
	set_debug_visible(_debug_visible)


func bind_player(player: PlayerController) -> void:
	if player == null:
		push_error("HUD cannot bind a null player.")
		return

	_player = player
	player.health.health_changed.connect(_on_health_changed)
	player.debug_stats_changed.connect(_on_debug_stats_changed)
	player.active_weapon_changed.connect(_on_active_weapon_changed)
	_on_active_weapon_changed(player.weapon)

	if _active_weapon == null:
		push_error("HUD cannot bind because the player has no active weapon.")
		return

	_on_health_changed(player.health.current_health, player.health.max_health)
	_on_ammo_changed(_active_weapon.ammo_in_mag, _active_weapon.reserve_ammo)
	_on_weapon_state_changed(_active_weapon.state)


func _process(_delta: float) -> void:
	fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
	position_label.text = "POS: %.1f, %.1f, %.1f" % [_debug_position.x, _debug_position.y, _debug_position.z]
	speed_label.text = "SPEED: %.1f" % _debug_speed
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
