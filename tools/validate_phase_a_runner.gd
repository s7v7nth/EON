extends Node
## Phase A smoke: catalog, economy plugins, Synthetic spend, heat zones, vent.


func _ready() -> void:
	await get_tree().process_frame
	await _run()


func _run() -> void:
	RunState.reset()
	var arches := RunState.get_architectures()
	assert(arches.size() >= 3, "catalog should list architectures")
	for arch in arches:
		assert(arch.economy != null, "%s missing economy" % arch.display_name)

	RunState.choose_architecture(GameplayEnums.ArchitectureId.DEFAULT)
	assert(RunState.architecture.display_name == "Синтетик")
	assert(RunState.owned_tags.has("default"))

	var room: Node = load("res://levels/rooms/room_01.tscn").instantiate()
	add_child(room)
	await get_tree().process_frame
	var player: Player = room.get_node("Entities/Player") as Player
	RunState.apply_to_player(player)
	assert(player.active_economy != null)
	assert(player.active_economy.policy == GameplayEnums.EconomyPolicy.ENERGY_ADRENALINE)
	# Synthetic: F reserved; Q needs Energy Mirrors (Lattice Collapse).
	assert(not player.parry_ready())
	assert(not player.try_special())
	var energy_before := player.energy.current_energy
	assert(player.try_spend_dash())
	assert(player.energy.current_energy < energy_before)

	RunState.choose_architecture(GameplayEnums.ArchitectureId.NANOMACHINES)
	RunState.apply_to_player(player)
	assert(player.active_economy.policy == GameplayEnums.EconomyPolicy.BLOOD_HARVEST)
	assert(player.get_node_or_null("SwarmCloud") != null, "Hive should wear a nano swarm")
	var dummy: EnemyDummy = (load("res://entities/enemies/dummy/enemy_dummy.tscn") as PackedScene).instantiate() as EnemyDummy
	player.get_parent().add_child(dummy)
	dummy.global_position = player.global_position + Vector2(48, 0)
	await get_tree().process_frame
	var hp_before := player.health.current_health
	await get_tree().create_timer(0.35, true, false, true).timeout
	assert(player.health.current_health < hp_before, "blood harvest should drain HP")

	RunState.choose_architecture(GameplayEnums.ArchitectureId.ELECTRO_TRAIN)
	RunState.apply_to_player(player)
	assert(player.active_economy.policy == GameplayEnums.EconomyPolicy.OVERHEAT)
	assert(player.try_spend_attack_energy(player.hitbox.attack_data))
	assert(float(player.active_economy.get("heat")) > 0.0)
	player.active_economy.set("heat", float(player.active_economy.get("heat_max")))
	assert(is_equal_approx(player.effective_damage_multiplier() / player.damage_multiplier, 2.0))
	assert(player.try_special())
	assert(is_equal_approx(float(player.active_economy.get("heat")), 0.0))

	room.queue_free()
	RunState.reset()
	print("PHASE_A_OK economies + catalog + vent")
	get_tree().quit(0)
