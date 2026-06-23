class_name GlImportedArena
extends Node3D

@export var map_model_path: NodePath = ^"MapModel"


func _ready() -> void:
	_setup_map_collision()


func _setup_map_collision() -> void:
	var map_model := get_node_or_null(map_model_path) as Node3D
	if map_model == null:
		push_error("%s requires a valid MapModel node." % name)
		return

	var collision_mesh_count := 0
	for node in map_model.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		mesh_instance.create_trimesh_collision()
		_enable_backface_collision(mesh_instance)
		collision_mesh_count += 1

	if collision_mesh_count == 0:
		push_error("%s could not create collision because the model contains no meshes." % name)


func _enable_backface_collision(mesh_instance: MeshInstance3D) -> void:
	for child in mesh_instance.get_children():
		var static_body := child as StaticBody3D
		if static_body == null:
			continue
		for body_child in static_body.get_children():
			var collision_shape := body_child as CollisionShape3D
			if collision_shape != null and collision_shape.shape is ConcavePolygonShape3D:
				(collision_shape.shape as ConcavePolygonShape3D).backface_collision = true


func _on_void_recovery_body_entered(body: Node3D) -> void:
	var player := body as PlayerController
	if player == null:
		return

	var game_root := get_parent()
	if game_root == null or not game_root.has_method("recover_player_from_world_bounds"):
		push_error("%s requires a game root that can recover out-of-bounds players." % name)
		return
	game_root.call_deferred("recover_player_from_world_bounds", player)
