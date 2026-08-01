class_name AdrenalineComponent
extends Node
## Builds in combat, boosts EnergyComponent regen, decays after idle delay.

@export var stats: CharacterStats
@export var energy_component: EnergyComponent

## Threshold fractions of max_adrenaline → regen multipliers.
const THRESHOLDS: Array[Dictionary] = [
	{"min_ratio": 0.75, "multiplier": 2.5},
	{"min_ratio": 0.5, "multiplier": 2.0},
	{"min_ratio": 0.25, "multiplier": 1.5},
	{"min_ratio": 0.0, "multiplier": 1.0},
]

var current_adrenaline: float = 0.0
var _time_since_combat: float = 0.0

signal adrenaline_changed(current: float, max_value: float)


func _ready() -> void:
	if stats == null:
		push_error("%s: CharacterStats is required" % name)
		return
	_time_since_combat = stats.adrenaline_decay_delay
	_apply_regen_multiplier()
	adrenaline_changed.emit(current_adrenaline, stats.max_adrenaline)


func _process(delta: float) -> void:
	if stats == null or stats.max_adrenaline <= 0.0:
		return
	_time_since_combat += delta
	if _time_since_combat < stats.adrenaline_decay_delay:
		return
	if current_adrenaline <= 0.0:
		return
	current_adrenaline = maxf(current_adrenaline - stats.adrenaline_decay_rate * delta, 0.0)
	_apply_regen_multiplier()
	adrenaline_changed.emit(current_adrenaline, stats.max_adrenaline)


func add(amount: float) -> void:
	if amount <= 0.0 or stats == null or stats.max_adrenaline <= 0.0:
		return
	current_adrenaline = minf(current_adrenaline + amount, stats.max_adrenaline)
	_time_since_combat = 0.0
	_apply_regen_multiplier()
	adrenaline_changed.emit(current_adrenaline, stats.max_adrenaline)


func _apply_regen_multiplier() -> void:
	if energy_component == null or stats == null:
		return
	var ratio := 0.0
	if stats.max_adrenaline > 0.0:
		ratio = current_adrenaline / stats.max_adrenaline
	var multiplier := 1.0
	for entry in THRESHOLDS:
		if ratio >= float(entry["min_ratio"]):
			multiplier = float(entry["multiplier"])
			break
	energy_component.set_regen_multiplier(multiplier)


func get_max_adrenaline() -> float:
	return stats.max_adrenaline if stats else 0.0
