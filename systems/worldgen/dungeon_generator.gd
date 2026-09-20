class_name DungeonGenerator
extends RefCounted
## Isaac-style grid: grow rooms from start, pick layouts/biomes from pools via map RNG.

const _FloorPlacer := preload("res://systems/worldgen/floor_placer.gd")
const _RoomFootprint := preload("res://systems/worldgen/room_footprint.gd")

const DIRS: Array[Vector2i] = [
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 0),
]

const LAYOUT_POOL: PackedStringArray = [
	"res://levels/rooms/room_01.tscn",
	"res://levels/rooms/room_02.tscn",
	"res://levels/rooms/room_03.tscn",
	"res://levels/rooms/room_04.tscn",
	"res://levels/rooms/room_05.tscn",
]

const BIOME_PATHS: PackedStringArray = [
	"res://resources/biomes/landfill.tres",
	"res://resources/biomes/wasteland.tres",
	"res://resources/biomes/alley.tres",
	"res://resources/biomes/mall.tres",
	"res://resources/biomes/downtown.tres",
	"res://resources/biomes/residential.tres",
	"res://resources/biomes/jungle.tres",
	"res://resources/biomes/taiga.tres",
	"res://resources/biomes/gateway.tres",
	"res://resources/biomes/data_center.tres",
]

const DEFAULT_ROOM_COUNT := 12
const SAME_BIOME_CHANCE := 0.55
const BLEND_AMOUNT := 0.32


static func generate(rng: RunRng, room_count: int = DEFAULT_ROOM_COUNT) -> DungeonGraph:
	var graph := DungeonGraph.new()
	var target := maxi(room_count, 3)
	var biomes := _load_biomes()
	if biomes.is_empty():
		push_error("DungeonGenerator: no biomes loaded")
		return graph

	var start := DungeonRoom.new()
	start.coord = Vector2i.ZERO
	start.kind = DungeonRoom.RoomKind.START
	start.layout_path = LAYOUT_POOL[0]  # Matches main_scene so route pick stays on start cell.
	start.biome = _starter_biome(rng, biomes)
	start.footprint_id = "octa"
	start.linear_index = 0
	start.world_origin = Vector2.INF
	graph.rooms[start.coord] = start
	graph.start_coord = start.coord

	var open: Array[Vector2i] = [start.coord]
	while graph.rooms.size() < target and not open.is_empty():
		var from_idx := rng.map.randi() % open.size()
		var from_coord: Vector2i = open[from_idx]
		var from_room: DungeonRoom = graph.rooms[from_coord]
		var dir: Vector2i = DIRS[rng.map.randi() % DIRS.size()]
		var to_coord := from_coord + dir
		if graph.rooms.has(to_coord):
			continue
		var to_room := DungeonRoom.new()
		to_room.coord = to_coord
		to_room.kind = DungeonRoom.RoomKind.COMBAT
		to_room.layout_path = _pick_layout(rng)
		to_room.biome = _pick_neighbor_biome(rng, from_room.biome, biomes)
		to_room.footprint_id = _pick_shape(rng)
		to_room.linear_index = graph.rooms.size()
		to_room.world_origin = Vector2.INF
		graph.rooms[to_coord] = to_room
		_link(from_room, to_room, dir, rng)
		open.append(to_coord)
		# Occasionally drop a dead-end from the frontier for branchier shapes.
		if open.size() > 3 and rng.map.randf() < 0.25:
			open.remove_at(from_idx)

	_assign_boss(graph, rng)
	_assign_special_rooms(graph, rng)
	_apply_blends(graph)
	graph.rebuild_order()
	_FloorPlacer.place(graph)
	return graph


static func _link(a: DungeonRoom, b: DungeonRoom, dir_a_to_b: Vector2i, rng: RunRng) -> void:
	a.doors[dir_a_to_b] = true
	b.doors[-dir_a_to_b] = true
	var t_a := 0.18 + rng.map.randf() * 0.64
	var t_b := 0.18 + rng.map.randf() * 0.64
	if absf(t_a - 0.5) < 0.06:
		t_a = 0.32 if rng.map.randf() < 0.5 else 0.68
	if absf(t_b - 0.5) < 0.06:
		t_b = 0.27 if rng.map.randf() < 0.5 else 0.73
	a.door_t[dir_a_to_b] = t_a
	b.door_t[-dir_a_to_b] = t_b


static func _pick_shape(rng: RunRng) -> String:
	var pool := _RoomFootprint.pool()
	return pool[rng.map.randi() % pool.size()]


static func _pick_layout(rng: RunRng) -> String:
	return LAYOUT_POOL[rng.map.randi() % LAYOUT_POOL.size()]


static func _load_biomes() -> Dictionary:
	var by_id: Dictionary = {}
	for path in BIOME_PATHS:
		var biome := load(path) as BiomeDefinition
		if biome:
			by_id[int(biome.biome_id)] = biome
	return by_id


