class_name BiomeDefinition
extends Resource
## Biome package — palette, waves, faction pressure, loot tags, neighbors.

@export var biome_id: GameplayEnums.BiomeId = GameplayEnums.BiomeId.DATA_CENTER
@export var display_name: String = "Biome"
@export var wave_set: WaveSet
@export var floor_color: Color = Color(0.2, 0.21, 0.23, 1)
@export var wall_color: Color = Color(0.12, 0.13, 0.14, 1)

@export_group("Pressure")
## Parallel arrays: faction id ints matching GameplayEnums.Faction, weights.
@export var faction_ids: Array[int] = []
@export var faction_weights: Array[float] = []
@export var element_bias: Array[int] = []
@export var loot_tags: PackedStringArray = []
@export var neighbor_biomes: Array[int] = []

@export_group("Blend")
## Optional second biome for gateway transition tint lerp.
@export var blend_biome: BiomeDefinition
@export_range(0.0, 1.0, 0.01) var blend_amount: float = 0.0


func get_floor_color() -> Color:
	if blend_biome and blend_amount > 0.0:
		return floor_color.lerp(blend_biome.floor_color, blend_amount)
	return floor_color


func get_wall_color() -> Color:
	if blend_biome and blend_amount > 0.0:
		return wall_color.lerp(blend_biome.wall_color, blend_amount)
	return wall_color


func has_faction_weights() -> bool:
	return not faction_ids.is_empty() and not faction_weights.is_empty()


func pick_faction() -> int:
	if not has_faction_weights():
		return -1
	var total := 0.0
	var n := mini(faction_ids.size(), faction_weights.size())
	for i in n:
		total += maxf(faction_weights[i], 0.0)
	if total <= 0.0:
		return faction_ids[0]
	var roll := randf() * total
	var acc := 0.0
	for i in n:
		acc += maxf(faction_weights[i], 0.0)
		if roll <= acc:
			return faction_ids[i]
	return faction_ids[n - 1]
