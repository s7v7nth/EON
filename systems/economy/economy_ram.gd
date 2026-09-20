class_name EconomyRam
extends "res://systems/economy/resource_economy.gd"
## Neuro-hacker: RAM slots occupied by drones. Q summons a drone into a free slot.

const DRONE_SCENE := preload("res://entities/allies/drone/ally_drone.tscn")

@export var max_slots: int = 2
@export var special_slot_cost: int = 1
@export var drone_lifetime: float = 18.0
@export var starter_drone: bool = true

var used_slots: int = 0
var drone_damage_mult: float = 1.0
var drone_speed_mult: float = 1.0
var drone_glitch_buildup: float = 12.0
var _drones: Array[Node] = []


func _init() -> void:
	policy = GameplayEnums.EconomyPolicy.RAM_COMPUTE


func on_equip(host: Node) -> void:
	_despawn_all()
	used_slots = 0
	drone_damage_mult = 1.0
	drone_speed_mult = 1.0
	drone_glitch_buildup = 12.0
	_emit_slots()
	var energy: EnergyComponent = host.get("energy") as EnergyComponent
	if energy:
		energy.unlock_regen(0.65)
	if starter_drone and host:
		host.call_deferred("try_special")


func on_unequip(host: Node) -> void:
	_despawn_all()
	used_slots = 0
	_emit_slots()


func can_afford(host: Node, action: StringName, cost: float = 0.0) -> bool:
	if action == &"special":
		return used_slots + special_slot_cost <= max_slots
	if action == &"attack" or action == &"ranged" or action == &"dash" or action == &"parry":
		return true
	if cost <= 0.0:
		return true
	var energy: EnergyComponent = host.get("energy") as EnergyComponent if host else null
	return energy != null and energy.current_energy >= cost


func spend(host: Node, action: StringName, cost: float = 0.0) -> bool:
	if not can_afford(host, action, cost):
		return false
	if action == &"special":
		used_slots += special_slot_cost
		_emit_slots()
		return true
	if action == &"attack" or action == &"ranged" or action == &"dash" or action == &"parry":
		return true
	if cost > 0.0:
		var energy: EnergyComponent = host.get("energy") as EnergyComponent
		return energy != null and energy.try_spend(cost)
	return true


func on_hit(_host: Node, target: Node) -> void:
	if target == null:
		return
	var body := target.get_parent() if target is HurtboxComponent else target
	if body == null:
		return
	var status: StatusComponent = body.get("status") as StatusComponent
	if status == null:
		status = body.get_node_or_null("StatusComponent") as StatusComponent
	if status:
		status.add_buildup(StatusComponent.STATUS_GLITCH, 10.0, 1.5)


func try_special(host: Node) -> bool:
	if not spend(host, &"special"):
		return false
	if not _spawn_drone(host):
		# Refund slot if spawn failed.
		used_slots = maxi(used_slots - special_slot_cost, 0)
		_emit_slots()
		return false
	if host is Node2D:
		HitVFX.spawn_optic_burst(
			(host as Node2D).get_parent(),
			(host as Node2D).global_position,
			Color(0.72, 0.4, 1.0, 1),
			Vector2.UP,
			1.05
		)
	SignalBus.special_triggered.emit(host)
	return true


func release_drone(drone: Node) -> void:
	if drone in _drones:
		_drones.erase(drone)
	used_slots = maxi(used_slots - special_slot_cost, 0)
	_emit_slots()


func add_max_slots(amount: int) -> void:
	max_slots = maxi(max_slots + amount, 1)
	_emit_slots()


func boost_drones(damage_mult: float, speed_mult: float, glitch_buildup: float) -> void:
	drone_damage_mult = maxf(drone_damage_mult * damage_mult, 0.1)
	drone_speed_mult = maxf(drone_speed_mult * speed_mult, 0.1)
	drone_glitch_buildup = maxf(drone_glitch_buildup + glitch_buildup, 0.0)
	for drone in _drones:
		if is_instance_valid(drone) and drone.has_method("apply_economy_boosts"):
			drone.call("apply_economy_boosts", self)


func get_hud_values(_host: Node) -> Dictionary:
	return {
		"primary": _bar(
			float(used_slots),
			float(max_slots),
			"RAM  %d / %d" % [used_slots, max_slots],
			Color(0.62, 0.38, 0.98, 1)
		),
		"secondary": _bar(float(used_slots), float(max_slots), "Drones", Color(0.75, 0.55, 1.0, 1)),
	}


func _spawn_drone(host: Node) -> bool:
	if host is not Node2D:
		return false
	var parent := host.get_parent()
	if parent == null:
		return false
	var drone := DRONE_SCENE.instantiate() as Node2D
	if drone == null:
		return false
	parent.add_child(drone)
	drone.global_position = (host as Node2D).global_position + Vector2(28, -20)
	if drone.has_method("configure"):
		drone.call("configure", host, self, drone_lifetime)
	_drones.append(drone)
	return true


func _despawn_all() -> void:
	for drone in _drones:
		if is_instance_valid(drone):
			drone.set("economy", null)
			drone.queue_free()
	_drones.clear()


func _emit_slots() -> void:
	SignalBus.ram_slots_changed.emit(used_slots, max_slots)
