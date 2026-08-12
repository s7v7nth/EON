class_name EffectRoomInfect
extends "res://systems/upgrades/upgrade_effect.gd"
## Toad hit infects the room; tick damage ramps and can cascade.

@export var tick_damage: float = 2.5
@export var duration: float = 6.0
@export var required_shape: StringName = &"toad"

var _timer: float = 0.0
var _ramp: float = 0.0


func remove(_host: Node) -> void:
	_timer = 0.0
	_ramp = 0.0


func on_ranged_hit(_host: Node, _target: Node) -> void:
	if _weapon_shape(_host) != required_shape:
		return
	_timer = duration
	_ramp = 1.0


func tick(host: Node, delta: float) -> void:
	if _timer <= 0.0 or tick_damage <= 0.0:
		return
	_timer -= delta
	_ramp += delta * 0.35
	var tick := tick_damage * (1.0 + _ramp)
	var killed := 0
	for enemy in _enemies_near(host, 9999.0):
		var health = enemy.get("health")
		if health == null or not health.has_method("take_damage"):
			continue
		var before := float(health.get("current_health"))
		health.call("take_damage", tick * delta)
		if before > 0.0 and float(health.get("current_health")) <= 0.0:
			killed += 1
	if killed >= 2:
		SignalBus.style_action.emit(GameplayEnums.StyleAction.ELEMENT_CASCADE, 120)
