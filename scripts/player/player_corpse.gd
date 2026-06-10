class_name PlayerCorpse
extends RigidBody3D

const CORPSE_LIFETIME: float = 4.0

@export_range(2.0, 20.0, 0.5) var impulse_strength: float = 8.0

var _lifetime: float = CORPSE_LIFETIME


func _ready() -> void:
	continuous_cd = true
	contact_monitor = true
	max_contacts_reported = 4
	linear_damp = 0.18
	angular_damp = 0.35
	_setup_collision()


func setup(body_color: Color, impulse: Vector3) -> void:
	_apply_body_color(body_color)
	apply_central_impulse(impulse)
	apply_torque_impulse(Vector3(randf_range(-1.2, 1.2), randf_range(-0.4, 0.4), randf_range(-1.2, 1.2)) * impulse_strength)
	_lifetime = CORPSE_LIFETIME


func _physics_process(delta: float) -> void:
	_lifetime -= delta
	if _lifetime <= 0.0 or global_position.y < -10.0:
		queue_free()


func _setup_collision() -> void:
	var shape_node := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.2
	shape_node.shape = capsule
	shape_node.position = Vector3(0.0, 0.6, 0.0)
	add_child(shape_node)


func _apply_body_color(body_color: Color) -> void:
	var mesh_instance := get_node_or_null("BodyMesh") as Node3D
	if mesh_instance == null:
		return

	var material := StandardMaterial3D.new()
	material.albedo_color = body_color
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_apply_material_recursive(mesh_instance, material)


func _apply_material_recursive(node: Node, material: StandardMaterial3D) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_override = material
	for child in node.get_children():
		_apply_material_recursive(child, material)
