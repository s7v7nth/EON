class_name CharacterStats
extends Resource
## Tunable character attributes — assign via .tres, never hardcode in scripts.

@export_group("Vitality")
@export var max_health: float = 100.0

@export_group("Movement")
@export var move_speed: float = 300.0

@export_group("Energy")
@export var max_energy: float = 100.0
@export var energy_regen_rate: float = 20.0

@export_group("Dash")
@export var dash_speed: float = 900.0
@export var dash_duration: float = 0.15
@export var dash_cost: float = 25.0
@export var dash_cooldown: float = 1.5

@export_group("Adrenaline")
@export var max_adrenaline: float = 100.0
@export var adrenaline_gain_on_hit: float = 10.0
@export var adrenaline_gain_on_hurt: float = 5.0
@export var adrenaline_decay_delay: float = 2.0
@export var adrenaline_decay_rate: float = 15.0

@export_group("Resists")
## 0 = normal, 0.5 = half damage, -0.5 = 50% more damage.
@export_range(-1.0, 0.9, 0.01) var resist_physical: float = 0.0
@export_range(-1.0, 0.9, 0.01) var resist_electricity: float = 0.0
@export_range(-1.0, 0.9, 0.01) var resist_corrosion: float = 0.0
@export_range(-1.0, 0.9, 0.01) var resist_fire: float = 0.0
@export_range(-1.0, 0.9, 0.01) var resist_bleed: float = 0.0
@export_range(-1.0, 0.9, 0.01) var resist_glitch: float = 0.0


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
