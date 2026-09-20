extends State
## Windup → activate hitbox → optional combo_next → cooldown → Chase/Idle.
## Supports SLASH / OVERHEAD_SLAM / COMBO with early aim-lock and circular slam.
## Hive slam: dark circle on the floor under the player, then the mass comes down.

const _SlamCircle := preload("res://entities/hazards/hive_slam_circle.gd")

@onready var enemy: EnemyDummy = owner as EnemyDummy

enum Phase { WINDUP, ACTIVE, COMBO_GAP }

var _phase: Phase = Phase.WINDUP
var _elapsed: float = 0.0
var _attack: AttackData
var _aim_angle: float = 0.0
var _anim_variant: int = 0
var _locked_aim: bool = false
var _slam: Node2D
var _slam_world: Vector2 = Vector2.ZERO
var _vis_rest: Vector2 = Vector2.ZERO
var _vis_scale: Vector2 = Vector2.ONE


func enter(msg: Dictionary = {}) -> void:
	_elapsed = 0.0
	_phase = Phase.WINDUP
	_locked_aim = false
	_attack = msg.get("attack", enemy.pending_attack) as AttackData
	if _attack == null and enemy.hitbox:
		_attack = enemy.hitbox.attack_data
	enemy.pending_attack = null
	enemy.stop_movement()
	enemy.set_meta("is_attacking", true)
	if _attack == null:
		transition_to(&"Chase")
		return
	if not enemy.attack_cooldown.is_stopped() and not msg.get("combo_continue", false):
		transition_to(&"Chase")
		return
	if enemy.hitbox:
		enemy.hitbox.attack_data = _attack
	_anim_variant = _variant_for_pattern(_attack)
	_face_target(true)
	var speed := enemy.get_action_speed_multiplier()
	if enemy.combat_visual and not _is_hive_slam():
		enemy.combat_visual.play_hostile_pattern_windup(
			_attack.pattern_kind, _aim_angle, _attack.windup / speed, _anim_variant,
			_attack.circular_radius if _attack.circular else 0.0
		)
	_begin_hive_slam()


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
				_face_target(false)
				_lock_hive_slam()
			else:
				_face_target(true)
			if _elapsed >= _attack.windup:
				_elapsed = 0.0
				_phase = Phase.ACTIVE
				_locked_aim = true
				_face_target(false)
				_lock_hive_slam()
				_configure_melee_hitbox()
				_place_hive_slam_hitbox()
				_apply_lunge_impulse()
				enemy.hitbox.activate()
				_strike_hive_slam()
				if enemy.combat_visual and not _is_hive_slam():
					if _attack.circular or _attack.pattern_kind == AttackData.PatternKind.OVERHEAD_SLAM:
						enemy.combat_visual.play_circle_slash(
							maxf(_attack.active_duration / speed, 0.22)
						)
					else:
						enemy.combat_visual.play_melee_swing(
							_aim_angle,
							maxf(_attack.active_duration / speed, 0.22),
							_attack.damage_type,
							Color(0, 0, 0, 0),
							_anim_variant
						)
		Phase.ACTIVE:
			_place_hive_slam_hitbox()
			if _elapsed >= _attack.active_duration:
				enemy.hitbox.deactivate()
				if _attack.combo_next != null:
					_elapsed = 0.0
					_phase = Phase.COMBO_GAP
				else:
					_finish_string()
		Phase.COMBO_GAP:
			if _elapsed >= 0.08:
				transition_to(&"Attack", {"attack": _attack.combo_next, "combo_continue": true})


func exit() -> void:
	enemy.hitbox.deactivate()
	_clear_hive_slam()
	if enemy.has_meta("is_attacking"):
		enemy.remove_meta("is_attacking")
	if enemy.combat_visual:
		enemy.combat_visual.reset_pose()


func _finish_string() -> void:
	var speed := enemy.get_action_speed_multiplier()
	enemy.attack_cooldown.start(_attack.cooldown / speed)
	if enemy.target != null:
		transition_to(&"Chase")
	else:
		transition_to(&"Idle")


func _face_target(update_visual: bool) -> void:
	if _locked_aim:
		return
	if enemy.target == null:
		return
	var to_target := enemy.target.global_position - enemy.global_position
	to_target += Vector2(0, -20)
	if to_target == Vector2.ZERO:
		return
	_aim_angle = to_target.angle()
	_configure_melee_hitbox()
	if update_visual and enemy.combat_visual and _phase == Phase.WINDUP and _attack and not _is_hive_slam():
		enemy.combat_visual.aim_hostile_pattern_telegraph(
			_attack.pattern_kind, _aim_angle,
			_attack.circular_radius if _attack.circular else 0.0
		)


func _apply_lunge_impulse() -> void:
	if _attack == null:
		return
	var force := _attack.lunge_force
	if force <= 0.0 and _attack.lunge_distance > 0.0:
		force = _attack.lunge_distance * 4.0
	if force <= 0.0:
		return
	var dir := Vector2.from_angle(_aim_angle)
	enemy.apply_knockback(dir, force * 0.35, maxf(_attack.active_duration, 0.08))


