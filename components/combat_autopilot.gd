class_name CombatAutopilot
extends Node
## Playtest driver. Enabled with `--autopilot` after `--`. Not a cheat door.

var _attack_cd: float = 0.0
var _dash_cd: float = 0.0
var _reward_wait: float = 0.0
var _move_names: PackedStringArray = PackedStringArray(["move_left", "move_right", "move_up", "move_down"])


static func is_requested() -> bool:
	for arg in OS.get_cmdline_user_args():
		if arg == "--autopilot":
			return true
	return false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_physics_process(true)


func _exit_tree() -> void:
	_release_all()


func _physics_process(delta: float) -> void:
	var player := get_parent() as Player
	if player == null or not is_instance_valid(player):
		return
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_dash_cd = maxf(0.0, _dash_cd - delta)
	var overlay := _overlay()
	if overlay and overlay.is_run_over():
		_release_all()
		return
	if overlay and overlay.is_reward_open():
		_release_all()
		player.aim_override = Vector2.ZERO
		_reward_wait += delta
		if _reward_wait >= 2.6:
			if overlay.has_method("try_autopilot_reward"):
				overlay.try_autopilot_reward()
			else:
				_tap_key(KEY_1)
			_reward_wait = 0.0
		return
	_reward_wait = 0.0
	if get_tree().paused:
		_release_all()
		return
	var enemy := _nearest_enemy(player)
	if enemy:
		_fight(player, enemy, delta)
		return
	player.aim_override = Vector2.ZERO
	_walk_to_exit(player)


func _fight(player: Player, enemy: EnemyDummy, _delta: float) -> void:
	var to_enemy := enemy.global_position - player.global_position
	var dist := to_enemy.length()
	player.aim_override = to_enemy
	var trap_push := _trap_repulsion(player.global_position)
	var hp_ratio := 1.0
	if player.health and player.health.get_max_health() > 0.0:
		hp_ratio = player.health.current_health / player.health.get_max_health()
	var energy_ok := true
	if player.energy:
		energy_ok = player.energy.current_energy > 4.0
	var kite := enemy.prefers_kite or enemy.ranged_range > 220.0
	var desired := 40.0 if kite else (50.0 if hp_ratio > 0.55 else 78.0)
	var steer := to_enemy
	if dist < desired - 8.0:
		steer = to_enemy.rotated(1.25) * -0.4 + to_enemy.orthogonal()
	elif dist > desired + 14.0:
		steer = to_enemy
	else:
		steer = to_enemy.orthogonal() * (1.0 if hp_ratio > 0.5 else 1.4)
	steer += trap_push * 2.2
	_set_move(steer)
	if (hp_ratio < 0.62 or dist < 28.0) and _dash_cd <= 0.0 and player.dash_ready():
		_tap_action("dash")
		_dash_cd = 0.55
	if dist > 88.0 and _dash_cd <= 0.0 and player.dash_ready():
		_tap_action("dash")
		_dash_cd = 0.7 if kite else 0.8
	if dist <= 64.0 and _attack_cd <= 0.0 and energy_ok and hp_ratio > 0.18:
		_tap_action("attack")
		_attack_cd = 0.2


func _walk_to_exit(player: Player) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		_set_move(Vector2.ZERO)
		return
	var exit := scene.get_node_or_null("ExitMarker") as Node2D
	if exit == null or not exit.visible:
		_set_move(Vector2.ZERO)
		return
	_set_move(exit.global_position - player.global_position)


func _nearest_enemy(player: Player) -> EnemyDummy:
	var best: EnemyDummy = null
	var best_d := INF
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as EnemyDummy
		if enemy == null or not is_instance_valid(enemy):
			continue
		if enemy.health and enemy.health.current_health <= 0.0:
			continue
		var d := player.global_position.distance_squared_to(enemy.global_position)
		if d < best_d:
			best_d = d
			best = enemy
	return best


func _trap_repulsion(origin: Vector2) -> Vector2:
	var push := Vector2.ZERO
	for node in get_tree().get_nodes_in_group("biome_traps"):
		var trap := node as Node2D
		if trap == null:
			continue
		var delta := origin - trap.global_position
		var d := delta.length()
		if d < 70.0 and d > 0.1:
			push += delta.normalized() * ((70.0 - d) / 70.0)
	return push


func _overlay() -> Node:
	var scene := get_tree().current_scene
	if scene == null:
		return null
	return scene.get_node_or_null("RunOverlay")


func _set_move(dir: Vector2) -> void:
	_release_moves()
	if dir == Vector2.ZERO:
		return
	if absf(dir.x) >= 8.0 or absf(dir.y) >= 8.0 or dir.length() <= 2.0:
		pass
	if absf(dir.x) >= absf(dir.y) * 0.35:
		Input.action_press("move_right" if dir.x > 0.0 else "move_left")
	if absf(dir.y) >= absf(dir.x) * 0.35:
		Input.action_press("move_down" if dir.y > 0.0 else "move_up")


func _tap_action(action: StringName) -> void:
	Input.action_press(action)
	await get_tree().create_timer(0.05).timeout
	Input.action_release(action)


func _tap_key(code: Key) -> void:
	var press := InputEventKey.new()
	press.physical_keycode = code
	press.pressed = true
	Input.parse_input_event(press)
	var rel := InputEventKey.new()
	rel.physical_keycode = code
	rel.pressed = false
	Input.parse_input_event(rel)


func _release_moves() -> void:
	for name in _move_names:
		if Input.is_action_pressed(name):
			Input.action_release(name)


func _release_all() -> void:
	_release_moves()
	if Input.is_action_pressed("attack"):
		Input.action_release("attack")
	if Input.is_action_pressed("dash"):
		Input.action_release("dash")
