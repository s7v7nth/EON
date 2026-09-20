class_name EffectHeatCoil
extends "res://systems/upgrades/upgrade_effect.gd"
## Coil Overdrive: damage scales with heat (rides the curve, not a flat mult).

@export var base_mult: float = 1.05
@export var yellow_bonus: float = 0.15
@export var red_bonus: float = 0.35


func damage_multiplier(host: Node) -> float:
	var econ = host.get("active_economy")
	if econ == null or not (econ is EconomyOverheat):
		return base_mult
	var heat: float = float(econ.get("heat"))
	var heat_max: float = maxf(float(econ.get("heat_max")), 1.0)
	var yellow: float = float(econ.get("yellow_threshold"))
	if heat >= heat_max:
		return base_mult + red_bonus
	if heat >= yellow:
		return base_mult + yellow_bonus * ((heat - yellow) / maxf(heat_max - yellow, 1.0))
	return base_mult
