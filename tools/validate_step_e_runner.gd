extends Node
## Step E smoke: modifiers, room clear → reward → next room, final win.


func _ready() -> void:
	await get_tree().process_frame
	await _run()


func _run() -> void:
	RunState.reset()
	assert(RunState.room_index == 0)

	var room1: Node = load("res://levels/rooms/room_01.tscn").instantiate()
	add_child(room1)
	await get_tree().process_frame
	assert(room1.get("is_final_room") == false)

	var player: Player = room1.get_node("Entities/Player") as Player
	assert(is_equal_approx(player.damage_multiplier, 1.0))

	# Clear both waves quickly.
	await _clear_all_enemies(room1, 0.9)
	await _clear_all_enemies(room1, 1.4)
	await get_tree().process_frame
	assert(room1.get_node("ExitMarker").visible)

	# Enter exit → reward overlay path.
	SignalBus.exit_reached.emit()
	await get_tree().process_frame
	assert(get_tree().paused)

	RunState.choose_modifier(&"damage")
	assert(is_equal_approx(RunState.damage_mult, 1.2))

	get_tree().paused = false
	room1.queue_free()
	await get_tree().process_frame

	RunState.room_index = 1
	var room2: Node = load("res://levels/rooms/room_02.tscn").instantiate()
	add_child(room2)
	await get_tree().process_frame
	player = room2.get_node("Entities/Player") as Player
	RunState.apply_to_player(player)
	assert(is_equal_approx(player.damage_multiplier, 1.2))
	room2.queue_free()
	await get_tree().process_frame

	# Final room: listen before load, force clear after spawn settles.
	RunState.room_index = 2
	var won_flag := {"value": false}
	SignalBus.run_won.connect(func() -> void: won_flag.value = true)

	var room3: Node = load("res://levels/rooms/room_03.tscn").instantiate()
	add_child(room3)
	await get_tree().process_frame
	assert(room3.get("is_final_room") == true)

	# Direct controller path (same as after last wave).
	(room3 as ArenaController).force_clear_room()
	await get_tree().process_frame
	assert(won_flag.value)
	assert(get_tree().paused)
	get_tree().paused = false
	RunState.reset()

	print("STEP_E_OK rooms + modifiers + final win")
	get_tree().quit(0)


func _clear_all_enemies(room: Node, wait_spawn: float) -> void:
	await get_tree().create_timer(wait_spawn).timeout
	var entities: Node = room.get_node("Entities")
	var enemies: Array = []
	for child in entities.get_children():
		if child is EnemyDummy:
			enemies.append(child)
	for enemy in enemies:
		(enemy as EnemyDummy).health.take_damage(999.0)
	await get_tree().process_frame
	await get_tree().process_frame
