class_name EnemyDefinition
extends Resource
## Data-driven enemy archetype — stats, attacks, behaviors, resists.

@export var display_name: String = "Enemy"
@export var faction: GameplayEnums.Faction = GameplayEnums.Faction.SAVAGE
@export var stats: CharacterStats
@export var melee_attack: AttackData
@export var ranged_attack: AttackData
@export var attack_range: float = 36.0
@export var ranged_range: float = 260.0
@export var detection_radius: float = 340.0
@export var visual_color: Color = Color(0.72, 0.28, 0.28, 1)
@export var prefers_kite: bool = false

@export_group("Behaviors")
@export var behavior_modules: Array[EnemyBehavior] = []
@export var on_death_effect: StatusEffect
@export var tags: PackedStringArray = []
## status_id (String) -> buildup multiplier, e.g. {"burn": 1.5}
@export var status_vulnerabilities: Dictionary = {}

@export_group("Resist Overrides")
## If true, use override resists instead of stats resists.
@export var use_resist_overrides: bool = false
@export_range(-1.0, 0.9, 0.01) var resist_physical: float = 0.0
@export_range(-1.0, 0.9, 0.01) var resist_electricity: float = 0.0
@export_range(-1.0, 0.9, 0.01) var resist_corrosion: float = 0.0
@export_range(-1.0, 0.9, 0.01) var resist_fire: float = 0.0
@export_range(-1.0, 0.9, 0.01) var resist_bleed: float = 0.0
@export_range(-1.0, 0.9, 0.01) var resist_glitch: float = 0.0

@export_group("Poise")
## Hit poise pool — depleted by AttackData.poise_damage → brief flinch.
@export var max_poise: float = 40.0
## Poise restored per second while not flinching.
@export var poise_regen: float = 18.0


func get_resist(damage_type: GameplayEnums.DamageType) -> float:
	if use_resist_overrides:
		match damage_type:
			GameplayEnums.DamageType.PHYSICAL:
				return resist_physical
			GameplayEnums.DamageType.ELECTRICITY:
				return resist_electricity
			GameplayEnums.DamageType.CORROSION:
				return resist_corrosion
			GameplayEnums.DamageType.FIRE:
				return resist_fire
			GameplayEnums.DamageType.BLEED:
				return resist_bleed
			GameplayEnums.DamageType.GLITCH:
				return resist_glitch
	if stats:
		return stats.get_resist(damage_type)
	return 0.0


func get_status_vulnerability(status_id: StringName) -> float:
	if status_vulnerabilities.is_empty() or status_id == StringName():
		return 1.0
	if status_vulnerabilities.has(status_id):
		return maxf(float(status_vulnerabilities[status_id]), 0.0)
	var key := String(status_id)
	if status_vulnerabilities.has(key):
		return maxf(float(status_vulnerabilities[key]), 0.0)
	return 1.0


func has_behavior(behavior_id: StringName) -> bool:
	for module in behavior_modules:
		if module and module.behavior_id == behavior_id:
			return true
	return false


func find_behavior(behavior_id: StringName) -> EnemyBehavior:
	for module in behavior_modules:
		if module and module.behavior_id == behavior_id:
			return module
	return null
