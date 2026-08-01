class_name EnergyComponent
extends Node
## Spendable energy pool with passive regen. Adrenaline can raise regen_multiplier.

@export var stats: CharacterStats

var current_energy: float = 0.0
var regen_multiplier: float = 1.0
## When false, Adrenaline/external systems cannot raise regen (nano swarm).
var allow_external_regen_mult: bool = true

signal energy_changed(current: float, max_value: float)


func _ready() -> void:
	if stats == null:
		push_error("%s: CharacterStats is required" % name)
		return
	current_energy = stats.max_energy
	energy_changed.emit(current_energy, stats.max_energy)


func _process(delta: float) -> void:
	if stats == null:
		return
	if current_energy >= stats.max_energy:
		return
	var regen := stats.energy_regen_rate * regen_multiplier * delta
	if regen <= 0.0:
		return
	current_energy = minf(current_energy + regen, stats.max_energy)
	energy_changed.emit(current_energy, stats.max_energy)


func try_spend(amount: float) -> bool:
	if amount <= 0.0:
		return true
	if current_energy < amount:
		return false
	current_energy -= amount
	energy_changed.emit(current_energy, stats.max_energy)
	return true


func set_regen_multiplier(mult: float) -> void:
	if not allow_external_regen_mult:
		return
	regen_multiplier = maxf(mult, 0.0)


func lock_regen(mult: float = 0.0) -> void:
	allow_external_regen_mult = false
	regen_multiplier = maxf(mult, 0.0)


func unlock_regen(mult: float = 1.0) -> void:
	allow_external_regen_mult = true
	regen_multiplier = maxf(mult, 0.0)


func get_max_energy() -> float:
	return stats.max_energy if stats else 0.0
