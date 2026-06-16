class_name HitscanWeapon
extends WeaponBase

const PlayerSettingsAccess = preload("res://scripts/game/player_settings_access.gd")
const BULLET_SCENE: PackedScene = preload("res://assets/models/vfx/low_poly_bullet.glb")

@export var hit_marker_duration: float = 0.08
@export var impact_lifetime: float = 0.45
@export var decal_lifetime: float = 5.0
@export_range(0, 128) var max_active_impacts: int = 48
@export_range(0, 128) var max_active_decals: int = 64
@export_range(1, 24) var pellet_count: int = 1
@export_range(20.0, 300.0) var bullet_travel_speed: float = 90.0
@export_range(0.02, 0.5) var bullet_model_scale: float = 0.1
@export_range(0.2, 3.0) var bullet_bounce_lifetime: float = 1.6
@export_range(0.1, 2.0) var bullet_bounce_distance: float = 0.75

@onready var muzzle_flash: Node = get_node_or_null("MuzzleFlash")

var bullet_bounce_enabled: bool = true

# Pool compartido entre todas las armas hitscan: las balas se reutilizan
# (ocultar/mostrar) en lugar de instanciar y liberar una por disparo.
static var _active_bullet_markers: Array[Node3D] = []
static var _bullet_marker_pool: Array[Node3D] = []

var _default_impact_lifetime: float = 0.45
var _default_decal_lifetime: float = 5.0
var _default_max_active_impacts: int = 48
var _default_max_active_decals: int = 64
var _default_bullet_bounce_lifetime: float = 1.6
var _default_bullet_bounce_distance: float = 0.75
var _defaults_cached: bool = false


func _ready() -> void:
	super()
	_cache_default_performance_values()
	if PlayerSettingsAccess.has_settings():
		apply_performance_profile(PlayerSettingsAccess.get_performance_profile())


func try_fire(camera: Camera3D) -> bool:
	if camera == null:
		push_error("HitscanWeapon requires a valid Camera3D to fire.")
		return false

	var did_fire: bool = super(camera)
	if not did_fire:
		return false

	for _pellet_index in range(pellet_count):
		_perform_hitscan(camera)
	_show_muzzle_flash()
	fired.emit(self)
	return true


func apply_performance_profile(profile: int) -> void:
	_cache_default_performance_values()
	var safe_profile := clampi(profile, 0, 2)
	match safe_profile:
		PlayerSettingsAccess.PERFORMANCE_PROFILE_LOW:
			impact_lifetime = minf(_default_impact_lifetime, 0.18)
			decal_lifetime = minf(_default_decal_lifetime, 1.2)
			max_active_impacts = mini(_default_max_active_impacts, 12)
			max_active_decals = mini(_default_max_active_decals, 16)
			bullet_bounce_lifetime = 0.0
			bullet_bounce_distance = 0.0
			bullet_bounce_enabled = false
		PlayerSettingsAccess.PERFORMANCE_PROFILE_ULTRA_LOW:
			impact_lifetime = 0.0
			decal_lifetime = minf(_default_decal_lifetime, 0.45)
			max_active_impacts = 0
			max_active_decals = mini(_default_max_active_decals, 4)
			bullet_bounce_lifetime = 0.0
			bullet_bounce_distance = 0.0
			bullet_bounce_enabled = false
		_:
			impact_lifetime = _default_impact_lifetime
			decal_lifetime = _default_decal_lifetime
			max_active_impacts = _default_max_active_impacts
			max_active_decals = _default_max_active_decals
			bullet_bounce_lifetime = _default_bullet_bounce_lifetime
			bullet_bounce_distance = _default_bullet_bounce_distance
			bullet_bounce_enabled = true

	if muzzle_flash != null and muzzle_flash.has_method("apply_performance_profile"):
		muzzle_flash.apply_performance_profile(safe_profile)


