class_name WaveSet
extends Resource
## Ordered list of combat waves for an arena / room.

@export var waves: Array[WaveDefinition] = []
@export var between_wave_heal: float = 0.22


func wave_count() -> int:
	return waves.size()


func get_wave(index: int) -> WaveDefinition:
	if index < 0 or index >= waves.size():
		return null
	return waves[index]
