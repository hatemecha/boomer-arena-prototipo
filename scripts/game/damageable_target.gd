class_name DamageableTarget
extends StaticBody3D

@export_range(1, 500) var max_health: int = 80
@export_range(0.1, 60.0) var respawn_time: float = 2.5

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var body_mesh: MeshInstance3D = $Body

var current_health: int
var _is_dead: bool = false
var _base_material: StandardMaterial3D
var _hurt_material: StandardMaterial3D


func _ready() -> void:
	current_health = max_health
	_setup_materials()


func apply_damage(amount: int) -> void:
	if amount <= 0:
		push_warning("Damage amount must be greater than zero.")
		return
	if _is_dead:
		return

	current_health = max(current_health - amount, 0)
	_flash_hurt()

	if current_health == 0:
		_die()


func _die() -> void:
	_is_dead = true
	visible = false
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)

	await get_tree().create_timer(respawn_time).timeout
	_respawn()


func _respawn() -> void:
	current_health = max_health
	_is_dead = false
	visible = true
	collision_layer = 1
	collision_mask = 1
	if collision_shape != null:
		collision_shape.disabled = false
	if body_mesh != null:
		body_mesh.material_override = _base_material


func _setup_materials() -> void:
	_base_material = StandardMaterial3D.new()
	_base_material.albedo_color = Color(0.16, 0.16, 0.18)

	_hurt_material = StandardMaterial3D.new()
	_hurt_material.albedo_color = Color(0.9, 0.04, 0.02)
	_hurt_material.emission_enabled = true
	_hurt_material.emission = Color(0.8, 0.02, 0.02)
	_hurt_material.emission_energy_multiplier = 0.75

	if body_mesh != null:
		body_mesh.material_override = _base_material


func _flash_hurt() -> void:
	if body_mesh == null:
		return

	body_mesh.material_override = _hurt_material
	var tween: Tween = create_tween()
	tween.tween_interval(0.08)
	tween.tween_callback(func() -> void:
		if is_instance_valid(body_mesh) and not _is_dead:
			body_mesh.material_override = _base_material
	)
