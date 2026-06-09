@tool
extends Node3D


const UNUSED_MODEL_PATHS: Array[NodePath] = [
	NodePath("Model/Sketchfab_model/root/GLTF_SceneRootNode/Armature_001_16"),
	NodePath("Model/Sketchfab_model/root/GLTF_SceneRootNode/Armature_002_33"),
]


func _ready() -> void:
	_remove_unused_models.call_deferred()


func _remove_unused_models() -> void:
	for model_path in UNUSED_MODEL_PATHS:
		var unused_model: Node = get_node_or_null(model_path)
		if unused_model != null:
			unused_model.queue_free()
