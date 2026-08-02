extends State
## Windup → activate hitbox → cooldown → back to Chase/Idle.

@onready var enemy: EnemyDummy = owner as EnemyDummy

enum Phase { WINDUP, ACTIVE }

var _phase: Phase = Phase.WINDUP
var _elapsed: float = 0.0
var _attack: AttackData
var _aim_angle: float = 0.0


func enter(_msg: Dictionary = {}) -> void:
	_elapsed = 0.0
	_phase = Phase.WINDUP
	_attack = enemy.hitbox.attack_data
	enemy.stop_movement()
	enemy.set_meta("is_attacking", true)
	if _attack == null:
		transition_to(&"Chase")
		return
	if not enemy.attack_cooldown.is_stopped():
		transition_to(&"Chase")
		return
	_face_target()
	var speed := enemy.get_action_speed_multiplier()
	if enemy.combat_visual:
		enemy.combat_visual.play_hostile_melee_windup(_aim_angle, _attack.windup / speed)


func physics_update(delta: float) -> void:
	enemy.stop_movement()
	var speed := enemy.get_action_speed_multiplier()
	_elapsed += delta * speed
	match _phase:
		Phase.WINDUP:
			if _elapsed >= _attack.windup:
				_elapsed = 0.0
				_phase = Phase.ACTIVE
				enemy.hitbox.activate()
				if enemy.combat_visual:
					enemy.combat_visual.play_melee_swing(
						_aim_angle, _attack.active_duration / speed, _attack.damage_type
					)
		Phase.ACTIVE:
			if _elapsed >= _attack.active_duration:
				enemy.hitbox.deactivate()
				enemy.attack_cooldown.start(_attack.cooldown / speed)
				if enemy.combat_visual:
					enemy.combat_visual.reset_pose()
				if enemy.target != null:
					transition_to(&"Chase")
				else:
					transition_to(&"Idle")


func exit() -> void:
	enemy.hitbox.deactivate()
	if enemy.has_meta("is_attacking"):
		enemy.remove_meta("is_attacking")
	if enemy.combat_visual and _phase == Phase.WINDUP:
		enemy.combat_visual.reset_pose()


func _face_target() -> void:
	if enemy.target == null:
		return
	var dir := enemy.global_position.direction_to(enemy.target.global_position)
	if dir != Vector2.ZERO:
		_aim_angle = dir.angle()
		enemy.hitbox.rotation = _aim_angle
		enemy.hitbox.position = dir.normalized() * 28.0 + Vector2(0, -18)
