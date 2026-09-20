extends State
## Line-telegraph leap / gap-close. Windup → dash with active hitbox → cooldown.

@onready var enemy: EnemyDummy = owner as EnemyDummy

enum Phase { WINDUP, ACTIVE }

var _phase: Phase = Phase.WINDUP
var _elapsed: float = 0.0
var _attack: AttackData
var _aim: Vector2 = Vector2.RIGHT
var _aim_angle: float = 0.0
var _locked_aim: bool = false


func enter(msg: Dictionary = {}) -> void:
	_elapsed = 0.0
	_phase = Phase.WINDUP
	_locked_aim = false
	_attack = msg.get("attack", enemy.pending_attack) as AttackData
	enemy.pending_attack = null
	enemy.stop_movement()
	enemy.set_meta("is_attacking", true)
	if _attack == null:
		transition_to(&"Chase")
		return
	if not enemy.attack_cooldown.is_stopped():
		transition_to(&"Chase")
		return
	if enemy.hitbox:
		enemy.hitbox.attack_data = _attack
	_face_target(true)
	var speed := enemy.get_action_speed_multiplier()
	if enemy.combat_visual:
		enemy.combat_visual.play_hostile_pattern_windup(
			AttackData.PatternKind.LUNGE, _aim_angle, _attack.windup / speed, 3, 0.0
		)


func physics_update(delta: float) -> void:
	if enemy.is_stunned() or enemy.is_flinching():
		enemy.stop_movement()
		return
	if _attack == null:
		transition_to(&"Chase")
		return
	var speed := enemy.get_action_speed_multiplier()
	_elapsed += delta * speed
	match _phase:
		Phase.WINDUP:
			enemy.stop_movement()
			var lock_at := _attack.windup * clampf(_attack.commit_lock_early, 0.0, 1.0)
			if not _locked_aim and _elapsed >= lock_at:
				_locked_aim = true
				_face_target(false)
			else:
				_face_target(true)
			if _elapsed >= _attack.windup:
				_elapsed = 0.0
				_phase = Phase.ACTIVE
				_locked_aim = true
				_face_target(false)
				_configure_hitbox()
				enemy.hitbox.activate()
				var leap_dist := _attack.lunge_distance if _attack.lunge_distance > 0.0 else 110.0
				var leap_dur := maxf(_attack.active_duration, 0.12)
				enemy.begin_lunge(_aim, leap_dist, leap_dur)
				if enemy.combat_visual:
					enemy.combat_visual.play_melee_swing(
						_aim_angle,
						maxf(leap_dur / speed, 0.18),
						_attack.damage_type,
						Color(0, 0, 0, 0),
						3
					)
		Phase.ACTIVE:
			enemy.stop_movement()
			if _elapsed >= maxf(_attack.active_duration, 0.12):
				enemy.hitbox.deactivate()
				enemy.attack_cooldown.start(_attack.cooldown / speed)
				if enemy.target != null:
					transition_to(&"Chase")
				else:
					transition_to(&"Idle")


func exit() -> void:
	enemy.hitbox.deactivate()
	enemy.clear_lunge()
	if enemy.has_meta("is_attacking"):
		enemy.remove_meta("is_attacking")
	if enemy.combat_visual:
		enemy.combat_visual.reset_pose()


func _face_target(update_visual: bool) -> void:
	if _locked_aim:
		return
	if enemy.target == null:
		return
	var to_target := enemy.target.global_position - enemy.global_position + Vector2(0, -16)
	if to_target == Vector2.ZERO:
		return
	_aim = to_target.normalized()
	_aim_angle = _aim.angle()
	_configure_hitbox()
	if update_visual and enemy.combat_visual and _phase == Phase.WINDUP:
		enemy.combat_visual.aim_hostile_pattern_telegraph(
			AttackData.PatternKind.LUNGE, _aim_angle, 0.0
		)


func _configure_hitbox() -> void:
	if enemy.hitbox == null:
		return
	enemy.hitbox.rotation = 0.0
	enemy.hitbox.position = _aim * 28.0 + Vector2(0, -8)
	var shape_node := enemy.hitbox.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		return
	var circle := CircleShape2D.new()
	circle.radius = 30.0
	shape_node.shape = circle
	shape_node.position = Vector2.ZERO
