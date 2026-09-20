extends State
## Ranged attack — can move while firing; short windup then projectile.

@onready var player: Player = owner as Player

var _elapsed: float = 0.0
var _fired: bool = false
var _aim: Vector2 = Vector2.RIGHT
var _aim_angle: float = 0.0


func enter(_msg: Dictionary = {}) -> void:
	_elapsed = 0.0
	_fired = false
	if not player.ranged_ready():
		_return_to_locomotion()
		return
	if not player.try_spend_attack_energy(player.ranged_attack_data):
		_return_to_locomotion()
		return
	_aim = player.get_aim_direction()
	_aim_angle = _aim.angle()
	player.facing_direction = _aim
	var speed := player.get_attack_speed_multiplier()
	if player.combat_visual and player.ranged_attack_data:
		player.combat_visual.play_ranged_windup(_aim_angle, player.ranged_attack_data.windup / speed)


func physics_update(delta: float) -> void:
	var move_dir := player.get_input_direction()
	if move_dir != Vector2.ZERO:
		player.apply_movement(move_dir)
	else:
		player.stop_movement()

	var speed := player.get_attack_speed_multiplier()
	_elapsed += delta * speed

	if not _fired:
		if _elapsed >= player.ranged_attack_data.windup:
			player.spawn_projectile(_aim)
			if player.combat_visual and player.ranged_attack_data:
				player.combat_visual.play_ranged_fire(
					_aim_angle, player.ranged_attack_data.damage_type
				)
			player.ranged_cooldown.start((player.ranged_attack_data.cooldown / speed) * player.ranged_cooldown_mult)
			_fired = true
			_return_to_locomotion()
	else:
		_return_to_locomotion()


func exit() -> void:
	if player.combat_visual and not _fired:
		player.combat_visual.reset_pose()


func _return_to_locomotion() -> void:
	if player.get_input_direction() != Vector2.ZERO:
		transition_to(&"Move")
	else:
		transition_to(&"Idle")
