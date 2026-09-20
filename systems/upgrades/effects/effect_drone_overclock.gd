class_name EffectDroneOverclock
extends "res://systems/upgrades/upgrade_effect.gd"
## Neuro craft: drones hit harder and move faster.

@export var damage_mult: float = 1.4
@export var speed_mult: float = 1.25


func apply(host: Node) -> void:
	var economy = host.get("active_economy")
	if economy and economy.has_method("boost_drones"):
		economy.call("boost_drones", damage_mult, speed_mult, 0.0)


func remove(host: Node) -> void:
	var economy = host.get("active_economy")
	if economy and economy.has_method("boost_drones"):
		economy.call("boost_drones", 1.0 / maxf(damage_mult, 0.01), 1.0 / maxf(speed_mult, 0.01), 0.0)
