class_name PlayerBodyVisual
extends RefCounted

const LIMB_LEFT_UPPER: String = "left_upper"
const LIMB_LEFT_LOWER: String = "left_lower"
const LIMB_LEFT_FOOT: String = "left_foot"
const LIMB_RIGHT_UPPER: String = "right_upper"
const LIMB_RIGHT_LOWER: String = "right_lower"
const LIMB_RIGHT_FOOT: String = "right_foot"
const AUTO_IMPORTED_MATERIAL_PREFIX: String = "Material"
const MAX_REMOTE_AIM_PITCH_DEGREES: float = 55.0
const THIRD_PERSON_SPEED_EPSILON: float = 0.001

const LIMB_BONE_NAMES: Dictionary = {
	LIMB_LEFT_UPPER: "Bone.003.L_41",
	LIMB_LEFT_LOWER: "Bone.004.L_40",
	LIMB_LEFT_FOOT: "Bone.005.L_39",
	LIMB_RIGHT_UPPER: "Bone.003.R_44",
	LIMB_RIGHT_LOWER: "Bone.004.R_43",
	LIMB_RIGHT_FOOT: "Bone.005.R_42",
}

var _body_visual_default_transform: Transform3D = Transform3D.IDENTITY
var _third_person_weapon_default_transform: Transform3D = Transform3D.IDENTITY
var _third_person_weapon_models: Array[Node3D] = []
var _limb_bone_indices: Dictionary = {}
var _limb_rest_rotations: Dictionary = {}
var _body_motion_time: float = 0.0
var _damage_flash_material: StandardMaterial3D


func setup(player) -> void:
	_cache_third_person_weapon_rig(player)
	_cache_limb_bones(player)


func reset_motion() -> void:
	_body_motion_time = 0.0


func set_damage_flash(node: Node, enabled: bool) -> void:
	if node == null:
		return
	if enabled and _damage_flash_material == null:
		_damage_flash_material = StandardMaterial3D.new()
		_damage_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_damage_flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_damage_flash_material.albedo_color = Color(1.0, 0.02, 0.01, 0.62)
		_damage_flash_material.emission_enabled = true
		_damage_flash_material.emission = Color(1.0, 0.01, 0.0)
		_damage_flash_material.emission_energy_multiplier = 1.35
	_apply_damage_overlay_recursive(node, _damage_flash_material if enabled else null)


func _apply_damage_overlay_recursive(node: Node, overlay: Material) -> void:
	if node is MeshInstance3D:
		(node as MeshInstance3D).material_overlay = overlay
	for child in node.get_children():
		_apply_damage_overlay_recursive(child, overlay)


func update_body_visibility(player) -> void:
	if player.body_mesh == null:
		return
	if not player.is_alive():
		player.body_mesh.visible = false
		update_third_person_weapon_visibility(player)
		return
	var hide_body: bool = (
		player.hide_body_for_local_player
		and player.is_local_controlled()
		and player.is_debug_first_person_view()
	)
	player.body_mesh.visible = not hide_body
	update_third_person_weapon_visibility(player)


func update_first_person_weapon_visibility(player, weapons: Array[WeaponBase], active_weapon_index: int, viewmodel_fill_light: OmniLight3D) -> void:
	if viewmodel_fill_light != null:
		viewmodel_fill_light.visible = player.is_local_controlled() and player.is_debug_first_person_view()

	for weapon_index in range(weapons.size()):
		weapons[weapon_index].visible = (
			player.is_local_controlled()
			and player.is_debug_first_person_view()
			and weapon_index == active_weapon_index
		)


func update_third_person_weapon_visibility(player) -> void:
	if player.third_person_weapon_rig == null:
		return

	var should_show_rig: bool = player.is_alive()
	if player.is_local_controlled():
		if player.is_debug_first_person_view() and player.hide_third_person_weapon_for_local_player:
			should_show_rig = false
	player.third_person_weapon_rig.visible = should_show_rig

	for weapon_index in range(_third_person_weapon_models.size()):
		_third_person_weapon_models[weapon_index].visible = should_show_rig and weapon_index == player.get_active_weapon_index()


