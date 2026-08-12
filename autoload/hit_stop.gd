extends Node
## Brief Engine.time_scale punch on successful hits.
## Duration is REAL time (ignore_time_scale) so freezes stay sharp and never stall.

var _busy: bool = false
var _current_weight: float = 0.0
var _generation: int = 0


func punch(time_scale: float = 0.12, duration: float = 0.045) -> void:
	var ts: float = clampf(time_scale, 0.05, 1.0)
	var dur: float = maxf(duration, 0.0)
	if dur <= 0.0:
		return
	var weight: float = dur / ts
	if _busy and weight <= _current_weight:
		return
	_generation += 1
	var my_gen: int = _generation
	_busy = true
	_current_weight = weight
	Engine.time_scale = ts
	# process_always=true, ignore_time_scale=true — wait `dur` wall-clock seconds.
	await get_tree().create_timer(dur, true, true, true).timeout
	if my_gen != _generation:
		return
	Engine.time_scale = 1.0
	_busy = false
	_current_weight = 0.0


func reset() -> void:
	_generation += 1
	_busy = false
	_current_weight = 0.0
	Engine.time_scale = 1.0
