extends Node
## Geometry of Reflections smoke: parry→mirror, ricochet, Lattice Collapse, crafts.


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
	enemy.position = Vector2(120, 0)
	container.add_child(player)
	container.add_child(enemy)
	await get_tree().process_frame
	RunState.apply_to_player(player)
	await get_tree().process_frame

	assert(player.active_economy != null)
	assert(player.active_economy is EconomyAdrenaline)
	var econ := player.active_economy as EconomyAdrenaline

	# Q with no mirrors must fail.
	assert(not player.try_special())

	# Parry success spawns an Energy Mirror at midpoint.
	SignalBus.parry_success.emit(enemy)
	await get_tree().process_frame
	assert(_count_mirrors(container) == 1, "parry should spawn one mirror")
	var mirror: Node2D = _first_mirror(container)
	assert(mirror != null)
	var expected := (player.global_position + enemy.global_position) * 0.5
	assert(mirror.global_position.distance_to(expected) < 1.0)

	# Cap 3 with FIFO.
	SignalBus.parry_success.emit(enemy)
	SignalBus.parry_success.emit(enemy)
	SignalBus.parry_success.emit(enemy)
	await get_tree().process_frame
	await get_tree().create_timer(0.15).timeout
	assert(_count_mirrors(container) <= 3, "mirror cap should be 3")

	# Action budget: no timer despawn; 3 ricochets spend a mirror.
	econ._clear_mirrors()
	await get_tree().process_frame
	var budget_mirror: Node = econ.spawn_mirror_at(Vector2(60, 0))
	assert(budget_mirror != null)
	assert(int(budget_mirror.call("remaining_actions")) == 3)
	await get_tree().create_timer(0.3).timeout
	assert(_count_mirrors(container) == 1, "mirrors must not timer-despawn")
	for _i in 3:
		budget_mirror.call("register_action", &"ricochet")
	await get_tree().process_frame
	assert(_count_mirrors(container) == 0, "3 actions should spend mirror")
	# Ensure fading node is gone before next spawn.
	await get_tree().create_timer(0.25).timeout
	econ._prune_mirrors()

	# Ricochet redirects blade toward nearest enemy.
	econ._clear_mirrors()
	await get_tree().process_frame
	var m: Node2D = econ.spawn_mirror_at(Vector2(60, 0)) as Node2D
	assert(m != null)
	var proj := (load("res://entities/projectiles/projectile.tscn") as PackedScene).instantiate() as Projectile
	proj.attack_data = player.blade_throw_attack.duplicate(true)
	proj.direction = Vector2.RIGHT
	proj.source = player
	proj.max_mirror_bounces = 1
	proj.ricochet_damage_mult = 1.5
	proj.global_position = Vector2(40, 0)
	container.add_child(proj)
	await get_tree().process_frame
	assert(proj.apply_mirror_ricochet(m))
	assert(proj.direction.x > 0.5, "ricochet should aim toward enemy on the right")
	assert(proj.attack_data.damage > player.blade_throw_attack.damage)
	assert(not proj._returning)
	proj.queue_free()

	# Lead aim: moving enemy → ricochet aims ahead of current position.
	econ._clear_mirrors()
	await get_tree().process_frame
	var lead_mirror: Node2D = econ.spawn_mirror_at(Vector2(60, 0)) as Node2D
	enemy.velocity = Vector2(0, 400)
	var lead_proj := (load("res://entities/projectiles/projectile.tscn") as PackedScene).instantiate() as Projectile
	lead_proj.attack_data = player.blade_throw_attack.duplicate(true)
	lead_proj.direction = Vector2.RIGHT
	lead_proj.source = player
	lead_proj.max_mirror_bounces = 1
	lead_proj.global_position = Vector2(40, 0)
	container.add_child(lead_proj)
	await get_tree().process_frame
	var from := lead_mirror.global_position
	var raw_dir := (lead_proj._aim_point_of(enemy) - from).normalized()
	var led_dir := lead_proj._lead_direction(from, enemy, 420.0)
	assert(led_dir.y > raw_dir.y + 0.02, "lead aim should bias toward +Y velocity")
	assert(lead_proj.apply_mirror_ricochet(lead_mirror))
	enemy.velocity = Vector2.ZERO
	lead_proj.queue_free()

	# Pierce: hitting an enemy does not start return / does not block further flight.
	var pierce_proj := (load("res://entities/projectiles/projectile.tscn") as PackedScene).instantiate() as Projectile
	pierce_proj.attack_data = player.blade_throw_attack.duplicate(true)
	pierce_proj.direction = Vector2.RIGHT
	pierce_proj.source = player
	pierce_proj.global_position = enemy.global_position + Vector2(-40, 0)
	container.add_child(pierce_proj)
	await get_tree().process_frame
	var hp_before := enemy.health.current_health
	pierce_proj._resolve_pierce_hit(enemy.hurtbox)
	assert(enemy.health.current_health < hp_before, "pierce should damage")
	assert(not pierce_proj._returning, "pierce must not begin return")
	assert(not pierce_proj._hit_done, "pierce must keep blade active")
	pierce_proj.queue_free()

	# Lattice Collapse spends energy and clears mirrors.
	econ._clear_mirrors()
	econ.spawn_mirror_at(Vector2(40, 0))
	econ.spawn_mirror_at(Vector2(80, 0))
	await get_tree().process_frame
	assert(_count_mirrors(container) == 2)
	var energy_before := player.energy.current_energy
	assert(player.try_special())
	await get_tree().create_timer(0.2).timeout
	assert(player.energy.current_energy < energy_before)
	assert(_count_mirrors(container) == 0, "collapse should detonate all mirrors")

	# Prism Chain craft raises bounce budget.
	var prism := load("res://resources/loot/prism_shard.tres") as LootPart
	RunState.grant_part(prism)
	var prism_up := load("res://resources/upgrades/default_prism_chain.tres") as UpgradeData
	assert(RunState.craft_upgrade(prism_up))
	RunState.apply_to_player(player)
	econ = player.active_economy as EconomyAdrenaline
	assert(econ.max_bounces == 3)

	# Echo Shade craft is registered and craftable with servo.
	var echo_up := load("res://resources/upgrades/default_echo_shade.tres") as UpgradeData
	assert(echo_up != null)
	var servo := load("res://resources/loot/servo_motor.tres") as LootPart
	RunState.grant_part(servo)
	var has_echo := false
	for u in RunState.get_craftable_upgrades():
		if u.upgrade_id == &"default_echo_shade":
			has_echo = true
			break
	assert(has_echo)

	print("GEOMETRY_OK mirrors + ricochet + collapse + crafts")
	get_tree().quit(0)


func _count_mirrors(parent: Node) -> int:
	var n := 0
	for child in parent.get_children():
		if child.is_in_group("energy_mirror"):
			n += 1
	return n


func _first_mirror(parent: Node) -> Node2D:
	for child in parent.get_children():
		if child.is_in_group("energy_mirror") and child is Node2D:
			return child as Node2D
	return null
