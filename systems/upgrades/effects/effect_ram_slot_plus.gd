class_name EffectRamSlotPlus
extends "res://systems/upgrades/upgrade_effect.gd"
## Neuro craft: +1 RAM slot for drones.

@export var bonus_slots: int = 1


func apply(host: Node) -> void:
	var economy = host.get("active_economy")
	if economy and economy.has_method("add_max_slots"):
		economy.call("add_max_slots", bonus_slots)


func remove(host: Node) -> void:
	var economy = host.get("active_economy")
	if economy and economy.has_method("add_max_slots"):
		economy.call("add_max_slots", -bonus_slots)
