class_name UpgradeCatalog
extends Resource
## Pool of craftable upgrades + loot parts for a run.

@export var upgrades: Array = []
@export var loot_parts: Array = []


func all_upgrades() -> Array:
	var out: Array = []
	for item in upgrades:
		if item:
			out.append(item)
	return out


func all_parts() -> Array:
	var out: Array = []
	for item in loot_parts:
		if item:
			out.append(item)
	return out


func parts_for_biome_tags(biome_tags: PackedStringArray) -> Array:
	var out: Array = []
	for item in loot_parts:
		var part := item as LootPart
		if part == null:
			continue
		if part.drop_tags.is_empty():
			out.append(part)
			continue
		for tag in part.drop_tags:
			if biome_tags.has(tag):
				out.append(part)
				break
	return out
