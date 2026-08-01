class_name HealthComponent
extends Node
## Owns current HP. Emits signals; does not know about the owner entity.

@export var stats: CharacterStats

var current_health: float = 0.0

signal health_changed(current: float, max_value: float)
signal died


func _ready() -> void:
	if stats == null:
		push_error("%s: CharacterStats is required" % name)
		return
	current_health = stats.max_health
	health_changed.emit(current_health, stats.max_health)


func take_damage(amount: float) -> void:
	if amount <= 0.0 or current_health <= 0.0:
		return
	current_health = maxf(current_health - amount, 0.0)
	health_changed.emit(current_health, stats.max_health)
	if current_health <= 0.0:
		died.emit()


func heal(amount: float) -> void:
	if amount <= 0.0 or current_health <= 0.0:
		return
	current_health = minf(current_health + amount, stats.max_health)
	health_changed.emit(current_health, stats.max_health)


func get_max_health() -> float:
	return stats.max_health if stats else 0.0