func warmup_runtime_effects(scene_root: Node, bullet_pool_size: int = 8, decal_pool_size: int = 8) -> void:
	if scene_root == null:
		return
	if muzzle_flash != null and muzzle_flash.has_method("warmup"):
		muzzle_flash.call("warmup")
	_warmup_bullet_markers(scene_root, bullet_pool_size)
	BulletImpactVFX.warmup(scene_root, decal_pool_size)


func _perform_hitscan(camera: Camera3D) -> void:
	var effective_spread_degrees: float = spread_degrees
	if is_aiming:
		effective_spread_degrees *= aim_spread_multiplier

	var origin: Vector3 = camera.global_transform.origin
	var direction: Vector3 = _get_camera_forward_with_spread(camera, effective_spread_degrees)
	var end_position: Vector3 = origin + direction * weapon_range
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, end_position)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var owner_body: CollisionObject3D = _get_owner_body()
	if owner_body != null:
		query.exclude = [owner_body.get_rid()]

	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	var impact_position: Vector3 = end_position
	var impact_normal: Vector3 = -direction.normalized()
	var did_hit: bool = not hit.is_empty()
	if not did_hit:
		_debug_draw_shot_ray(origin, end_position, end_position, false)
		_spawn_bullet_tracer(origin, direction, impact_position, impact_normal, false)
		return

	var damage_target: Object = _find_damage_target(hit.get("collider") as Object)
	if damage_target != null:
		if damage_target is PlayerController:
			var victim: PlayerController = damage_target as PlayerController
			var attacker_player_id: int = _get_owner_player_id()
			if not _request_network_player_damage(victim.player_id, damage, attacker_player_id):
				victim.apply_damage(damage, attacker_player_id)
		else:
			damage_target.apply_damage(damage)

	impact_position = hit.get("position", end_position)
	impact_normal = hit.get("normal", impact_normal).normalized()
	var should_bounce: bool = _should_bullet_bounce(hit, damage_target)
	_debug_draw_shot_ray(origin, end_position, impact_position, true)
	_spawn_bullet_tracer(origin, direction, impact_position, impact_normal, should_bounce)
	_spawn_impact_decal(impact_position, impact_normal)


func _get_camera_forward_with_spread(camera: Camera3D, effective_spread_degrees: float) -> Vector3:
	var direction: Vector3 = -camera.global_transform.basis.z.normalized()
	if effective_spread_degrees <= 0.001:
		return direction

	var spread_x: float = deg_to_rad(randf_range(-effective_spread_degrees, effective_spread_degrees))
	var spread_y: float = deg_to_rad(randf_range(-effective_spread_degrees, effective_spread_degrees))
	var spread_basis: Basis = camera.global_transform.basis * Basis.from_euler(Vector3(spread_y, spread_x, 0.0))
	return -spread_basis.z.normalized()


func _show_muzzle_flash() -> void:
	if muzzle_flash == null:
		return
	if not muzzle_flash.has_method("trigger_shot"):
		push_warning("%s muzzle flash node does not implement trigger_shot()." % name)
		return
	muzzle_flash.trigger_shot()


func _spawn_bullet_tracer(
	_ray_origin: Vector3,
	direction: Vector3,
	impact_position: Vector3,
	impact_normal: Vector3,
	should_bounce: bool
) -> void:
	if max_active_impacts <= 0:
		return

	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return

	_cleanup_invalid_bullets()
	while _active_bullet_markers.size() >= max_active_impacts:
		_release_bullet_marker(_active_bullet_markers.pop_front())

	var bullet: Node3D = _acquire_bullet_marker(scene_root)
	if bullet == null:
		return

	var spawn_position: Vector3 = _get_bullet_spawn_position()
	var travel_direction: Vector3 = direction.normalized()
	if travel_direction.length_squared() <= 0.0001:
		travel_direction = -global_transform.basis.z.normalized()

	var surface_stop: Vector3 = impact_position - travel_direction * 0.04

	bullet.visible = true
	bullet.scale = Vector3.ONE * bullet_model_scale
	bullet.global_position = spawn_position
	_orient_bullet(bullet, spawn_position, travel_direction)
	_active_bullet_markers.append(bullet)

	var travel_distance: float = spawn_position.distance_to(surface_stop)
	var travel_time: float = clampf(travel_distance / maxf(bullet_travel_speed, 1.0), 0.05, 0.35)
	var tween: Tween = bullet.create_tween()
	bullet.set_meta("flight_tween", tween)
	tween.tween_property(bullet, "global_position", surface_stop, travel_time).set_trans(Tween.TRANS_LINEAR)
	await tween.finished
	if bullet.has_meta("flight_tween"):
		bullet.remove_meta("flight_tween")

	if should_bounce:
		await _animate_bullet_bounce(bullet, surface_stop, travel_direction, impact_normal)
	else:
		_orient_bullet(bullet, surface_stop, travel_direction)
		await get_tree().create_timer(impact_lifetime).timeout

	if _active_bullet_markers.has(bullet):
		_active_bullet_markers.erase(bullet)
	_release_bullet_marker(bullet)