static func _starter_biome(rng: RunRng, biomes: Dictionary) -> BiomeDefinition:
	var starters: Array[int] = [
		GameplayEnums.BiomeId.LANDFILL,
		GameplayEnums.BiomeId.WASTELAND,
		GameplayEnums.BiomeId.ALLEY,
	]
	var options: Array[BiomeDefinition] = []
	for id in starters:
		if biomes.has(id):
			options.append(biomes[id])
	if options.is_empty():
		return biomes.values()[0]
	return options[rng.map.randi() % options.size()]


static func _pick_neighbor_biome(rng: RunRng, parent: BiomeDefinition, biomes: Dictionary) -> BiomeDefinition:
	if parent == null:
		return _starter_biome(rng, biomes)
	if rng.map.randf() < SAME_BIOME_CHANCE:
		return parent
	var candidates: Array[BiomeDefinition] = []
	for nid in parent.neighbor_biomes:
		if biomes.has(int(nid)):
			candidates.append(biomes[int(nid)])
	if candidates.is_empty():
		return parent
	return candidates[rng.map.randi() % candidates.size()]


static func _assign_boss(graph: DungeonGraph, rng: RunRng) -> void:
	var best: Vector2i = graph.start_coord
	var best_dist := -1
	var ties: Array[Vector2i] = []
	for key in graph.rooms.keys():
		var coord := key as Vector2i
		if coord == graph.start_coord:
			continue
		var dist := absi(coord.x) + absi(coord.y)
		if dist > best_dist:
			best_dist = dist
			best = coord
			ties = [coord]
		elif dist == best_dist:
			ties.append(coord)
	if not ties.is_empty():
		best = ties[rng.map.randi() % ties.size()]
	var boss: DungeonRoom = graph.rooms[best]
	boss.kind = DungeonRoom.RoomKind.BOSS
	boss.boss_id = &"hive"
	# Prefer endgame biome pack when available.
	var endgame := load("res://resources/biomes/data_center.tres") as BiomeDefinition
	var gateway := load("res://resources/biomes/gateway.tres") as BiomeDefinition
	if rng.map.randf() < 0.5 and gateway:
		boss.biome = gateway
	elif endgame:
		boss.biome = endgame
	graph.boss_coord = best


static func _assign_special_rooms(graph: DungeonGraph, rng: RunRng) -> void:
	## Sprinkle shop / treasure / secret on combat cells (not start/boss).
	var combat: Array[Vector2i] = []
	for key in graph.rooms.keys():
		var coord := key as Vector2i
		var room: DungeonRoom = graph.rooms[coord]
		if room.kind == DungeonRoom.RoomKind.COMBAT:
			combat.append(coord)
	if combat.is_empty():
		return
	# Shuffle-ish via RNG picks.
	var picks: Array[int] = [
		DungeonRoom.RoomKind.TREASURE,
		DungeonRoom.RoomKind.SHOP,
		DungeonRoom.RoomKind.SECRET,
		DungeonRoom.RoomKind.REMNANT,
	]
	var count := mini(picks.size(), maxi(combat.size() / 3, 2))
	count = mini(count, combat.size())
	for i in count:
		var idx := rng.map.randi() % combat.size()
		var coord: Vector2i = combat[idx]
		combat.remove_at(idx)
		var room: DungeonRoom = graph.rooms[coord]
		room.kind = picks[i % picks.size()]
		if room.kind == DungeonRoom.RoomKind.REMNANT:
			room.remnant = true
		if room.kind == DungeonRoom.RoomKind.SECRET or room.kind == DungeonRoom.RoomKind.TREASURE:
			room.layout_path = LAYOUT_POOL[rng.map.randi() % LAYOUT_POOL.size()]
	_assign_warden(graph, rng)


static func _assign_warden(graph: DungeonGraph, rng: RunRng) -> void:
	var combat: Array[Vector2i] = []
	for key in graph.rooms.keys():
		var coord := key as Vector2i
		var room: DungeonRoom = graph.rooms[coord]
		if room.kind == DungeonRoom.RoomKind.COMBAT and coord != graph.start_coord:
			combat.append(coord)
	if combat.is_empty():
		return
	var pick: Vector2i = combat[rng.map.randi() % combat.size()]
	var room: DungeonRoom = graph.rooms[pick]
	room.boss_id = &"warden"
	room.is_elite = true


static func _apply_blends(graph: DungeonGraph) -> void:
	for key in graph.rooms.keys():
		var room: DungeonRoom = graph.rooms[key]
		if room.biome == null:
			continue
		var blend_target: BiomeDefinition = null
		for dir in DIRS:
			if not room.has_door(dir):
				continue
			var neighbor: DungeonRoom = graph.rooms.get(room.coord + dir) as DungeonRoom
			if neighbor == null or neighbor.biome == null:
				continue
			if int(neighbor.biome.biome_id) != int(room.biome.biome_id):
				blend_target = neighbor.biome
				break
		if blend_target == null:
			continue
		var painted := room.biome.duplicate(true) as BiomeDefinition
		painted.blend_biome = blend_target
		painted.blend_amount = BLEND_AMOUNT
		room.biome = painted
