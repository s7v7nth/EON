class_name RouteGraph
extends RefCounted
## Authored irregular graphs for tutorial / campaign so every route uses a floor.


static func build(route: ActRoute) -> DungeonGraph:
	if route == null:
		return DungeonGenerator.generate(RunRng.new(1), 6)
	if route.route_id == &"campaign":
		return _campaign(route)
	if route.route_id == &"tutorial":
		return _tutorial(route)
	return DungeonGenerator.generate(RunRng.new(1), route.procedural_room_count)


static func _tutorial(route: ActRoute) -> DungeonGraph:
	var g := DungeonGraph.new()
	var a := _room(g, Vector2i(0, 0), DungeonRoom.RoomKind.START, "notch", route, 0)
	var remnant := _room(g, Vector2i(0, 1), DungeonRoom.RoomKind.REMNANT, "wedge", route, 1)
	var last := _room(g, Vector2i(1, 1), DungeonRoom.RoomKind.COMBAT, "l_wing", route, 2)
	remnant.remnant = true
	_link(a, remnant, Vector2i(0, 1), 0.38, 0.62)
	_link(remnant, last, Vector2i(1, 0), 0.41, 0.27)
	g.start_coord = a.coord
	g.boss_coord = last.coord
	g.rebuild_order()
	FloorPlacer.place(g)
	return g


static func _campaign(route: ActRoute) -> DungeonGraph:
	var g := DungeonGraph.new()
	var start := _room(g, Vector2i(0, 0), DungeonRoom.RoomKind.START, "octa", route, 0)
	var shop := _room(g, Vector2i(1, 0), DungeonRoom.RoomKind.SHOP, "skew", route, 1)
	var elite := _room(g, Vector2i(2, 0), DungeonRoom.RoomKind.COMBAT, "l_wing", route, 2)
	var cache := _room(g, Vector2i(2, 1), DungeonRoom.RoomKind.TREASURE, "t_stub", route, 3)
	var remnant := _room(g, Vector2i(0, 1), DungeonRoom.RoomKind.REMNANT, "wedge", route, 4)
	var warden := _room(g, Vector2i(0, 2), DungeonRoom.RoomKind.COMBAT, "notch", route, 5)
	var hive := _room(g, Vector2i(1, 1), DungeonRoom.RoomKind.BOSS, "octa", route, 6)
	elite.is_elite = true
	warden.boss_id = &"warden"
	hive.boss_id = &"hive"
	remnant.remnant = true
	start.remnant = false
	_link(start, shop, Vector2i(1, 0), 0.24, 0.68)
	_link(shop, elite, Vector2i(1, 0), 0.72, 0.31)
	_link(elite, cache, Vector2i(0, 1), 0.22, 0.58)
	_link(start, remnant, Vector2i(0, 1), 0.61, 0.37)
	_link(remnant, hive, Vector2i(1, 0), 0.41, 0.19)
	_link(remnant, warden, Vector2i(0, 1), 0.18, 0.77)
	g.start_coord = start.coord
	g.boss_coord = hive.coord
	g.rebuild_order()
	FloorPlacer.place(g)
	return g


static func _room(
	g: DungeonGraph,
	coord: Vector2i,
	kind: int,
	shape: String,
	route: ActRoute,
	index: int
) -> DungeonRoom:
	var room := DungeonRoom.new()
	room.coord = coord
	room.kind = kind
	room.footprint_id = shape
	room.linear_index = index
	room.world_origin = Vector2.INF
	if route:
		var resolved := route.resolve_room(index)
		room.biome = resolved.get("biome") as BiomeDefinition
		var layout := route.layout_scene_at(index)
		if layout != "":
			room.layout_path = layout
	g.rooms[coord] = room
	return room


static func _link(a: DungeonRoom, b: DungeonRoom, dir: Vector2i, t_a: float, t_b: float) -> void:
	a.doors[dir] = true
	b.doors[-dir] = true
	a.door_t[dir] = t_a
	b.door_t[-dir] = t_b
