extends Node
## Task 8 — attack windup/active window and cooldown.


func _ready() -> void:
	await get_tree().process_frame
	await _run()


func _run() -> void:
	var packed: PackedScene = load("res://entities/player/player.tscn")
	var player: Player = packed.instantiate() as Player
	add_child(player)
	await get_tree().process_frame
	await get_tree().process_frame

	var attack: AttackData = player.hitbox.attack_data
	assert(attack != null)

	player.state_machine.transition_to(&"Attack")
	await get_tree().process_frame
	assert(player.state_machine.current_state.name == "Attack")
	# Windup is 0 on light attacks — hitbox is live on the click.
	await get_tree().create_timer(attack.windup + 0.03).timeout
	await get_tree().physics_frame
	assert(player.hitbox.monitoring)

	# After active + recovery, leave Attack and start cooldown.
	await get_tree().create_timer(attack.active_duration + attack.recovery + 0.08).timeout
	await get_tree().process_frame
	assert(player.state_machine.current_state.name != "Attack")
	assert(not player.hitbox.monitoring)
	assert(not player.attack_cooldown.is_stopped())

	# Cooldown blocks re-entry.
	player.state_machine.transition_to(&"Attack")
	await get_tree().process_frame
	assert(player.state_machine.current_state.name != "Attack")

	print("TASK8_OK player attack window/cooldown passed")
	get_tree().quit(0)
