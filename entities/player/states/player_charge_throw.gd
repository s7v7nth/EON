extends State
## Hold LMB to charge, release to throw a returning energy blade.

const MIN_HOLD := 0.18
const MAX_CHARGE := 0.85

@onready var player: Player = owner as Player

var _elapsed: float = 0.0
var _aim: Vector2 = Vector2.RIGHT
var _active: bool = false


func enter(_msg: Dictionary = {}) -> void:
	_elapsed = 0.0
	_active = true
	_aim = player.get_aim_direction()
	if player.blade_in_flight():
		_return_to_locomotion()
		return
	if player.combat_visual:
		player.combat_visual.play_charge_start(_aim.angle())


func physics_update(delta: float) -> void:
	if not _active:
		return
	_elapsed += delta
	_aim = player.get_aim_direction()
	var charge := clampf(_elapsed / MAX_CHARGE, 0.0, 1.0)
	if player.combat_visual:
		player.combat_visual.play_charge_tick(_aim.angle(), charge)

	var move_dir := player.get_input_direction()
	if move_dir != Vector2.ZERO:
		player.apply_movement(move_dir * 0.55)
	else:
		player.stop_movement()

	if Input.is_action_just_pressed("dash") and player.dash_ready():
		transition_to(&"Dash")
		return

	if not Input.is_action_pressed("attack"):
		if _elapsed >= MIN_HOLD:
			_throw()
		_return_to_locomotion()


func exit() -> void:
	if player.combat_visual:
		player.combat_visual.reset_pose()
	_active = false


func _throw() -> void:
	var attack := player.blade_throw_attack
	if attack == null:
		return
	if not player.try_spend_attack_energy(attack):
		return
	var charge := clampf(_elapsed / MAX_CHARGE, 0.2, 1.0)
	player.spawn_returning_blade(_aim, charge)
	if player.combat_visual:
		player.combat_visual.play_ranged_fire(_aim.angle(), attack.damage_type)


func _return_to_locomotion() -> void:
	if player.get_input_direction() != Vector2.ZERO:
		transition_to(&"Move")
	else:
		transition_to(&"Idle")
