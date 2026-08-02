class_name ActRoute
extends Resource
## Linear run path: acts → biomes. Room layouts stay separate geometry templates.

@export var route_id: StringName = &"tutorial"
@export var display_name: String = "Tutorial Route"
@export var acts: Array[ActDefinition] = []
## Geometry templates cycled by global room index.
@export var layout_scenes: PackedStringArray = PackedStringArray([
	"res://levels/rooms/room_01.tscn",
	"res://levels/rooms/room_02.tscn",
	"res://levels/rooms/room_03.tscn",
])


func total_rooms() -> int:
	var total := 0
	for act in acts:
		if act:
			total += act.room_count()
	return total


func resolve_room(global_index: int) -> Dictionary:
	## Returns {act_index, room_in_act, biome, act, is_final}
	var remaining := global_index
	var last_act: ActDefinition = null
	for act in acts:
		if act == null:
			continue
		last_act = act
		var count := act.room_count()
		if remaining < count:
			var biome := act.biome_for_room(remaining)
			return {
				"act_index": act.act_index,
				"room_in_act": remaining,
				"biome": biome,
				"act": act,
				"is_final": global_index >= total_rooms() - 1,
			}
		remaining -= count
	# Past end — clamp to last biome.
	var biome: BiomeDefinition = null
	if last_act:
		biome = last_act.biome_for_room(maxi(last_act.room_count() - 1, 0))
	return {
		"act_index": last_act.act_index if last_act else 0,
		"room_in_act": 0,
		"biome": biome,
		"act": last_act,
		"is_final": true,
	}


func layout_scene_at(global_index: int) -> String:
	if layout_scenes.is_empty():
		return "res://levels/rooms/room_01.tscn"
	var idx := clampi(global_index, 0, layout_scenes.size() - 1)
	# If more rooms than layouts, cycle; if fewer, use sequential then last.
	if global_index < layout_scenes.size():
		return layout_scenes[global_index]
	return layout_scenes[global_index % layout_scenes.size()]


func biome_at(global_index: int) -> BiomeDefinition:
	return resolve_room(global_index).get("biome") as BiomeDefinition
