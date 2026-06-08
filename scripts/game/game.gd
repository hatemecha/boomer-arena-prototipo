class_name Game
extends Node3D

@export var player_scene: PackedScene = preload("res://scenes/player/Player.tscn")
@export var ammo_pickup_scene: PackedScene = preload("res://scenes/pickups/AmmoPickup.tscn")
@export var health_pickup_scene: PackedScene = preload("res://scenes/pickups/HealthPickup.tscn")
@export var target_scene: PackedScene = preload("res://scenes/game/DamageableTarget.tscn")
@export var hud_scene: PackedScene = preload("res://scenes/ui/HUD.tscn")
@export var options_menu_scene: PackedScene = preload("res://scenes/ui/OptionsMenu.tscn")
@export_range(0.1, 10.0) var player_respawn_delay: float = 3.0

var _player: PlayerController
var _hud: HUD
var _options_layer: CanvasLayer
var _options_menu: OptionsMenu
var _visual_director: PSXVisualDirector
var _spawn_points: Array[Transform3D] = [
	Transform3D(Basis().rotated(Vector3.UP, deg_to_rad(180.0)), Vector3(0.0, 1.2, 12.0)),
	Transform3D(Basis(), Vector3(0.0, 1.2, -12.0)),
	Transform3D(Basis().rotated(Vector3.UP, deg_to_rad(90.0)), Vector3(-12.0, 1.2, 0.0)),
	Transform3D(Basis().rotated(Vector3.UP, deg_to_rad(-90.0)), Vector3(12.0, 1.2, 0.0)),
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_visual_director = $PSXVisualDirector as PSXVisualDirector
	_spawn_player()
	_spawn_pickups()
	_spawn_targets()
	_setup_hud()
	_setup_options_menu()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if _options_menu != null:
			_options_menu.toggle()
			get_viewport().set_input_as_handled()


func _spawn_player() -> void:
	_player = player_scene.instantiate() as PlayerController
	if _player == null:
		push_error("Player scene must instantiate a PlayerController.")
		return

	add_child(_player)
	_player.died.connect(_on_player_died)
	_respawn_player()


func _spawn_pickups() -> void:
	_spawn_pickup(ammo_pickup_scene, Vector3(-11.0, 1.0, -11.0))
	_spawn_pickup(ammo_pickup_scene, Vector3(11.0, 1.0, 11.0))
	_spawn_pickup(health_pickup_scene, Vector3(-11.0, 1.0, 11.0))
	_spawn_pickup(health_pickup_scene, Vector3(11.0, 1.0, -11.0))


func _spawn_pickup(scene: PackedScene, spawn_position: Vector3) -> void:
	var pickup: Node3D = scene.instantiate() as Node3D
	if pickup == null:
		push_error("Pickup scene must instantiate a Node3D.")
		return
	add_child(pickup)
	pickup.global_position = spawn_position


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
	_options_menu.bind_context(_player, _hud, _visual_director)
	_options_menu.menu_visibility_changed.connect(_on_options_visibility_changed)
	_options_menu.respawn_requested.connect(_on_options_respawn_requested)


func _on_player_died() -> void:
	await get_tree().create_timer(player_respawn_delay).timeout
	_respawn_player()


func _on_options_respawn_requested() -> void:
	_respawn_player()


func _on_options_visibility_changed(is_visible: bool) -> void:
	if _player == null:
		return
	_player.set_gameplay_input_enabled(not is_visible)


func _respawn_player() -> void:
	if _player == null:
		push_error("Cannot respawn because no player exists.")
		return
	var spawn_transform: Transform3D = _choose_spawn_transform()
	_player.respawn_at(spawn_transform.origin, spawn_transform.basis.get_euler().y)


func _choose_spawn_transform() -> Transform3D:
	if _spawn_points.is_empty():
		push_warning("No spawn points configured. Falling back to origin.")
		return Transform3D(Basis(), Vector3(0.0, 1.2, 0.0))
	return _spawn_points.pick_random()
