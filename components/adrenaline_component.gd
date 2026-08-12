class_name AdrenalineComponent
extends Node
## Builds in combat toward/above a baseline; drives EnergyComponent regen rate.

@export var stats: CharacterStats
@export var energy_component: EnergyComponent
@export var engagement: CombatEngagementComponent

var current_adrenaline: float = 0.0
var _time_since_gain: float = 0.0

signal adrenaline_changed(current: float, max_value: float)


func _ready() -> void:
	if stats == null:
		push_error("%s: CharacterStats is required" % name)
		return
	_time_since_gain = stats.adrenaline_decay_delay
	call_deferred("_bind_engagement")
	_apply_regen_from_adrenaline()
	adrenaline_changed.emit(current_adrenaline, stats.max_adrenaline)


func _bind_engagement() -> void:
	if engagement == null:
		var parent := get_parent()
		if parent:
			engagement = parent.get_node_or_null("CombatEngagement") as CombatEngagementComponent
	if engagement and not engagement.combat_changed.is_connected(_on_combat_changed):
		engagement.combat_changed.connect(_on_combat_changed)
	_apply_regen_from_adrenaline()


func _process(delta: float) -> void:
	if stats == null or stats.max_adrenaline <= 0.0:
		return
	_time_since_gain += delta
	var floor_v := _floor()
	var changed := false
	# Snap up to combat baseline when engaged.
	if floor_v > 0.0 and current_adrenaline < floor_v:
		current_adrenaline = floor_v
		changed = true

	if _time_since_gain >= stats.adrenaline_decay_delay and current_adrenaline > floor_v + 0.01:
		current_adrenaline = maxf(current_adrenaline - stats.adrenaline_decay_rate * delta, floor_v)
		changed = true
	elif current_adrenaline < floor_v:
		current_adrenaline = floor_v
		changed = true

	_apply_regen_from_adrenaline()
	if changed:
		adrenaline_changed.emit(current_adrenaline, stats.max_adrenaline)


func add(amount: float) -> void:
	if amount <= 0.0 or stats == null or stats.max_adrenaline <= 0.0:
		return
	current_adrenaline = minf(current_adrenaline + amount, stats.max_adrenaline)
	_time_since_gain = 0.0
	if engagement:
		engagement.notify_exchange()
	_apply_regen_from_adrenaline()
	adrenaline_changed.emit(current_adrenaline, stats.max_adrenaline)


func _floor() -> float:
	if engagement == null or not engagement.in_combat:
		return 0.0
	return stats.baseline_adrenaline if stats else 0.0


func _on_combat_changed(in_combat: bool) -> void:
	if in_combat and stats and current_adrenaline < stats.baseline_adrenaline:
		current_adrenaline = stats.baseline_adrenaline
		adrenaline_changed.emit(current_adrenaline, stats.max_adrenaline)
	_apply_regen_from_adrenaline()


func _apply_regen_from_adrenaline() -> void:
	if energy_component == null or stats == null:
		return
	## Adrenaline drives regen even while leaving combat (until it decays to 0).
	var regen := 0.0
	if current_adrenaline > 0.01:
		if current_adrenaline >= stats.baseline_adrenaline:
			var span := maxf(stats.max_adrenaline - stats.baseline_adrenaline, 1.0)
			var above := current_adrenaline - stats.baseline_adrenaline
			regen = stats.baseline_energy_regen + stats.max_bonus_energy_regen * (above / span)
		else:
			regen = stats.baseline_energy_regen * (current_adrenaline / maxf(stats.baseline_adrenaline, 1.0))
	if energy_component.allow_external_regen_mult:
		energy_component.set_absolute_regen(regen)


func get_max_adrenaline() -> float:
	return stats.max_adrenaline if stats else 0.0
