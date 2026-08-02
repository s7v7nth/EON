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
	if target.has_method("interrupt_attack"):
		target.call("interrupt_attack")
	elif target.has_node("StateMachine"):
		var sm = target.get_node("StateMachine")
		if sm and sm.has_method("transition_to"):
			# Soft interrupt into Idle when available.
			if sm.has_method("has_state") and sm.call("has_state", &"Idle"):
				sm.call("transition_to", &"Idle")
			elif sm.get("current_state") != null:
				pass


func get_action_speed_multiplier(_target: Node) -> float:
	return speed_mult
