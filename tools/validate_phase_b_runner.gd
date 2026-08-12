extends Node
## Phase B smoke: buildup procs, glitch status, acid+shock synergy.


func _ready() -> void:
	await get_tree().process_frame
	await _run()


func _run() -> void:
	var catalog := load("res://resources/statuses/status_catalog.tres") as StatusCatalog
	assert(catalog != null)
	assert(catalog.get_definition(&"burn") != null)
	assert(catalog.get_definition(&"glitch") != null)
	assert(catalog.status_id_for_damage_type(GameplayEnums.DamageType.FIRE) == &"burn")
	assert(catalog.all_synergies().size() >= 1)

	var host := Node2D.new()
	host.name = "StatusHost"
	add_child(host)

	var health := HealthComponent.new()
	health.name = "HealthComponent"
	var stats := CharacterStats.new()
	stats.max_health = 200.0
	health.stats = stats
	host.add_child(health)
	host.set("health", health)

	var status := StatusComponent.new()
	status.name = "StatusComponent"
	status.health_component = health
	host.add_child(status)
	host.set("status", status)
	await get_tree().process_frame

	status.add_buildup(&"burn", 50.0, 5.0)
	assert(not status.has_status(&"burn"))
	assert(status.get_buildup_ratio(&"burn") > 0.0)

	status.add_buildup(&"burn", 60.0, 5.0)
	assert(status.has_status(&"burn"))
	assert(host.get_meta("panicking", false) == true)

	status.clear_all()
	status.apply_status(&"acid", 6.0, 2.0)
	status.apply_status(&"shock", 6.0, 2.0)
	await get_tree().process_frame
	# Synergy consumes both and fires cascade.
	assert(not status.has_status(&"acid") or not status.has_status(&"shock"))

	status.clear_all()
	status.add_buildup(&"glitch", 120.0, 5.0)
	assert(status.has_status(&"glitch"))
	assert(host.get_meta("glitched", false) == true)

	print("PHASE_B_OK statuses + synergy + glitch")
	get_tree().quit(0)
