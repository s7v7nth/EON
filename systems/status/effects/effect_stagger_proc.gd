class_name EffectStaggerProc
extends "res://systems/status/status_effect.gd"
## Physical stagger: interrupt + next hit crit window.

@export var crit_window: float = 1.2
@export var crit_bonus: float = 1.35
@export var speed_mult: float = 0.5


func on_proc(target: Node, _ctx: Dictionary) -> void:
	if target == null:
		return
	target.set_meta("stagger_crit_until", Time.get_ticks_msec() / 1000.0 + crit_window)
	target.set_meta("stagger_crit_bonus", crit_bonus)
	if target.has_method("apply_hard_stun"):
		target.call("apply_hard_stun", maxf(crit_window * 0.55, 0.7))
	elif target.has_method("interrupt_attack"):
		target.call("interrupt_attack")
		if target.get("combat_visual") is CombatVisualComponent:
			(target.get("combat_visual") as CombatVisualComponent).play_stun_stars(maxf(crit_window * 0.55, 0.7))


func get_action_speed_multiplier(_target: Node) -> float:
	return speed_mult
