extends Node
## Step B smoke: knockback impulse + hit-stop punch.


func _ready() -> void:
	await get_tree().process_frame
	await _run()


func _run() -> void:
	var arena_packed: PackedScene = load("res://levels/arena/arena.tscn")
	var arena: Node = arena_packed.instantiate()
	add_child(arena)
	await get_tree().process_frame

	# Spawn one enemy immediately without waiting for wave delay.
	var enemy_scene: PackedScene = load("res://entities/enemies/dummy/enemy_dummy.tscn")
	var enemy: EnemyDummy = enemy_scene.instantiate() as EnemyDummy
	arena.get_node("Entities").add_child(enemy)
	enemy.global_position = Vector2(100, 0)
	await get_tree().physics_frame

	var player: Player = arena.get_node("Entities/Player") as Player
	var attack := load("res://resources/attacks/player_basic_attack.tres") as AttackData
	assert(attack.knockback_force > 0.0)

	var pos_before := enemy.global_position
	enemy.hurtbox.receive_hit(attack, player)
	assert(enemy._kb_time > 0.0)
	assert(enemy._kb_force > 0.0)

	# Simulate a few physics ticks of knockback movement.
	for _i in 5:
		enemy.apply_chase_movement()
		await get_tree().physics_frame
	assert(enemy.global_position.distance_to(pos_before) > 1.0)

	# Hit-stop should restore time_scale.
	HitStop.punch(0.1, 0.02)
	await get_tree().create_timer(0.05, true, false, true).timeout
	assert(is_equal_approx(Engine.time_scale, 1.0))

	var heavy := load("res://resources/attacks/player_heavy_attack.tres") as AttackData
	assert(heavy.damage > attack.damage)
	assert(heavy.knockback_force > attack.knockback_force)

	print("STEP_B_OK knockback + hitstop + heavy attack data")
	get_tree().quit(0)
