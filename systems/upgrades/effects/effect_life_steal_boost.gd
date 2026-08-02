class_name EffectLifeStealBoost
extends "res://systems/upgrades/upgrade_effect.gd"
## Flat life steal / HP regen bonuses (Hive bioreactor).

@export var life_steal: float = 0.08
@export var hp_regen: float = 3.0


func apply(host: Node) -> void:
	var steal = float(host.get("_life_steal_bonus")) if host.get("_life_steal_bonus") != null else 0.0
	var regen = float(host.get("_hp_regen_bonus")) if host.get("_hp_regen_bonus") != null else 0.0
	host.set("_life_steal_bonus", steal + life_steal)
	host.set("_hp_regen_bonus", regen + hp_regen)


func remove(host: Node) -> void:
	var steal = float(host.get("_life_steal_bonus")) if host.get("_life_steal_bonus") != null else 0.0
	var regen = float(host.get("_hp_regen_bonus")) if host.get("_hp_regen_bonus") != null else 0.0
	host.set("_life_steal_bonus", maxf(steal - life_steal, 0.0))
	host.set("_hp_regen_bonus", maxf(regen - hp_regen, 0.0))
