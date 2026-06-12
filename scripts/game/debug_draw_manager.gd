class_name ArenaDebugDrawManager
extends Node

signal debug_draw_toggled(enabled: bool)

@export var debug_draw_enabled: bool = false
@export_range(0.01, 2.0) var shot_ray_duration: float = 0.15

var _spawn_manager: SpawnManager
var _pickup_spawner: PickupSpawner
var _players: Array[PlayerController] = []


func _ready() -> void:
	add_to_group("arena_debug_draw")
	set_process(debug_draw_enabled)


func bind_context(spawn_manager: SpawnManager, pickup_spawner: PickupSpawner, players: Array[PlayerController]) -> void:
	_spawn_manager = spawn_manager
	_pickup_spawner = pickup_spawner
	_players = players


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed("debug_draw_toggle"):
		set_debug_draw_enabled(not debug_draw_enabled)


func _process(_delta: float) -> void:
	if not debug_draw_enabled:
		return
	var debug_draw: Object = _get_debug_draw_3d()
	if debug_draw == null:
		return

	_draw_spawn_points(debug_draw)
	_draw_pickup_positions(debug_draw)
	_draw_player_vectors(debug_draw)


func set_debug_draw_enabled(value: bool) -> void:
	debug_draw_enabled = value
	set_process(debug_draw_enabled)
	debug_draw_toggled.emit(debug_draw_enabled)


func draw_shot_ray(origin: Vector3, end_position: Vector3, hit_position: Vector3, did_hit: bool) -> void:
	if not debug_draw_enabled:
		return
	var debug_draw: Object = _get_debug_draw_3d()
	if debug_draw == null:
		return

	var final_position: Vector3 = hit_position if did_hit else end_position
	debug_draw.call("draw_line", origin, final_position, Color(1.0, 0.1, 0.02), shot_ray_duration)
	if did_hit:
		debug_draw.call("draw_sphere", hit_position, 0.18, Color(1.0, 0.05, 0.02), shot_ray_duration)
		debug_draw.call("draw_line", hit_position, end_position, Color(0.35, 0.08, 0.06, 0.5), shot_ray_duration)


func _draw_spawn_points(debug_draw: Object) -> void:
	if _spawn_manager == null:
		return
	for spawn_position in _spawn_manager.get_spawn_positions():
		debug_draw.call("draw_sphere", spawn_position, 0.35, Color(0.15, 0.9, 1.0))
		debug_draw.call("draw_line", spawn_position, spawn_position + Vector3.UP * 1.4, Color(0.15, 0.9, 1.0))


func _draw_pickup_positions(debug_draw: Object) -> void:
	if _pickup_spawner == null:
		return
	for pickup_position in _pickup_spawner.get_pickup_positions():
		debug_draw.call("draw_box", pickup_position, Quaternion.IDENTITY, Vector3(0.45, 0.45, 0.45), Color(0.9, 0.85, 0.1))


func _draw_player_vectors(debug_draw: Object) -> void:
	for player in _players:
		if player == null or not is_instance_valid(player):
			continue
		var origin: Vector3 = player.global_position + Vector3.UP * 0.2
		var horizontal_velocity: Vector3 = Vector3(player.velocity.x, 0.0, player.velocity.z)
		if horizontal_velocity.length_squared() > 0.01:
			debug_draw.call("draw_arrow", origin, origin + horizontal_velocity.normalized() * 2.0, Color(0.2, 1.0, 0.25), 0.2, true)


func _get_debug_draw_3d() -> Object:
	if not Engine.has_singleton("DebugDraw3D"):
		return null
	return Engine.get_singleton("DebugDraw3D")
