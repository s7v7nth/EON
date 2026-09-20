extends State
## Charge shot / fan volley. Readable tells, optional multi-projectile.

@onready var enemy: EnemyDummy = owner as EnemyDummy

enum Phase { WINDUP, VOLLEY, DONE }

var _phase: Phase = Phase.WINDUP
var _elapsed: float = 0.0
var _attack: AttackData
var _aim: Vector2 = Vector2.RIGHT
var _aim_angle: float = 0.0
var _locked_aim: bool = false
var _shots_fired: int = 0
var _shot_timer: float = 0.0
var _cough_rest: Vector2 = Vector2.ZERO
var _coughed: bool = false
var _spit: Line2D


func enter(msg: Dictionary = {}) -> void:
	_elapsed = 0.0
	_phase = Phase.WINDUP
	_locked_aim = false
	_shots_fired = 0
	_shot_timer = 0.0
	_attack = msg.get("attack", enemy.pending_attack) as AttackData
	if _attack == null:
		_attack = enemy.ranged_attack_data
	enemy.pending_attack = null
	enemy.stop_movement()
	enemy.set_meta("is_attacking", true)
	if enemy.target == null or _attack == null:
		transition_to(&"Idle")
		return
	enemy.ranged_attack_data = _attack
	_aim = enemy.global_position.direction_to(enemy.target.global_position)
	_aim_angle = _aim.angle()
	var speed := enemy.get_action_speed_multiplier()
	if enemy.combat_visual:
		enemy.combat_visual.play_hostile_pattern_windup(
			_attack.pattern_kind, _aim_angle, _attack.windup / speed, 0, 0.0
		)
		if _is_hive_bile() and enemy.combat_visual.telegraph:
			enemy.combat_visual.telegraph.color = Color(0.48, 0.68, 0.14, enemy.combat_visual.telegraph.color.a)
		if _is_hive_bile() and enemy.combat_visual.swing_arc:
			enemy.combat_visual.swing_arc.color = Color(0.42, 0.58, 0.12, 0.7)
	_begin_hive_cough()


func physics_update(delta: float) -> void:
	enemy.stop_movement()
	if enemy.is_stunned() or enemy.is_flinching():
		return
	if _attack == null:
		transition_to(&"Chase")
		return
	var speed := enemy.get_action_speed_multiplier()
	_elapsed += delta * speed
	match _phase:
		Phase.WINDUP:
			var lock_at := _attack.windup * clampf(_attack.commit_lock_early, 0.0, 1.0)
			if not _locked_aim and _elapsed >= lock_at:
				_locked_aim = true
			elif not _locked_aim and enemy.target != null:
				_aim = enemy.global_position.direction_to(enemy.target.global_position)
				_aim_angle = _aim.angle()
				if enemy.combat_visual:
					enemy.combat_visual.aim_hostile_pattern_telegraph(
						_attack.pattern_kind, _aim_angle, 0.0
					)
			_update_spit(48.0 + _elapsed * 420.0, 0.7)
			if _elapsed >= _attack.windup:
				_elapsed = 0.0
				_phase = Phase.VOLLEY
				_shot_timer = 0.0
				_restore_cough()
				_fire_one()
		Phase.VOLLEY:
			_update_spit(220.0, 0.92)
			var total := maxi(_attack.projectile_count, 1)
			if _shots_fired >= total:
				_phase = Phase.DONE
				enemy.ranged_cooldown.start(_attack.cooldown / speed)
				_clear_spit()
				if enemy.combat_visual:
					enemy.combat_visual.reset_pose()
				return
			_shot_timer += delta * speed
			if _shot_timer >= maxf(_attack.projectile_delay, 0.04):
				_shot_timer = 0.0
				_fire_one()
		Phase.DONE:
			if enemy.target != null:
				transition_to(&"Chase")
			else:
				transition_to(&"Idle")


func exit() -> void:
	_restore_cough()
	_clear_spit()
	if enemy.has_meta("is_attacking"):
		enemy.remove_meta("is_attacking")
	if enemy.combat_visual and _phase != Phase.DONE:
		enemy.combat_visual.reset_pose()


func _fire_one() -> void:
	var total := maxi(_attack.projectile_count, 1)
	if _attack.pattern_kind == AttackData.PatternKind.FAN_SHOT and total > 1 and _shots_fired == 0:
		# Fire whole fan at once for readability.
		enemy.spawn_projectile_volley(_aim, _attack)
		_shots_fired = total
	elif total > 1 and _attack.projectile_delay > 0.0:
		var spread := deg_to_rad(_attack.spread_deg)
		var offset := 0.0
		if total > 1:
			offset = -spread * 0.5 + spread * float(_shots_fired) / float(total - 1)
		enemy.spawn_projectile(_aim.rotated(offset), _attack)
		_shots_fired += 1
	else:
		enemy.spawn_projectile_volley(_aim, _attack)
		_shots_fired = total
	if enemy.combat_visual:
		enemy.combat_visual.play_ranged_fire(_aim_angle, _attack.damage_type)


func _is_hive_bile() -> bool:
	return enemy != null and enemy.is_hive_boss() and _attack != null and _attack.leaves_puddle


func _begin_hive_cough() -> void:
	if not _is_hive_bile():
		return
	var vis := enemy.get_node_or_null("Visual") as Node2D
	if vis:
		_cough_rest = vis.scale
		_coughed = true
		vis.scale = _cough_rest * Vector2(1.12, 0.82)
	_ensure_spit()


func _ensure_spit() -> void:
	if not _is_hive_bile():
		return
	_spit = enemy.get_node_or_null("BileSpit") as Line2D
	if _spit == null:
		_spit = Line2D.new()
		_spit.name = "BileSpit"
		_spit.width = 9.0
		_spit.default_color = Color(0.46, 0.62, 0.12, 0.0)
		_spit.z_index = 9
		enemy.add_child(_spit)


func _update_spit(reach: float, alpha: float) -> void:
	if _spit == null or not _is_hive_bile():
		return
	var tip := _aim * reach
	_spit.points = PackedVector2Array([Vector2(0, -18), tip])
	_spit.default_color = Color(0.48, 0.66, 0.12, alpha)
	_spit.width = 10.0 if _phase == Phase.VOLLEY else 7.0


func _clear_spit() -> void:
	if _spit and is_instance_valid(_spit):
		_spit.queue_free()
	_spit = null


func _restore_cough() -> void:
	if not _coughed:
		return
	var vis := enemy.get_node_or_null("Visual") as Node2D
	if vis:
		vis.scale = _cough_rest
	_coughed = false

