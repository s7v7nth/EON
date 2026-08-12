class_name EffectSyncBlade
extends "res://systems/upgrades/upgrade_effect.gd"
## Neuro melee: hits briefly overclock nearby drones (summoner + melee link).

@export var pulse_radius: float = 220.0
@export var speed_boost: float = 1.35
@export var damage_boost: float = 1.3
@export var pulse_sec: float = 2.2


func on_melee_hit(host: Node, _target: Node) -> void:
	if host is not Node2D:
		return
	var parent := host.get_parent()
	if parent == null:
		return
	var origin := (host as Node2D).global_position
	for child in parent.get_children():
		if child == null or not is_instance_valid(child):
			continue
		if not child.is_in_group("ally_drone"):
			continue
		if child is Node2D and origin.distance_to((child as Node2D).global_position) > pulse_radius:
			continue
		if child.has_method("apply_overclock_pulse"):
			child.call("apply_overclock_pulse", speed_boost, damage_boost, pulse_sec)
		HitVFX.spawn_optic_ring(parent, (child as Node2D).global_position, Color(0.55, 0.4, 1.0, 0.7), 0.55)
