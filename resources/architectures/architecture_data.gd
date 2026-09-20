class_name ArchitectureData
extends Resource
## Player architecture — economy plugin + starter primitives (WeaponData slots).

@export var architecture_id: GameplayEnums.ArchitectureId = GameplayEnums.ArchitectureId.DEFAULT
@export var display_name: String = "Default"
@export var description: String = ""
@export var economy: ResourceEconomy
## Legacy mirror for filters; prefer economy.policy at runtime.
@export var economy_policy: GameplayEnums.EconomyPolicy = GameplayEnums.EconomyPolicy.ENERGY_ADRENALINE
@export var primitives: Array[WeaponData] = []
@export var starting_tags: PackedStringArray = PackedStringArray()
@export var visual_tint: Color = Color(0.55, 0.58, 0.62, 1)
@export var bonus_max_health: float = 0.0

@export_group("Base Resists")
@export_range(-1.0, 0.9, 0.01) var resist_physical: float = 0.0
@export_range(-1.0, 0.9, 0.01) var resist_electricity: float = 0.0
@export_range(-1.0, 0.9, 0.01) var resist_corrosion: float = 0.0
@export_range(-1.0, 0.9, 0.01) var resist_fire: float = 0.0
@export_range(-1.0, 0.9, 0.01) var resist_bleed: float = 0.0
@export_range(-1.0, 0.9, 0.01) var resist_glitch: float = 0.0


func get_policy() -> GameplayEnums.EconomyPolicy:
	if economy:
		return economy.policy
	return economy_policy


func get_resist(damage_type: GameplayEnums.DamageType) -> float:
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
	return 0.0
