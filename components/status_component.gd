class_name StatusComponent
extends Node
## Buildup gauges + active status windows driven by StatusCatalog definitions.

const STATUS_BURN := &"burn"
const STATUS_BLEED := &"bleed"
const STATUS_ACID := &"acid"
const STATUS_SHOCK := &"shock"
const STATUS_STAGGER := &"stagger"
const STATUS_GLITCH := &"glitch"

const CATALOG := preload("res://resources/statuses/status_catalog.tres")

@export var health_component: HealthComponent

## status_id -> { buildup, time_left, tick_accum, power, active }
var _statuses: Dictionary = {}
## recipe_id -> last trigger time (seconds)
var _synergy_cd: Dictionary = {}

signal statuses_changed(active: PackedStringArray)


func _process(delta: float) -> void:
	if _statuses.is_empty():
		return
	var catalog := _catalog()
	var to_remove: Array[StringName] = []
	var changed := false
	for status_id in _statuses.keys():
		var entry: Dictionary = _statuses[status_id]
		var def := _def(status_id)
		var active := float(entry.get("time_left", 0.0)) > 0.0
		# Buildup decays only while not actively procced.
		if not active and float(entry.get("buildup", 0.0)) > 0.0:
			var decay := def.decay_per_sec if def else 8.0
			entry["buildup"] = maxf(float(entry["buildup"]) - decay * delta, 0.0)
			changed = true
		if active:
			entry["time_left"] = float(entry["time_left"]) - delta
			entry["tick_accum"] = float(entry.get("tick_accum", 0.0)) + delta
			var interval := def.tick_interval if def else 0.4
			if float(entry["tick_accum"]) >= interval:
				entry["tick_accum"] = 0.0
				_tick_status(status_id, entry, def, interval)
			if float(entry["time_left"]) <= 0.0:
				_expire_status(status_id, entry, def)
				# Keep residual buildup entry if any remains.
				if float(entry.get("buildup", 0.0)) <= 0.0:
					to_remove.append(status_id)
				else:
					entry["time_left"] = 0.0
					entry["tick_accum"] = 0.0
				changed = true
		elif float(entry.get("buildup", 0.0)) <= 0.0:
			to_remove.append(status_id)
		_statuses[status_id] = entry
	for status_id in to_remove:
		_statuses.erase(status_id)
		changed = true
	if changed:
		_emit_statuses()
	# Silence unused warning if catalog preload fails in tooling.
	if catalog == null:
		pass


func add_buildup(status_id: StringName, amount: float, power: float = 1.0) -> void:
	if status_id == StringName() or amount <= 0.0:
		return
	var def := _def(status_id)
	var entry: Dictionary = _statuses.get(status_id, {
		"buildup": 0.0,
		"time_left": 0.0,
		"tick_accum": 0.0,
		"power": 0.0,
	})
	entry["buildup"] = float(entry.get("buildup", 0.0)) + amount
	entry["power"] = maxf(float(entry.get("power", 0.0)), power)
	var max_buildup := def.max_buildup if def else 100.0
	var procced := false
	if float(entry["buildup"]) >= max_buildup:
		entry["buildup"] = 0.0
		entry["time_left"] = def.active_duration if def else 2.5
		entry["tick_accum"] = 0.0
		procced = true
	_statuses[status_id] = entry
	_emit_statuses()
	var owner_node := get_parent()
	if owner_node:
		SignalBus.status_applied.emit(owner_node, status_id)
	if procced:
		_proc_status(status_id, entry, def)
	_check_synergies()


## Legacy / forced activation (parry stagger, scripted applies).
func apply_status(status_id: StringName, power: float, duration: float) -> void:
	if status_id == StringName() or power <= 0.0 or duration <= 0.0:
		return
	var def := _def(status_id)
	var entry: Dictionary = _statuses.get(status_id, {
		"buildup": 0.0,
		"time_left": 0.0,
		"tick_accum": 0.0,
		"power": 0.0,
	})
	entry["power"] = maxf(float(entry.get("power", 0.0)), power)
	entry["time_left"] = maxf(float(entry.get("time_left", 0.0)), duration)
	entry["tick_accum"] = 0.0
	# Partial buildup credit so synergies / gauges stay meaningful.
	var max_buildup := def.max_buildup if def else 100.0
	entry["buildup"] = minf(float(entry.get("buildup", 0.0)) + power * 8.0, max_buildup * 0.9)
	_statuses[status_id] = entry
	_emit_statuses()
	var owner_node := get_parent()
	if owner_node:
		SignalBus.status_applied.emit(owner_node, status_id)
	_proc_status(status_id, entry, def)
	_check_synergies()


func has_status(status_id: StringName) -> bool:
	if not _statuses.has(status_id):
		return false
	return float(_statuses[status_id].get("time_left", 0.0)) > 0.0


func get_buildup_ratio(status_id: StringName) -> float:
	if not _statuses.has(status_id):
		return 0.0
	var def := _def(status_id)
	var max_b := def.max_buildup if def else 100.0
	if max_b <= 0.0:
		return 0.0
	return clampf(float(_statuses[status_id].get("buildup", 0.0)) / max_b, 0.0, 1.0)


