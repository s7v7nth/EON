class_name BehaviorAggroSwarm
extends "res://systems/enemies/enemy_behavior.gd"
## Savages pack up: move faster when allies are nearby.

@export var ally_radius: float = 140.0
@export var speed_per_ally: float = 0.12
@export var max_bonus: float = 0.45


func _init() -> void:
	behavior_id = &"aggro_swarm"


func modify_move_speed(host: Node, base_speed: float) -> float:
	var allies := _count_allies(host)
	if allies <= 0:
		return base_speed
	var bonus := minf(float(allies) * speed_per_ally, max_bonus)
	return base_speed * (1.0 + bonus)


func _count_allies(host: Node) -> int:
	if host is not Node2D:
		return 0
	var parent := host.get_parent()
	if parent == null:
		return 0
	var origin := (host as Node2D).global_position
	var n := 0
	for child in parent.get_children():
		if child == host or child is not Node2D:
			continue
		if not child.has_method("apply_chase_movement"):
			continue
		if origin.distance_to((child as Node2D).global_position) <= ally_radius:
			n += 1
	return n
