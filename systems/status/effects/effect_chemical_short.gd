class_name EffectChemicalShort
extends "res://systems/status/status_effect.gd"
## Acid + Shock synergy: charged gas cloud that damages and paralyzes the room cluster.

@export var radius: float = 140.0
@export var damage: float = 16.0
@export var shock_buildup: float = 40.0
@export var stagger_buildup: float = 50.0


func on_proc(target: Node, ctx: Dictionary) -> void:
	if target == null or target is not Node2D:
		return
	var parent := target.get_parent()
	if parent == null:
		return
	var origin := (target as Node2D).global_position
	for child in parent.get_children():
		if child is not Node2D:
			continue
		if not child.has_method("apply_knockback") and child.get("health") == null:
			continue
		if origin.distance_to((child as Node2D).global_position) > radius:
			continue
		var health = child.get("health")
		if health and health.has_method("take_damage"):
			health.call("take_damage", damage)
		var status = child.get("status")
		if status and status.has_method("add_buildup"):
			status.call("add_buildup", &"shock", shock_buildup, 4.0)
			status.call("add_buildup", &"stagger", stagger_buildup, 5.0)
		if child.has_method("apply_knockback"):
			child.call(
				"apply_knockback",
				((child as Node2D).global_position - origin).normalized(),
				180.0
			)
	var points := int(ctx.get("style_points", 120))
	SignalBus.style_action.emit(GameplayEnums.StyleAction.ELEMENT_CASCADE, points)
	SignalBus.synergy_triggered.emit(target, &"chemical_short")
