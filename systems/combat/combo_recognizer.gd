class_name ComboRecognizer
extends Node
## Buffers attack / ranged taps and matches ComboRecipe sequences.

signal combo_resolved(result_id: StringName, attack_data: AttackData)
signal sequence_updated(steps: PackedStringArray)

@export var recipes: Array[ComboRecipe] = []
@export var step_window: float = 0.8

var _buffer: Array[Dictionary] = []  # {action: StringName, time: float}


func clear() -> void:
	_buffer.clear()
	sequence_updated.emit(PackedStringArray())


func push(action: StringName) -> StringName:
	## Returns matched result_id, or empty if only a prefix / no match.
	_prune()
	_buffer.append({"action": action, "time": _now()})
	sequence_updated.emit(get_sequence())
	var matched := _try_match()
	if matched != StringName():
		_buffer.clear()
		sequence_updated.emit(PackedStringArray())
	return matched


func expects(action: StringName) -> bool:
	_prune()
	if _buffer.is_empty():
		return false
	var candidate := get_sequence()
	candidate.append(String(action))
	for recipe in recipes:
		if recipe == null or recipe.sequence.is_empty():
			continue
		if _is_prefix(candidate, recipe.sequence) or _sequences_equal(candidate, recipe.sequence):
			return true
	return false


func has_open_prefix() -> bool:
	_prune()
	if _buffer.is_empty():
		return false
	var current := get_sequence()
	for recipe in recipes:
		if recipe == null or recipe.sequence.is_empty():
			continue
		if current.size() < recipe.sequence.size() and _is_prefix(current, recipe.sequence):
			return true
	return false


func get_sequence() -> PackedStringArray:
	_prune()
	return _current_sequence()


func _now() -> float:
	# Wall-clock seconds — immune to HitStop time_scale.
	return Time.get_ticks_msec() / 1000.0


func _try_match() -> StringName:
	var current := _current_sequence()
	var best: ComboRecipe = null
	for recipe in recipes:
		if recipe == null or recipe.sequence.is_empty():
			continue
		if not _sequences_equal(current, recipe.sequence):
			continue
		if best == null or recipe.sequence.size() > best.sequence.size():
			best = recipe
	if best == null:
		return StringName()
	combo_resolved.emit(best.result_id, best.attack_data)
	return best.result_id


func _prune() -> void:
	if _buffer.is_empty():
		return
	var now := _now()
	var cutoff := now - step_window
	while not _buffer.is_empty() and float(_buffer[0]["time"]) < cutoff:
		_buffer.pop_front()
	# Also drop if gap between last two steps exceeded window.
	if _buffer.size() >= 2:
		var last := float(_buffer[_buffer.size() - 1]["time"])
		var prev := float(_buffer[_buffer.size() - 2]["time"])
		if last - prev > step_window:
			var keep: Dictionary = _buffer[_buffer.size() - 1]
			_buffer.clear()
			_buffer.append(keep)


func _current_sequence() -> PackedStringArray:
	var out := PackedStringArray()
	for entry in _buffer:
		out.append(String(entry["action"]))
	return out


func _sequences_equal(a: PackedStringArray, b: PackedStringArray) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if StringName(a[i]) != StringName(b[i]):
			return false
	return true


func _is_prefix(prefix: PackedStringArray, full: PackedStringArray) -> bool:
	if prefix.size() > full.size():
		return false
	for i in prefix.size():
		if StringName(prefix[i]) != StringName(full[i]):
			return false
	return true
