class_name WeaponData
extends Resource
## Equippable weapon module — primary (LMB) + optional secondary (RMB).

@export var display_name: String = "Weapon"
@export var primary: AttackData
@export var secondary: AttackData
@export var hitbox_reach: float = 22.0
@export var visual_tint: Color = Color(0.55, 0.58, 0.62, 1)
