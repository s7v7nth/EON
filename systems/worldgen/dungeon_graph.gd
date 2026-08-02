class_name DungeonGraph
extends RefCounted
## Generated room grid keyed by Vector2i.

var rooms: Dictionary = {} ## Vector2i → DungeonRoom
var start_coord: Vector2i = Vector2i.ZERO
var boss_coord: Vector2i = Vector2i.ZERO


func get_room(coord: Vector2i) -> DungeonRoom:
	return rooms.get(coord) as DungeonRoom


func room_count() -> int:
	return rooms.size()


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
		parts.append("%d,%d:%d:%d:%d:%s" % [
			key.x, key.y, room.kind, biome_id, door_bits, room.layout_path.get_file()
		])
	return "|".join(parts)


static func _key_less(a: Variant, b: Variant) -> bool:
	var av := a as Vector2i
	var bv := b as Vector2i
	if av.y != bv.y:
		return av.y < bv.y
	return av.x < bv.x
