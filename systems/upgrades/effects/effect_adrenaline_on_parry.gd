class_name EffectAdrenalineOnParry
extends "res://systems/upgrades/upgrade_effect.gd"
## Synthetic craft: parries dump extra adrenaline.

@export var adrenaline_bonus: float = 18.0


func on_parry(host: Node, _source: Node) -> void:
	var adrenaline = host.get("adrenaline")
	if adrenaline and adrenaline.has_method("add"):
		adrenaline.call("add", adrenaline_bonus)
