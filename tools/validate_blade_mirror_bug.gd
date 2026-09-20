extends Node
## Repro fixes: blade with mirrors, action-budget lifetime, collapse.


func _ready() -> void:
	await get_tree().process_frame
	await _run()


func _run() -> void:
	RunState.reset()
	RunState.choose_architecture(GameplayEnums.ArchitectureId.DEFAULT)
	var container := Node2D.new()
	add_child(container)
	var player: Player = (load("res://entities/player/player.tscn") as PackedScene).instantiate() as Player
	var enemy: EnemyDummy = (load("res://entities/enemies/dummy/enemy_dummy.tscn") as PackedScene).instantiate() as EnemyDummy
	player.position = Vector2(0, 0)
	enemy.position = Vector2(220, 0)
	container.add_child(player)
	container.add_child(enemy)
	await get_tree().process_frame
	RunState.apply_to_player(player)
	# Keep enemy alive across multiple throws (direct HP pad; take_damage doesn't clamp up).
	enemy.health.current_health = 500.0
	player.state_machine.set_physics_process(false)
	enemy.state_machine.set_physics_process(false)
	await get_tree().process_frame

	var econ := player.active_economy as EconomyAdrenaline

	# 1) Baseline throw
	var hp0 := enemy.health.current_health
	player.spawn_returning_blade(Vector2.RIGHT, 1.0)
	for i in 120:
		if enemy.health.current_health < hp0:
			break
		await get_tree().physics_frame
	assert(enemy.health.current_health < hp0, "baseline throw damages")
	for i in 200:
		if not player.blade_in_flight():
			break
		await get_tree().physics_frame
	assert(not player.blade_in_flight(), "baseline returns")
	print("1 baseline OK")

	# 2) Mirror on path → ricochet still damages + returns + second throw works
	econ.spawn_mirror_at(Vector2(110, 0))
	await get_tree().process_frame
	assert(_mirrors(container) == 1)
	var hp1 := enemy.health.current_health
	player.spawn_returning_blade(Vector2.RIGHT, 1.0)
	for i in 120:
		if enemy.health.current_health < hp1:
			break
		await get_tree().physics_frame
	assert(enemy.health.current_health < hp1, "ricochet throw damages")
	for i in 200:
		if not player.blade_in_flight():
			break
		await get_tree().physics_frame
	assert(not player.blade_in_flight(), "ricochet throw returns")
	var hp2 := enemy.health.current_health
	player.spawn_returning_blade(Vector2.RIGHT, 1.0)
	for i in 120:
		if enemy.health.current_health < hp2:
			break
		await get_tree().physics_frame
	assert(enemy.health.current_health < hp2, "second throw after mirror works")
	for i in 200:
		if not player.blade_in_flight():
			break
		await get_tree().physics_frame
	print("2 ricochet + second throw OK")

	# 3) Dash through counts as actions; 3 dashes clear the mirror (no timer).
	econ._clear_mirrors()
	var m: Node = econ.spawn_mirror_at(player.global_position)
	await get_tree().physics_frame
	await get_tree().physics_frame
	assert(_mirrors(container) == 1)
	assert(m.has_method("remaining_actions") and int(m.call("remaining_actions")) == 3)
	player.hurtbox.set_invincible(true, true)
	var dash_state := player.state_machine.get_node("Dash")
	for _dash_i in 3:
		player.state_machine.current_state = dash_state
		# Force a fresh dash-touch edge each loop.
		if m != null and is_instance_valid(m):
			m.set("_dash_touched", false)
		for i in 20:
			if _mirrors(container) == 0:
				break
			await get_tree().physics_frame
		player.state_machine.current_state = player.state_machine.get_node("Idle")
		await get_tree().physics_frame
	assert(_mirrors(container) == 0, "3 dash actions must spend the mirror")
	player.hurtbox.set_invincible(false, false)
	print("3 dash action budget OK")

	# 3b) Mirror does NOT expire on a timer.
	econ.spawn_mirror_at(Vector2(40, 0))
	await get_tree().create_timer(0.35).timeout
	assert(_mirrors(container) == 1, "mirrors must not timer-despawn")
	econ._clear_mirrors()

	# 4) Lattice Collapse
	econ.spawn_mirror_at(Vector2(40, 0))
	econ.spawn_mirror_at(Vector2(80, 0))
	await get_tree().process_frame
	await get_tree().physics_frame
	assert(_mirrors(container) == 2, "expected 2 mirrors before collapse, got %s" % _mirrors(container))
	player.energy.current_energy = 50.0
	assert(player.try_special())
	await get_tree().create_timer(0.25).timeout
	assert(_mirrors(container) == 0, "collapse clears mirrors")
	print("4 collapse OK")

	print("BLADE_MIRROR_FIX_OK")
	get_tree().quit(0)


func _mirrors(parent: Node) -> int:
	var n := 0
	for c in parent.get_children():
		if c.is_in_group("energy_mirror"):
			n += 1
	return n
