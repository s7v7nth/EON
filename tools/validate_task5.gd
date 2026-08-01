extends SceneTree
## FSM enter/exit order smoke test for Task 5.


func _initialize() -> void:
	var host := Node.new()
	host.name = "Host"
	root.add_child(host)

	var log: Array = []

	var machine := StateMachine.new()
	machine.name = "StateMachine"

	var idle := LoggingState.new()
	idle.name = "Idle"
	idle.label = "Idle"
	idle.log_ref = log

	var move := LoggingState.new()
	move.name = "Move"
	move.label = "Move"
	move.log_ref = log

	machine.add_child(idle)
	machine.add_child(move)
	machine.initial_state = idle
	host.add_child(machine)

	await process_frame

	assert(machine.current_state == idle)
	assert(log == ["Idle:enter"])

	machine.transition_to(&"Move")
	assert(log == ["Idle:enter", "Idle:exit", "Move:enter"])
	assert(machine.current_state == move)

	machine.transition_to(&"Idle")
	assert(log == ["Idle:enter", "Idle:exit", "Move:enter", "Move:exit", "Idle:enter"])

	print("TASK5_OK state machine transitions passed")
	quit(0)
