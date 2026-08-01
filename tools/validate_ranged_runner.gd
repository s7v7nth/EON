extends Node
## Validates projectiles (both sides) and dash ghosts.


func _ready() -> void:
	await get_tree().process_frame
	await _run()


func _run() -> void:
	var container := Node2D.new()
	add_child(container)

	var player: Player = (load("res://entities/player/player.tscn") as PackedScene).instantiate() as Player
	var enemy: EnemyDummy = (load("res://entities/enemies/dummy/enemy_dummy.tscn") as PackedScene).instantiate() as EnemyDummy
	player.position = Vector2(0, 0)
	enemy.position = Vector2(150, 0)
	container.add_child(player)
	container.add_child(enemy)
	await get_tree().process_frame
	await get_tree().physics_frame

	# Freeze AI/FSMs so nothing moves while projectiles fly.
	player.state_machine.set_physics_process(false)
	enemy.state_machine.set_physics_process(false)

	# Player projectile hits enemy hurtbox.
	var enemy_hp_before := enemy.health.current_health
	player.spawn_projectile(Vector2.RIGHT)
	for i in 60:
		if not is_instance_valid(enemy) or enemy.health.current_health < enemy_hp_before:
			break
		await get_tree().physics_frame
	assert(enemy.health.current_health < enemy_hp_before)
	print("player projectile OK: ", enemy_hp_before, " -> ", enemy.health.current_health)

	# Enemy projectile hits player hurtbox.
	var player_hp_before := player.health.current_health
	enemy.spawn_projectile(Vector2.LEFT)
	for i in 60:
		if player.health.current_health < player_hp_before:
			break
		await get_tree().physics_frame
	assert(player.health.current_health < player_hp_before)
	print("enemy projectile OK: ", player_hp_before, " -> ", player.health.current_health)

	# Enemy projectile must NOT hit during player i-frames.
	player.hurtbox.set_invincible(true)
	await get_tree().physics_frame
	var hp_iframes := player.health.current_health
	enemy.spawn_projectile(Vector2.LEFT)
	for i in 40:
		await get_tree().physics_frame
	assert(is_equal_approx(player.health.current_health, hp_iframes))
	player.hurtbox.set_invincible(false)
	print("projectile i-frames OK")

	# Dash spawns ghost afterimages.
	player.state_machine.set_physics_process(true)
	var ghosts_before := _count_ghosts(container)
	player.state_machine.transition_to(&"Dash")
	for i in 10:
		await get_tree().physics_frame
	var ghosts_after := _count_ghosts(container)
	assert(ghosts_after > ghosts_before)
	print("dash ghosts OK: ", ghosts_after - ghosts_before, " spawned")

	print("RANGED_DASH_OK all new mechanics passed")
	get_tree().quit(0)


func _count_ghosts(container: Node) -> int:
	var count := 0
	for child in container.get_children():
		if child is Polygon2D:
			count += 1
	return count
