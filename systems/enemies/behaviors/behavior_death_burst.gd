class_name BehaviorDeathBurst
extends "res://systems/enemies/enemy_behavior.gd"
## Bio-mutant death cloud: AOE damage + acid buildup on nearby bodies.

@export var radius: float = 78.0
@export var damage: float = 8.0
@export var acid_buildup: float = 22.0
@export var knockback: float = 160.0


func _init() -> void:
	behavior_id = &"death_burst"


func on_death(host: Node) -> void:
	if host is not Node2D:
		return
	var parent := host.get_parent()
	if parent == null:
		return
	var origin := (host as Node2D).global_position
	for child in parent.get_children():
		if child == host or child is not Node2D:
			continue
		var body := child as Node2D
		if origin.distance_to(body.global_position) > radius:
			continue
		var health: HealthComponent = child.get("health") as HealthComponent
		if child is Player:
			if health:
				health.take_damage(damage * 0.22)
			continue
		if health:
			health.take_damage(damage)
		var status: StatusComponent = child.get("status") as StatusComponent
		if status:
			status.add_buildup(StatusComponent.STATUS_ACID, acid_buildup, 1.2)
		if child.has_method("apply_knockback"):
			child.call("apply_knockback", (body.global_position - origin).normalized(), knockback)
