class_name EffectDamageMult
extends "res://systems/upgrades/upgrade_effect.gd"
## Multiplies outgoing damage while equipped.

@export var mult: float = 1.15


func damage_multiplier(_host: Node) -> float:
	return mult
