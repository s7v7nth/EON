class_name WaveSpawnGroup
extends Resource
## One spawn group inside a wave (count of a given enemy scene/definition).

@export var count: int = 1
@export var enemy_scene: PackedScene
## Optional — when set, applied to EnemyDummy after spawn.
@export var enemy_definition: EnemyDefinition
## Elite: denser HP, tint, slight speed bump, faster actions.
@export var is_elite: bool = false
@export var elite_hp_mult: float = 2.0
@export var elite_move_mult: float = 1.12
@export var elite_action_speed: float = 1.15
