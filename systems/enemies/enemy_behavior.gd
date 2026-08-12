class_name EnemyBehavior
extends Resource
## Pluggable enemy AI verb. Host is Node to avoid class cycles.

@export var behavior_id: StringName = &""


func on_ready(_host: Node) -> void:
	pass


func tick(_host: Node, _delta: float) -> void:
	pass


func modify_move_speed(_host: Node, base_speed: float) -> float:
	return base_speed


func try_dodge_projectile(_host: Node, _attack: AttackData, _source: Node) -> bool:
	return false


func on_death(_host: Node) -> void:
	pass


func wants_retreat(_host: Node) -> bool:
	return false