func should_update_third_person_visual(player) -> bool:
	if not player.is_local_controlled():
		return true
	if not player.is_debug_first_person_view():
		return true

	var body_visible: bool = player.body_mesh != null and player.body_mesh.visible
	var weapon_rig_visible: bool = player.third_person_weapon_rig != null and player.third_person_weapon_rig.visible
	return body_visible or weapon_rig_visible


func update_third_person_visual(player, delta: float) -> void:
	var horizontal_speed: float = Vector2(player.velocity.x, player.velocity.z).length()
	var speed_ratio: float = clampf(horizontal_speed / maxf(player.run_speed, THIRD_PERSON_SPEED_EPSILON), 0.0, 1.0)
	var stride_frequency: float = lerpf(player.body_breath_frequency, 6.0, speed_ratio)
	_body_motion_time += delta * stride_frequency

	var breath_wave: float = sin(_body_motion_time * TAU)
	var walk_wave: float = sin(_body_motion_time * TAU * 1.35)
	var lateral_wave: float = cos(_body_motion_time * TAU * 0.675)
	var local_velocity: Vector3 = player.global_transform.basis.inverse() * player.velocity
	var strafe_ratio: float = clampf(local_velocity.x / maxf(player.run_speed, THIRD_PERSON_SPEED_EPSILON), -1.0, 1.0)
	var forward_ratio: float = clampf(-local_velocity.z / maxf(player.run_speed, THIRD_PERSON_SPEED_EPSILON), -1.0, 1.0)
	var body_offset: Vector3 = _calculate_body_offset(player, breath_wave, walk_wave, speed_ratio)
	var body_rotation: Vector3 = _calculate_body_rotation(player, strafe_ratio, forward_ratio, lateral_wave, speed_ratio)

	_update_limb_animation(player, speed_ratio, walk_wave)
	_apply_body_visual_transform(player, body_offset, body_rotation)
	_apply_weapon_rig_transform(player, body_offset, strafe_ratio, speed_ratio)


func _calculate_body_offset(player, breath_wave: float, walk_wave: float, speed_ratio: float) -> Vector3:
	var body_offset := Vector3(0.0, breath_wave * player.body_breath_amount, 0.0)
	body_offset.y += absf(walk_wave) * player.body_walk_bob_amount * speed_ratio
	return body_offset


func _calculate_body_rotation(player, strafe_ratio: float, forward_ratio: float, lateral_wave: float, speed_ratio: float) -> Vector3:
	return Vector3(
		deg_to_rad(forward_ratio * player.body_walk_roll_degrees * 0.35 * speed_ratio),
		0.0,
		deg_to_rad((-strafe_ratio * player.body_walk_roll_degrees) + lateral_wave * player.body_walk_roll_degrees * 0.18 * speed_ratio)
	)


func _apply_body_visual_transform(player, body_offset: Vector3, body_rotation: Vector3) -> void:
	if player.body_visual != null:
		player.body_visual.transform = Transform3D(
			_body_visual_default_transform.basis * Basis.from_euler(body_rotation),
			_body_visual_default_transform.origin + body_offset
		)


func _apply_weapon_rig_transform(player, body_offset: Vector3, strafe_ratio: float, speed_ratio: float) -> void:
	if player.third_person_weapon_rig == null:
		return

	var pitch_radians: float = deg_to_rad(clampf(
		player.camera_pivot.rotation_degrees.x,
		-MAX_REMOTE_AIM_PITCH_DEGREES,
		MAX_REMOTE_AIM_PITCH_DEGREES
	))
	var aim_blend: float = 1.0 if player.is_aiming() else 0.0
	var rig_offset: Vector3 = _calculate_weapon_rig_offset(player, body_offset, aim_blend)
	var rig_sway: Vector3 = _calculate_weapon_rig_sway(pitch_radians, strafe_ratio, speed_ratio)
	player.third_person_weapon_rig.transform = Transform3D(
		_third_person_weapon_default_transform.basis * Basis.from_euler(rig_sway),
		_third_person_weapon_default_transform.origin + rig_offset
	)


func _calculate_weapon_rig_offset(player, body_offset: Vector3, aim_blend: float) -> Vector3:
	return Vector3(
		lerpf(0.0, -player.third_person_aim_offset * 0.25, aim_blend),
		body_offset.y * 0.35 + lerpf(0.0, player.third_person_aim_offset * 0.15, aim_blend),
		lerpf(0.0, -player.third_person_aim_offset, aim_blend)
	)


