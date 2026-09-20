class_name EffectHoloEdge
extends "res://systems/upgrades/upgrade_effect.gd"
## Neuro melee: holo slash applies glitch buildup and a small damage pulse.

@export var glitch_buildup: float = 32.0
@export var bonus_damage: float = 4.0


func on_melee_hit(host: Node, target: Node) -> void:
	var body := target.get_parent() if target is HurtboxComponent else target
	if body == null:
		return
	var status = body.get("status")
	if status != null and status.has_method("add_buildup"):
		status.call("add_buildup", &"glitch", glitch_buildup, 2.5)
	var health = body.get("health")
	if health != null and health.has_method("take_damage") and bonus_damage > 0.0:
		health.call("take_damage", bonus_damage)
	if host is Node2D and body is Node2D:
		HitVFX.spawn_optic_ring(host.get_parent(), (body as Node2D).global_position, Color(0.7, 0.45, 1.0, 0.85), 0.7)
