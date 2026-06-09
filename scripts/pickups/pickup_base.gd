class_name PickupBase
extends Area3D

signal availability_changed(pickup_id: int, is_available: bool)

@export_range(0.1, 120.0) var respawn_time: float = 15.0
@export_range(0.0, 10.0) var rotation_speed: float = 2.5
@export var pickup_sound: AudioStream

@onready var visual_root: Node3D = $VisualRoot
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var pickup_id: int = -1

var _is_available: bool = true
var _audio_player: AudioStreamPlayer3D


func _ready() -> void:
	_audio_player = AudioStreamPlayer3D.new()
	_audio_player.name = "PickupAudio"
	add_child(_audio_player)
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	if visual_root != null:
		visual_root.rotate_y(rotation_speed * delta)


func apply_to_player(_player: PlayerController) -> bool:
	push_warning("PickupBase.apply_to_player must be overridden.")
	return false


func set_pickup_id(next_pickup_id: int) -> void:
	pickup_id = next_pickup_id


func is_available() -> bool:
	return _is_available


func collect_for_player(player: PlayerController) -> bool:
	if not _is_available or player == null:
		return false

	if not apply_to_player(player):
		return false

	_play_pickup_sound()
	_disable_temporarily()
	return true


func set_network_available(is_next_available: bool) -> void:
	_set_available(is_next_available, false)


func _on_body_entered(body: Node3D) -> void:
	if not _is_available or not (body is PlayerController):
		return

	var player: PlayerController = body as PlayerController
	if collect_for_player(player):
		_request_network_pickup(player)


func _disable_temporarily() -> void:
	_set_available(false, true)

	await get_tree().create_timer(respawn_time).timeout

	_set_available(true, true)


func _set_available(is_next_available: bool, should_emit_signal: bool) -> void:
	_is_available = is_next_available
	visible = is_next_available
	set_deferred("monitoring", is_next_available)
	if collision_shape != null:
		collision_shape.set_deferred("disabled", not is_next_available)
	if should_emit_signal:
		availability_changed.emit(pickup_id, _is_available)


func _request_network_pickup(player: PlayerController) -> void:
	if player == null or pickup_id < 0:
		return

	var scene_root: Node = get_tree().current_scene
	if scene_root == null or not scene_root.has_method("request_network_pickup"):
		return
	scene_root.call("request_network_pickup", pickup_id, player.player_id)


func _play_pickup_sound() -> void:
	if pickup_sound == null or _audio_player == null:
		return
	_audio_player.stream = pickup_sound
	_audio_player.play()
