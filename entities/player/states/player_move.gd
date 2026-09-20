extends State
## Player move — instant start/stop with iso Y compression.

@onready var player: Player = owner as Player


func physics_update(_delta: float) -> void:
	if _check_combat_inputs():
		return
	var direction := player.get_input_direction()
	if direction == Vector2.ZERO:
		transition_to(&"Idle")
		return
	player.apply_movement(direction)


func _check_combat_inputs() -> bool:
	var intent := player.locomotion_combat_intent()
	if bool(intent.get("handled", false)):
		return true
	if intent.has("state"):
		var st: StringName = intent["state"]
		var msg: Dictionary = intent.get("msg", {})
		transition_to(st, msg)
		return true
	if player.uses_synthetic_kit():
		return _check_synthetic_inputs()
	return false


func _check_synthetic_inputs() -> bool:
	if player.pressed_or_buffered(&"dash") and player.mobility_ready():
		transition_to(player.mobility_state_name())
		return true

	if player.pressed_or_buffered(&"special"):
		player.try_special()
		return true

	# RMB: always raise shield. Also register combo step if the circle path expects it.
	if player.pressed_or_buffered(&"ranged_attack"):
		if player.combo_expects(&"ranged_attack"):
			player.push_combo_input(&"ranged_attack")
		transition_to(&"Block")
		return true

	if player.consume_melee_press():
		_resolve_attack_tap()
		return true
	if player.consume_buffered(&"attack") and player.attack_ready():
		_resolve_attack_tap()
		return true
	if player.wants_charge_throw():
		var seed := player.get_attack_hold_time()
		player.clear_attack_hold_tracking()
		transition_to(&"ChargeThrow", {"seed": seed})
		return true
	return false


func _resolve_attack_tap() -> void:
	var result := player.push_combo_input(&"attack")
	if result == &"circle_slash":
		SignalBus.style_action.emit(GameplayEnums.StyleAction.COMBO, 60)
		transition_to(&"Attack", {"attack": Player.CIRCLE_SLASH_ATTACK, "circular": true})
		return
	if result == &"melee_string":
		SignalBus.style_action.emit(GameplayEnums.StyleAction.COMBO, 40)
		transition_to(&"Attack", {"combo_index": 2})
		return
	var index := _melee_index_from_buffer()
	transition_to(&"Attack", {"combo_index": index})


func _melee_index_from_buffer() -> int:
	if player.combo == null:
		return 0
	var steps := player.combo.get_sequence()
	var n := 0
	for i in steps.size():
		if StringName(steps[i]) == &"attack":
			n += 1
		else:
			n = 0
	return maxi(n - 1, 0)
