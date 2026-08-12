class_name BehaviorHyperChase
extends "res://systems/enemies/enemy_behavior.gd"
## Robo-beast: relentless speed while chasing.

@export var speed_mult: float = 1.35


func _init() -> void:
	behavior_id = &"hyper_chase"


func modify_move_speed(_host: Node, base_speed: float) -> float:
	return base_speed * speed_mult
