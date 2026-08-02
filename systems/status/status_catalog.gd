class_name StatusCatalog
extends Resource
## Lookup table for StatusDefinition + SynergyRecipe.

@export var statuses: Array = []
@export var synergies: Array = []


func get_definition(status_id: StringName) -> StatusDefinition:
	for item in statuses:
		var def := item as StatusDefinition
		if def and def.status_id == status_id:
			return def
	return null


func status_id_for_damage_type(damage_type: GameplayEnums.DamageType) -> StringName:
	for item in statuses:
		var def := item as StatusDefinition
		if def and def.damage_type == damage_type:
			return def.status_id
	return StringName()


func all_synergies() -> Array:
	var out: Array = []
	for item in synergies:
		if item:
			out.append(item)
	return out
