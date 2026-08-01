class_name WeaponData
extends Resource
## Equippable weapon / architecture primitive — primary (LMB) + optional secondary (RMB).

@export var display_name: String = "Weapon"
@export var primary: AttackData
@export var secondary: AttackData
@export var hitbox_reach: float = 22.0
@export var visual_tint: Color = Color(0.55, 0.58, 0.62, 1)
@export var shape_tag: StringName = &"blade"
@export var element_tag: StringName = &"physical"
