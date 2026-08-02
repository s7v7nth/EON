class_name EffectCounterCharge
extends "res://systems/upgrades/upgrade_effect.gd"
## Perfect dodge opens a counter window and restores energy.

@export var window: float = 0.75
@export var damage_bonus: float = 1.35
@export var energy_restore: float = 15.0


func on_perfect_dodge(host: Node, _source: Node) -> void:
	host.set("counter_window", window)
	host.set("counter_damage_bonus", damage_bonus)
	var energy = host.get("energy")
	if energy and energy.has_method("get_max_energy"):
		energy.current_energy = minf(
			float(energy.current_energy) + energy_restore,
			float(energy.call("get_max_energy"))
		)
		if energy.has_signal("energy_changed"):
			energy.emit_signal("energy_changed", energy.current_energy, energy.call("get_max_energy"))
