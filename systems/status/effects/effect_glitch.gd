class_name EffectGlitch
extends "res://systems/status/status_effect.gd"
## Digital fault: robots shut down hard; organics confuse / slow.

@export var robot_speed_mult: float = 0.15
@export var organic_speed_mult: float = 0.55


func on_proc(target: Node, _ctx: Dictionary) -> void:
	if target == null:
		return
	var robot := _is_robot(target)
	target.set_meta("glitched", true)
	target.set_meta("glitch_robot", robot)
	if robot and target.has_method("interrupt_attack"):
		target.call("interrupt_attack")


func on_expire(target: Node, _ctx: Dictionary) -> void:
	if target == null:
		return
	if target.has_meta("glitched"):
		target.remove_meta("glitched")
	if target.has_meta("glitch_robot"):
		target.remove_meta("glitch_robot")


func get_action_speed_multiplier(target: Node) -> float:
	if target and target.get_meta("glitch_robot", false):
		return robot_speed_mult
	return organic_speed_mult


func _is_robot(target: Node) -> bool:
	var def = target.get("definition")
	if def == null:
		return false
	var faction = def.get("faction")
	if faction == null:
		return false
	return int(faction) == int(GameplayEnums.Faction.ANDROID) \
		or int(faction) == int(GameplayEnums.Faction.CYBORG) \
		or int(faction) == int(GameplayEnums.Faction.ROBO_BEAST)
