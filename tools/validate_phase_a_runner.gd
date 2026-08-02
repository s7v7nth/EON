extends Node
## Phase A smoke: catalog, economy plugins, free basics, heat zones, vent.


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
	assert(player.try_spend_parry())
	assert(player.try_spend_dash())
	# Basics must not drain energy for Synthetic.
	assert(is_equal_approx(player.energy.current_energy, player.energy.get_max_energy()))

	RunState.choose_architecture(GameplayEnums.ArchitectureId.NANOMACHINES)
	RunState.apply_to_player(player)
	assert(player.active_economy.policy == GameplayEnums.EconomyPolicy.BLOOD_HARVEST)
	var hp_before := player.health.current_health
	await get_tree().create_timer(0.25).timeout
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
