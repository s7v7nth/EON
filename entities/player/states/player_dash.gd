extends State
## Dash — spends energy, grants i-frames, fixed burst velocity, then cooldown.

@onready var player: Player = owner as Player

var _elapsed: float = 0.0
var _dash_dir: Vector2 = Vector2.RIGHT
var _active: bool = false


func enter(_msg: Dictionary = {}) -> void:
	_elapsed = 0.0
	_active = false
	if not _can_dash():
		_return_to_locomotion()
		return

	if not player.energy.try_spend(player.stats.dash_cost):
		_return_to_locomotion()
		return

	_active = true
	var input_dir := player.get_input_direction()
	_dash_dir = input_dir.normalized() if input_dir != Vector2.ZERO else player.facing_direction
	if _dash_dir == Vector2.ZERO:
		_dash_dir = Vector2.RIGHT

	player.facing_direction = _dash_dir
	player.hurtbox.set_invincible(true)
	player.velocity = Iso.apply_velocity(_dash_dir, player.stats.dash_speed)


func physics_update(delta: float) -> void:
	if not _active:
		return
	_elapsed += delta
	player.velocity = Iso.apply_velocity(_dash_dir, player.stats.dash_speed)
	player.move_and_slide()
	if _elapsed >= player.stats.dash_duration:
		_return_to_locomotion()


func exit() -> void:
	if not _active:
		return
	player.hurtbox.set_invincible(false)
	if player.dash_cooldown and player.stats:
		player.dash_cooldown.start(player.stats.dash_cooldown)
	_active = false


func _can_dash() -> bool:
	if player.stats == null:
		return false
	if player.dash_cooldown and not player.dash_cooldown.is_stopped():
		return false
	if player.energy.current_energy < player.stats.dash_cost:
		return false
	return true


func _return_to_locomotion() -> void:
	if player.get_input_direction() != Vector2.ZERO:
		transition_to(&"Move")
	else:
		transition_to(&"Idle")
