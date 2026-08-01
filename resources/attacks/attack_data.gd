class_name AttackData
extends Resource
## Tunable attack properties — future weapon modules = new AttackData resources.

@export var damage: float = 10.0
@export var cooldown: float = 0.5
@export var windup: float = 0.05
@export var active_duration: float = 0.15
@export var knockback_force: float = 0.0

@export_group("Projectile")
## 0 = melee attack; > 0 = ranged, projectile flies at this speed.
@export var projectile_speed: float = 0.0
@export var projectile_lifetime: float = 1.2
