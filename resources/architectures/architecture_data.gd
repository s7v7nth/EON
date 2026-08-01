class_name ArchitectureData
extends Resource
## Player architecture — economy policy + starter primitives (WeaponData slots).

@export var architecture_id: GameplayEnums.ArchitectureId = GameplayEnums.ArchitectureId.DEFAULT
@export var display_name: String = "Default"
@export var economy_policy: GameplayEnums.EconomyPolicy = GameplayEnums.EconomyPolicy.ENERGY_ADRENALINE
@export var primitives: Array[WeaponData] = []
@export var visual_tint: Color = Color(0.55, 0.58, 0.62, 1)

@export_group("Economy Tunables")
## Continuous energy drain for NANO_SWARM (per second).
@export var swarm_energy_drain: float = 8.0
## HP regen per second for NANO_SWARM.
@export var hp_regen_rate: float = 0.0
## Life steal fraction on hit for NANO_SWARM.
@export_range(0.0, 1.0, 0.01) var life_steal: float = 0.0
## Multiplier on AttackData.energy_cost (0 = free attacks).
@export var attack_energy_mult: float = 1.0
## Passive energy regen multiplier override (NANO often 0).
@export var energy_regen_mult: float = 1.0

@export_group("Base Resists")
@export_range(-1.0, 0.9, 0.01) var resist_physical: float = 0.0
@export_range(-1.0, 0.9, 0.01) var resist_electricity: float = 0.0
@export_range(-1.0, 0.9, 0.01) var resist_corrosion: float = 0.0
@export_range(-1.0, 0.9, 0.01) var resist_fire: float = 0.0
@export_range(-1.0, 0.9, 0.01) var resist_bleed: float = 0.0

@export_group("Overheat (Electro-Train)")
@export var overheat_gain_per_action: float = 20.0
@export var overheat_max: float = 100.0
@export var overheat_cooldown: float = 1.5


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
	return 0.0
