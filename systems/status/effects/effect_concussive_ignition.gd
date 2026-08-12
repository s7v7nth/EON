class_name EffectConcussiveIgnition
extends "res://systems/status/status_effect.gd"
## Burn + Stagger synergy: stun blast that knocks and reignites.

@export var radius: float = 110.0
@export var damage: float = 18.0
@export var burn_buildup: float = 35.0
@export var stagger_buildup: float = 80.0
@export var knockback: float = 240.0


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
		if child.get("health") == null and not child.has_method("apply_knockback"):
			continue
		if origin.distance_to((child as Node2D).global_position) > radius:
			continue
		var health = child.get("health")
		if health and health.has_method("take_damage"):
			health.call("take_damage", damage)
		var status = child.get("status")
		if status and status.has_method("add_buildup"):
			status.call("add_buildup", &"burn", burn_buildup, 3.5)
			status.call("add_buildup", &"stagger", stagger_buildup, 6.0)
		if child.has_method("apply_knockback"):
			child.call(
				"apply_knockback",
				((child as Node2D).global_position - origin).normalized(),
				knockback
			)
		if child.has_method("interrupt_attack"):
			child.call("interrupt_attack")
	var points := int(ctx.get("style_points", 130))
	SignalBus.style_action.emit(GameplayEnums.StyleAction.ELEMENT_CASCADE, points)
	SignalBus.synergy_triggered.emit(target, &"concussive_ignition")
