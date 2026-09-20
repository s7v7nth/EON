extends Node
## Global event bus for cross-system communication.
## Entities emit; UI and systems listen — no direct scene coupling.

signal player_health_changed(current: float, max_value: float)
signal player_energy_changed(current: float, max_value: float)
signal player_adrenaline_changed(current: float, max_value: float)
signal player_economy_hud_changed(primary: Dictionary, secondary: Dictionary)
signal damage_dealt(amount: float, target: Node, source: Node)
signal entity_died(entity: Node)
signal player_died
signal enemy_died(enemy: Node)
signal enemy_spawned(enemy: Node)
signal wave_started(index: int, total: int)
signal wave_cleared(index: int)
signal run_won
signal room_cleared
signal room_entered(coord: Vector2i)
signal exit_reached
signal modifier_chosen(modifier_id: StringName)
signal weapon_changed(weapon_name: String)

## Style / skill loop
signal style_action(action: int, points: int)
signal perfect_dodge(source: Node)
signal parry_success(source: Node)
signal style_score_changed(score: int, multiplier: float, rank: String)
signal status_applied(target: Node, status_id: StringName)
signal synergy_triggered(target: Node, recipe_id: StringName)
signal architecture_changed(architecture_id: int)
signal biome_changed(biome_id: int)
signal route_chosen(route_id: StringName)
signal upgrade_crafted(upgrade_id: StringName)
signal loot_gained(summary: String)
signal player_statuses_changed(statuses: PackedStringArray)
signal special_triggered(source: Node)
signal vent_triggered(source: Node)
signal ram_slots_changed(used: int, max_slots: int)
signal combo_unlocked(combo_name: String, description: String)
signal combo_proc(combo_name: String, description: String)
signal artifact_pickup_available
signal gold_changed(amount: int)
signal boss_spawned(boss_name: String)
signal boss_health_changed(current: float, max_value: float, boss_name: String)
signal boss_phase(phase: int, boss_name: String)
signal meta_progress_changed
signal remnant_spoken
signal architecture_unlock_denied(architecture_id: int, reason: String)
