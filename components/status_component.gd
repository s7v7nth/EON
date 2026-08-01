class_name StatusComponent
extends Node
## Tracks elemental statuses and ticks DoTs into HealthComponent.

const STATUS_BURN := &"burn"
const STATUS_BLEED := &"bleed"
const STATUS_ACID := &"acid"
const STATUS_SHOCK := &"shock"
const STATUS_STAGGER := &"stagger"

@export var health_component: HealthComponent

## status_id -> { power, time_left, tick_accum }
var _statuses: Dictionary = {}

signal statuses_changed(active: PackedStringArray)


func _process(delta: float) -> void:
	if _statuses.is_empty():
		return
	var moved := _owner_speed()
	var to_remove: Array[StringName] = []
	for status_id in _statuses.keys():
		var entry: Dictionary = _statuses[status_id]
		entry["time_left"] = float(entry["time_left"]) - delta
		entry["tick_accum"] = float(entry.get("tick_accum", 0.0)) + delta
		var power: float = float(entry.get("power", 0.0))
		match status_id:
			STATUS_BURN:
				if float(entry["tick_accum"]) >= 0.4:
					entry["tick_accum"] = 0.0
					_deal_dot(power * 0.35)
			STATUS_ACID:
				if float(entry["tick_accum"]) >= 0.5:
					entry["tick_accum"] = 0.0
					_deal_dot(power * 0.25)
			STATUS_BLEED:
				var interval := 0.55 if moved < 40.0 else 0.28
				if float(entry["tick_accum"]) >= interval:
					entry["tick_accum"] = 0.0
					_deal_dot(power * (0.2 if moved < 40.0 else 0.35))
			STATUS_SHOCK, STATUS_STAGGER:
				pass
		_statuses[status_id] = entry
		if float(entry["time_left"]) <= 0.0:
			to_remove.append(status_id)
	for status_id in to_remove:
		_statuses.erase(status_id)
	if not to_remove.is_empty():
		_emit_statuses()


func apply_status(status_id: StringName, power: float, duration: float) -> void:
	if status_id == StringName() or power <= 0.0 or duration <= 0.0:
		return
	var existing: Dictionary = _statuses.get(status_id, {})
	var new_power := maxf(float(existing.get("power", 0.0)), power)
	var new_time := maxf(float(existing.get("time_left", 0.0)), duration)
	_statuses[status_id] = {
		"power": new_power,
		"time_left": new_time,
		"tick_accum": float(existing.get("tick_accum", 0.0)),
	}
	_emit_statuses()
	var owner_node := get_parent()
	if owner_node:
		SignalBus.status_applied.emit(owner_node, status_id)


func has_status(status_id: StringName) -> bool:
	return _statuses.has(status_id)


func get_action_speed_multiplier() -> float:
	if has_status(STATUS_SHOCK):
		return 0.7
	if has_status(STATUS_STAGGER):
		return 0.5
	return 1.0


func get_resist_shred() -> float:
	## Acid lowers effective resists when reading damage.
	if has_status(STATUS_ACID):
		return 0.15 + float(_statuses[STATUS_ACID].get("power", 0.0)) * 0.01
	return 0.0


func get_active_ids() -> PackedStringArray:
	var out: PackedStringArray = []
	for key in _statuses.keys():
		out.append(String(key))
	return out


func clear_all() -> void:
	_statuses.clear()
	_emit_statuses()


func _deal_dot(amount: float) -> void:
	if health_component == null or amount <= 0.0:
		return
	health_component.take_damage(amount)


func _owner_speed() -> float:
	var body := get_parent()
	if body is CharacterBody2D:
		return (body as CharacterBody2D).velocity.length()
	return 0.0


func _emit_statuses() -> void:
	statuses_changed.emit(get_active_ids())