func get_action_speed_multiplier() -> float:
	var mult := 1.0
	var owner_node := get_parent()
	for status_id in _statuses.keys():
		if not has_status(status_id):
			continue
		var def := _def(status_id)
		if def == null:
			continue
		var while_active := def.while_active as StatusEffect
		var on_proc := def.on_proc as StatusEffect
		if while_active:
			mult *= while_active.get_action_speed_multiplier(owner_node)
		elif on_proc:
			mult *= on_proc.get_action_speed_multiplier(owner_node)
	return mult


func get_resist_shred() -> float:
	var shred := 0.0
	var owner_node := get_parent()
	for status_id in _statuses.keys():
		if not has_status(status_id):
			continue
		var def := _def(status_id)
		var power := float(_statuses[status_id].get("power", 0.0))
		if def == null:
			continue
		var while_active := def.while_active as StatusEffect
		if while_active:
			shred += while_active.get_resist_shred(owner_node, power)
	return shred


func modify_incoming_damage(damage: float, damage_type: int) -> float:
	var result := damage
	var owner_node := get_parent()
	for status_id in _statuses.keys():
		if not has_status(status_id):
			continue
		var def := _def(status_id)
		if def == null:
			continue
		var while_active := def.while_active as StatusEffect
		if while_active:
			result = while_active.modify_incoming_damage(owner_node, result, damage_type)
	return result


func get_active_ids() -> PackedStringArray:
	var out: PackedStringArray = []
	for key in _statuses.keys():
		if has_status(key):
			out.append(String(key))
	return out


func clear_all() -> void:
	for status_id in _statuses.keys():
		var def := _def(status_id)
		_expire_status(status_id, _statuses[status_id], def)
	_statuses.clear()
	_emit_statuses()


func remove_status(status_id: StringName) -> void:
	if not _statuses.has(status_id):
		return
	var def := _def(status_id)
	_expire_status(status_id, _statuses[status_id], def)
	_statuses.erase(status_id)
	_emit_statuses()


func _proc_status(status_id: StringName, entry: Dictionary, def: StatusDefinition) -> void:
	if def == null:
		return
	var owner_node := get_parent()
	var ctx := {
		"power": float(entry.get("power", 1.0)),
		"status_id": status_id,
	}
	var on_proc := def.on_proc as StatusEffect
	var while_active := def.while_active as StatusEffect
	if on_proc:
		on_proc.on_proc(owner_node, ctx)
	if while_active and while_active != on_proc:
		while_active.on_proc(owner_node, ctx)


func _tick_status(status_id: StringName, entry: Dictionary, def: StatusDefinition, interval: float) -> void:
	if def == null:
		return
	var while_active := def.while_active as StatusEffect
	if while_active == null:
		return
	var ctx := {
		"power": float(entry.get("power", 1.0)),
		"status_id": status_id,
		"interval": interval,
	}
	while_active.on_tick(get_parent(), interval, ctx)


func _expire_status(status_id: StringName, entry: Dictionary, def: StatusDefinition) -> void:
	if def == null:
		return
	var ctx := {
		"power": float(entry.get("power", 1.0)),
		"status_id": status_id,
	}
	var while_active := def.while_active as StatusEffect
	var on_proc := def.on_proc as StatusEffect
	if while_active:
		while_active.on_expire(get_parent(), ctx)
	if on_proc and on_proc != while_active:
		on_proc.on_expire(get_parent(), ctx)


func _check_synergies() -> void:
	var catalog := _catalog()
	if catalog == null:
		return
	var active := get_active_ids()
	# Also allow synergy when gauges are high enough via forced actives only — active ids.
	var now := Time.get_ticks_msec() / 1000.0
	var owner_node := get_parent()
	for item in catalog.all_synergies():
		var recipe := item as SynergyRecipe
		if recipe == null or not recipe.matches(active):
			continue
		var last := float(_synergy_cd.get(recipe.recipe_id, -9999.0))
		if now - last < recipe.cooldown:
			continue
		_synergy_cd[recipe.recipe_id] = now
		var effect := recipe.effect as StatusEffect
		if effect:
			effect.on_proc(owner_node, {"style_points": recipe.style_points, "recipe_id": recipe.recipe_id})
		else:
			SignalBus.style_action.emit(GameplayEnums.StyleAction.ELEMENT_CASCADE, recipe.style_points)
			SignalBus.synergy_triggered.emit(owner_node, recipe.recipe_id)
		if recipe.consume_on_trigger:
			for need in recipe.required_statuses:
				remove_status(StringName(need))


func _def(status_id: StringName) -> StatusDefinition:
	var catalog := _catalog()
	if catalog == null:
		return null
	return catalog.get_definition(status_id)


func _catalog() -> StatusCatalog:
	return CATALOG as StatusCatalog


func _emit_statuses() -> void:
	statuses_changed.emit(get_active_ids())
