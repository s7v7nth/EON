extends Node
## Smoke: elites, boss wave pack, special room kinds.


func _ready() -> void:
	await get_tree().process_frame
	await _run()


func _run() -> void:
	# Elite apply on dummy.
	var enemy: EnemyDummy = (load("res://entities/enemies/dummy/enemy_dummy.tscn") as PackedScene).instantiate() as EnemyDummy
	add_child(enemy)
	await get_tree().process_frame
	var def := load("res://resources/enemies/bruiser.tres") as EnemyDefinition
	enemy.apply_definition(def)
	var hp0 := enemy.health.get_max_health()
	enemy.apply_elite(2.0, 1.1)
	assert(enemy.is_elite)
	assert(enemy.health.get_max_health() >= hp0 * 1.9, "elite should densify HP")
	enemy.queue_free()
	await get_tree().process_frame

	# Boss wave set loads and has elite spawn.
	var boss_waves := load("res://resources/waves/boss_encounter_waves.tres") as WaveSet
	assert(boss_waves != null and boss_waves.wave_count() >= 2)
	var has_elite := false
	for i in boss_waves.wave_count():
		var wave := boss_waves.get_wave(i)
		for group in wave.spawns:
			if group != null and group.is_elite:
				has_elite = true
	assert(has_elite, "boss encounter should include an elite spawn")

	# Procedural graph includes special kinds.
	RunState.reset()
	var found_special := false
	for seed in [111, 222, 333, 444, 555, 777, 999, 12345]:
		RunState.reset()
		RunState.begin_procedural_with_seed(seed)
		for key in RunState.dungeon.rooms.keys():
			var room: DungeonRoom = RunState.dungeon.rooms[key]
			if room.kind == DungeonRoom.RoomKind.SHOP \
					or room.kind == DungeonRoom.RoomKind.TREASURE \
					or room.kind == DungeonRoom.RoomKind.SECRET:
				found_special = true
				break
		if found_special:
			break
	assert(found_special, "procedural graphs should place shop/treasure/secret")

	# Special loot grants parts.
	RunState.reset()
	RunState.begin_procedural_with_seed(42)
	RunState.choose_architecture(GameplayEnums.ArchitectureId.DEFAULT)
	RunState.grant_special_room_loot(DungeonRoom.RoomKind.TREASURE)
	assert(not RunState.last_loot.is_empty(), "treasure room should grant loot")
	assert(RunState.owned_tags.has("style"))

	# Shop / cache orbs: preset claim grants the named boon; exclusive siblings vanish.
	RunState.reset()
	RunState.choose_architecture(GameplayEnums.ArchitectureId.DEFAULT)
	var stock := RunState.roll_boon_offers(3)
	assert(stock.size() == 3, "shop stock should be a 3-card roll")
	var holder := Node2D.new()
	add_child(holder)
	var orb_a := ArtifactOrb.spawn_at(holder, Vector2(-40, 0), stock[0])
	var orb_b := ArtifactOrb.spawn_at(holder, Vector2(40, 0), stock[1])
	orb_a.exclusive_group = [orb_a, orb_b]
	orb_b.exclusive_group = [orb_a, orb_b]
	var player: Player = (load("res://entities/player/player.tscn") as PackedScene).instantiate() as Player
	add_child(player)
	await get_tree().process_frame
	assert(orb_a.try_claim(player), "shop orb should grant the preset boon")
	assert(RunState._already_crafted(stock[0].upgrade_id))
	await get_tree().process_frame
	assert(not is_instance_valid(orb_b), "exclusive shop siblings should despawn")

	print("ENCOUNTERS_ROOMS_OK")
	get_tree().quit(0)
