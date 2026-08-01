class_name State
extends Node
## Base FSM state. Concrete states override virtual methods.

var state_machine: StateMachine


func enter(_msg: Dictionary = {}) -> void:
	pass


func exit() -> void:
	pass


func update(_delta: float) -> void:
	pass


func physics_update(_delta: float) -> void:
	pass


func handle_input(_event: InputEvent) -> void:
	pass


func transition_to(state_name: StringName, msg: Dictionary = {}) -> void:
	state_machine.transition_to(state_name, msg)
