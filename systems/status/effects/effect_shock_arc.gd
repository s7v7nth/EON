class_name EffectShockArc
extends "res://systems/status/status_effect.gd"
## Shock proc: chain lightning to nearby enemies + slow while active.

@export var arc_radius: float = 110.0
@export var arc_damage: float = 10.0
@export var arc_buildup: float = 35.0
@export var speed_mult: float = 0.7


func on_proc(target: Node, ctx: Dictionary) -> void:
	if target == null or target is not Node2D:
		return
	var parent := target.get_parent()
	if parent == null:
		return
	var origin := (target as Node2D).global_position
	var power := float(ctx.get("power", 1.0))
	for child in parent.get_children():
		if child == target or child is not Node2D:
			continue
		if not child.has_method("apply_knockback"):
			continue
		if origin.distance_to((child as Node2D).global_position) > arc_radius:
			continue
		var health = child.get("health")
		if health and health.has_method("take_damage"):
			health.call("take_damage", arc_damage + power * 0.5)
		var status = child.get("status")
		if status and status.has_method("add_buildup"):
			status.call("add_buildup", &"shock", arc_buildup * 0.45, power * 0.5)


func get_action_speed_multiplier(_target: Node) -> float:
	return speed_mult
