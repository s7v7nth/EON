class_name BehaviorReturnToHive
extends "res://systems/enemies/enemy_behavior.gd"
## Hive chunks crawl home. Kill them or the butcher gets thicker.


func _init() -> void:
	behavior_id = &"return_to_hive"


func on_ready(host: Node) -> void:
	if host:
		host.set_meta("return_to_hive", true)


func modify_move_speed(_host: Node, base_speed: float) -> float:
	return base_speed * 0.72
