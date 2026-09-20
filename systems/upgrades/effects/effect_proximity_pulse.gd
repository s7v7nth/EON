class_name EffectProximityPulse
extends "res://systems/upgrades/upgrade_effect.gd"
## Melee hit pulses corrosion damage around the player.

@export var damage: float = 6.0
@export var radius: float = 70.0
@export var acid_power: float = 5.0
@export var acid_duration: float = 1.5


func on_melee_hit(host: Node, _target: Node) -> void:
	if damage <= 0.0:
		return
	for enemy in _enemies_near(host, radius):
		var health = enemy.get("health")
		if health and health.has_method("take_damage"):
			health.call("take_damage", damage)
		var status = enemy.get("status")
		if status and status.has_method("apply_status"):
			status.call("apply_status", &"acid", acid_power, acid_duration)
		elif status and status.has_method("add_buildup"):
			status.call("add_buildup", &"acid", acid_power * 12.0, acid_power)
