extends Node
## Step C smoke: enemy definitions apply + sniper kite retreat.


func _ready() -> void:
	await get_tree().process_frame
	await _run()


func _run() -> void:
	var enemy_scene: PackedScene = load("res://entities/enemies/dummy/enemy_dummy.tscn")
	var bruiser_def := load("res://resources/enemies/bruiser.tres") as EnemyDefinition
	var sniper_def := load("res://resources/enemies/sniper.tres") as EnemyDefinition
	var swarm_def := load("res://resources/enemies/swarm.tres") as EnemyDefinition
	assert(bruiser_def and sniper_def and swarm_def)

	var root := Node2D.new()
	add_child(root)

	var bruiser: EnemyDummy = enemy_scene.instantiate() as EnemyDummy
	root.add_child(bruiser)
	bruiser.apply_definition(bruiser_def)
	assert(bruiser.health.get_max_health() == bruiser_def.stats.max_health)
	assert(bruiser.hitbox.attack_data == bruiser_def.melee_attack)
	assert(bruiser.ranged_attack_data == null)
	var bvis := bruiser.get_node("Visual") as Polygon2D
	assert(bvis.color.is_equal_approx(bruiser_def.visual_color))

	var sniper: EnemyDummy = enemy_scene.instantiate() as EnemyDummy
	root.add_child(sniper)
	sniper.apply_definition(sniper_def)
	assert(sniper.prefers_kite)
	assert(sniper.hitbox.attack_data == null)
	assert(sniper.ranged_attack_data == sniper_def.ranged_attack)

	var target := Node2D.new()
	root.add_child(target)
	target.global_position = Vector2(40, 0)
	sniper.global_position = Vector2.ZERO
	sniper.target = target
	var pos_before := sniper.global_position
	sniper.apply_retreat_movement()
	await get_tree().physics_frame
	assert(sniper.global_position.distance_to(pos_before) > 0.5)

	var swarm: EnemyDummy = enemy_scene.instantiate() as EnemyDummy
	root.add_child(swarm)
	swarm.apply_definition(swarm_def)
	assert(swarm.stats.move_speed > bruiser.stats.move_speed)

	# Wave set mixes definitions.
	var waves := load("res://resources/waves/default_waves.tres") as WaveSet
	assert(waves.wave_count() == 5)
	var w3 := waves.get_wave(2)
	assert(w3.spawns.size() == 2)

	print("STEP_C_OK archetypes + kite + wave mix")
	get_tree().quit(0)
