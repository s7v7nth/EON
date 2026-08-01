extends SceneTree
## Isolated component smoke test for Task 3.


func _initialize() -> void:
	var root := Node.new()
	root.name = "TestRoot"
	root.set_process(true)
	self.root.add_child(root)

	var stats := CharacterStats.new()
	stats.max_health = 100.0
	stats.max_energy = 100.0
	stats.energy_regen_rate = 20.0
	stats.max_adrenaline = 100.0
	stats.adrenaline_decay_delay = 0.1
	stats.adrenaline_decay_rate = 100.0

	var health := HealthComponent.new()
	health.name = "Health"
	health.stats = stats
	root.add_child(health)

	var energy := EnergyComponent.new()
	energy.name = "Energy"
	energy.stats = stats
	root.add_child(energy)

	var adrenaline := AdrenalineComponent.new()
	adrenaline.name = "Adrenaline"
	adrenaline.stats = stats
	adrenaline.energy_component = energy
	root.add_child(adrenaline)

	# Wait one frame so _ready runs.
	await process_frame

	assert(is_equal_approx(health.current_health, 100.0))
	health.take_damage(30.0)
	assert(is_equal_approx(health.current_health, 70.0))

	assert(energy.try_spend(40.0))
	assert(is_equal_approx(energy.current_energy, 60.0))
	assert(not energy.try_spend(100.0))

	adrenaline.add(80.0)
	assert(is_equal_approx(energy.regen_multiplier, 2.5))

	var energy_before := energy.current_energy
	await create_timer(0.2).timeout
	assert(energy.current_energy > energy_before)

	# Let decay delay + decay clear adrenaline.
	await create_timer(1.2).timeout
	assert(energy.regen_multiplier <= 1.0 + 0.01)
	assert(adrenaline.current_adrenaline <= 0.01)

	var died_flag: Array = [false]
	health.died.connect(func() -> void: died_flag[0] = true)
	health.take_damage(999.0)
	assert(died_flag[0])
	assert(is_equal_approx(health.current_health, 0.0))

	print("TASK3_OK health/energy/adrenaline components passed")
	quit(0)