func _animate_bullet_bounce(
	bullet: Node3D,
	impact_position: Vector3,
	incoming_direction: Vector3,
	surface_normal: Vector3
) -> void:
	var normal: Vector3 = surface_normal.normalized()
	if normal.length_squared() <= 0.0001:
		normal = Vector3.UP

	var reflected: Vector3 = incoming_direction.normalized().reflect(normal)
	if reflected.length_squared() <= 0.0001:
		reflected = normal

	_orient_bullet(bullet, impact_position, reflected)
	var bounce_distance: float = randf_range(bullet_bounce_distance * 0.55, bullet_bounce_distance * 1.35)
	var bounce_target: Vector3 = impact_position + reflected * bounce_distance + Vector3(0.0, -0.12, 0.0)

	var bounce_time: float = clampf(bounce_distance / maxf(bullet_travel_speed * 0.45, 1.0), 0.08, 0.28)
	var bounce_tween: Tween = bullet.create_tween()
	bullet.set_meta("flight_tween", bounce_tween)
	bounce_tween.tween_property(bullet, "global_position", bounce_target, bounce_time).set_trans(Tween.TRANS_LINEAR)
	await bounce_tween.finished
	if bullet.has_meta("flight_tween"):
		bullet.remove_meta("flight_tween")

	var drop_target: Vector3 = bounce_target + Vector3(
		reflected.x * 0.18,
		-0.42,
		reflected.z * 0.18
	)
	var drop_tween: Tween = bullet.create_tween()
	bullet.set_meta("flight_tween", drop_tween)
	drop_tween.tween_property(bullet, "global_position", drop_target, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	drop_tween.parallel().tween_property(bullet, "scale", Vector3.ONE * bullet_model_scale * 0.85, 0.22)
	await drop_tween.finished
	if bullet.has_meta("flight_tween"):
		bullet.remove_meta("flight_tween")

	await get_tree().create_timer(bullet_bounce_lifetime).timeout


func _orient_bullet(bullet: Node3D, from_position: Vector3, forward_direction: Vector3) -> void:
	var direction: Vector3 = forward_direction.normalized()
	if direction.length_squared() <= 0.0001:
		return
	bullet.look_at(from_position + direction, Vector3.UP)


func _spawn_impact_decal(world_position: Vector3, surface_normal: Vector3) -> void:
	if max_active_decals <= 0 or decal_lifetime <= 0.0:
		return

	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return

	BulletImpactVFX.spawn_decal(scene_root, world_position, surface_normal, decal_lifetime, max_active_decals)


func _should_bullet_bounce(hit: Dictionary, damage_target: Object) -> bool:
	if not bullet_bounce_enabled:
		return false
	if damage_target != null:
		return false

	var collider: Object = hit.get("collider")
	if collider == null:
		return false
	if collider is StaticBody3D:
		return true
	if collider is Node:
		var parent_body: Node = (collider as Node).get_parent()
		while parent_body != null:
			if parent_body is StaticBody3D:
				return true
			if parent_body is CharacterBody3D or parent_body is RigidBody3D:
				return false
			parent_body = parent_body.get_parent()
	return false


func _get_bullet_spawn_position() -> Vector3:
	if muzzle_flash is Node3D:
		return (muzzle_flash as Node3D).global_position
	return global_position


func _acquire_bullet_marker(scene_root: Node) -> Node3D:
	while not _bullet_marker_pool.is_empty():
		var pooled: Node3D = _bullet_marker_pool.pop_back()
		if pooled != null and is_instance_valid(pooled) and pooled.get_parent() == scene_root:
			return pooled
		if pooled != null and is_instance_valid(pooled):
			pooled.queue_free()

	return _create_bullet_marker(scene_root)


func _create_bullet_marker(scene_root: Node) -> Node3D:
	var bullet: Node3D = BULLET_SCENE.instantiate() as Node3D
	if bullet == null:
		push_error("HitscanWeapon failed to instantiate assets/models/vfx/low_poly_bullet.glb")
		return null

	bullet.name = "BulletTracer"
	bullet.visible = false
	scene_root.add_child(bullet)
	return bullet


func _warmup_bullet_markers(scene_root: Node, pool_size: int) -> void:
	if pool_size <= 0:
		return

	_cleanup_invalid_bullets()
	while _get_pooled_bullet_count(scene_root) < pool_size:
		var bullet := _create_bullet_marker(scene_root)
		if bullet == null:
			return
		_bullet_marker_pool.append(bullet)


func _get_pooled_bullet_count(scene_root: Node) -> int:
	var count: int = 0
	for bullet in _bullet_marker_pool:
		if bullet != null and is_instance_valid(bullet) and bullet.get_parent() == scene_root:
			count += 1
	return count


func _release_bullet_marker(bullet: Node3D) -> void:
	if bullet == null or not is_instance_valid(bullet):
		return
	if bullet.has_meta("flight_tween"):
		var flight_tween: Variant = bullet.get_meta("flight_tween")
		if flight_tween is Tween and (flight_tween as Tween).is_valid():
			(flight_tween as Tween).kill()
		bullet.remove_meta("flight_tween")
	bullet.visible = false
	_bullet_marker_pool.append(bullet)


func _cleanup_invalid_bullets() -> void:
	for bullet_index in range(_active_bullet_markers.size() - 1, -1, -1):
		var bullet: Node3D = _active_bullet_markers[bullet_index]
		if bullet == null or not is_instance_valid(bullet):
			_active_bullet_markers.remove_at(bullet_index)


func _debug_draw_shot_ray(origin: Vector3, end_position: Vector3, hit_position: Vector3, did_hit: bool) -> void:
	var scene_tree: SceneTree = get_tree()
	if scene_tree == null:
		return
	scene_tree.call_group("arena_debug_draw", "draw_shot_ray", origin, end_position, hit_position, did_hit)


func _get_owner_body() -> CollisionObject3D:
	var current: Node = get_parent()
	while current != null:
		if current is CollisionObject3D:
			return current
		current = current.get_parent()
	return null


func _get_owner_player_id() -> int:
	var owner_body: CollisionObject3D = _get_owner_body()
	if owner_body is PlayerController:
		return (owner_body as PlayerController).player_id
	return 0


func _request_network_player_damage(victim_player_id: int, amount: int, attacker_player_id: int) -> bool:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null or not scene_root.has_method("request_network_damage"):
		return false
	return bool(scene_root.call("request_network_damage", victim_player_id, amount, attacker_player_id))


func _find_damage_target(collider: Object) -> Object:
	var current: Object = collider
	while current != null:
		if current.has_method("apply_damage"):
			return current
		if not (current is Node):
			break
		current = (current as Node).get_parent()
	return null


func _cache_default_performance_values() -> void:
	if _defaults_cached:
		return
	_default_impact_lifetime = impact_lifetime
	_default_decal_lifetime = decal_lifetime
	_default_max_active_impacts = max_active_impacts
	_default_max_active_decals = max_active_decals
	_default_bullet_bounce_lifetime = bullet_bounce_lifetime
	_default_bullet_bounce_distance = bullet_bounce_distance
	_defaults_cached = true
