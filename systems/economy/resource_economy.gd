class_name ResourceEconomy
extends Resource
## Pluggable architecture resource policy. Host is untyped Node to avoid
## global-class cycles (ArchitectureData ↔ Player ↔ ResourceEconomy).

@export var policy: GameplayEnums.EconomyPolicy = GameplayEnums.EconomyPolicy.ENERGY_ADRENALINE


func on_equip(_host: Node) -> void:
	pass


func on_unequip(_host: Node) -> void:
	pass


func tick(_host: Node, _delta: float) -> void:
	pass


func can_afford(_host: Node, _action: StringName, _cost: float = 0.0) -> bool:
	return true


func spend(_host: Node, _action: StringName, _cost: float = 0.0) -> bool:
	return true


func is_action_locked(_host: Node) -> bool:
	return false


func damage_multiplier(_host: Node) -> float:
	return 1.0


func attack_speed_multiplier(_host: Node) -> float:
	return 1.0


func on_hit(_host: Node, _target: Node) -> void:
	pass


func on_kill(_host: Node, _enemy: Node) -> void:
	pass


func try_special(_host: Node) -> bool:
	return false


## Returns { "primary": {value,max,label,color}, "secondary": {...} }.
func get_hud_values(_host: Node) -> Dictionary:
	return {}


func _bar(value: float, max_value: float, label: String, color: Color) -> Dictionary:
	return {
		"value": value,
		"max": max_value,
		"label": label,
		"color": color,
	}
