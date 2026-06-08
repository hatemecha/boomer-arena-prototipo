class_name PickupBase
extends Area3D

@export_range(0.1, 120.0) var respawn_time: float = 15.0
@export_range(0.0, 10.0) var rotation_speed: float = 2.5
@export var pickup_sound: AudioStream

@onready var visual_root: Node3D = $VisualRoot
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

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


func _on_body_entered(body: Node3D) -> void:
	if not _is_available or not (body is PlayerController):
		return

	if apply_to_player(body):
		_play_pickup_sound()
		_disable_temporarily()


func _disable_temporarily() -> void:
	_is_available = false
	visible = false
	set_deferred("monitoring", false)
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)

	await get_tree().create_timer(respawn_time).timeout

	_is_available = true
	visible = true
	set_deferred("monitoring", true)
	if collision_shape != null:
		collision_shape.set_deferred("disabled", false)


func _play_pickup_sound() -> void:
	if pickup_sound == null or _audio_player == null:
		return
	_audio_player.stream = pickup_sound
	_audio_player.play()
