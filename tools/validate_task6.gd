extends SceneTree
## Validates player scene load, movement helpers, iso compression for Task 6.


func _initialize() -> void:
	var packed: PackedScene = load("res://entities/player/player.tscn")
	assert(packed != null)
	var player: Player = packed.instantiate() as Player
	root.add_child(player)
	await process_frame
	await process_frame

	assert(player.state_machine.current_state.name == "Idle")
	assert(player.stats != null)
	assert(player.health != null and player.energy != null)

	var y_scale: float = 0.7
	var iso := root.get_node_or_null("/root/Iso")
	if iso:
		y_scale = iso.Y_SCALE

	var start := player.global_position
	for i in 10:
		player.apply_movement(Vector2.RIGHT)
		await physics_frame
	assert(player.global_position.x > start.x)

	start = player.global_position
	var horiz_step := player.stats.move_speed / float(Engine.physics_ticks_per_second)
	for i in 10:
		player.apply_movement(Vector2.UP)
		await physics_frame
	var dy := absf(player.global_position.y - start.y)
	assert(dy > 0.0)
	# Vertical travel must be slower than full-speed horizontal would be.
	assert(dy < horiz_step * 10.0 * 0.95)
	assert(dy > horiz_step * 10.0 * y_scale * 0.5)

	var dir := Vector2(1, 1).normalized()
	var expected := dir * player.stats.move_speed
	expected.y *= y_scale
	player.velocity = Vector2.ZERO
	player.apply_movement(dir)
	assert(player.velocity.distance_to(expected) < 0.1)

	print("TASK6_OK player idle/move + iso velocity passed dy=", dy)
	quit(0)
