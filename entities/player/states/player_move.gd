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
	player.handle_weapon_hotkeys()
	if Input.is_action_just_pressed("dash") and player.dash_ready():
		transition_to(&"Dash")
		return true
	if Input.is_action_just_pressed("attack") and player.attack_ready():
		transition_to(&"Attack")
		return true
	if Input.is_action_just_pressed("ranged_attack") and player.ranged_ready():
		transition_to(&"RangedAttack")
		return true
	return false
