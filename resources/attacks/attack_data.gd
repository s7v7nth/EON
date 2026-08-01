class_name AttackData
extends Resource
## Tunable attack properties — future weapon modules = new AttackData resources.

@export var damage: float = 10.0
@export var cooldown: float = 0.5
@export var windup: float = 0.05
@export var active_duration: float = 0.15
@export var knockback_force: float = 0.0

@export_group("Elements")
@export var damage_type: GameplayEnums.DamageType = GameplayEnums.DamageType.PHYSICAL
@export_range(0.0, 1.0, 0.01) var status_chance: float = 0.0
@export var status_power: float = 0.0
@export var status_duration: float = 2.0

@export_group("Combo")
## Optional next hit in a melee string (null = end of combo).
@export var combo_next: AttackData
@export var combo_scale: float = 1.0

@export_group("Projectile")
## 0 = melee attack; > 0 = ranged, projectile flies at this speed.
@export var projectile_speed: float = 0.0
@export var projectile_lifetime: float = 1.2

@export_group("Cost")
## Energy spent to perform this attack (architecture may override).
@export var energy_cost: float = 0.0
