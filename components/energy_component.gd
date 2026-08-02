class_name EnergyComponent
extends Node
## Spendable energy pool. Regen via rate*mult or absolute override (adrenaline).

@export var stats: CharacterStats

var current_energy: float = 0.0
var regen_multiplier: float = 1.0
## When >= 0, used instead of stats.energy_regen_rate * multiplier.
var absolute_regen_rate: float = -1.0
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
	var regen := 0.0
	if absolute_regen_rate >= 0.0:
		regen = absolute_regen_rate * delta
	else:
		regen = stats.energy_regen_rate * regen_multiplier * delta
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


func restore(amount: float) -> void:
	if amount <= 0.0 or stats == null:
		return
	current_energy = minf(current_energy + amount, stats.max_energy)
	energy_changed.emit(current_energy, stats.max_energy)


## Absorb up to `damage` from the energy pool. Returns leftover damage for HP.
func absorb_damage(damage: float) -> float:
	if damage <= 0.0:
		return 0.0
	var absorbed := minf(current_energy, damage)
	if absorbed > 0.0:
		current_energy -= absorbed
		energy_changed.emit(current_energy, stats.max_energy)
	return damage - absorbed


func set_regen_multiplier(mult: float) -> void:
	if not allow_external_regen_mult:
		return
	regen_multiplier = maxf(mult, 0.0)


func set_absolute_regen(rate: float) -> void:
	if not allow_external_regen_mult:
		return
	absolute_regen_rate = maxf(rate, 0.0)


func clear_absolute_regen() -> void:
	absolute_regen_rate = -1.0


func lock_regen(mult: float = 0.0) -> void:
	allow_external_regen_mult = false
	regen_multiplier = maxf(mult, 0.0)
	absolute_regen_rate = -1.0


func unlock_regen(mult: float = 1.0) -> void:
	allow_external_regen_mult = true
	regen_multiplier = maxf(mult, 0.0)


func get_max_energy() -> float:
	return stats.max_energy if stats else 0.0
