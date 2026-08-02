extends State
## Stand still, wind up, fire projectile at player, start cooldown, resume chase.

@onready var enemy: EnemyDummy = owner as EnemyDummy

var _elapsed: float = 0.0
var _fired: bool = false
var _aim: Vector2 = Vector2.RIGHT
var _aim_angle: float = 0.0


func enter(_msg: Dictionary = {}) -> void:
	_elapsed = 0.0
	_fired = false
	enemy.stop_movement()
	enemy.set_meta("is_attacking", true)
	if enemy.target == null or enemy.ranged_attack_data == null:
		transition_to(&"Idle")
		return
	_aim = enemy.global_position.direction_to(enemy.target.global_position)
	_aim_angle = _aim.angle()
	var speed := enemy.get_action_speed_multiplier()
	if enemy.combat_visual:
		enemy.combat_visual.play_hostile_ranged_windup(_aim_angle, enemy.ranged_attack_data.windup / speed)


func physics_update(delta: float) -> void:
	enemy.stop_movement()
	if enemy.is_stunned() or enemy.is_flinching():
		return
	var speed := enemy.get_action_speed_multiplier()
	_elapsed += delta * speed
	if not _fired:
		if _elapsed >= enemy.ranged_attack_data.windup:
			if enemy.target != null:
				_aim = enemy.global_position.direction_to(enemy.target.global_position)
				_aim_angle = _aim.angle()
			enemy.spawn_projectile(_aim)
			if enemy.combat_visual and enemy.ranged_attack_data:
				enemy.combat_visual.play_ranged_fire(
					_aim_angle, enemy.ranged_attack_data.damage_type
				)
			enemy.ranged_cooldown.start(enemy.ranged_attack_data.cooldown / speed)
			_fired = true
	else:
		if enemy.combat_visual:
			enemy.combat_visual.reset_pose()
		if enemy.target != null:
			transition_to(&"Chase")
		else:
			transition_to(&"Idle")


func exit() -> void:
	if enemy.has_meta("is_attacking"):
		enemy.remove_meta("is_attacking")
	if enemy.combat_visual and not _fired:
		enemy.combat_visual.reset_pose()
