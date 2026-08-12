class_name EffectPressureValve
extends "res://systems/upgrades/upgrade_effect.gd"
## Vent dumps harder, cools faster: larger blast, shorter weapon lock.

@export var vent_damage_mult: float = 1.4
@export var vent_radius_mult: float = 1.25
@export var lock_mult: float = 0.55

var _saved_damage: float = -1.0
var _saved_radius: float = -1.0
var _saved_cd_base: float = -1.0
var _saved_cd_per: float = -1.0


func apply(host: Node) -> void:
	var econ = host.get("active_economy")
	if econ == null or not (econ is EconomyOverheat):
		return
	_saved_damage = float(econ.vent_base_damage)
	_saved_radius = float(econ.vent_radius)
	_saved_cd_base = float(econ.vent_cooldown_base)
	_saved_cd_per = float(econ.vent_cooldown_per_heat)
	econ.vent_base_damage = _saved_damage * vent_damage_mult
	econ.vent_radius = _saved_radius * vent_radius_mult
	econ.vent_cooldown_base = _saved_cd_base * lock_mult
	econ.vent_cooldown_per_heat = _saved_cd_per * lock_mult


func remove(host: Node) -> void:
	var econ = host.get("active_economy")
	if econ == null or not (econ is EconomyOverheat):
		return
	if _saved_damage >= 0.0:
		econ.vent_base_damage = _saved_damage
	if _saved_radius >= 0.0:
		econ.vent_radius = _saved_radius
	if _saved_cd_base >= 0.0:
		econ.vent_cooldown_base = _saved_cd_base
	if _saved_cd_per >= 0.0:
		econ.vent_cooldown_per_heat = _saved_cd_per
	_saved_damage = -1.0
	_saved_radius = -1.0
	_saved_cd_base = -1.0
	_saved_cd_per = -1.0
