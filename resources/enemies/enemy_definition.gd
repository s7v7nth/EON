class_name EnemyDefinition
extends Resource
## Data-driven enemy archetype — stats, attacks, ranges, visual tint.

@export var display_name: String = "Enemy"
@export var stats: CharacterStats
@export var melee_attack: AttackData
@export var ranged_attack: AttackData
@export var attack_range: float = 36.0
@export var ranged_range: float = 260.0
@export var detection_radius: float = 340.0
@export var visual_color: Color = Color(0.72, 0.28, 0.28, 1)
@export var prefers_kite: bool = false
