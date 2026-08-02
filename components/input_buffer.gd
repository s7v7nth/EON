class_name InputBuffer
extends Node
## Short window so the next action pressed during recovery still fires.

@export var window: float = 0.22

var _pending: Dictionary = {} # StringName -> expire_time (sec)


func buffer(action: StringName) -> void:
	if action == StringName():
		return
	_pending[action] = _now() + window


func consume(action: StringName) -> bool:
	if not _pending.has(action):
		return false
	var until: float = float(_pending[action])
	_pending.erase(action)
	return _now() <= until


func peek(action: StringName) -> bool:
	if not _pending.has(action):
		return false
	if _now() > float(_pending[action]):
		_pending.erase(action)
		return false
	return true


func clear(action: StringName = StringName()) -> void:
	if action == StringName():
		_pending.clear()
	elif _pending.has(action):
		_pending.erase(action)


func capture_just_pressed(actions: Array[StringName]) -> void:
	for action in actions:
		if Input.is_action_just_pressed(action):
			buffer(action)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
