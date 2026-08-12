class_name BehaviorErraticDodge
extends "res://systems/enemies/enemy_behavior.gd"
## Cyborgs: chance to ignore a projectile hit.

@export_range(0.0, 1.0, 0.01) var dodge_chance: float = 0.28


func _init() -> void:
	behavior_id = &"erratic_dodge"


func try_dodge_projectile(host: Node, attack: AttackData, _source: Node) -> bool:
	if attack == null:
		return false
	# Melee swings are harder to shrug — only projectiles / ranged flags.
	if attack.projectile_speed <= 0.0 and attack.projectile_lifetime <= 0.0:
		return false
	if randf() > dodge_chance:
		return false
	if host and host.has_method("apply_knockback"):
		host.call("apply_knockback", Vector2.from_angle(randf() * TAU), 120.0)
	return true
