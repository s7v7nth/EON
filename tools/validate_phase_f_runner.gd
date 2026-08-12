extends Node
## Phase F smoke: campaign route, synergies pack, traps, neuro crafts.


func _ready() -> void:
	await get_tree().process_frame
	await _run()


func _run() -> void:
	RunState.reset()

	# Routes
	var routes := RunState.get_available_routes()
	assert(routes.size() >= 2)
	var campaign := load("res://resources/runs/campaign_route.tres") as ActRoute
	assert(campaign.total_rooms() >= 8)
	RunState.choose_route(campaign)
	assert(RunState.route_picked)
	assert(RunState.room_count() == campaign.total_rooms())
	assert(RunState.biome_for_current_room().biome_id == GameplayEnums.BiomeId.LANDFILL)

	# Synergies catalog
	var catalog := load("res://resources/statuses/status_catalog.tres") as StatusCatalog
	var synergy_ids: PackedStringArray = []
	for item in catalog.all_synergies():
		var recipe := item as SynergyRecipe
		if recipe:
			synergy_ids.append(String(recipe.recipe_id))
	assert(synergy_ids.has("chemical_short"))
	assert(synergy_ids.has("napalm_rend"))
	assert(synergy_ids.has("system_crash"))
	assert(synergy_ids.has("concussive_ignition"))

	# Traps spawn with biome
	var room: Node = load("res://levels/rooms/room_01.tscn").instantiate()
	add_child(room)
	await get_tree().process_frame
	var traps := room.get_node_or_null("Traps")
	assert(traps != null and traps.get_child_count() > 0, "biome traps should spawn")

	# Neuro crafts
	RunState.choose_architecture(GameplayEnums.ArchitectureId.NEURO_HACKER)
	var player: Player = room.get_node("Entities/Player") as Player
	RunState.apply_to_player(player)
	RunState.grant_part(load("res://resources/loot/logic_core.tres") as LootPart)
	RunState.grant_part(load("res://resources/loot/signal_antenna.tres") as LootPart)
	var overclock := load("res://resources/upgrades/neuro_overclock.tres") as UpgradeData
	var glitch_link := load("res://resources/upgrades/neuro_glitch_link.tres") as UpgradeData
	assert(RunState.craft_upgrade(overclock))
	assert(RunState.craft_upgrade(glitch_link))
	RunState.apply_to_player(player)
	var econ := player.active_economy as EconomyRam
	assert(econ != null)
	assert(econ.drone_damage_mult > 1.0)
	assert(econ.drone_glitch_buildup > 0.0)
	assert(player.try_special())
	await get_tree().process_frame
	assert(get_tree().get_nodes_in_group("ally_drone").size() >= 1)

	room.queue_free()
	RunState.reset()
	print("PHASE_F_OK campaign + synergies + traps + neuro crafts")
	get_tree().quit(0)
