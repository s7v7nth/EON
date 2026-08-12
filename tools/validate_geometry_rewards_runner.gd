extends Node
## Smoke: Geometry reward upgrades — grant flags + combat depth (bounce/crystal/lens/confuse).


func _ready() -> void:
	await get_tree().process_frame
	await _run()


func _run() -> void:
	RunState.reset()
	RunState.choose_architecture(GameplayEnums.ArchitectureId.DEFAULT)
	var rewards := RunState.get_reward_upgrades()
	assert(rewards.size() >= 5, "expected 5 geometry reward upgrades, got %s" % rewards.size())
	var ids: PackedStringArray = PackedStringArray()
	for u in rewards:
		ids.append(String(u.upgrade_id))
	for need in [&"default_kinetic_pingpong", &"default_prism_trap", &"default_optic_labyrinth", &"default_focus_lens", &"default_holo_sub"]:
		assert(need in ids, "missing reward %s" % need)

	# Not shown in loot craft list.
	for u in RunState.get_craftable_upgrades():
		assert(not u.reward_offerable)

	var container := Node2D.new()
	add_child(container)
	var player: Player = (load("res://entities/player/player.tscn") as PackedScene).instantiate() as Player
	var enemy: EnemyDummy = (load("res://entities/enemies/dummy/enemy_dummy.tscn") as PackedScene).instantiate() as EnemyDummy
	player.position = Vector2(0, 0)
	enemy.position = Vector2(200, 0)
	container.add_child(player)
	container.add_child(enemy)
	await get_tree().process_frame
	RunState.apply_to_player(player)

	var ping := load("res://resources/upgrades/default_kinetic_pingpong.tres") as UpgradeData
	assert(RunState.grant_upgrade(ping))
	RunState.apply_to_player(player)
	var econ := player.active_economy as EconomyAdrenaline
	assert(econ.wall_bounce_enabled)
	assert(econ.dash_blade_intercept)

	# Wall bounce: returning blade with wall_bounce reflects off a StaticBody2D.
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	var wall_shape := CollisionShape2D.new()
	var wall_rect := RectangleShape2D.new()
	wall_rect.size = Vector2(20, 120)
	wall_shape.shape = wall_rect
	wall.add_child(wall_shape)
	wall.position = Vector2(140, 0)
	container.add_child(wall)
	await get_tree().process_frame
	var bounce_proj := (load("res://entities/projectiles/projectile.tscn") as PackedScene).instantiate() as Projectile
	bounce_proj.attack_data = player.blade_throw_attack.duplicate(true)
	bounce_proj.direction = Vector2.RIGHT
	bounce_proj.source = player
	bounce_proj.wall_bounce_enabled = true
	bounce_proj.global_position = Vector2(100, 0)
	container.add_child(bounce_proj)
	await get_tree().process_frame
	# Force body enter path.
	bounce_proj._on_body_entered(wall)
	assert(bounce_proj._wall_bounces == 1, "kinetic ping-pong should wall-bounce")
	assert(bounce_proj.direction.x < 0.0, "wall bounce should reverse X")
	bounce_proj.queue_free()
	wall.queue_free()

	var trap := load("res://resources/upgrades/default_prism_trap.tres") as UpgradeData
	assert(RunState.grant_upgrade(trap))
	RunState.apply_to_player(player)
	econ = player.active_economy as EconomyAdrenaline
	assert(econ.spawn_crystal_on_return)

	# Crystal spawn + melee split → ray projectiles.
	var crystal: Node = econ.spawn_prism_crystal(Vector2(80, 0))
	assert(crystal != null and is_instance_valid(crystal), "prism trap should spawn crystal")
	assert(crystal.is_in_group("prism_crystal"))
	var before_kids := container.get_child_count()
	assert(bool(crystal.call("try_split_from_melee", Vector2(80, 0), 70.0)))
	await get_tree().process_frame
	var ray_count := 0
	for child in container.get_children():
		if child is Projectile:
			ray_count += 1
	assert(ray_count >= 8, "crystal melee split should spawn ray projectiles, got %s" % ray_count)
	assert(before_kids <= container.get_child_count())
	# Cleanup rays.
	for child in container.get_children():
		if child is Projectile:
			child.queue_free()
	await get_tree().process_frame

	var lab := load("res://resources/upgrades/default_optic_labyrinth.tres") as UpgradeData
	assert(RunState.grant_upgrade(lab))
	RunState.apply_to_player(player)
	econ = player.active_economy as EconomyAdrenaline
	assert(econ.max_mirrors >= 5)
	assert(econ.mirror_confuse)

	# Confuse aura applies glitch buildup near mirror.
	econ._clear_mirrors()
	await get_tree().process_frame
	var confuse_mirror: Node2D = econ.spawn_mirror_at(Vector2(200, 0)) as Node2D
	assert(confuse_mirror != null)
	enemy.position = Vector2(200, 0)
	await get_tree().process_frame
	# Drive aura ticks past 0.35s threshold.
	for _i in 3:
		confuse_mirror.call("_tick_confuse_aura", 0.4)
	await get_tree().process_frame
	var status = enemy.get("status")
	assert(status != null)
	assert(status.has_method("get_buildup_ratio"))
	assert(float(status.call("get_buildup_ratio", &"glitch")) > 0.0, "optic labyrinth confuse aura should apply glitch near mirror")

	var lens := load("res://resources/upgrades/default_focus_lens.tres") as UpgradeData
	assert(RunState.grant_upgrade(lens))
	RunState.apply_to_player(player)
	econ = player.active_economy as EconomyAdrenaline
	assert(econ.spawn_lens_on_parry)

	# Focus lens: amplify + action budget (no timer).
	var lens_node: Node = econ.spawn_focus_lens(Vector2(40, -20))
	assert(lens_node != null and is_instance_valid(lens_node))
	assert(int(lens_node.call("remaining_actions")) == 3)
	await get_tree().create_timer(0.25).timeout
	assert(is_instance_valid(lens_node), "focus lens must not timer-despawn")
	var amp_proj := (load("res://entities/projectiles/projectile.tscn") as PackedScene).instantiate() as Projectile
	amp_proj.attack_data = player.blade_throw_attack.duplicate(true)
	var base_dmg := amp_proj.attack_data.damage
	amp_proj.direction = Vector2.RIGHT
	amp_proj.source = player
	amp_proj.global_position = Vector2(40, -20)
	container.add_child(amp_proj)
	await get_tree().process_frame
	assert(bool(lens_node.call("try_amplify_projectile", amp_proj)))
	assert(amp_proj.attack_data.damage > base_dmg * 2.0, "lens should amplify damage ×2.5")
	assert(int(lens_node.call("remaining_actions")) == 2)
	amp_proj.queue_free()
	# Spend remaining actions.
	for _j in 2:
		var p2 := (load("res://entities/projectiles/projectile.tscn") as PackedScene).instantiate() as Projectile
		p2.attack_data = player.blade_throw_attack.duplicate(true)
		p2.direction = Vector2.RIGHT
		p2.source = player
		container.add_child(p2)
		await get_tree().process_frame
		lens_node.call("try_amplify_projectile", p2)
		p2.queue_free()
	await get_tree().create_timer(0.25).timeout
	assert(not is_instance_valid(lens_node) or not lens_node.is_inside_tree(), "3 amplifies should spend focus lens")

	var holo := load("res://resources/upgrades/default_holo_sub.tres") as UpgradeData
	assert(RunState.grant_upgrade(holo))
	RunState.apply_to_player(player)
	player.health.current_health = 5.0
	assert(player.try_prevent_death(50.0))
	assert(player.health.current_health > 5.0)

	# Already granted → no longer in reward pool.
	assert(RunState.get_reward_upgrades().is_empty())

	print("GEOMETRY_REWARDS_OK")
	get_tree().quit(0)
