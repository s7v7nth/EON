class_name EffectPrismChain
extends "res://systems/upgrades/upgrade_effect.gd"
## Synthetic craft: blade chains mirror→mirror with stacking ricochet damage.

@export var max_bounces: int = 3
@export var extra_bounce_mult: float = 1.25


func apply(host: Node) -> void:
	_apply_to_economy(host)


func remove(host: Node) -> void:
	var economy = host.get("active_economy")
	if economy != null and economy.has_method("set_prism_chain"):
		# Restore baseline Geometry bounce budget.
		economy.call("set_prism_chain", 1, 1.25)


func _apply_to_economy(host: Node) -> void:
	var economy = host.get("active_economy")
	if economy != null and economy.has_method("set_prism_chain"):
		economy.call("set_prism_chain", max_bounces, extra_bounce_mult)
