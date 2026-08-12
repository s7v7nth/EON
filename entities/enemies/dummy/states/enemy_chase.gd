extends State
## Move toward the player; pick signature moves from moveset when in range.

@onready var enemy: EnemyDummy = owner as EnemyDummy


func physics_update(_delta: float) -> void:
	if enemy.is_stunned() or enemy.is_flinching():
		enemy.stop_movement()
		return
	if enemy.target == null:
		transition_to(&"Idle")
		return
	if enemy.is_panicking():
		enemy.apply_retreat_movement()
		return

	# Prefer moveset selection whenever any attack CD allows a legal pick.
	if enemy.attack_cooldown.is_stopped() or enemy.ranged_cooldown.is_stopped():
		if enemy.pick_and_begin_attack():
			return

	# Hold distance / kite when no attack available.
	if enemy.is_target_in_attack_range():
		if enemy.prefers_kite:
			enemy.apply_retreat_movement()
		else:
			enemy.stop_movement()
		return
	if enemy.prefers_kite and enemy.ranged_attack_data and enemy.ranged_range > 0.0:
		if enemy.distance_to_target() < enemy.ranged_range * 0.45:
			enemy.apply_retreat_movement()
			return
	enemy.apply_chase_movement()
