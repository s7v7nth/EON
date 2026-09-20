extends Node
## Phase D smoke: ActRoute path, per-biome waves, faction weights, final craft→win.


func _ready() -> void:
	await get_tree().process_frame
	await _run()


func _run() -> void:
	RunState.reset()
	RunState.choose_architecture(GameplayEnums.ArchitectureId.DEFAULT)

	var route := RunState.current_route
	assert(route != null, "tutorial ActRoute missing")
	assert(route.total_rooms() == 3, "tutorial should be 3 rooms")
	assert(route.biome_at(0).biome_id == GameplayEnums.BiomeId.LANDFILL)
	assert(route.biome_at(1).biome_id == GameplayEnums.BiomeId.WASTELAND)
	assert(route.biome_at(2).biome_id == GameplayEnums.BiomeId.DATA_CENTER)

	# Dedicated wave sets — no mall/downtown sharing data_center waves.
	var mall := load("res://resources/biomes/mall.tres") as BiomeDefinition
	var downtown := load("res://resources/biomes/downtown.tres") as BiomeDefinition
	var data := load("res://resources/biomes/data_center.tres") as BiomeDefinition
	assert(mall.wave_set != data.wave_set)
	assert(downtown.wave_set != data.wave_set)
	var wasteland := load("res://resources/biomes/wasteland.tres") as BiomeDefinition
	var landfill := load("res://resources/biomes/landfill.tres") as BiomeDefinition
	assert(wasteland.wave_set != landfill.wave_set)

	# Faction weights resolve.
	assert(landfill.has_faction_weights())
	var faction := landfill.pick_faction()
	assert(faction in landfill.faction_ids)
	var catalog := RunState.enemy_catalog
	assert(catalog != null)
	var picked := catalog.pick_for_biome(landfill, null)
	assert(picked != null)
	assert(int(picked.faction) in landfill.faction_ids)

	# Room 0 applies landfill from route (not scene export).
	var room1: Node = load("res://levels/rooms/room_01.tscn").instantiate()
	add_child(room1)
	await get_tree().process_frame
	assert(RunState.current_biome.biome_id == GameplayEnums.BiomeId.LANDFILL)
	assert((room1 as ArenaController).is_final_room == false)
	var tutorial_waves := load("res://resources/waves/tutorial_landfill_waves.tres") as WaveSet
	assert((room1 as ArenaController).wave_set == tutorial_waves, "tutorial room 1 keeps authored waves")

	(room1 as ArenaController).force_clear_room()
	await get_tree().process_frame
	assert(room1.get_node("ExitMarker").visible)
	SignalBus.exit_reached.emit()
	await get_tree().process_frame
	assert(get_tree().paused)
	get_tree().paused = false
	room1.queue_free()
	await get_tree().process_frame

	# Advance to wasteland layout.
	RunState.seek_room(1)
	var room2: Node = load(RunState.layout_scene_for_current_room()).instantiate()
	add_child(room2)
	await get_tree().process_frame
	assert(RunState.current_biome.biome_id == GameplayEnums.BiomeId.WASTELAND)
	room2.queue_free()
	await get_tree().process_frame

	# Final room: clear → reward → win (not instant run_won).
	RunState.seek_room(2)
	var won_flag := {"value": false}
	SignalBus.run_won.connect(func() -> void: won_flag.value = true)

	var room3: Node = load(RunState.layout_scene_for_current_room()).instantiate()
	add_child(room3)
	await get_tree().process_frame
	assert(RunState.current_biome.biome_id == GameplayEnums.BiomeId.DATA_CENTER)
	assert((room3 as ArenaController).is_final_room == true)

	(room3 as ArenaController).force_clear_room()
	await get_tree().process_frame
	assert(not won_flag.value, "win must wait for final craft/reward")
	assert(room3.get_node("ExitMarker").visible)

	SignalBus.exit_reached.emit()
	await get_tree().process_frame
	assert(get_tree().paused)
	RunState.choose_modifier(&"damage")
	RunState.finish_room_reward()
	await get_tree().process_frame
	assert(won_flag.value)

	get_tree().paused = false
	room3.queue_free()
	RunState.reset()

	print("PHASE_D_OK act route + biome waves + faction weights + final craft")
	get_tree().quit(0)
