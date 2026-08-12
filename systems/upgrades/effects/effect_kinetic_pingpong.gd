class_name EffectKineticPingPong
extends "res://systems/upgrades/upgrade_effect.gd"
## Walls bounce the blade; dash across a flying blade intercepts and boosts it.


func apply(host: Node) -> void:
	var economy = host.get("active_economy")
	if economy != null and economy.has_method("enable_kinetic_pingpong"):
		economy.call("enable_kinetic_pingpong")


func remove(host: Node) -> void:
	var economy = host.get("active_economy")
	if economy != null:
		economy.set("wall_bounce_enabled", false)
		economy.set("dash_blade_intercept", false)
