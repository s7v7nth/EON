class_name EconomyAdrenaline
extends "res://systems/economy/resource_economy.gd"
## Synthetic: attacks/dash spend Energy; adrenaline drives regen; Q/F reserved.

@export var max_attack_speed_bonus: float = 0.35


func _init() -> void:
	policy = GameplayEnums.EconomyPolicy.ENERGY_ADRENALINE


func on_equip(host: Node) -> void:
	var energy: EnergyComponent = host.get("energy") as EnergyComponent
	if energy:
		energy.unlock_regen(1.0)


func can_afford(host: Node, action: StringName, cost: float = 0.0) -> bool:
	if action == &"special" or action == &"parry":
		return false
	var energy: EnergyComponent = host.get("energy") as EnergyComponent
	if action == &"attack" or action == &"ranged" or action == &"dash":
		if cost <= 0.0:
			return true
		return energy != null and energy.current_energy >= cost
	if cost <= 0.0:
		return true
	return energy != null and energy.current_energy >= cost


func spend(host: Node, action: StringName, cost: float = 0.0) -> bool:
	if not can_afford(host, action, cost):
		return false
	if action == &"special" or action == &"parry":
		return false
	var energy: EnergyComponent = host.get("energy") as EnergyComponent
	if cost > 0.0:
		return energy != null and energy.try_spend(cost)
	return true


func attack_speed_multiplier(host: Node) -> float:
	var adrenaline: AdrenalineComponent = host.get("adrenaline") as AdrenalineComponent
	if adrenaline == null:
		return 1.0
	var max_a := adrenaline.get_max_adrenaline()
	if max_a <= 0.0:
		return 1.0
	return 1.0 + max_attack_speed_bonus * (adrenaline.current_adrenaline / max_a)


func try_special(_host: Node) -> bool:
	## Q reserved for future Synthetic buttons.
	return false


func get_hud_values(host: Node) -> Dictionary:
	var energy: EnergyComponent = host.get("energy") as EnergyComponent
	var adrenaline: AdrenalineComponent = host.get("adrenaline") as AdrenalineComponent
	var energy_v := energy.current_energy if energy else 0.0
	var energy_m := energy.get_max_energy() if energy else 50.0
	var adr_v := adrenaline.current_adrenaline if adrenaline else 0.0
	var adr_m := adrenaline.get_max_adrenaline() if adrenaline else 100.0
	return {
		"primary": _bar(energy_v, energy_m, "Energy", Color(0.25, 0.55, 0.95, 1)),
		"secondary": _bar(adr_v, adr_m, "Adrenaline", Color(0.95, 0.8, 0.2, 1)),
	}
