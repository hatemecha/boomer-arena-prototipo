class_name AmmoPickup
extends PickupBase

@export_range(1, 300) var ammo_amount: int = 30


func apply_to_player(player: PlayerController) -> bool:
	if player == null:
		return false
	return player.add_ammo(ammo_amount)
