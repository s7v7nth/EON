extends Node
## Phase E smoke: behaviors, BIO_MUTANT death burst, Neuro RAM drone + craft.


func _ready() -> void:
	await get_tree().process_frame
	await _run()


func _run() -> void:
	RunState.reset()

	# --- Behaviors + vulnerabilities ---
	var bruiser := load("res://resources/enemies/bruiser.tres") as EnemyDefinition
	var cyborg := load("res://resources/enemies/cyborg.tres") as EnemyDefinition
	var beast := load("res://resources/enemies/robo_beast.tres") as EnemyDefinition
	var android := load("res://resources/enemies/android.tres") as EnemyDefinition
	var mutant := load("res://resources/enemies/bio_mutant.tres") as EnemyDefinition
	assert(bruiser.has_behavior(&"aggro_swarm"))
	assert(cyborg.has_behavior(&"erratic_dodge"))
	assert(beast.has_behavior(&"hyper_chase"))
	assert(android.has_behavior(&"tactical_support"))
	assert(mutant.has_behavior(&"death_burst"))
	assert(mutant.faction == GameplayEnums.Faction.BIO_MUTANT)
	assert(bruiser.get_status_vulnerability(&"burn") > 1.0)
	assert(beast.get_status_vulnerability(&"bleed") > 1.0)
	assert(android.get_status_vulnerability(&"shock") > 1.0)
	assert(cyborg.get_status_vulnerability(&"glitch") > 1.0)

	var room: Node = load("res://levels/rooms/room_01.tscn").instantiate()
	add_child(room)
	await get_tree().process_frame
	var entities: Node2D = room.get_node("Entities") as Node2D

	var enemy_scene := load("res://entities/enemies/dummy/enemy_dummy.tscn") as PackedScene
	var mutant_node := enemy_scene.instantiate() as EnemyDummy
	entities.add_child(mutant_node)
	mutant_node.global_position = Vector2(80, 0)
	mutant_node.apply_definition(mutant)
	assert(mutant_node.has_behavior(&"death_burst"))

	# Dummy nearby to soak death burst.
	var victim := enemy_scene.instantiate() as EnemyDummy
	entities.add_child(victim)
	victim.global_position = Vector2(100, 0)
	victim.apply_definition(bruiser)
	await get_tree().process_frame
	var hp_before := victim.health.current_health
	mutant_node.health.take_damage(9999.0)
	await get_tree().process_frame
	assert(victim.health.current_health < hp_before, "death burst should damage nearby")

	# Erratic dodge chance path exists (force via behavior API).
	var dodge := load("res://resources/enemies/behaviors/erratic_dodge.tres") as BehaviorErraticDodge
	var dodge_inst := dodge.duplicate(true) as BehaviorErraticDodge
	dodge_inst.dodge_chance = 1.0
	var ranged := load("res://resources/attacks/player_ranged_attack.tres") as AttackData
	assert(dodge_inst.try_dodge_projectile(victim, ranged, null))

	# --- Neuro-hacker RAM ---
	RunState.choose_architecture(GameplayEnums.ArchitectureId.NEURO_HACKER)
	assert(RunState.architecture.architecture_id == GameplayEnums.ArchitectureId.NEURO_HACKER)
	var player: Player = room.get_node("Entities/Player") as Player
	RunState.apply_to_player(player)
	assert(player.active_economy != null)
	assert(player.active_economy.policy == GameplayEnums.EconomyPolicy.RAM_COMPUTE)
	var econ := player.active_economy as EconomyRam
	assert(econ != null)
	assert(econ.max_slots == 2)
	assert(player.try_special())
	await get_tree().process_frame
	assert(econ.used_slots == 1)
	var drones := get_tree().get_nodes_in_group("ally_drone")
	assert(drones.size() >= 1)

	# Craft +1 RAM slot.
	var part := load("res://resources/loot/logic_core.tres") as LootPart
	RunState.grant_part(part)
	var upgrade := load("res://resources/upgrades/neuro_extra_slot.tres") as UpgradeData
	assert(RunState.craft_upgrade(upgrade))
	RunState.apply_to_player(player)
	econ = player.active_economy as EconomyRam
	assert(econ.max_slots >= 3)

	room.queue_free()
	RunState.reset()
	print("PHASE_E_OK behaviors + bio mutant + neuro ram")
	get_tree().quit(0)
