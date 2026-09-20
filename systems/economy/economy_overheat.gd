class_name EconomyOverheat
extends "res://systems/economy/resource_economy.gd"
## Locomotive: Heat meter. Yellow 50%+ = ×1.5 + burn; Red 100% = ×2 + self-burn.
## Special (Vent) dumps heat into an AoE and locks weapons briefly.

@export var heat_max: float = 100.0
@export var heat_gain_per_action: float = 14.0
@export var heat_decay_per_sec: float = 3.2
@export var yellow_threshold: float = 50.0
@export var yellow_damage_mult: float = 1.5
@export var red_damage_mult: float = 2.0
@export var red_self_dps: float = 0.8
@export var vent_base_damage: float = 20.0
@export var vent_radius: float = 120.0
@export var vent_cooldown_base: float = 0.6
@export var vent_cooldown_per_heat: float = 0.02

var heat: float = 0.0
var _weapon_lock: float = 0.0
var _stack: Node2D
var _vent_fx: float = 0.0
var _stack_t: float = 0.0


func _init() -> void:
	policy = GameplayEnums.EconomyPolicy.OVERHEAT


func on_equip(host: Node) -> void:
	heat = 0.0
	_weapon_lock = 0.0
	_vent_fx = 0.0
	var energy: EnergyComponent = host.get("energy") as EnergyComponent
	if energy:
		energy.unlock_regen(0.8)
	_ensure_stack(host)


func on_unequip(host: Node) -> void:
	heat = 0.0
	_weapon_lock = 0.0
	_free_stack(host)


func tick(host: Node, delta: float) -> void:
	if _weapon_lock > 0.0:
		_weapon_lock = maxf(0.0, _weapon_lock - delta)
	if _vent_fx > 0.0:
		_vent_fx = maxf(0.0, _vent_fx - delta)
	var health: HealthComponent = host.get("health") as HealthComponent
	if heat >= heat_max and health:
		health.take_damage(red_self_dps * delta)
	elif heat > 0.0:
		var decay := heat_decay_per_sec
		if heat >= yellow_threshold:
			decay *= 0.35
		heat = maxf(heat - decay * delta, 0.0)
	_paint_heat_aura(host)
	_spin_stack(host, delta)


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
	_vent_fx = 0.7
	_weapon_lock = vent_cooldown_base + dumped * vent_cooldown_per_heat
	if host.has_method("grant_iframes"):
		host.call("grant_iframes", 0.7)
	var health: HealthComponent = host.get("health") as HealthComponent
	if health and dumped >= yellow_threshold:
		health.heal(health.get_max_health() * 0.1)
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
	var vent_label := "Vent CD  %.1fs" % _weapon_lock if _weapon_lock > 0.0 else "Vent ready"
	return {
		"primary": _bar(heat, heat_max, "Heat  %d" % roundi(heat), color),
		"secondary": _bar(
			_weapon_lock,
			maxf(vent_cooldown_base + heat_max * vent_cooldown_per_heat, 0.01),
			vent_label,
			Color(0.7, 0.85, 1.0, 1)
		),
	}


func _gain_heat() -> void:
	heat = minf(heat + heat_gain_per_action, heat_max)


func _paint_heat_aura(host: Node) -> void:
	var cv: CombatVisualComponent = host.get("combat_visual") as CombatVisualComponent
	if cv == null:
		return
	if heat >= heat_max:
		cv.set_kit_aura(Color(1.0, 0.22, 0.12, 0.42), Vector2(1.35, 1.35), true)
	elif heat >= yellow_threshold:
		cv.set_kit_aura(Color(1.0, 0.72, 0.12, 0.34), Vector2(1.22, 1.22), true)
	elif heat > 8.0 or _vent_fx > 0.0:
		cv.set_kit_aura(Color(0.45, 0.75, 1.0, 0.22), Vector2(1.1, 1.1), true)
	else:
		cv.set_kit_aura(Color(0.45, 0.75, 1.0, 0.12), Vector2.ONE, false)


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
		DamagePop.spawn_label(
			(host as Node2D).get_parent(),
			origin + Vector2(0, -48),
			"Vent",
			Color(1.0, 0.72, 0.28, 1),
			18
		)


func _ensure_stack(host: Node) -> void:
	if host is not Node2D:
		return
	_stack = (host as Node2D).get_node_or_null("HeatStack") as Node2D
	if _stack:
		return
	_stack = Node2D.new()
	_stack.name = "HeatStack"
	_stack.z_index = 7
	(host as Node2D).add_child(_stack)
	var flame_tex := ArtBank.particle("flame_04")
	if flame_tex == null:
		flame_tex = ArtBank.particle("fire_01")
	for i in 4:
		var puff := Sprite2D.new()
		puff.name = "Puff%d" % i
		puff.texture = flame_tex
		puff.centered = true
		puff.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		puff.modulate = Color(1.0, 0.55, 0.18, 0.0)
		puff.z_index = 7
		puff.scale = Vector2(0.16, 0.16)
		_stack.add_child(puff)


func _spin_stack(host: Node, delta: float) -> void:
	if _stack == null or not is_instance_valid(_stack):
		_ensure_stack(host)
	if _stack == null:
		return
	var ratio := clampf(heat / maxf(heat_max, 1.0), 0.0, 1.0)
	if _vent_fx > 0.0:
		ratio = maxf(ratio, 0.85)
	_stack_t += delta
	var kids := _stack.get_children()
	for i in kids.size():
		var puff := kids[i] as Sprite2D
		if puff == null:
			continue
		var t := _stack_t + float(i) * 0.7
		puff.position = Vector2(sin(t * 2.2) * 6.0, -28.0 - float(i) * 10.0 - sin(t * 3.1) * 4.0)
		var a := ratio * (0.85 if heat >= yellow_threshold else 0.45)
		if heat >= heat_max:
			puff.modulate = Color(1.0, 0.28, 0.12, a)
		elif heat >= yellow_threshold or _vent_fx > 0.0:
			puff.modulate = Color(1.0, 0.72, 0.18, a)
		else:
			puff.modulate = Color(0.55, 0.8, 1.0, a * 0.6)
		puff.scale = Vector2(0.15, 0.15) * (0.8 + ratio * 0.85)
		puff.visible = ratio > 0.04


func _free_stack(host: Node) -> void:
	if _stack and is_instance_valid(_stack):
		_stack.queue_free()
	_stack = null
	if host:
		var existing := host.get_node_or_null("HeatStack")
		if existing:
			existing.queue_free()
	var cv: CombatVisualComponent = host.get("combat_visual") as CombatVisualComponent if host else null
	if cv:
		cv.set_kit_aura(Color.WHITE, Vector2.ONE, false)
