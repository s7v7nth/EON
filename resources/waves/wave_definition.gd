class_name WaveDefinition
extends Resource
## A single wave: delay before spawn, then one or more spawn groups.

@export var delay: float = 1.5
@export var spawns: Array[WaveSpawnGroup] = []
