class_name EnemyCatalog
extends Resource
## Faction → enemy definition pool for biome-weighted spawns.

@export var enemies: Array[EnemyDefinition] = []


func all() -> Array[EnemyDefinition]:
	var result: Array[EnemyDefinition] = []
	for enemy in enemies:
		if enemy:
			result.append(enemy)
	return result


func for_faction(faction: int) -> Array[EnemyDefinition]:
	var result: Array[EnemyDefinition] = []
	for enemy in enemies:
		if enemy and int(enemy.faction) == faction:
			result.append(enemy)
	return result


func pick_for_biome(biome: BiomeDefinition, fallback: EnemyDefinition = null) -> EnemyDefinition:
	if biome == null:
		return fallback
	var faction := biome.pick_faction()
	if faction < 0:
		return fallback
	var pool := for_faction(faction)
	if pool.is_empty():
		return fallback
	return pool[randi() % pool.size()]
