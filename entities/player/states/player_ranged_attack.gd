extends State
## Ranged attack — short windup, fire projectile toward cursor, cooldown.

@onready var player: Player = owner as Player

var _elapsed: float = 0.0
var _fired: bool = false
var _aim: Vector2 = Vector2.RIGHT


func enter(_msg: Dictionary = {}) -> void:
	_elapsed = 0.0
	_fired = false
	if not player.ranged_ready():
		_return_to_locomotion()
		return
	player.stop_movement()
	_aim = player.get_aim_direction()
	player.facing_direction = _aim


func physics_update(delta: float) -> void:
	player.stop_movement()
	_elapsed += delta
	if not _fired:
		if _elapsed >= player.ranged_attack_data.windup:
			player.spawn_projectile(_aim)
			player.ranged_cooldown.start(player.ranged_attack_data.cooldown)
			_fired = true
			_return_to_locomotion()
	else:
		_return_to_locomotion()


func _return_to_locomotion() -> void:
	if player.get_input_direction() != Vector2.ZERO:
		transition_to(&"Move")
	else:
		transition_to(&"Idle")
