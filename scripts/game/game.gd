class_name Game
extends Node3D

@export var player_scene: PackedScene = preload("res://scenes/player/Player.tscn")
@export var ammo_pickup_scene: PackedScene = preload("res://scenes/pickups/AmmoPickup.tscn")
@export var health_pickup_scene: PackedScene = preload("res://scenes/pickups/HealthPickup.tscn")
@export var target_scene: PackedScene = preload("res://scenes/game/DamageableTarget.tscn")
@export var hud_scene: PackedScene = preload("res://scenes/ui/HUD.tscn")
@export var options_menu_scene: PackedScene = preload("res://scenes/ui/OptionsMenu.tscn")
@export_range(0.1, 10.0) var player_respawn_delay: float = 3.0

var players: Array[PlayerController] = []

var _player: PlayerController
var _hud: HUD
var _options_layer: CanvasLayer
var _options_menu: OptionsMenu
var _visual_director: PSXVisualDirector
var _spawn_manager: SpawnManager
var _pickup_spawner: PickupSpawner
var _match_manager: MatchManager
var _debug_draw_manager: ArenaDebugDrawManager


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	DefaultInputActions.ensure_default_actions()
	_visual_director = $PSXVisualDirector as PSXVisualDirector
	_setup_managers()
	_match_manager.start_match()
	_spawn_player()
	_pickup_spawner.spawn_pickups(self)
	_spawn_targets()
	_setup_hud()
	_setup_options_menu()
	_debug_draw_manager.bind_context(_spawn_manager, _pickup_spawner, players)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return
	if event.is_action_pressed("pause"):
		if _options_menu != null:
			_options_menu.toggle()
			get_viewport().set_input_as_handled()


func _setup_managers() -> void:
	_spawn_manager = SpawnManager.new()
	_spawn_manager.name = "SpawnManager"
	add_child(_spawn_manager)

	_pickup_spawner = PickupSpawner.new()
	_pickup_spawner.name = "PickupSpawner"
	_pickup_spawner.ammo_pickup_scene = ammo_pickup_scene
	_pickup_spawner.health_pickup_scene = health_pickup_scene
	add_child(_pickup_spawner)

	_match_manager = MatchManager.new()
	_match_manager.name = "MatchManager"
	add_child(_match_manager)

	_debug_draw_manager = ArenaDebugDrawManager.new()
	_debug_draw_manager.name = "ArenaDebugDrawManager"
	add_child(_debug_draw_manager)


func _spawn_player() -> void:
	_player = player_scene.instantiate() as PlayerController
	if _player == null:
		push_error("Player scene must instantiate a PlayerController.")
		return

	_player.player_id = 1
	_player.display_name = "Player"
	add_child(_player)
	players.append(_player)
	_match_manager.ensure_player(_player.player_id)
	_player.died.connect(_on_player_died.bind(_player))
	_respawn_player(_player)


func _spawn_targets() -> void:
	_spawn_target(Vector3(-7.0, 0.0, -8.0))
	_spawn_target(Vector3(7.0, 0.0, 8.0))
	_spawn_target(Vector3(0.0, 0.0, -5.5))


func _spawn_target(spawn_position: Vector3) -> void:
	var target: Node3D = target_scene.instantiate() as Node3D
	if target == null:
		push_error("Target scene must instantiate a Node3D.")
		return
	add_child(target)
	target.global_position = spawn_position


func _setup_hud() -> void:
	var hud: HUD = hud_scene.instantiate() as HUD
	if hud == null:
		push_error("HUD scene must instantiate HUD.")
		return

	add_child(hud)
	_hud = hud
	hud.bind_player(_player)


func _setup_options_menu() -> void:
	var options_menu: OptionsMenu = options_menu_scene.instantiate() as OptionsMenu
	if options_menu == null:
		push_error("Options menu scene must instantiate OptionsMenu.")
		return

	_options_layer = CanvasLayer.new()
	_options_layer.name = "OptionsLayer"
	_options_layer.layer = 256
	_options_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_options_layer)
	_options_layer.add_child(options_menu)
	_options_menu = options_menu
	_options_menu.bind_context(_player, _hud, _visual_director, _debug_draw_manager)
	_options_menu.menu_visibility_changed.connect(_on_options_visibility_changed)
	_options_menu.respawn_requested.connect(_on_options_respawn_requested)


func _on_player_died(player: PlayerController) -> void:
	if player != null:
		_match_manager.register_death(player.player_id)
	await get_tree().create_timer(player_respawn_delay).timeout
	_respawn_player(player)


func _on_options_respawn_requested() -> void:
	_respawn_player(_player)


func _on_options_visibility_changed(is_visible: bool) -> void:
	if _player == null:
		return
	_player.set_gameplay_input_enabled(not is_visible)


func _respawn_player(player: PlayerController = null) -> void:
	var player_to_respawn: PlayerController = player if player != null else _player
	if player_to_respawn == null:
		push_error("Cannot respawn because no player exists.")
		return
	var spawn_transform: Transform3D = _spawn_manager.get_spawn_transform(players)
	player_to_respawn.respawn_at(spawn_transform.origin, spawn_transform.basis.get_euler().y)
