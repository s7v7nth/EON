class_name ComboRecipe
extends Resource
## Input sequence → resolved action id (+ optional AttackData override).

@export var sequence: PackedStringArray = PackedStringArray()
@export var result_id: StringName = &""
@export var attack_data: AttackData
