extends State
## Stand still, wind up, fire projectile at player, start cooldown, resume chase.

@onready var enemy: EnemyDummy = owner as EnemyDummy

var _elapsed: float = 0.0
var _fired: bool = false
var _aim: Vector2 = Vector2.RIGHT


func enter(_msg: Dictionary = {}) -> void:
	_elapsed = 0.0
	_fired = false
	enemy.stop_movement()
	if enemy.target == null or enemy.ranged_attack_data == null:
		transition_to(&"Idle")
		return
	_aim = enemy.global_position.direction_to(enemy.target.global_position)


func physics_update(delta: float) -> void:
	enemy.stop_movement()
	_elapsed += delta
	if not _fired:
		if _elapsed >= enemy.ranged_attack_data.windup:
			# Re-aim at fire moment so the shot tracks slightly.
			if enemy.target != null:
				_aim = enemy.global_position.direction_to(enemy.target.global_position)
			enemy.spawn_projectile(_aim)
			enemy.ranged_cooldown.start(enemy.ranged_attack_data.cooldown)
			_fired = true
	else:
		if enemy.target != null:
			transition_to(&"Chase")
		else:
			transition_to(&"Idle")
