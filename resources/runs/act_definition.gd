class_name ActDefinition
extends Resource
## One act inside an ActRoute — ordered biome pool for a linear tutorial path.

@export var act_index: int = 1
@export var display_name: String = "Act"
@export var biomes: Array[BiomeDefinition] = []
## How many rooms to play from `biomes` (prefix). 0 = use biomes.size().
@export var rooms_in_act: int = 0
@export var boss_biome: BiomeDefinition


func room_count() -> int:
	if biomes.is_empty():
		return 0
	if rooms_in_act <= 0:
		return biomes.size()
	return mini(rooms_in_act, biomes.size())


func biome_for_room(room_in_act: int) -> BiomeDefinition:
	var count := room_count()
	if count <= 0:
		return boss_biome
	var idx := clampi(room_in_act, 0, count - 1)
	# Optional boss package replaces the final room of the act.
	if boss_biome and idx >= count - 1:
		return boss_biome
	return biomes[idx]
