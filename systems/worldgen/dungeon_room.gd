class_name DungeonRoom
extends RefCounted
## One island in a physical dungeon graph.

enum RoomKind { START, COMBAT, BOSS, SHOP, TREASURE, SECRET, REMNANT }

var coord: Vector2i = Vector2i.ZERO
var kind: int = RoomKind.COMBAT
var layout_path: String = "res://levels/rooms/room_01.tscn"
## Runtime biome (may be a duplicate with blend tint).
var biome: BiomeDefinition
var doors: Dictionary = {} ## Vector2i dir → true
## Offset along the side (0..1). Not snapped to edge-centers.
var door_t: Dictionary = {} ## Vector2i dir → float
var hall_length: Dictionary = {} ## Vector2i dir → float
var footprint_id: String = "notch"
var footprint: RoomFootprint
var world_origin: Vector2 = Vector2.INF
var linear_index: int = 0
var boss_id: StringName = &""
var remnant: bool = false
var is_elite: bool = false
var rewarded: bool = false
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


func door_offset(dir: Vector2i) -> float:
	return float(door_t.get(dir, 0.5))
