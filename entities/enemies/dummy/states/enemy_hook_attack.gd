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
		if enemy.is_hive_boss() and enemy.combat_visual.telegraph:
			enemy.combat_visual.telegraph.color.a = 0.0
			if enemy.combat_visual.swing_arc:
				enemy.combat_visual.swing_arc.modulate.a = 0.0
		else:
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
		_line.width = 16.0
		_line.default_color = Color(0.42, 0.28, 0.1, 0.0)
		_line.z_index = 8
		enemy.add_child(_line)
	var core := enemy.get_node_or_null("HookCore") as Line2D
	if core == null:
		core = Line2D.new()
		core.name = "HookCore"
		core.width = 6.0
		core.default_color = Color(0.58, 0.42, 0.12, 0.0)
		core.z_index = 9
		enemy.add_child(core)
	var tip := enemy.get_node_or_null("HookTip") as Polygon2D
	if tip == null:
		tip = Polygon2D.new()
		tip.name = "HookTip"
		tip.polygon = PackedVector2Array([
			Vector2(22, 0), Vector2(-4, -14), Vector2(6, -4), Vector2(-10, 0), Vector2(6, 8), Vector2(-6, 16)
		])
		tip.color = Color(0.48, 0.22, 0.1, 0.0)
		tip.z_index = 10
		enemy.add_child(tip)
	if enemy.get_node_or_null("HookMeat") == null:
		var meat := Node2D.new()
		meat.name = "HookMeat"
		meat.z_index = 8
		enemy.add_child(meat)
		for i in 5:
			var lump := Polygon2D.new()
			lump.name = "Lump%d" % i
			lump.polygon = PackedVector2Array([
				Vector2(8, 0), Vector2(2, -7), Vector2(-8, -3), Vector2(-6, 5), Vector2(3, 7)
			])
			lump.color = Color(0.4, 0.32, 0.1, 0.0)
			meat.add_child(lump)


func _update_line(reach: float, alpha: float) -> void:
	if _line == null:
		return
	var origin := Vector2(0, -12)
	var tip := _aim * reach
	_line.points = PackedVector2Array([origin, tip])
	_line.default_color = Color(0.38, 0.26, 0.08, alpha)
	_line.width = 18.0 if _phase == Phase.FLY else 12.0
	var core := enemy.get_node_or_null("HookCore") as Line2D
	if core:
		core.points = PackedVector2Array([origin, tip])
		core.default_color = Color(0.62, 0.48, 0.14, alpha * 0.95)
		core.width = 7.0 if _phase == Phase.FLY else 4.5
	var barb := enemy.get_node_or_null("HookTip") as Polygon2D
	if barb:
		barb.position = tip
		barb.rotation = _aim_angle
		barb.color = Color(0.52, 0.22, 0.1, alpha)
	var meat := enemy.get_node_or_null("HookMeat") as Node2D
	if meat:
		var kids := meat.get_children()
		for i in kids.size():
			var lump := kids[i] as Polygon2D
			if lump == null:
				continue
			var t := (float(i) + 1.0) / float(kids.size() + 1)
			lump.position = origin.lerp(tip, t)
			lump.rotation = _aim_angle + 0.4 * sin(float(i) * 1.7)
			lump.color = Color(0.4, 0.3, 0.1, alpha * 0.9)


func _clear_line() -> void:
	if _line and is_instance_valid(_line):
		_line.queue_free()
	_line = null
	var core := enemy.get_node_or_null("HookCore") as Line2D
	if core:
		core.queue_free()
	var barb := enemy.get_node_or_null("HookTip") as Polygon2D
	if barb:
		barb.queue_free()
	var meat := enemy.get_node_or_null("HookMeat") as Node2D
	if meat:
		meat.queue_free()


func _restore_vis() -> void:
	var vis := enemy.get_node_or_null("Visual") as Node2D
	if vis:
		vis.position = _vis_rest
