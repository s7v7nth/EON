extends Node
## Task 10–11 smoke: arena loads, HUD listens, combat loop basics.


func _ready() -> void:
	await get_tree().process_frame
	await _run()


func _run() -> void:
	var arena_packed: PackedScene = load("res://levels/arena/arena.tscn")
	var arena: Node = arena_packed.instantiate()
	add_child(arena)
	await get_tree().process_frame
	await get_tree().physics_frame

	var player: Player = arena.get_node("Entities/Player") as Player
	var enemy: EnemyDummy = arena.get_node("Entities/EnemyDummy") as EnemyDummy
	var hud := arena.get_node("DebugHUD")
	assert(player != null and enemy != null and hud != null)
	assert(arena.get_node("Entities").y_sort_enabled)

	# HUD should have received deferred initial values.
	var health_bar: ProgressBar = hud.get_node("Margin/VBox/HealthBar")
	assert(health_bar.value > 0.0)

	# Player hits enemy via hurtbox API (simulates landed attack).
	var hp_before := enemy.health.current_health
	enemy.hurtbox.receive_hit(player.hitbox.attack_data, player)
	assert(enemy.health.current_health < hp_before)

	# Walls exist on world layer.
	var walls: StaticBody2D = arena.get_node("Walls")
	assert(walls.collision_layer == 1)

	print("TASK10_11_OK arena + hud smoke passed")
	get_tree().quit(0)
