class_name EnemyDefinition
extends Resource
## Data-driven enemy archetype — stats, attacks, ranges, visual tint.

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

@export_group("Resist Overrides")
## If true, use override resists instead of stats resists.
@export var use_resist_overrides: bool = false
@export_range(-1.0, 0.9, 0.01) var resist_physical: float = 0.0
@export_range(-1.0, 0.9, 0.01) var resist_electricity: float = 0.0
@export_range(-1.0, 0.9, 0.01) var resist_corrosion: float = 0.0
@export_range(-1.0, 0.9, 0.01) var resist_fire: float = 0.0
@export_range(-1.0, 0.9, 0.01) var resist_bleed: float = 0.0
@export_range(-1.0, 0.9, 0.01) var resist_glitch: float = 0.0


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
