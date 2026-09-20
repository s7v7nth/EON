class_name EffectHookshot
extends "res://systems/upgrades/upgrade_effect.gd"
## Whip pulls the player toward the struck target.

@export var pull_distance: float = 48.0
@export var required_shape: StringName = &"whip"


func on_melee_hit(host: Node, target: Node) -> void:
	if target == null or host is not Node2D:
		return
	if _weapon_shape(host) != required_shape:
		return
	var body: Node = target
	if target.get_class() == "Area2D" or target.has_method("receive_hit"):
		body = target.get_parent()
	if body is Node2D:
		(host as Node2D).global_position = (host as Node2D).global_position.move_toward(
			(body as Node2D).global_position, pull_distance
		)
