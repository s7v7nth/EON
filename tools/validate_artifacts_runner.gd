extends Node
## Smoke: 36+ distinct artifacts, 3-card rolls, grants, combos, class select scene.


func _ready() -> void:
	await get_tree().process_frame
	await _run()


func _run() -> void:
	RunState.reset()
	RunState.choose_architecture(GameplayEnums.ArchitectureId.DEFAULT)
	var library := ArtifactLibrary.all_boons()
	assert(library.size() >= 36, "library must have 36+ boons, got %s" % library.size())
	var ids: Dictionary = {}
	for boon in library:
		assert(boon != null)
		assert(boon.upgrade_id != &"")
		assert(boon.display_name != "")
		assert(boon.description != "")
		assert(boon.any_architecture)
		assert(boon.reward_offerable)
		assert(not boon.effects.is_empty(), "%s needs an effect" % boon.upgrade_id)
		assert(not ids.has(boon.upgrade_id), "duplicate id %s" % boon.upgrade_id)
		ids[boon.upgrade_id] = true

	var pool := RunState.get_reward_upgrades()
	assert(pool.size() >= 36, "run pool should include shared boons, got %s" % pool.size())

	var offers := RunState.roll_boon_offers(3)
	assert(offers.size() == 3)
	assert(offers[0].upgrade_id != offers[1].upgrade_id)
	assert(offers[1].upgrade_id != offers[2].upgrade_id)

	var first := offers[0]
	assert(RunState.grant_upgrade(first))
	assert(RunState._already_crafted(first.upgrade_id))
	assert(not RunState.grant_upgrade(first))

	# Combos: Bloodletter + Executioner's Eye → Mercy Kill
	var blood := _from_lib(&"bloodletter")
	var eye := _from_lib(&"executioners_eye")
	assert(blood and eye)
	assert(RunState.grant_upgrade(blood) or RunState._already_crafted(&"bloodletter"))
	assert(RunState.grant_upgrade(eye) or RunState._already_crafted(&"executioners_eye"))
	assert(RunState.unlocked_combos.has(&"mercy_kill") or RunState._already_crafted(&"mercy_kill"), "Mercy Kill combo should unlock")

	var player: Player = (load("res://entities/player/player.tscn") as PackedScene).instantiate() as Player
	add_child(player)
	await get_tree().process_frame
	RunState.apply_to_player(player)
	assert(player.crit_chance >= 0.0)
	assert(player.execute_threshold >= 0.25)
	player.add_max_health(25.0)
	assert(player.health.get_max_health() >= 125.0)

	var select: PackedScene = load("res://ui/class_select.tscn") as PackedScene
	assert(select != null)
	var boot := select.instantiate()
	add_child(boot)
	await get_tree().process_frame
	assert(boot.get_child_count() > 0)

	print("ARTIFACTS_OK count=%s offers=%s combo=%s" % [
		library.size(), offers.size(), RunState.last_combo_name
	])
	get_tree().quit(0)


func _from_lib(id: StringName) -> UpgradeData:
	for item in ArtifactLibrary.all_boons():
		if item.upgrade_id == id:
			return item
	return null
