class_name EffectPrismTrap
extends "res://systems/upgrades/upgrade_effect.gd"
## Returning blade leaves a prism crystal; melee near it splits into rays.


func apply(host: Node) -> void:
	var economy = host.get("active_economy")
	if economy != null and economy.has_method("enable_prism_trap"):
		economy.call("enable_prism_trap")


func remove(host: Node) -> void:
	var economy = host.get("active_economy")
	if economy != null:
		economy.set("spawn_crystal_on_return", false)


func on_melee_hit(host: Node, _target: Node) -> void:
	if host is not Node2D:
		return
	var origin := (host as Node2D).global_position
	var parent := host.get_parent()
	if parent == null:
		return
	for child in parent.get_children():
		if child.is_in_group("prism_crystal") and child.has_method("try_split_from_melee"):
			child.call("try_split_from_melee", origin, 78.0)
