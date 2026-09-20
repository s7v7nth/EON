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
	assert(not start.door_dirs().is_empty(), "start room needs at least one door")
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

	# Arena builds door areas after late route pick (the stuck-after-clear bug).
	RunState.reset()
	var arena_scene := load("res://levels/rooms/room_01.tscn") as PackedScene
	var arena := arena_scene.instantiate() as ArenaController
	add_child(arena)
	await get_tree().process_frame
	RunState.begin_procedural_with_seed(seed_a)
	RunState.choose_architecture(GameplayEnums.ArchitectureId.DEFAULT)
	await get_tree().process_frame
	var doors_root := arena.get_node_or_null("Doors")
	assert(doors_root != null and doors_root.get_child_count() > 0, "doors must exist after procedural route pick")
	arena.force_clear_room()
	var visible_doors := 0
	for child in doors_root.get_children():
		if child is Area2D and (child as Area2D).visible:
			visible_doors += 1
	assert(visible_doors > 0, "doors must open after room clear")

	# Cleared rooms stay empty on revisit (no enemy respawn).
	var cleared_room := RunState.current_dungeon_room()
	assert(cleared_room != null and cleared_room.cleared, "force_clear must mark room cleared")
	arena.queue_free()
	await get_tree().process_frame
	var revisit := arena_scene.instantiate() as ArenaController
	add_child(revisit)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	assert(revisit._room_cleared, "revisit must restore cleared state")
	var enemies := 0
	var entities := revisit.get_node_or_null("Entities")
	if entities:
		for child in entities.get_children():
			if child is Player:
				continue
			if child.get("health") != null:
				enemies += 1
	assert(enemies == 0, "cleared room revisit must not respawn enemies")
	assert(revisit._revisit_cleared, "revisit flag must be set")
	# Revisit must not open the reward overlay (that caused the bounce loop).
	var reward_hits := [0]
	var on_reward := func () -> void: reward_hits[0] += 1
	SignalBus.exit_reached.connect(on_reward)
	revisit._exit_latch = false
	revisit._blocked_entry_dir = Vector2i(-1, 0)
	var player_ghost: Player = (load("res://entities/player/player.tscn") as PackedScene).instantiate() as Player
	# Entry door ignored.
	revisit._on_door_body_entered(player_ghost, Vector2i(-1, 0))
	assert(reward_hits[0] == 0, "blocked entry door must not emit exit_reached")
	assert(not revisit._exit_latch, "blocked entry must not latch")
	# Non-entry door on revisit: no reward signal. Null dungeon so travel no-ops.
	var saved_dungeon = RunState.dungeon
	RunState.dungeon = null
	revisit._on_door_body_entered(player_ghost, Vector2i(1, 0))
	assert(reward_hits[0] == 0, "revisit door must not emit exit_reached/reward")
	assert(revisit._exit_latch, "revisit travel should latch")
	RunState.dungeon = saved_dungeon
	if SignalBus.exit_reached.is_connected(on_reward):
		SignalBus.exit_reached.disconnect(on_reward)
	player_ghost.queue_free()
	revisit.queue_free()
	RunState.reset()

	# Physical campaign floor: Hive + remnant, no overlap, layout is one floor.
	RunState.choose_route(RunState.CAMPAIGN_ROUTE)
	assert(RunState.dungeon != null)
	assert(RunState.layout_scene_for_current_room().ends_with("floor_world.tscn"))
	var hive_ok := false
	var remnant_ok := false
	for item in RunState.dungeon.all_rooms():
		var room: DungeonRoom = item
		if room.boss_id == &"hive":
			hive_ok = true
		if room.kind == DungeonRoom.RoomKind.REMNANT or room.remnant:
			remnant_ok = true
	assert(hive_ok, "campaign graph must place The Hive")
	assert(remnant_ok, "campaign graph must place a remnant talk room")
	assert(not FloorPlacer.any_overlap(RunState.dungeon), "islands must not overlap")
	assert(AttackData.PatternKind.FAN_SHOT == 5)
	assert(AttackData.PatternKind.HOOK == 6)

	# Cheater path: class data refuses locked kits even if forced.
	MetaSave.wipe_for_tests()
	RunState.reset()
	assert(MetaSave.is_architecture_unlocked(int(GameplayEnums.ArchitectureId.DEFAULT)))
	assert(not MetaSave.is_architecture_unlocked(int(GameplayEnums.ArchitectureId.NANOMACHINES)))
	assert(not RunState.choose_architecture(GameplayEnums.ArchitectureId.NANOMACHINES))
	assert(RunState.architecture == null or RunState.architecture.architecture_id == GameplayEnums.ArchitectureId.DEFAULT)
	assert(not RunState.architecture_picked)
	MetaSave.unlock_all_for_tests()
	assert(RunState.choose_architecture(GameplayEnums.ArchitectureId.NANOMACHINES))
	assert(RunState.architecture_picked)

	print("PROCEDURAL_OK seed graph + loot streams")
	get_tree().quit(0)
