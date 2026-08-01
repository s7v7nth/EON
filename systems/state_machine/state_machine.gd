class_name StateMachine
extends Node
## Dispatches process/physics/input to the active State child.

@export var initial_state: State

var current_state: State
var _states: Dictionary = {} # StringName -> State


func _ready() -> void:
	for child in get_children():
		if child is State:
			var state := child as State
			state.state_machine = self
			_states[state.name] = state
	if initial_state == null and not _states.is_empty():
		initial_state = _states.values()[0]
	if initial_state:
		current_state = initial_state
		current_state.enter()


func _unhandled_input(event: InputEvent) -> void:
	if current_state:
		current_state.handle_input(event)


func _process(delta: float) -> void:
	if current_state:
		current_state.update(delta)


func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)


func transition_to(state_name: StringName, msg: Dictionary = {}) -> void:
	if not _states.has(state_name):
		push_warning("StateMachine: unknown state '%s'" % state_name)
		return
	var next: State = _states[state_name]
	if next == current_state:
		return
	if current_state:
		current_state.exit()
	current_state = next
	current_state.enter(msg)
