class_name StatusEffect
extends Resource
## Scripted status behaviour. Host is Node to avoid class cycles.


func on_proc(_target: Node, _ctx: Dictionary) -> void:
	pass


func on_tick(_target: Node, _delta: float, _ctx: Dictionary) -> void:
	pass


func on_expire(_target: Node, _ctx: Dictionary) -> void:
	pass


func modify_incoming_damage(_target: Node, damage: float, _damage_type: int) -> float:
	return damage


func get_action_speed_multiplier(_target: Node) -> float:
	return 1.0


func get_resist_shred(_target: Node, _power: float) -> float:
	return 0.0


func _health_of(target: Node) -> Node:
	if target == null:
		return null
	var hc = target.get("health")
	if hc:
		return hc
	return target.get_node_or_null("HealthComponent")


func _status_of(target: Node) -> Node:
	if target == null:
		return null
	var sc = target.get("status")
	if sc:
		return sc
	return target.get_node_or_null("StatusComponent")


func _deal_dot(target: Node, amount: float) -> void:
	var health = _health_of(target)
	if health and amount > 0.0 and health.has_method("take_damage"):
		health.call("take_damage", amount)
