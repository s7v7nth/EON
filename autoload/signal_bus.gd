extends Node
## Global event bus for cross-system communication.
## Entities emit; UI and systems listen — no direct scene coupling.

signal player_health_changed(current: float, max_value: float)
signal player_energy_changed(current: float, max_value: float)
signal player_adrenaline_changed(current: float, max_value: float)
signal entity_died(entity: Node)
signal player_died
signal enemy_died(enemy: Node)
signal wave_started(index: int, total: int)
signal wave_cleared(index: int)
signal run_won
signal room_cleared
signal exit_reached
signal modifier_chosen(modifier_id: StringName)
signal weapon_changed(weapon_name: String)
