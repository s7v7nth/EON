class_name EconomyAdrenaline
extends "res://systems/economy/resource_economy.gd"
## Synthetic: basics free + generate adrenaline; specials spend Energy.

@export var special_energy_cost: float = 28.0
@export var special_radius: float = 90.0
@export var special_damage: float = 18.0
@export var adrenaline_on_basic: float = 6.0
@export var max_attack_speed_bonus: float = 0.55


func _init() -> void:
	policy = GameplayEnums.EconomyPolicy.ENERGY_ADRENALINE


func on_equip(host: Node) -> void:
	var energy: EnergyComponent = host.get("energy") as EnergyComponent
	if energy:
		energy.unlock_regen(1.0)


func can_afford(host: Node, action: StringName, cost: float = 0.0) -> bool:
	var energy: EnergyComponent = host.get("energy") as EnergyComponent
	if action == &"special":
		return energy != null and energy.current_energy >= special_energy_cost
	if action == &"attack" or action == &"ranged" or action == &"dash" or action == &"parry":
		return true
	if cost <= 0.0:
		return true
	return energy != null and energy.current_energy >= cost


func spend(host: Node, action: StringName, cost: float = 0.0) -> bool:
	if not can_afford(host, action, cost):
		return false
	var energy: EnergyComponent = host.get("energy") as EnergyComponent
	if action == &"special":
		return energy != null and energy.try_spend(special_energy_cost)
	if action == &"attack" or action == &"ranged" or action == &"dash" or action == &"parry":
		var adrenaline: AdrenalineComponent = host.get("adrenaline") as AdrenalineComponent
		if adrenaline:
			adrenaline.add(adrenaline_on_basic)
		return true
	if cost > 0.0 and energy:
		return energy.try_spend(cost)
	return true


func attack_speed_multiplier(host: Node) -> float:
	var adrenaline: AdrenalineComponent = host.get("adrenaline") as AdrenalineComponent
	if adrenaline == null:
		return 1.0
	var max_a := adrenaline.get_max_adrenaline()
	if max_a <= 0.0:
		return 1.0
	return 1.0 + max_attack_speed_bonus * (adrenaline.current_adrenaline / max_a)


func try_special(host: Node) -> bool:
	if not spend(host, &"special"):
		return false
	_reactor_pulse(host)
	SignalBus.special_triggered.emit(host)
	return true


func get_hud_values(host: Node) -> Dictionary:
	var energy: EnergyComponent = host.get("energy") as EnergyComponent
	var adrenaline: AdrenalineComponent = host.get("adrenaline") as AdrenalineComponent
	var energy_v := energy.current_energy if energy else 0.0
	var energy_m := energy.get_max_energy() if energy else 100.0
	var adr_v := adrenaline.current_adrenaline if adrenaline else 0.0
	var adr_m := adrenaline.get_max_adrenaline() if adrenaline else 100.0
	return {
		"primary": _bar(energy_v, energy_m, "Energy", Color(0.25, 0.55, 0.95, 1)),
		"secondary": _bar(adr_v, adr_m, "Adrenaline", Color(0.95, 0.8, 0.2, 1)),
	}


func _reactor_pulse(host: Node) -> void:
	var parent := host.get_parent()
	if parent == null or host is not Node2D:
		return
	var origin := (host as Node2D).global_position
	var dmg_mult := 1.0
	if host.has_method("effective_damage_multiplier"):
		dmg_mult = float(host.call("effective_damage_multiplier"))
	for child in parent.get_children():
		if not child.has_method("apply_knockback"):
			continue
		if child is not Node2D:
			continue
		var enemy := child as Node2D
		if origin.distance_to(enemy.global_position) > special_radius:
			continue
		var health: HealthComponent = child.get("health") as HealthComponent
		if health:
			health.take_damage(special_damage * dmg_mult)
		child.call("apply_knockback", (enemy.global_position - origin).normalized(), 260.0)
