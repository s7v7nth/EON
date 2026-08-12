class_name EffectPlasmaAfterburn
extends "res://systems/upgrades/upgrade_effect.gd"
## After Vent: brief afterburn window — attacks add less heat, deal bonus damage.

@export var window_sec: float = 4.0
@export var damage_bonus: float = 1.25
@export var heat_gain_mult: float = 0.35

var _remaining: float = 0.0
var _connected: bool = false
var _saved_heat_gain: float = -1.0
var _host_ref: WeakRef


func apply(host: Node) -> void:
	_host_ref = weakref(host)
	if not _connected and not SignalBus.vent_triggered.is_connected(_on_vent):
		SignalBus.vent_triggered.connect(_on_vent)
		_connected = true


func remove(host: Node) -> void:
	_end_window(host)
	if _connected and SignalBus.vent_triggered.is_connected(_on_vent):
		SignalBus.vent_triggered.disconnect(_on_vent)
	_connected = false
	_host_ref = null


func tick(host: Node, delta: float) -> void:
	if _remaining <= 0.0:
		return
	_remaining = maxf(0.0, _remaining - delta)
	if _remaining <= 0.0:
		_end_window(host)


func damage_multiplier(_host: Node) -> float:
	return damage_bonus if _remaining > 0.0 else 1.0


func _on_vent(source: Node) -> void:
	var host: Node = _host_ref.get_ref() if _host_ref != null else null
	if host == null or source != host:
		return
	_begin_window(host)


func _begin_window(host: Node) -> void:
	_remaining = window_sec
	var econ = host.get("active_economy")
	if econ == null or not (econ is EconomyOverheat):
		return
	if _saved_heat_gain < 0.0:
		_saved_heat_gain = float(econ.heat_gain_per_action)
		econ.heat_gain_per_action = _saved_heat_gain * heat_gain_mult


func _end_window(host: Node) -> void:
	_remaining = 0.0
	var econ = host.get("active_economy") if host != null else null
	if econ != null and econ is EconomyOverheat and _saved_heat_gain >= 0.0:
		econ.heat_gain_per_action = _saved_heat_gain
	_saved_heat_gain = -1.0
