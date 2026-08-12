class_name EffectNapalmRend
extends "res://systems/status/status_effect.gd"
## Fire + Bleed synergy: napalm burst that keeps burn/bleed ticking nearby.

@export var radius: float = 120.0
@export var damage: float = 14.0
@export var burn_buildup: float = 45.0
@export var bleed_buildup: float = 45.0


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
			status.call("add_buildup", &"burn", burn_buildup, 4.0)
			status.call("add_buildup", &"bleed", bleed_buildup, 4.0)
	var points := int(ctx.get("style_points", 120))
	SignalBus.style_action.emit(GameplayEnums.StyleAction.ELEMENT_CASCADE, points)
	SignalBus.synergy_triggered.emit(target, &"napalm_rend")
