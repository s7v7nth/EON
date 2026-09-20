class_name FloorPlacer
extends RefCounted
## Places irregular room islands so reversed doors align and collision never overlaps.

const MIN_HALL := 160.0
const HALL_STEP := 140.0
const MAX_HALL_TRIES := 14
const PAD := 36.0


static func place(graph: DungeonGraph) -> void:
	if graph == null or graph.rooms.is_empty():
		return
	var start: DungeonRoom = graph.get_room(graph.start_coord)
	if start == null:
		return
	start.world_origin = Vector2.ZERO
	start.footprint = RoomFootprint.make(start.footprint_id)
	var placed: Array[DungeonRoom] = [start]
	var open: Array[DungeonRoom] = [start]
	while not open.is_empty():
		var from: DungeonRoom = open.pop_front()
		for dir in from.door_dirs():
			var to: DungeonRoom = graph.get_room(from.coord + dir)
			if to == null:
				continue
			if to.footprint == null:
				to.footprint = RoomFootprint.make(to.footprint_id)
			if to.world_origin != Vector2.INF and _already_placed(to, placed):
				continue
			var hall := MIN_HALL
			var ok := false
			for _try in MAX_HALL_TRIES:
				to.world_origin = _origin_for(from, to, dir, hall)
				if not _overlaps_any(to, placed):
					ok = true
					break
				hall += HALL_STEP
			if not ok:
				to.world_origin = _origin_for(from, to, dir, hall)
			from.hall_length[dir] = hall
			to.hall_length[-dir] = hall
			placed.append(to)
			open.append(to)
	_nudge_until_clear(placed)


static func door_world(room: DungeonRoom, dir: Vector2i) -> Vector2:
	if room == null:
		return Vector2.ZERO
	if room.footprint == null:
		room.footprint = RoomFootprint.make(room.footprint_id)
	var t := float(room.door_t.get(dir, 0.5))
	return room.world_origin + room.footprint.door_local(dir, t)


static func _origin_for(from: DungeonRoom, to: DungeonRoom, dir: Vector2i, hall: float) -> Vector2:
	var from_door := door_world(from, dir)
	var axis := Vector2(float(dir.x), float(dir.y))
	var to_door_target := from_door + axis * hall
	var t_to := float(to.door_t.get(-dir, 0.5))
	var local := to.footprint.door_local(-dir, t_to)
	return to_door_target - local


static func _already_placed(room: DungeonRoom, placed: Array[DungeonRoom]) -> bool:
	for other in placed:
		if other == room:
			return true
	return false


static func _overlaps_any(room: DungeonRoom, placed: Array[DungeonRoom]) -> bool:
	var poly := room.footprint.world_poly(room.world_origin)
	var grow := room.footprint.aabb(room.world_origin).grow(PAD)
	for other in placed:
		if other == room or other.footprint == null:
			continue
		var other_aabb := other.footprint.aabb(other.world_origin).grow(PAD)
		if not grow.intersects(other_aabb):
			continue
		var hit := Geometry2D.intersect_polygons(poly, other.footprint.world_poly(other.world_origin))
		if not hit.is_empty():
			return true
	return false


static func _nudge_until_clear(placed: Array[DungeonRoom]) -> void:
	## Last-pass: if any pair still clips, shove the later room along the connecting axis.
	for i in range(1, placed.size()):
		var room: DungeonRoom = placed[i]
		var guard := 0
		while _overlaps_any(room, placed) and guard < 8:
			room.world_origin += Vector2(180, 80)
			guard += 1


static func any_overlap(graph: DungeonGraph) -> bool:
	if graph == null:
		return false
	var rooms: Array = graph.all_rooms()
	for i in rooms.size():
		var a: DungeonRoom = rooms[i]
		if a == null or a.footprint == null:
			continue
		for j in range(i + 1, rooms.size()):
			var b: DungeonRoom = rooms[j]
			if b == null or b.footprint == null:
				continue
			if Geometry2D.intersect_polygons(
				a.footprint.world_poly(a.world_origin),
				b.footprint.world_poly(b.world_origin)
			).is_empty():
				continue
			return true
	return false
