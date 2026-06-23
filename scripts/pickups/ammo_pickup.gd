class_name AmmoPickup
extends PickupBase

@export_range(1, 300) var ammo_amount: int = 30


func apply_to_player(player: PlayerController) -> bool:
	if player == null:
		return false
	return player.add_ammo(ammo_amount)


func can_apply_to_player(player: PlayerController) -> bool:
	if player == null or player.weapon == null:
		return false
	return player.weapon.can_accept_more_ammo()


func get_interaction_prompt(player: PlayerController) -> String:
	if not can_apply_to_player(player):
		return "MUNICIÓN LLENA"
	return "MANTENER E"
