class_name HealthPickup
extends PickupBase

@export_range(1, 200) var heal_amount: int = 25


func apply_to_player(player: PlayerController) -> bool:
	if player == null:
		return false
	return player.heal(heal_amount)


func can_apply_to_player(player: PlayerController) -> bool:
	return player != null and player.health != null and not player.health.is_dead and player.health.current_health < player.health.max_health


func get_interaction_prompt(player: PlayerController) -> String:
	if not can_apply_to_player(player):
		return "VIDA LLENA"
	return "MANTENER E"
