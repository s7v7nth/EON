extends Node
## Procedural dungeon smoke: same seed → identical graph fingerprint; doors/biomes wired.


func _ready() -> void:
	await get_tree().process_frame
	await _run()


func _run() -> void:
	var seed_a := 424242
	RunState.reset()
	RunState.begin_procedural_with_seed(seed_a)
	assert(RunState.is_procedural_run(), "procedural run should be active")
	assert(RunState.run_seed == seed_a)
	assert(RunState.dungeon != null)
	assert(RunState.dungeon.room_count() == 12, "expected 12 rooms")
	var fp1 := RunState.dungeon.fingerprint()
	var start := RunState.current_dungeon_room()
	assert(start != null)
	assert(start.kind == DungeonRoom.RoomKind.START)
	assert(start.layout_path.ends_with("room_01.tscn"))
	assert(start.biome != null)
	var boss := RunState.dungeon.get_room(RunState.dungeon.boss_coord)
	assert(boss != null and boss.kind == DungeonRoom.RoomKind.BOSS)

	# Doors are mutual.
	for key in RunState.dungeon.rooms.keys():
		var room: DungeonRoom = RunState.dungeon.rooms[key]
		for dir in room.door_dirs():
			var neighbor: DungeonRoom = RunState.dungeon.get_room(room.coord + dir)
			assert(neighbor != null, "dangling door")
			assert(neighbor.has_door(-dir), "door not mutual")

	# Same seed reproduces.
	RunState.reset()
	RunState.begin_procedural_with_seed(seed_a)
	var fp2 := RunState.dungeon.fingerprint()
	assert(fp1 == fp2, "seed must reproduce dungeon graph")

	# Different seed differs (extremely likely).
	RunState.reset()
	RunState.begin_procedural_with_seed(seed_a + 7)
	var fp3 := RunState.dungeon.fingerprint()
	assert(fp3 != fp1, "different seed should differ")

	# Route list includes procedural.
	RunState.reset()
	var routes := RunState.get_available_routes()
	var found := false
	for route in routes:
		if route and route.is_procedural:
			found = true
	assert(found, "procedural route missing from picker")

	# Loot stream is seeded (same rolls after same setup).
	RunState.begin_procedural_with_seed(seed_a)
	RunState.choose_architecture(GameplayEnums.ArchitectureId.DEFAULT)
	RunState.current_biome = RunState.current_dungeon_room().biome
	RunState.peak_multiplier = 4.0
	RunState.room_kills = 5
	RunState.room_took_damage = false
	RunState.grant_loot_for_room_rank()
	var loot1 := RunState.loot_summary()
	RunState.reset()
	RunState.begin_procedural_with_seed(seed_a)
	RunState.choose_architecture(GameplayEnums.ArchitectureId.DEFAULT)
	RunState.current_biome = RunState.current_dungeon_room().biome
	RunState.peak_multiplier = 4.0
	RunState.room_kills = 5
	RunState.room_took_damage = false
	RunState.grant_loot_for_room_rank()
	var loot2 := RunState.loot_summary()
	assert(loot1 == loot2, "loot stream must match for same seed + rank")

	print("PROCEDURAL_OK seed graph + loot streams")
	get_tree().quit(0)
