class_name HealthComponent
extends Node
## Owns current HP. Emits signals; does not know about the owner entity.

@export var stats: CharacterStats

var current_health: float = 0.0
## Last HP change kind for HUD chips: hurt / fuel / heal.
var last_reason: StringName = StringName()

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
	if amount >= current_health:
		var owner_node := get_parent()
		if owner_node != null and owner_node.has_method("try_prevent_death"):
			if bool(owner_node.call("try_prevent_death", amount)):
				return
	last_reason = &"hurt"
	current_health = maxf(current_health - amount, 0.0)
	health_changed.emit(current_health, get_max_health())
	if current_health <= 0.0:
		died.emit()


func heal(amount: float) -> void:
	if amount <= 0.0 or current_health <= 0.0:
		return
	var mx := get_max_health()
	if current_health >= mx:
		return
	last_reason = &"heal"
	current_health = minf(current_health + amount, mx)
	health_changed.emit(current_health, mx)


func spend_as_fuel(amount: float, floor_hp: float = 0.0) -> void:
	if amount <= 0.0 or current_health <= 0.0:
		return
	last_reason = &"fuel"
	current_health = maxf(current_health - amount, maxf(floor_hp, 0.0))
	health_changed.emit(current_health, get_max_health())


func get_max_health() -> float:
	var bonus := 0.0
	var owner_node := get_parent()
	if owner_node != null and "bonus_max_health" in owner_node:
		bonus = float(owner_node.bonus_max_health)
	return (stats.max_health if stats else 0.0) + bonus


func set_bonus_max(bonus: float) -> void:
	var prev := get_max_health()
	var owner_node := get_parent()
	if owner_node:
		owner_node.set("bonus_max_health", maxf(bonus, 0.0))
	var now := get_max_health()
	if now > prev and current_health > 0.0:
		current_health += now - prev
	elif current_health > now and now > 0.0:
		current_health = now
	health_changed.emit(current_health, now)


func apply_stats(new_stats: CharacterStats) -> void:
	stats = new_stats
	if stats == null:
		return
	current_health = stats.max_health
	health_changed.emit(current_health, stats.max_health)
