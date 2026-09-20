class_name DungeonGraph
extends RefCounted
## Generated room grid keyed by Vector2i.

var rooms: Dictionary = {} ## Vector2i → DungeonRoom
var start_coord: Vector2i = Vector2i.ZERO
var boss_coord: Vector2i = Vector2i.ZERO
var room_order: Array[Vector2i] = []


func get_room(coord: Vector2i) -> DungeonRoom:
	return rooms.get(coord) as DungeonRoom


func room_count() -> int:
	return rooms.size()


func all_rooms() -> Array:
	var out: Array = []
	for key in rooms.keys():
		out.append(rooms[key])
	return out


func rebuild_order() -> void:
	room_order.clear()
	var indexed: Array = []
	for key in rooms.keys():
		indexed.append(rooms[key])
	indexed.sort_custom(func(a, b):
		var ra := a as DungeonRoom
		var rb := b as DungeonRoom
		if ra.linear_index != rb.linear_index:
			return ra.linear_index < rb.linear_index
		return _key_less(ra.coord, rb.coord)
	)
	for room in indexed:
		room_order.append((room as DungeonRoom).coord)


func coord_at_index(index: int) -> Vector2i:
	if room_order.is_empty():
		rebuild_order()
	if room_order.is_empty():
		return start_coord
	var i := clampi(index, 0, room_order.size() - 1)
	return room_order[i]


func index_of(coord: Vector2i) -> int:
	if room_order.is_empty():
		rebuild_order()
	var found := room_order.find(coord)
	return found if found >= 0 else 0


func fingerprint() -> String:
	## Stable string for seed smoke tests.
	var keys: Array = rooms.keys()
	keys.sort_custom(func(a, b): return _key_less(a, b))
	var parts: PackedStringArray = []
	for key in keys:
		var room: DungeonRoom = rooms[key]
		var biome_id := -1
		if room.biome:
			biome_id = int(room.biome.biome_id)
		var door_bits := 0
		if room.has_door(Vector2i(0, -1)):
			door_bits |= 1
		if room.has_door(Vector2i(1, 0)):
			door_bits |= 2
		if room.has_door(Vector2i(0, 1)):
			door_bits |= 4
		if room.has_door(Vector2i(-1, 0)):
			door_bits |= 8
		var t_bits := int(round(room.door_offset(Vector2i(1, 0)) * 100.0))
		parts.append("%d,%d:%d:%d:%d:%s:%s:%d" % [
			key.x, key.y, room.kind, biome_id, door_bits, room.layout_path.get_file(),
			room.footprint_id, t_bits
		])
	return "|".join(parts)


static func _key_less(a: Variant, b: Variant) -> bool:
	var av := a as Vector2i
	var bv := b as Vector2i
	if av.y != bv.y:
		return av.y < bv.y
	return av.x < bv.x
