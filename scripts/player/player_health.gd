class_name PlayerHealth
extends Node

signal health_changed(current_health: int, max_health: int)
signal died

@export_range(1, 500) var max_health: int = 100

var current_health: int = max_health
var is_dead: bool = false


func _ready() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)


func apply_damage(amount: int) -> void:
	if amount <= 0:
		push_warning("Damage amount must be greater than zero.")
		return
	if is_dead:
		return

	current_health = max(current_health - amount, 0)
	health_changed.emit(current_health, max_health)

	if current_health == 0:
		is_dead = true
		died.emit()


func heal(amount: int) -> bool:
	if amount <= 0:
		push_warning("Heal amount must be greater than zero.")
		return false
	if is_dead or current_health >= max_health:
		return false

	current_health = min(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)
	return true


func respawn() -> void:
	is_dead = false
	current_health = max_health
	health_changed.emit(current_health, max_health)
