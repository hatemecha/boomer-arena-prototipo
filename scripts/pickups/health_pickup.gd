class_name HealthPickup
extends PickupBase

@export_range(1, 200) var heal_amount: int = 25


func apply_to_player(player: PlayerController) -> bool:
	if player == null:
		return false
	return player.heal(heal_amount)
