extends Node
## Task 9 — enemy aggro, chase, attack, death.


func _ready() -> void:
	await get_tree().process_frame
	await _run()


func _run() -> void:
	var player_packed: PackedScene = load("res://entities/player/player.tscn")
	var enemy_packed: PackedScene = load("res://entities/enemies/dummy/enemy_dummy.tscn")
	var player: Player = player_packed.instantiate() as Player
	var enemy: EnemyDummy = enemy_packed.instantiate() as EnemyDummy
	player.position = Vector2(0, 0)
	enemy.position = Vector2(80, 0)
	add_child(player)
	add_child(enemy)
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().physics_frame

	# Detection should pick up player (within 220px).
	assert(enemy.target == player)
	assert(enemy.state_machine.current_state.name == "Chase" or enemy.state_machine.current_state.name == "Attack")

	# Deal enough damage to kill (50 HP / 10 dmg = 5 hits).
	var died_flag: Array = [false]
	SignalBus.enemy_died.connect(func(_e: Node) -> void: died_flag[0] = true)
	for i in 5:
		enemy.hurtbox.receive_hit(player.hitbox.attack_data, player)
	await get_tree().process_frame
	assert(died_flag[0])
	assert(not is_instance_valid(enemy) or enemy.is_queued_for_deletion())

	print("TASK9_OK enemy aggro/death passed")
	get_tree().quit(0)
