extends State
## Hold RMB energy shield. First 0.5s = parry; after that = damage reduction block.

const PARRY_WINDOW := 0.5
const BLOCK_MOVE_MULT := 0.45

@onready var player: Player = owner as Player

var _elapsed: float = 0.0
var _active: bool = false


func enter(_msg: Dictionary = {}) -> void:
	_elapsed = 0.0
	_active = true
	player.hurtbox.set_blocking(true)
	player.hurtbox.set_parrying(true)
	if player.combat_visual:
		player.combat_visual.play_block_start(true)


func physics_update(delta: float) -> void:
	if not _active:
		return
	if not Input.is_action_pressed("ranged_attack"):
		_return_to_locomotion()
		return

	_elapsed += delta
	if _elapsed >= PARRY_WINDOW and player.hurtbox.is_parrying():
		player.hurtbox.set_parrying(false)
		if player.combat_visual:
			player.combat_visual.play_block_hold()

	var move_dir := player.get_input_direction()
	if move_dir != Vector2.ZERO:
		var saved := player.move_speed_multiplier
		player.move_speed_multiplier = saved * BLOCK_MOVE_MULT
		player.apply_movement(move_dir)
		player.move_speed_multiplier = saved
	else:
		player.stop_movement()

	if Input.is_action_just_pressed("dash") and player.dash_ready():
		transition_to(&"Dash")
		return


func exit() -> void:
	player.hurtbox.set_parrying(false)
	player.hurtbox.set_blocking(false)
	if player.combat_visual:
		player.combat_visual.play_block_end()
	_active = false


func _return_to_locomotion() -> void:
	if player.get_input_direction() != Vector2.ZERO:
		transition_to(&"Move")
	else:
		transition_to(&"Idle")
