extends Node
## Persists across room scene changes for a single run.

const ROOM_SCENES: PackedStringArray = [
	"res://levels/rooms/room_01.tscn",
	"res://levels/rooms/room_02.tscn",
	"res://levels/rooms/room_03.tscn",
]

var room_index: int = 0
var damage_mult: float = 1.0
var speed_mult: float = 1.0
var dash_cost_mult: float = 1.0


func reset() -> void:
	room_index = 0
	damage_mult = 1.0
	speed_mult = 1.0
	dash_cost_mult = 1.0


func apply_to_player(player: Player) -> void:
	if player == null:
		return
	player.damage_multiplier = damage_mult
	player.move_speed_multiplier = speed_mult
	player.dash_cost_multiplier = dash_cost_mult


func choose_modifier(modifier_id: StringName) -> void:
	match modifier_id:
		&"damage":
			damage_mult *= 1.2
		&"speed":
			speed_mult *= 1.15
		&"dash":
			dash_cost_mult *= 0.75
		_:
			push_warning("RunState: unknown modifier %s" % modifier_id)
			return
	SignalBus.modifier_chosen.emit(modifier_id)


func is_last_room() -> bool:
	return room_index >= ROOM_SCENES.size() - 1


func advance_to_next_room() -> void:
	if is_last_room():
		return
	room_index += 1
	get_tree().paused = false
	get_tree().change_scene_to_file(ROOM_SCENES[room_index])


func restart_run() -> void:
	reset()
	get_tree().paused = false
	get_tree().change_scene_to_file(ROOM_SCENES[0])
