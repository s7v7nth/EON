extends State
## Move toward the player; melee when close, ranged shot at mid distance.
## Snipers kite when too close and melee is not ready.

@onready var enemy: EnemyDummy = owner as EnemyDummy


func physics_update(_delta: float) -> void:
	if enemy.is_stunned() or enemy.is_flinching():
		enemy.stop_movement()
		return
	if enemy.target == null:
		transition_to(&"Idle")
		return
	# Fire panic / scripted flee.
	if enemy.is_panicking():
		enemy.apply_retreat_movement()
		return
	if enemy.is_target_in_attack_range():
		if enemy.hitbox and enemy.hitbox.attack_data and enemy.attack_cooldown.is_stopped():
			transition_to(&"Attack")
		elif enemy.prefers_kite:
			enemy.apply_retreat_movement()
		else:
			enemy.stop_movement()
		return
	if enemy.ranged_ready():
		transition_to(&"RangedAttack")
		return
	# Hold distance: kite if prefers_kite and inside comfort band.
	if enemy.prefers_kite and enemy.ranged_attack_data and enemy.ranged_range > 0.0:
		if enemy.distance_to_target() < enemy.ranged_range * 0.45:
			enemy.apply_retreat_movement()
			return
	enemy.apply_chase_movement()
