class_name EconomyBloodHarvest
extends "res://systems/economy/resource_economy.gd"
## Hive: no energy. Passive HP drain fuels the swarm; hits/kills restore HP.

@export var hp_drain_percent_per_sec: float = 0.03
@export var life_steal: float = 0.18
@export var heal_on_kill: float = 12.0
@export var dash_hp_cost_percent: float = 0.04
@export var special_hp_cost_percent: float = 0.06
@export var special_radius: float = 100.0
@export var special_damage: float = 14.0
@export var min_hp_from_drain: float = 8.0

var _swarm: Node2D
var _swarm_spin: float = 0.0
var _siphon: Line2D
var _last_vamp_ms: int = 0


func _init() -> void:
	policy = GameplayEnums.EconomyPolicy.BLOOD_HARVEST


func on_equip(host: Node) -> void:
	var energy: EnergyComponent = host.get("energy") as EnergyComponent
	if energy:
		energy.lock_regen(0.0)
		energy.current_energy = 0.0
		energy.energy_changed.emit(0.0, energy.get_max_energy())
	_ensure_swarm(host)


func on_unequip(host: Node) -> void:
	var energy: EnergyComponent = host.get("energy") as EnergyComponent
	if energy:
		energy.unlock_regen(1.0)
	_free_swarm(host)


func tick(host: Node, delta: float) -> void:
	_spin_swarm(host, delta)
	var health: HealthComponent = host.get("health") as HealthComponent
	if health == null:
		return
	var max_hp := health.get_max_health()
	if max_hp <= 0.0 or health.current_health <= min_hp_from_drain:
		return
	if not _enemy_in_range(host, 240.0):
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
	var healed := life_steal * 10.0
	health.heal(healed)
	var now := Time.get_ticks_msec()
	if host is Node2D and now - _last_vamp_ms > 220:
		_last_vamp_ms = now
		DamagePop.spawn_label(
			(host as Node2D).get_parent(),
			(host as Node2D).global_position + Vector2(0, -42),
			"+HP",
			Color(0.35, 1.0, 0.48, 1),
			15
		)


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
		"primary": _bar(pressure, 100.0, "Swarm Hunger  %d" % roundi(pressure), Color(0.35, 0.85, 0.45, 1)),
		"secondary": {},
	}


func _spend_hp_percent(host: Node, percent: float) -> void:
	var health: HealthComponent = host.get("health") as HealthComponent
	if health == null:
		return
	var max_hp := health.get_max_health()
	health.current_health = maxf(health.current_health - max_hp * percent, min_hp_from_drain)
	health.health_changed.emit(health.current_health, max_hp)


func _enemy_in_range(host: Node, radius: float) -> bool:
	if host is not Node2D:
		return false
	var parent := (host as Node2D).get_parent()
	if parent == null:
		return false
	var origin := (host as Node2D).global_position
	for child in parent.get_children():
		if child == host or child is not Node2D:
			continue
		if not child.has_method("apply_chase_movement"):
			continue
		if origin.distance_to((child as Node2D).global_position) <= radius:
			return true
	return false


func _ensure_swarm(host: Node) -> void:
	if host is not Node2D:
		return
	_swarm = (host as Node2D).get_node_or_null("SwarmCloud") as Node2D
	if _swarm == null:
		_swarm = Node2D.new()
		_swarm.name = "SwarmCloud"
		_swarm.z_index = 6
		(host as Node2D).add_child(_swarm)
		var tex := ArtBank.particle("magic_05")
		if tex == null:
			tex = ArtBank.particle("flare_01")
		for i in 12:
			var mote := Sprite2D.new()
			mote.name = "Mote%d" % i
			mote.texture = tex
			mote.centered = true
			mote.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			mote.modulate = Color(0.32, 1.0, 0.48, 0.95)
			mote.z_index = 6
			# Soft particle sheets have empty opaque rects; never use fit_height here.
			mote.scale = Vector2(0.11, 0.11)
			_swarm.add_child(mote)
	_siphon = (host as Node2D).get_node_or_null("SwarmSiphon") as Line2D
	if _siphon:
		return
	_siphon = Line2D.new()
	_siphon.name = "SwarmSiphon"
	_siphon.width = 7.0
	_siphon.default_color = Color(0.28, 1.0, 0.42, 0.0)
	_siphon.z_index = 5
	_siphon.joint_mode = Line2D.LINE_JOINT_ROUND
	_siphon.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_siphon.end_cap_mode = Line2D.LINE_CAP_ROUND
	(host as Node2D).add_child(_siphon)


func _spin_swarm(host: Node, delta: float) -> void:
	if _swarm == null or not is_instance_valid(_swarm):
		_ensure_swarm(host)
	if _swarm == null:
		return
	var prey := _nearest_enemy(host, 240.0)
	var hungry := prey != null
	_swarm_spin += delta * (4.8 if hungry else 1.8)
	var radius := 46.0 if hungry else 30.0
	var kids := _swarm.get_children()
	for i in kids.size():
		var mote := kids[i] as Node2D
		if mote == null:
			continue
		var ang := _swarm_spin + TAU * float(i) / float(maxi(kids.size(), 1))
		mote.position = Vector2(cos(ang) * radius, sin(ang) * radius * 0.55 - 20.0)
		mote.modulate = Color(0.32, 1.0, 0.46, 1.0 if hungry else 0.82)
		mote.scale = Vector2(0.16, 0.16) if hungry else Vector2(0.11, 0.11)
	if _siphon and is_instance_valid(_siphon) and host is Node2D:
		if hungry and prey is Node2D:
			_siphon.points = PackedVector2Array([
				Vector2(0, -18),
				(prey as Node2D).global_position - (host as Node2D).global_position + Vector2(0, -16)
			])
			_siphon.default_color = Color(0.28, 1.0, 0.4, 0.88)
		else:
			_siphon.points = PackedVector2Array()
			_siphon.default_color = Color(0.3, 1.0, 0.42, 0.0)
	var cv: CombatVisualComponent = host.get("combat_visual") as CombatVisualComponent
	if cv:
		cv.set_kit_aura(
			Color(0.28, 0.95, 0.38, 0.28 if hungry else 0.14),
			Vector2(1.18, 1.18) if hungry else Vector2(1.05, 1.05),
			true
		)


func _nearest_enemy(host: Node, radius: float) -> Node2D:
	if host is not Node2D:
		return null
	var parent := (host as Node2D).get_parent()
	if parent == null:
		return null
	var origin := (host as Node2D).global_position
	var best: Node2D = null
	var best_d := radius
	for child in parent.get_children():
		if child == host or child is not Node2D:
			continue
		if not child.has_method("apply_chase_movement"):
			continue
		var d := origin.distance_to((child as Node2D).global_position)
		if d <= best_d:
			best_d = d
			best = child as Node2D
	return best


func _free_swarm(host: Node) -> void:
	if _swarm and is_instance_valid(_swarm):
		_swarm.queue_free()
	_swarm = null
	if _siphon and is_instance_valid(_siphon):
		_siphon.queue_free()
	_siphon = null
	if host:
		var existing := host.get_node_or_null("SwarmCloud")
		if existing:
			existing.queue_free()
		var siphon := host.get_node_or_null("SwarmSiphon")
		if siphon:
			siphon.queue_free()
	var cv: CombatVisualComponent = host.get("combat_visual") as CombatVisualComponent if host else null
	if cv:
		cv.set_kit_aura(Color.WHITE, Vector2.ONE, false)
