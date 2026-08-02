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
	if Input.is_action_just_pressed("special"):
		player.try_special()
		return true
	if Input.is_action_just_pressed("dash") and player.dash_ready():
		transition_to(&"Dash")
		return true
	if Input.is_action_just_pressed("parry") and player.parry_ready():
		transition_to(&"Parry")
		return true
	if Input.is_action_just_pressed("attack") and player.attack_ready():
		transition_to(&"Attack", {"combo_index": 0})
		return true
	if Input.is_action_just_pressed("ranged_attack") and player.ranged_ready():
		transition_to(&"RangedAttack")
		return true
	return false
