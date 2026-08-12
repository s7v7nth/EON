class_name DungeonRoom
extends RefCounted
## One cell in a generated dungeon graph.

enum RoomKind { START, COMBAT, BOSS, SHOP, TREASURE, SECRET }

var coord: Vector2i = Vector2i.ZERO
var kind: int = RoomKind.COMBAT
var layout_path: String = "res://levels/rooms/room_01.tscn"
## Runtime biome (may be a duplicate with blend tint).
var biome: BiomeDefinition
var doors: Dictionary = {} ## Vector2i dir → true
var cleared: bool = false
## Visited / revealed for minimap fog-of-war.
var explored: bool = false


func has_door(dir: Vector2i) -> bool:
	return doors.get(dir, false)


func door_dirs() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for key in doors.keys():
		if doors[key]:
			out.append(key as Vector2i)
	return out
