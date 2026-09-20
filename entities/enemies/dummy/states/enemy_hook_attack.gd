extends State
## Flesh-hook: arm snaps back, cable flies. Kiss = pull. Sidestep the line.

@onready var enemy: EnemyDummy = owner as EnemyDummy

enum Phase { WINDUP, FLY, BITE }

var _phase: Phase = Phase.WINDUP
var _elapsed: float = 0.0
var _attack: AttackData
var _aim: Vector2 = Vector2.RIGHT
var _aim_angle: float = 0.0
var _line: Line2D
var _locked: bool = false
var _hit: bool = false
var _reach: float = 0.0
var _vis_rest: Vector2 = Vector2.ZERO


func enter(msg: Dictionary = {}) -> void:
	_elapsed = 0.0
	_phase = Phase.WINDUP
	_locked = false
	_hit = false
	_reach = 40.0
	_attack = msg.get("attack", enemy.pending_attack) as AttackData
	enemy.pending_attack = null
	enemy.stop_movement()
	enemy.set_meta("is_attacking", true)
	if _attack == null:
		transition_to(&"Chase")
		return
	_face(true)
	var vis := enemy.get_node_or_null("Visual") as Node2D
	if vis:
		_vis_rest = vis.position
		vis.position = _vis_rest - _aim * 16.0
	var speed := enemy.get_action_speed_multiplier()
	if enemy.combat_visual:
		enemy.combat_visual.play_hostile_pattern_windup(
			AttackData.PatternKind.HOOK, _aim_angle, _attack.windup / speed, 3, 0.0
		)
	_ensure_line()


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
			if not _locked and _elapsed >= lock_at:
				_locked = true
				_face(false)
			else:
				_face(true)
			_update_line(_reach, 0.42)
			if _elapsed >= _attack.windup:
				_elapsed = 0.0
				_phase = Phase.FLY
				_face(false)
		Phase.FLY:
			enemy.stop_movement()
			var max_reach := _attack.hook_range if _attack.hook_range > 0.0 else 280.0
			_reach = minf(max_reach, 40.0 + _elapsed * 980.0)
			_update_line(_reach, 0.95)
			if not _hit and _player_on_cable(_reach, 22.0):
				_hit = true
				_yank()
			if _reach >= max_reach or _elapsed >= 0.32:
				_elapsed = 0.0
				_phase = Phase.BITE
				if _hit and enemy.hitbox:
					enemy.hitbox.attack_data = _attack
					enemy.hitbox.activate()
				if enemy.combat_visual and _hit:
					enemy.combat_visual.play_melee_swing(_aim_angle, 0.2, _attack.damage_type)
		Phase.BITE:
			enemy.stop_movement()
			if _elapsed >= maxf(_attack.active_duration, 0.12):
				if enemy.hitbox:
					enemy.hitbox.deactivate()
				enemy.attack_cooldown.start(_attack.cooldown / speed)
				_clear_line()
				_restore_vis()
				enemy.set_meta("is_attacking", false)
				transition_to(&"Chase")


func exit() -> void:
	if enemy.hitbox:
		enemy.hitbox.deactivate()
	_clear_line()
	_restore_vis()
	enemy.set_meta("is_attacking", false)


func _yank() -> void:
	var player := enemy.target as Player
	if player == null:
		return
	var toward := (enemy.global_position - player.global_position).normalized()
	player.apply_knockback(toward, 560.0, 0.3)
	if FeelAudio:
		FeelAudio.play_hit()


func _player_on_cable(reach: float, width: float = 22.0) -> bool:
	var player := enemy.target as Player
	if player == null:
		return false
	var origin := enemy.global_position + Vector2(0, -12)
	var tip := origin + _aim * reach
	var p := player.global_position
	var ab := tip - origin
	var len_sq := ab.length_squared()
	if len_sq < 1.0:
		return p.distance_to(origin) <= width
	var t := clampf((p - origin).dot(ab) / len_sq, 0.0, 1.0)
	return p.distance_to(origin + ab * t) <= width


func _face(track: bool) -> void:
	if enemy.target == null:
		return
	if track or not _locked:
		_aim = (enemy.target.global_position - enemy.global_position).normalized()
		if _aim == Vector2.ZERO:
			_aim = Vector2.RIGHT
		_aim_angle = _aim.angle()
		enemy.facing_direction = _aim


func _ensure_line() -> void:
	_line = enemy.get_node_or_null("HookLine") as Line2D
	if _line == null:
		_line = Line2D.new()
		_line.name = "HookLine"
		_line.width = 7.0
		_line.default_color = Color(0.48, 0.28, 0.14, 0.0)
		_line.z_index = 8
		enemy.add_child(_line)


func _update_line(reach: float, alpha: float) -> void:
	if _line == null:
		return
	var tip := _aim * reach
	_line.points = PackedVector2Array([Vector2(0, -12), tip])
	_line.default_color = Color(0.52, 0.22, 0.14, alpha)
	_line.width = 7.0 if _phase == Phase.FLY else 5.0


func _clear_line() -> void:
	if _line and is_instance_valid(_line):
		_line.queue_free()
	_line = null


func _restore_vis() -> void:
	var vis := enemy.get_node_or_null("Visual") as Node2D
	if vis:
		vis.position = _vis_rest
