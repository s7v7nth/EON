class_name EconomyOverheat
extends "res://systems/economy/resource_economy.gd"
## Locomotive: Heat meter. Yellow 50%+ = ×1.5 + burn; Red 100% = ×2 + self-burn.
## Special (Vent) dumps heat into an AoE and locks weapons briefly.

@export var heat_max: float = 100.0
@export var heat_gain_per_action: float = 16.0
@export var heat_decay_per_sec: float = 16.0
@export var yellow_threshold: float = 50.0
@export var yellow_damage_mult: float = 1.5
@export var red_damage_mult: float = 2.0
@export var red_self_dps: float = 1.6
@export var vent_base_damage: float = 20.0
@export var vent_radius: float = 120.0
@export var vent_cooldown_base: float = 0.6
@export var vent_cooldown_per_heat: float = 0.02

var heat: float = 0.0
var _weapon_lock: float = 0.0


func _init() -> void:
	policy = GameplayEnums.EconomyPolicy.OVERHEAT


func on_equip(host: Node) -> void:
	heat = 0.0
	_weapon_lock = 0.0
	var energy: EnergyComponent = host.get("energy") as EnergyComponent
	if energy:
		energy.unlock_regen(0.8)


func on_unequip(_host: Node) -> void:
	heat = 0.0
	_weapon_lock = 0.0


func tick(host: Node, delta: float) -> void:
	if _weapon_lock > 0.0:
		_weapon_lock = maxf(0.0, _weapon_lock - delta)
	var health: HealthComponent = host.get("health") as HealthComponent
	if heat >= heat_max and health:
		health.take_damage(red_self_dps * delta)
	elif heat > 0.0:
		heat = maxf(heat - heat_decay_per_sec * delta, 0.0)
	_paint_heat_aura(host)


func is_action_locked(_host: Node) -> bool:
	return _weapon_lock > 0.0


func can_afford(host: Node, action: StringName, _cost: float = 0.0) -> bool:
	if action == &"special":
		return heat > 0.0 and _weapon_lock <= 0.0
	return not is_action_locked(host)


func spend(host: Node, action: StringName, _cost: float = 0.0) -> bool:
	if action == &"special":
		return can_afford(host, action)
	if is_action_locked(host):
		return false
	if action == &"attack" or action == &"ranged" or action == &"dash" or action == &"parry":
		_gain_heat()
		if action == &"dash":
			var energy: EnergyComponent = host.get("energy") as EnergyComponent
			var stats: CharacterStats = host.get("stats") as CharacterStats
			var dash_mult := float(host.get("dash_cost_multiplier")) if host.get("dash_cost_multiplier") != null else 1.0
			if energy and stats:
				energy.try_spend(stats.dash_cost * dash_mult * 0.5)
		return true
	return true


func damage_multiplier(_host: Node) -> float:
	if heat >= heat_max:
		return red_damage_mult
	if heat >= yellow_threshold:
		return yellow_damage_mult
	return 1.0


func on_hit(_host: Node, target: Node) -> void:
	if heat < yellow_threshold or target == null:
		return
	var body := target.get_parent() if target is HurtboxComponent else target
	if body == null:
		return
	var status: StatusComponent = body.get_node_or_null("StatusComponent") as StatusComponent
	if status == null:
		status = body.get("status") as StatusComponent
	if status:
		var power := 4.0 if heat < heat_max else 7.0
		status.apply_status(StatusComponent.STATUS_BURN, power, 1.8)


func try_special(host: Node) -> bool:
	if not can_afford(host, &"special"):
		return false
	var dumped := heat
	var ratio := dumped / heat_max if heat_max > 0.0 else 0.0
	_vent_blast(host, dumped, ratio)
	heat = 0.0
	_weapon_lock = vent_cooldown_base + dumped * vent_cooldown_per_heat
	if host.has_method("grant_iframes"):
		host.call("grant_iframes", 0.55)
	var status: StatusComponent = host.get("status") as StatusComponent
	if status:
		status.remove_status(StatusComponent.STATUS_BURN)
		status.remove_status(StatusComponent.STATUS_ACID)
	var attack_cd: Timer = host.get("attack_cooldown") as Timer
	var ranged_cd: Timer = host.get("ranged_cooldown") as Timer
	if attack_cd:
		attack_cd.start(_weapon_lock)
	if ranged_cd:
		ranged_cd.start(_weapon_lock)
	SignalBus.vent_triggered.emit(host)
	SignalBus.special_triggered.emit(host)
	return true


func restore(_host: Node, amount: float) -> void:
	heat = maxf(heat - amount, 0.0)


func get_hud_values(_host: Node) -> Dictionary:
	var color := Color(0.45, 0.75, 1.0, 1)
	if heat >= heat_max:
		color = Color(1.0, 0.25, 0.15, 1)
	elif heat >= yellow_threshold:
		color = Color(1.0, 0.75, 0.15, 1)
	return {
		"primary": _bar(heat, heat_max, "Heat", color),
		"secondary": _bar(
			_weapon_lock,
			maxf(vent_cooldown_base + heat_max * vent_cooldown_per_heat, 0.01),
			"Vent CD" if _weapon_lock > 0.0 else "Vent ready",
			Color(0.7, 0.85, 1.0, 1)
		),
	}


func _gain_heat() -> void:
	heat = minf(heat + heat_gain_per_action, heat_max)


func _paint_heat_aura(host: Node) -> void:
	var cv: CombatVisualComponent = host.get("combat_visual") as CombatVisualComponent
	if cv == null or cv.aura == null:
		return
	if heat >= heat_max:
		cv.aura.color = Color(1.0, 0.22, 0.12, 0.58)
		cv.aura.visible = true
	elif heat >= yellow_threshold:
		cv.aura.color = Color(1.0, 0.72, 0.12, 0.42)
		cv.aura.visible = true
	elif heat > 8.0:
		cv.aura.color = Color(0.45, 0.75, 1.0, 0.28)
		cv.aura.visible = true


func _vent_blast(host: Node, dumped: float, ratio: float) -> void:
	var parent := host.get_parent()
	if parent == null or host is not Node2D:
		return
	var origin := (host as Node2D).global_position
	var base_mult := float(host.get("damage_multiplier")) if host.get("damage_multiplier") != null else 1.0
	var dmg := (vent_base_damage + dumped * 0.55) * base_mult
	for child in parent.get_children():
		if child is not Node2D or not child.has_method("apply_knockback"):
			continue
		var enemy := child as Node2D
		if origin.distance_to(enemy.global_position) > vent_radius * (0.7 + 0.3 * ratio):
			continue
		var health: HealthComponent = child.get("health") as HealthComponent
		if health:
			health.take_damage(dmg)
		var status: StatusComponent = child.get("status") as StatusComponent
		if status:
			status.apply_status(StatusComponent.STATUS_BURN, 8.0 * ratio, 2.2)
		child.call(
			"apply_knockback",
			(enemy.global_position - origin).normalized(),
			200.0 + 180.0 * ratio
		)
	if host is Node2D:
		HitVFX.spawn_optic_burst(
			(host as Node2D).get_parent(),
			origin,
			Color(1.0, 0.45, 0.12, 1),
			Vector2.UP,
			1.2 + ratio
		)
		HitVFX.spawn_optic_ring(
			(host as Node2D).get_parent(),
			origin,
			Color(1.0, 0.55, 0.15, 0.9),
			1.1 + ratio
		)