func _calculate_weapon_rig_sway(pitch_radians: float, strafe_ratio: float, speed_ratio: float) -> Vector3:
	return Vector3(
		pitch_radians * 0.65,
		deg_to_rad(strafe_ratio * 4.0 * speed_ratio),
		deg_to_rad(-strafe_ratio * 5.0 * speed_ratio)
	)


func apply_body_material(node: Node, material: Material) -> void:
	if node is MeshInstance3D:
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if _should_tint_body_mesh(mesh_instance):
			mesh_instance.material_override = material
	for child in node.get_children():
		apply_body_material(child, material)


func _cache_third_person_weapon_rig(player) -> void:
	if player.body_visual != null:
		_body_visual_default_transform = player.body_visual.transform

	_third_person_weapon_models.clear()
	if player.third_person_weapon_rig == null:
		return

	_third_person_weapon_default_transform = player.third_person_weapon_rig.transform
	for child in player.third_person_weapon_rig.get_children():
		if child is Node3D:
			_third_person_weapon_models.append(child)


func _cache_limb_bones(player) -> void:
	_limb_bone_indices.clear()
	_limb_rest_rotations.clear()
	if player.character_skeleton == null:
		return

	for limb_name in LIMB_BONE_NAMES.keys():
		var bone_index: int = player.character_skeleton.find_bone(String(LIMB_BONE_NAMES[limb_name]))
		if bone_index < 0:
			continue
		_limb_bone_indices[limb_name] = bone_index
		_limb_rest_rotations[limb_name] = player.character_skeleton.get_bone_pose_rotation(bone_index)


func _update_limb_animation(player, speed_ratio: float, walk_wave: float) -> void:
	if player.character_skeleton == null or _limb_bone_indices.is_empty():
		return

	var jump_tuck: float = clampf(absf(player.velocity.y) / maxf(player.jump_velocity, THIRD_PERSON_SPEED_EPSILON), 0.0, 1.0)
	if player.is_on_floor():
		jump_tuck = 0.0
	var swing: float = deg_to_rad(player.leg_swing_degrees) * speed_ratio
	var tuck: float = deg_to_rad(player.leg_jump_tuck_degrees) * jump_tuck
	var left_angle: float = walk_wave * swing + tuck
	var right_angle: float = -walk_wave * swing + tuck

	_apply_limb_pose(player.character_skeleton, LIMB_LEFT_UPPER, Vector3.RIGHT, left_angle)
	_apply_limb_pose(player.character_skeleton, LIMB_RIGHT_UPPER, Vector3.RIGHT, right_angle)
	_apply_limb_pose(player.character_skeleton, LIMB_LEFT_LOWER, Vector3.RIGHT, -left_angle * 0.45 - tuck * 0.25)
	_apply_limb_pose(player.character_skeleton, LIMB_RIGHT_LOWER, Vector3.RIGHT, -right_angle * 0.45 - tuck * 0.25)
	_apply_limb_pose(player.character_skeleton, LIMB_LEFT_FOOT, Vector3.RIGHT, -left_angle * 0.25)
	_apply_limb_pose(player.character_skeleton, LIMB_RIGHT_FOOT, Vector3.RIGHT, -right_angle * 0.25)


func _apply_limb_pose(character_skeleton: Skeleton3D, limb_name: String, axis: Vector3, angle: float) -> void:
	if not _limb_bone_indices.has(limb_name) or not _limb_rest_rotations.has(limb_name):
		return

	var bone_index: int = int(_limb_bone_indices[limb_name])
	var rest_rotation: Quaternion = _limb_rest_rotations[limb_name] as Quaternion
	character_skeleton.set_bone_pose_rotation(bone_index, rest_rotation * Quaternion(axis, angle))


func _should_tint_body_mesh(mesh_instance: MeshInstance3D) -> bool:
	var mesh: Mesh = mesh_instance.mesh
	if mesh == null:
		return true

	for surface_index in range(mesh.get_surface_count()):
		var surface_material: Material = mesh.surface_get_material(surface_index)
		if surface_material != null and surface_material.resource_name.begins_with(AUTO_IMPORTED_MATERIAL_PREFIX):
			return false
	return true
