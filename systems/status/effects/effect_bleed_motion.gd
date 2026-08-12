class_name EffectBleedMotion
extends "res://systems/status/status_effect.gd"
## Bleed DoT — stronger while the target moves or attacks.

@export var idle_dot_scale: float = 0.2
@export var moving_dot_scale: float = 0.35
@export var move_speed_threshold: float = 40.0


func on_tick(target: Node, _delta: float, ctx: Dictionary) -> void:
	var power := float(ctx.get("power", 1.0))
	var speed := 0.0
	if target is CharacterBody2D:
		speed = (target as CharacterBody2D).velocity.length()
	var attacking := false
	if target and target.has_meta("is_attacking"):
		attacking = bool(target.get_meta("is_attacking"))
	var scale := moving_dot_scale if (speed >= move_speed_threshold or attacking) else idle_dot_scale
	_deal_dot(target, power * scale)
