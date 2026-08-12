class_name EffectBurn
extends "res://systems/status/status_effect.gd"
## Fire DoT; full proc can panic soft-AI (random flee impulse).

@export var dot_scale: float = 0.35
@export var panic_impulse: float = 220.0


func on_proc(target: Node, _ctx: Dictionary) -> void:
	if target == null:
		return
	target.set_meta("panicking", true)
	if target is CharacterBody2D:
		var dir := Vector2.from_angle(randf() * TAU)
		(target as CharacterBody2D).velocity = dir * panic_impulse
	if target.has_method("apply_knockback"):
		target.call("apply_knockback", Vector2.from_angle(randf() * TAU), panic_impulse * 0.5)


func on_tick(target: Node, _delta: float, ctx: Dictionary) -> void:
	var power := float(ctx.get("power", 1.0))
	_deal_dot(target, power * dot_scale)


func on_expire(target: Node, _ctx: Dictionary) -> void:
	if target and target.has_meta("panicking"):
		target.remove_meta("panicking")
