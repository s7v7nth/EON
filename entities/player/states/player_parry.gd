extends State
## Short parry window — successful hurtbox.parried handles rewards.

const PARRY_DURATION := 0.22
const PARRY_COOLDOWN := 0.7

@onready var player: Player = owner as Player

var _elapsed: float = 0.0
var _active: bool = false


func enter(_msg: Dictionary = {}) -> void:
	_elapsed = 0.0
	_active = false
	if not player.parry_ready():
		_return_to_locomotion()
		return
	if not player.try_spend_parry():
		_return_to_locomotion()
		return
	_active = true
	player.stop_movement()
	player.hurtbox.set_parrying(true)
	var visual := player.get_node_or_null("Visual") as Polygon2D
	if visual:
		visual.modulate = Color(1.2, 1.2, 0.7, 1.0)


func physics_update(delta: float) -> void:
	if not _active:
		return
	player.stop_movement()
	_elapsed += delta
	if _elapsed >= PARRY_DURATION:
		_return_to_locomotion()


func exit() -> void:
	player.hurtbox.set_parrying(false)
	var visual := player.get_node_or_null("Visual") as Polygon2D
	if visual:
		visual.modulate = Color(1, 1, 1, 1)
	if _active and player.parry_cooldown:
		player.parry_cooldown.start(PARRY_COOLDOWN)
	_active = false


func _return_to_locomotion() -> void:
	if player.get_input_direction() != Vector2.ZERO:
		transition_to(&"Move")
	else:
		transition_to(&"Idle")
