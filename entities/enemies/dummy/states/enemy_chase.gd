extends State
## Move toward the player; attack when close enough.

@onready var enemy: EnemyDummy = owner as EnemyDummy


func physics_update(_delta: float) -> void:
	if enemy.target == null:
		transition_to(&"Idle")
		return
	if enemy.is_target_in_attack_range():
		if enemy.attack_cooldown.is_stopped():
			transition_to(&"Attack")
		else:
			enemy.stop_movement()
		return
	enemy.apply_chase_movement()
