class_name LootPart
extends Resource
## Craft ingredient that grants tags for upgrade recipes.

@export var part_id: StringName = &""
@export var display_name: String = "Part"
@export_multiline var description: String = ""
@export var tags: PackedStringArray = PackedStringArray()
@export var rarity: int = 0
## Biome / pool filter tags (matched against biome.loot_tags).
@export var drop_tags: PackedStringArray = PackedStringArray()
