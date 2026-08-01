extends State
## Player move — instant start/stop with iso Y compression.

@onready var player: Player = owner as Player


func physics_update(_delta: float) -> void:
	if _try_dash():
		return
	if _try_attack():
		return
	var direction := player.get_input_direction()
	if direction == Vector2.ZERO:
		transition_to(&"Idle")
		return
	player.apply_movement(direction)


func handle_input(event: InputEvent) -> void:
	if event.is_action_pressed("dash"):
		_try_dash()
	elif event.is_action_pressed("attack"):
		_try_attack()


func _try_dash() -> bool:
	if not Input.is_action_just_pressed("dash"):
		return false
	if player.dash_cooldown and not player.dash_cooldown.is_stopped():
		return false
	if player.energy.current_energy < player.stats.dash_cost:
		return false
	transition_to(&"Dash")
	return true


func _try_attack() -> bool:
	if not Input.is_action_just_pressed("attack"):
		return false
	if player.attack_cooldown and not player.attack_cooldown.is_stopped():
		return false
	transition_to(&"Attack")
	return true
