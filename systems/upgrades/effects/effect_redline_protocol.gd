class_name EffectRedlineProtocol
extends "res://systems/upgrades/upgrade_effect.gd"
## In red heat: melee/ranged hits apply shock buildup + extra burn.

@export var shock_buildup: float = 28.0
@export var burn_power: float = 6.0
@export var burn_duration: float = 2.0


func on_melee_hit(host: Node, target: Node) -> void:
	_try_redline(host, target)


func on_ranged_hit(host: Node, target: Node) -> void:
	_try_redline(host, target)


func _try_redline(host: Node, target: Node) -> void:
	var econ = host.get("active_economy")
	if econ == null or not (econ is EconomyOverheat):
		return
	if float(econ.heat) < float(econ.heat_max):
		return
	var body := target.get_parent() if target is HurtboxComponent else target
	if body == null:
		return
	var status = body.get("status")
	if status == null:
		return
	if status.has_method("add_buildup"):
		status.call("add_buildup", &"shock", shock_buildup, 3.0)
	if status.has_method("apply_status"):
		status.call("apply_status", &"burn", burn_power, burn_duration)
