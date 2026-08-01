extends Node
## Task 7 — dash energy, cooldown, i-frames.


func _ready() -> void:
	await get_tree().process_frame
	await _run()


func _run() -> void:
	var packed: PackedScene = load("res://entities/player/player.tscn")
	var player: Player = packed.instantiate() as Player
	add_child(player)
	await get_tree().process_frame
	await get_tree().process_frame

	var energy_before := player.energy.current_energy
	player.facing_direction = Vector2.RIGHT
	player.state_machine.transition_to(&"Dash")
	await get_tree().process_frame

	assert(player.state_machine.current_state.name == "Dash")
	assert(player.hurtbox.is_invincible())
	assert(player.energy.current_energy < energy_before)

	# Wait out dash duration.
	await get_tree().create_timer(player.stats.dash_duration + 0.05).timeout
	await get_tree().process_frame
	assert(player.state_machine.current_state.name != "Dash")
	assert(not player.hurtbox.is_invincible())
	assert(not player.dash_cooldown.is_stopped())

	# Cooldown / insufficient energy should refuse dash.
	var mid_energy := player.energy.current_energy
	player.state_machine.transition_to(&"Dash")
	await get_tree().process_frame
	# Still on cooldown → immediately bounced back; must not spend dash_cost.
	assert(player.state_machine.current_state.name != "Dash")
	assert(player.energy.current_energy > mid_energy - 1.0) # regen ok, spend not ok
	assert(player.energy.current_energy > mid_energy - player.stats.dash_cost + 1.0)

	# Drain energy and ensure dash cannot spend.
	player.dash_cooldown.stop()
	player.energy.current_energy = 0.0
	player.energy.set_regen_multiplier(0.0)
	player.energy.set_process(false)
	player.state_machine.transition_to(&"Dash")
	await get_tree().process_frame
	assert(player.state_machine.current_state.name != "Dash")
	assert(player.energy.current_energy < player.stats.dash_cost)

	print("TASK7_OK dash energy/cooldown/i-frames passed")
	get_tree().quit(0)
