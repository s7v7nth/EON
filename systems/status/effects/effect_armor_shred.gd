class_name EffectArmorShred
extends "res://systems/status/status_effect.gd"
## Corrosion: +incoming damage; on death leaves a short acid puddle.

const PUDDLE_SCRIPT := preload("res://systems/status/effects/acid_puddle_runtime.gd")

@export var base_shred: float = 0.15
@export var shred_per_power: float = 0.01
@export var puddle_damage: float = 6.0
@export var puddle_radius: float = 56.0
@export var puddle_duration: float = 2.5


func get_resist_shred(_target: Node, power: float) -> float:
	return base_shred + power * shred_per_power


func modify_incoming_damage(_target: Node, damage: float, _damage_type: int) -> float:
	return damage * 1.08


func on_proc(target: Node, _ctx: Dictionary) -> void:
	_ensure_death_hook(target)


func on_tick(target: Node, _delta: float, ctx: Dictionary) -> void:
	_ensure_death_hook(target)
	var power := float(ctx.get("power", 1.0))
	_deal_dot(target, power * 0.25)


func _ensure_death_hook(target: Node) -> void:
	if target == null or target.has_meta("_acid_death_hooked"):
		return
	var health = _health_of(target)
	if health == null or not health.has_signal("died"):
		return
	target.set_meta("_acid_death_hooked", true)
	health.connect("died", func() -> void: _spawn_puddle(target), CONNECT_ONE_SHOT)


func _spawn_puddle(target: Node) -> void:
	if target == null or target is not Node2D:
		return
	var parent := target.get_parent()
	if parent == null:
		return
	var puddle := Area2D.new()
	puddle.set_script(PUDDLE_SCRIPT)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = puddle_radius
	shape.shape = circle
	puddle.add_child(shape)
	parent.add_child(puddle)
	puddle.global_position = (target as Node2D).global_position
	if puddle.has_method("setup"):
		puddle.call("setup", puddle_damage, puddle_duration, puddle_radius)
