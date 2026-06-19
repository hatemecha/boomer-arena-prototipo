extends SceneTree

const ImpactVFX = preload("res://scripts/vfx/bullet_impact_vfx.gd")


func _initialize() -> void:
	var root := Node3D.new()
	root.name = "TestRoot"
	get_root().add_child(root)
	current_scene = root

	var pickup := Area3D.new()
	pickup.position.z = -2.0
	_add_sphere(pickup)
	root.add_child(pickup)

	var wall := StaticBody3D.new()
	wall.position.z = -5.0
	_add_sphere(wall)
	root.add_child(wall)

	await physics_frame
	var query := PhysicsRayQueryParameters3D.create(Vector3.ZERO, Vector3(0.0, 0.0, -10.0))
	query.collide_with_areas = false
	var hit := root.get_world_3d().direct_space_state.intersect_ray(query)
	assert(hit.get("collider") == wall, "El raycast no debe chocar con pickups Area3D")

	ImpactVFX.spawn_decal(root, wall.global_position + Vector3(0.0, 0.0, 1.0), Vector3.FORWARD, 1.0, 4, wall)
	var decal := wall.get_node_or_null("BulletImpactDecal") as MeshInstance3D
	assert(decal != null, "El impacto debe quedar unido al objeto golpeado")
	var local_position := decal.position
	wall.position.x = 2.0
	assert(decal.position.is_equal_approx(local_position), "El impacto debe acompañar al objeto golpeado")

	print("VERIFY hitscan_ignores_pickups=true decals_follow_hit_object=true")
	quit()


func _add_sphere(body: CollisionObject3D) -> void:
	var shape := CollisionShape3D.new()
	shape.shape = SphereShape3D.new()
	body.add_child(shape)
