class_name CombatEngagementComponent
extends Node
## Tracks whether the player is in combat (enemy aggro or recent exchange).

signal combat_changed(in_combat: bool)

@export var linger_seconds: float = 1.75
@export var poll_interval: float = 0.2

var in_combat: bool = false
var _linger: float = 0.0
var _poll: float = 0.0


func notify_exchange() -> void:
	_linger = linger_seconds
	_set_combat(true)


func _process(delta: float) -> void:
	_poll += delta
	if _linger > 0.0:
		_linger = maxf(0.0, _linger - delta)
	if _poll < poll_interval:
		return
	_poll = 0.0
	var engaged := _any_enemy_targeting_player() or _linger > 0.0
	_set_combat(engaged)


func _set_combat(value: bool) -> void:
	if in_combat == value:
		return
	in_combat = value
	combat_changed.emit(in_combat)


func _any_enemy_targeting_player() -> bool:
	var player := get_parent()
	if player == null:
		return false
	var entities := player.get_parent()
	if entities == null:
		return false
	for child in entities.get_children():
		if child == player:
			continue
		if not child.has_method("apply_knockback"):
			continue
		if child.get("target") == player:
			var health = child.get("health")
			if health and health.has_method("is_dead") and health.is_dead():
				continue
			if health and "current_health" in health and float(health.current_health) <= 0.0:
				continue
			return true
	return false