func _configure_melee_hitbox() -> void:
	if enemy.hitbox == null:
		return
	var shape_node := enemy.hitbox.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		return
	if _is_hive_slam():
		# Damage lives on the floor circle, not a 128-radius blob on the butcher.
		enemy.hitbox.rotation = 0.0
		enemy.hitbox.position = Vector2(0, -8)
		var stub := CircleShape2D.new()
		stub.radius = 12.0
		shape_node.shape = stub
		shape_node.position = Vector2.ZERO
		return
	if _attack and (_attack.circular or _attack.pattern_kind == AttackData.PatternKind.OVERHEAD_SLAM):
		enemy.hitbox.rotation = 0.0
		enemy.hitbox.position = Vector2(0, -8)
		var circle := CircleShape2D.new()
		circle.radius = maxf(_attack.circular_radius, 56.0)
		shape_node.shape = circle
		shape_node.position = Vector2.ZERO
		return
	var dir := Vector2.from_angle(_aim_angle)
	var reach := maxf(enemy.attack_range * 0.72, 30.0)
	enemy.hitbox.rotation = 0.0
	enemy.hitbox.position = dir * reach + Vector2(0, -8)
	var hit_circle := CircleShape2D.new()
	hit_circle.radius = 34.0
	shape_node.shape = hit_circle
	shape_node.position = Vector2.ZERO


func _is_hive_slam() -> bool:
	if enemy == null or not enemy.is_hive_boss() or _attack == null:
		return false
	return _attack.circular or _attack.pattern_kind == AttackData.PatternKind.OVERHEAD_SLAM


func _begin_hive_slam() -> void:
	if not _is_hive_slam():
		return
	if enemy.combat_visual:
		if enemy.combat_visual.telegraph:
			enemy.combat_visual.telegraph.color.a = 0.0
		if enemy.combat_visual.swing_arc:
			enemy.combat_visual.swing_arc.modulate.a = 0.0
	var vis := enemy.get_node_or_null("Visual") as Node2D
	if vis:
		_vis_rest = vis.position
		_vis_scale = vis.scale
		vis.position = _vis_rest + Vector2(0, -22)
		vis.scale = _vis_scale * Vector2(1.04, 1.12)
	# Draw on the island floor: above night tiles, under the butcher / hero.
	var host: Node = _island_host(enemy)
	if host == null:
		return
	_slam = _SlamCircle.new()
	host.add_child(_slam)
	if enemy.target:
		_slam.global_position = enemy.target.global_position
	else:
		_slam.global_position = enemy.global_position
	_slam.call("setup", maxf(_attack.circular_radius, 96.0))
	if enemy.target:
		_slam.call("follow", enemy.target)


func _lock_hive_slam() -> void:
	if _slam == null or not is_instance_valid(_slam):
		return
	_slam.call("lock_here")
	_slam_world = _slam.global_position


func _place_hive_slam_hitbox() -> void:
	if not _is_hive_slam() or enemy.hitbox == null:
		return
	if _slam and is_instance_valid(_slam):
		_slam_world = _slam.global_position
	enemy.hitbox.global_position = _slam_world
	var shape_node := enemy.hitbox.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node:
		var circle := CircleShape2D.new()
		circle.radius = maxf(_attack.circular_radius, 56.0) if _attack else 96.0
		shape_node.shape = circle
		shape_node.position = Vector2.ZERO


func _strike_hive_slam() -> void:
	var vis := enemy.get_node_or_null("Visual") as Node2D
	if vis:
		vis.position = _vis_rest
		vis.scale = _vis_scale
	if _slam and is_instance_valid(_slam) and _slam.has_method("strike"):
		_slam.call("strike")
		_slam = null
	CameraFx.add_trauma(0.28)


func _clear_hive_slam() -> void:
	var vis := enemy.get_node_or_null("Visual") as Node2D
	if vis:
		vis.position = _vis_rest
		vis.scale = _vis_scale
	if _slam and is_instance_valid(_slam):
		_slam.queue_free()
	_slam = null
	if enemy.hitbox:
		enemy.hitbox.position = Vector2(22, 0)


func _island_host(from: Node) -> Node:
	var n := from
	while n:
		if n is RoomIsland:
			return n
		n = n.get_parent()
	var parent := from.get_parent() if from else null
	if parent and parent.name == "Entities" and parent.get_parent():
		return parent.get_parent()
	return parent


func _variant_for_pattern(atk: AttackData) -> int:
	if atk == null:
		return 0
	match atk.pattern_kind:
		AttackData.PatternKind.OVERHEAD_SLAM:
			return 2
		AttackData.PatternKind.LUNGE:
			return 3
		AttackData.PatternKind.COMBO:
			return 1
		_:
			return randi() % CombatVisualComponent.MELEE_VARIANT_COUNT
