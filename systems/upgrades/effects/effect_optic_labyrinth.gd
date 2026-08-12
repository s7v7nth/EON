class_name EffectOpticLabyrinth
extends "res://systems/upgrades/upgrade_effect.gd"
## More Energy Mirrors + confuse aura that glitches nearby foes.


func apply(host: Node) -> void:
	var economy = host.get("active_economy")
	if economy != null and economy.has_method("set_optic_labyrinth"):
		economy.call("set_optic_labyrinth", 5)


func remove(host: Node) -> void:
	var economy = host.get("active_economy")
	if economy != null:
		economy.set("mirror_confuse", false)
		economy.set("max_mirrors", 3)
