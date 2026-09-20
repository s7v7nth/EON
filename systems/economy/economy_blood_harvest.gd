class_name EconomyBloodHarvest
extends "res://systems/economy/resource_economy.gd"
## Hive: no energy. Passive HP drain fuels the swarm; hits/kills restore HP.

@export var hp_drain_percent_per_sec: float = 0.03
@export var life_steal: float = 0.14
@export var heal_on_kill: float = 8.0
@export var dash_hp_cost_percent: float = 0.04
@export var special_hp_cost_percent: float = 0.12
@export var special_radius: float = 100.0
@export var special_damage: float = 14.0
@export var min_hp_from_drain: float = 1.0


func _init() -> void:
	policy = GameplayEnums.EconomyPolicy.BLOOD_HARVEST


func on_equip(host: Node) -> void:
	var energy: EnergyComponent = host.get("energy") as EnergyComponent
	if energy:
		energy.lock_regen(0.0)
		energy.current_energy = 0.0
		energy.energy_changed.emit(0.0, energy.get_max_energy())


func on_unequip(host: Node) -> void:
	var energy: EnergyComponent = host.get("energy") as EnergyComponent
	if energy:
		energy.unlock_regen(1.0)


func tick(host: Node, delta: float) -> void:
	var health: HealthComponent = host.get("health") as HealthComponent
	if health == null:
		return
	var max_hp := health.get_max_health()
	if max_hp <= 0.0 or health.current_health <= min_hp_from_drain:
		return
	var drain := max_hp * hp_drain_percent_per_sec * delta
	health.current_health = maxf(health.current_health - drain, min_hp_from_drain)
	health.health_changed.emit(health.current_health, max_hp)


func can_afford(host: Node, action: StringName, _cost: float = 0.0) -> bool:
	var health: HealthComponent = host.get("health") as HealthComponent
	if health == null:
		return false
	var max_hp := health.get_max_health()
	match action:
		&"dash":
			return health.current_health > max_hp * dash_hp_cost_percent + min_hp_from_drain
		&"special":
			return health.current_health > max_hp * special_hp_cost_percent + min_hp_from_drain
		_:
			return true


func spend(host: Node, action: StringName, _cost: float = 0.0) -> bool:
	if not can_afford(host, action, _cost):
		return false
	match action:
		&"dash":
			_spend_hp_percent(host, dash_hp_cost_percent)
		&"special":
			_spend_hp_percent(host, special_hp_cost_percent)
		_:
			pass
	return true


func on_hit(host: Node, _target: Node) -> void:
	var health: HealthComponent = host.get("health") as HealthComponent
	if health == null or life_steal <= 0.0:
		return
	health.heal(4.0 * life_steal * 10.0)


func on_kill(host: Node, _enemy: Node) -> void:
	var health: HealthComponent = host.get("health") as HealthComponent
	if health and heal_on_kill > 0.0:
		health.heal(heal_on_kill)


func restore(host: Node, amount: float) -> void:
	var health: HealthComponent = host.get("health") as HealthComponent
	if health:
		health.heal(amount)


func try_special(host: Node) -> bool:
	if not spend(host, &"special"):
		return false
	var parent := host.get_parent()
	if parent == null or host is not Node2D:
		SignalBus.special_triggered.emit(host)
		return true
	var origin := (host as Node2D).global_position
	var dmg_mult := 1.0
	if host.has_method("effective_damage_multiplier"):
		dmg_mult = float(host.call("effective_damage_multiplier"))
	for child in parent.get_children():
		if child is not Node2D or not child.has_method("apply_knockback"):
			continue
		var enemy := child as Node2D
		if origin.distance_to(enemy.global_position) > special_radius:
			continue
		var health: HealthComponent = child.get("health") as HealthComponent
		if health:
			health.take_damage(special_damage * dmg_mult)
		var status: StatusComponent = child.get("status") as StatusComponent
		if status:
			status.apply_status(StatusComponent.STATUS_ACID, 6.0, 2.0)
	if host is Node2D:
		HitVFX.spawn_optic_burst(
			(host as Node2D).get_parent(),
			(host as Node2D).global_position,
			Color(0.35, 0.95, 0.4, 1),
			Vector2.UP,
			1.35
		)
		HitVFX.spawn_optic_ring(
			(host as Node2D).get_parent(),
			(host as Node2D).global_position,
			Color(0.4, 1.0, 0.45, 0.9),
			1.4
		)
	SignalBus.special_triggered.emit(host)
	return true


func get_hud_values(host: Node) -> Dictionary:
	var health: HealthComponent = host.get("health") as HealthComponent
	var hp_v := health.current_health if health else 0.0
	var hp_m := health.get_max_health() if health else 100.0
	var pressure := 0.0
	if hp_m > 0.0:
		pressure = (1.0 - hp_v / hp_m) * 100.0
	return {
		"primary": _bar(pressure, 100.0, "Swarm Hunger", Color(0.35, 0.85, 0.45, 1)),
		"secondary": {},
	}


func _spend_hp_percent(host: Node, percent: float) -> void:
	var health: HealthComponent = host.get("health") as HealthComponent
	if health == null:
		return
	var max_hp := health.get_max_health()
	health.current_health = maxf(health.current_health - max_hp * percent, min_hp_from_drain)
	health.health_changed.emit(health.current_health, max_hp)
