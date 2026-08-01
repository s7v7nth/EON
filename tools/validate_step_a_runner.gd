extends Node
## Step A smoke: waves spawn, clear advances, death pauses via overlay.


func _ready() -> void:
	await get_tree().process_frame
	await _run()


func _run() -> void:
	var arena_packed: PackedScene = load("res://levels/arena/arena.tscn")
	var arena: Node = arena_packed.instantiate()
	add_child(arena)
	await get_tree().process_frame

	var player: Player = arena.get_node("Entities/Player") as Player
	var hud := arena.get_node("DebugHUD")
	var overlay := arena.get_node("RunOverlay")
	var spawn_points := arena.get_node("SpawnPoints")
	assert(player != null and hud != null and overlay != null)
	assert(spawn_points.get_child_count() >= 3)
	assert(arena.get("wave_set") != null)

	# Wait for first wave spawn (delay 1.0s + margin).
	await get_tree().create_timer(1.3).timeout
	var enemies := _count_enemies(arena)
	assert(enemies == 1)

	# Kill the enemy via hurtbox.
	var enemy: EnemyDummy = _first_enemy(arena)
	assert(enemy != null)
	enemy.health.take_damage(999.0)
	await get_tree().process_frame
	assert(_count_enemies(arena) == 0)

	# Next wave should spawn (wave 2 delay 1.5).
	await get_tree().create_timer(1.8).timeout
	assert(_count_enemies(arena) == 2)

	# Death overlay path.
	player.health.take_damage(999.0)
	await get_tree().process_frame
	assert(get_tree().paused)
	get_tree().paused = false

	print("STEP_A_OK wave spawn + clear + death overlay")
	get_tree().quit(0)


func _count_enemies(arena: Node) -> int:
	var n := 0
	for child in arena.get_node("Entities").get_children():
		if child is EnemyDummy:
			n += 1
	return n


func _first_enemy(arena: Node) -> EnemyDummy:
	for child in arena.get_node("Entities").get_children():
		if child is EnemyDummy:
			return child as EnemyDummy
	return null
