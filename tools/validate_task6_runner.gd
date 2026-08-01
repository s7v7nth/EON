extends Node
## Task 6 validation — run as main scene so autoloads resolve.


func _ready() -> void:
	await get_tree().process_frame
	await _run()


func _run() -> void:
	var packed: PackedScene = load("res://entities/player/player.tscn")
	assert(packed != null)
	var player: Player = packed.instantiate() as Player
	add_child(player)
	await get_tree().process_frame
	await get_tree().process_frame

	assert(player.state_machine.current_state.name == "Idle")
	assert(player.stats != null)
	assert(player.health != null and player.energy != null)
	assert(Iso != null and SignalBus != null)

	var start := player.global_position
	for i in 10:
		player.apply_movement(Vector2.RIGHT)
		await get_tree().physics_frame
	assert(player.global_position.x > start.x)

	start = player.global_position
	var horiz_step := player.stats.move_speed / float(Engine.physics_ticks_per_second)
	for i in 10:
		player.apply_movement(Vector2.UP)
		await get_tree().physics_frame
	var dy := absf(player.global_position.y - start.y)
	assert(dy > 0.0)
	assert(dy < horiz_step * 10.0 * 0.95)
	assert(dy > horiz_step * 10.0 * Iso.Y_SCALE * 0.5)

	var dir := Vector2(1, 1).normalized()
	var expected := Iso.apply_velocity(dir, player.stats.move_speed)
	player.apply_movement(dir)
	assert(player.velocity.distance_to(expected) < 0.1)

	print("TASK6_OK player idle/move + iso velocity passed dy=", dy)
	get_tree().quit(0)
