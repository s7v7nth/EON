class_name SynergyRecipe
extends Resource
## Triggers when a target holds all required statuses.

@export var recipe_id: StringName = &""
@export var display_name: String = ""
@export var required_statuses: PackedStringArray = PackedStringArray()
@export var consume_on_trigger: bool = true
@export var style_points: int = 120
@export var cooldown: float = 1.5
@export var effect: Resource


func matches(active_ids: PackedStringArray) -> bool:
	if required_statuses.is_empty():
		return false
	for need in required_statuses:
		if not active_ids.has(need):
			return false
	return true
