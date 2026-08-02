extends State
## Hold RMB energy shield. Short parry window, then damage reduction block.
## Block cancels attacks immediately. LMB can finish an open combo (circle / melee).

const PARRY_WINDOW := 0.22
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

	# Allow finishing LMB→RMB→LMB / open melee string without waiting for shield drop.
	if _try_combo_finish_attack():
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

	if player.pressed_or_buffered(&"dash") and player.dash_ready():
		transition_to(&"Dash")
		return


func _try_combo_finish_attack() -> bool:
	if not player.uses_synthetic_kit():
		return false
	# Only steal LMB while the next combo step is an attack (circle finish, etc.).
	if not player.combo_expects(&"attack"):
		return false

	if Input.is_action_just_pressed("attack"):
		player.begin_attack_hold_tracking()
	if not player.is_tracking_attack_hold():
		return false
	if player.attack_hold_exceeded():
		player.clear_attack_hold_tracking()
		return false
	if not Input.is_action_just_released("attack"):
		return false

	player.clear_attack_hold_tracking()
	if not player.attack_ready():
		return false
	var result := player.push_combo_input(&"attack")
	if result == &"circle_slash":
		SignalBus.style_action.emit(GameplayEnums.StyleAction.COMBO, 60)
		transition_to(&"Attack", {"attack": Player.CIRCLE_SLASH_ATTACK, "circular": true})
		return true
	if result == &"melee_string":
		SignalBus.style_action.emit(GameplayEnums.StyleAction.COMBO, 40)
		transition_to(&"Attack", {"combo_index": 2})
		return true
	var index := 0
	if player.combo:
		var steps := player.combo.get_sequence()
		var n := 0
		for step in steps:
			if StringName(step) == &"attack":
				n += 1
			else:
				n = 0
		index = maxi(n - 1, 0)
	transition_to(&"Attack", {"combo_index": index})
	return true


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
