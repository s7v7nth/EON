extends Node
## Smoke: Паровоз heat crafts + Нейро melee crafts grant/apply correctly.


func _ready() -> void:
	await get_tree().process_frame
	await _run()


func _run() -> void:
	await _train_crafts()
	await _neuro_crafts()
	print("ARCH_DEPTH_OK")
	get_tree().quit(0)


func _train_crafts() -> void:
	RunState.reset()
	RunState.choose_architecture(GameplayEnums.ArchitectureId.ELECTRO_TRAIN)
	# Starting tags unlock Coil; mid/late need loot tags.
	var coil := load("res://resources/upgrades/train_coil_overdrive.tres") as UpgradeData
	assert(RunState.craft_upgrade(coil) or RunState.grant_upgrade(coil))
	var container := Node2D.new()
	add_child(container)
	var player: Player = (load("res://entities/player/player.tscn") as PackedScene).instantiate() as Player
	container.add_child(player)
	await get_tree().process_frame
	RunState.apply_to_player(player)
	var econ := player.active_economy as EconomyOverheat
	assert(econ != null)
	econ.heat = 0.0
	var cold := _fx_damage_mult(player)
	econ.heat = econ.heat_max
	var hot := _fx_damage_mult(player)
	assert(hot > cold, "Coil Overdrive should scale with heat")

	RunState._add_tag("servo")
	var valve := load("res://resources/upgrades/train_pressure_valve.tres") as UpgradeData
	assert(RunState.craft_upgrade(valve))
	RunState.apply_to_player(player)
	econ = player.active_economy as EconomyOverheat
	assert(econ.vent_base_damage > 20.0 * 1.2, "Pressure Valve should boost vent damage")
	assert(econ.vent_cooldown_base < 0.6, "Pressure Valve should shorten vent lock")

	RunState._add_tag("style")
	var redline := load("res://resources/upgrades/train_redline.tres") as UpgradeData
	assert(RunState.craft_upgrade(redline))
	RunState._add_tag("magnet")
	var afterburn := load("res://resources/upgrades/train_afterburn.tres") as UpgradeData
	assert(RunState.craft_upgrade(afterburn))
	RunState.apply_to_player(player)
	SignalBus.vent_triggered.emit(player)
	await get_tree().process_frame
	var after_mult := _fx_damage_mult(player)
	assert(after_mult >= 1.2, "Plasma Afterburn window should boost damage")
	container.queue_free()
	await get_tree().process_frame


func _neuro_crafts() -> void:
	RunState.reset()
	RunState.choose_architecture(GameplayEnums.ArchitectureId.NEURO_HACKER)
	var edge := load("res://resources/upgrades/neuro_holo_edge.tres") as UpgradeData
	assert(RunState.craft_upgrade(edge))
	var container := Node2D.new()
	add_child(container)
	var player: Player = (load("res://entities/player/player.tscn") as PackedScene).instantiate() as Player
	var enemy: EnemyDummy = (load("res://entities/enemies/dummy/enemy_dummy.tscn") as PackedScene).instantiate() as EnemyDummy
	player.position = Vector2.ZERO
	enemy.position = Vector2(40, 0)
	container.add_child(player)
	container.add_child(enemy)
	await get_tree().process_frame
	RunState.apply_to_player(player)
	var hp_before := enemy.health.current_health
	for fx in player.active_effects:
		if fx.has_method("on_melee_hit"):
			fx.on_melee_hit(player, enemy.hurtbox)
	await get_tree().process_frame
	assert(enemy.health.current_health < hp_before, "Holo Edge should deal bonus melee damage")
	assert(float(enemy.status.call("get_buildup_ratio", &"glitch")) > 0.0, "Holo Edge should apply glitch")

	RunState._add_tag("code")
	var frag := load("res://resources/upgrades/neuro_fragment_slash.tres") as UpgradeData
	assert(RunState.craft_upgrade(frag))
	RunState.apply_to_player(player)
	var kids_before := container.get_child_count()
	for fx in player.active_effects:
		if fx.get_script() != null and String(fx.get_script().resource_path).ends_with("effect_fragment_slash.gd"):
			fx.on_melee_hit(player, enemy.hurtbox)
	await get_tree().process_frame
	var shards := 0
	for child in container.get_children():
		if child is Projectile:
			shards += 1
	assert(shards >= 3, "Fragment Slash should spawn shards")
	assert(container.get_child_count() >= kids_before)

	RunState._add_tag("antenna")
	var sync := load("res://resources/upgrades/neuro_sync_blade.tres") as UpgradeData
	assert(RunState.craft_upgrade(sync))
	RunState.apply_to_player(player)
	assert(player.try_special())
	await get_tree().process_frame
	var drones := get_tree().get_nodes_in_group("ally_drone")
	assert(drones.size() >= 1, "Neuro Q should spawn a drone")
	var drone: AllyDrone = drones[0] as AllyDrone
	var base_dmg := drone.attack_damage
	for fx in player.active_effects:
		if fx.get_script() != null and String(fx.get_script().resource_path).ends_with("effect_sync_blade.gd"):
			fx.on_melee_hit(player, enemy.hurtbox)
	await get_tree().process_frame
	assert(drone.attack_damage > base_dmg, "Sync Blade should overclock nearby drones")
	container.queue_free()
	await get_tree().process_frame


func _fx_damage_mult(player: Player) -> float:
	var m := 1.0
	for fx in player.active_effects:
		if fx.has_method("damage_multiplier"):
			m *= float(fx.damage_multiplier(player))
	return m
