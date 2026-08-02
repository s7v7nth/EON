class_name EffectDroneGlitchLink
extends "res://systems/upgrades/upgrade_effect.gd"
## Neuro craft: drone strikes apply glitch buildup.

@export var glitch_buildup: float = 22.0


func apply(host: Node) -> void:
	var economy = host.get("active_economy")
	if economy and economy.has_method("boost_drones"):
		economy.call("boost_drones", 1.0, 1.0, glitch_buildup)


func remove(host: Node) -> void:
	var economy = host.get("active_economy")
	if economy and economy.has_method("boost_drones"):
		economy.call("boost_drones", 1.0, 1.0, -glitch_buildup)
