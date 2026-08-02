class_name BehaviorTacticalSupport
extends "res://systems/enemies/enemy_behavior.gd"
## Android medic/shield role: pulse-heal nearby allies.

@export var heal_radius: float = 120.0
@export var heal_amount: float = 4.0
@export var heal_interval: float = 1.6

var _accum: float = 0.0


func _init() -> void:
	behavior_id = &"tactical_support"


func tick(host: Node, delta: float) -> void:
	_accum += delta
	if _accum < heal_interval:
		return
	_accum = 0.0
	if host is not Node2D:
		return
	var parent := host.get_parent()
	if parent == null:
		return
	var origin := (host as Node2D).global_position
	for child in parent.get_children():
		if child == host or child is not Node2D:
			continue
		if not child.has_method("apply_chase_movement"):
			continue
		if origin.distance_to((child as Node2D).global_position) > heal_radius:
			continue
		var health: HealthComponent = child.get("health") as HealthComponent
		if health:
			health.heal(heal_amount)
