class_name EffectSystemCrash
extends "res://systems/status/status_effect.gd"
## Glitch + Shock synergy: hard reboot pulse — robots eat heavy glitch/stagger.

@export var radius: float = 150.0
@export var damage: float = 12.0
@export var glitch_buildup: float = 70.0
@export var stagger_buildup: float = 40.0
@export var robot_damage_mult: float = 1.75


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
		var mult := robot_damage_mult if _is_robot(child) else 1.0
		var health = child.get("health")
		if health and health.has_method("take_damage"):
			health.call("take_damage", damage * mult)
		var status = child.get("status")
		if status and status.has_method("add_buildup"):
			status.call("add_buildup", &"glitch", glitch_buildup * mult, 5.0)
			status.call("add_buildup", &"stagger", stagger_buildup, 4.0)
		if child.has_method("interrupt_attack"):
			child.call("interrupt_attack")
	var points := int(ctx.get("style_points", 140))
	SignalBus.style_action.emit(GameplayEnums.StyleAction.ELEMENT_CASCADE, points)
	SignalBus.synergy_triggered.emit(target, &"system_crash")


func _is_robot(node: Node) -> bool:
	var def = node.get("definition")
	if def == null:
		return false
	var faction = def.get("faction")
	if faction == null:
		return false
	var f := int(faction)
	return f == int(GameplayEnums.Faction.ANDROID) \
		or f == int(GameplayEnums.Faction.CYBORG) \
		or f == int(GameplayEnums.Faction.ROBO_BEAST)
