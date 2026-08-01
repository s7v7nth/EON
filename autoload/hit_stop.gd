extends Node
## Brief Engine.time_scale punch on successful hits.

var _busy: bool = false


func punch(time_scale: float = 0.12, duration: float = 0.045) -> void:
	if _busy:
		return
	_busy = true
	var previous := Engine.time_scale
	Engine.time_scale = time_scale
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = previous if previous > 0.0 else 1.0
	_busy = false
