extends Node
## Phase C smoke: UpgradeEffect plugins, loot parts, craft gating.


func _ready() -> void:
	await get_tree().process_frame
	await _run()


func _run() -> void:
	var catalog := load("res://resources/upgrades/upgrade_catalog.tres") as UpgradeCatalog
	assert(catalog != null)
	assert(catalog.all_upgrades().size() >= 6)
	assert(catalog.all_parts().size() >= 4)

	RunState.reset()
	RunState.choose_architecture(GameplayEnums.ArchitectureId.DEFAULT)
	# Counter needs magnet+servo from loot.
	assert(RunState.get_craftable_upgrades().is_empty() or not _has_upgrade(&"default_counter"))

	var magnet := load("res://resources/loot/rusty_magnet.tres") as LootPart
	var servo := load("res://resources/loot/servo_motor.tres") as LootPart
	RunState.grant_part(magnet)
	RunState.grant_part(servo)
	assert(RunState.owned_tags.has("magnet"))
	assert(RunState.owned_tags.has("servo"))
	assert(_has_upgrade(&"default_counter"))
	assert(_has_upgrade(&"default_parry_reactor"))

	var counter: UpgradeData = null
	for u in RunState.get_craftable_upgrades():
		if u.upgrade_id == &"default_counter":
			counter = u
			break
	assert(counter != null)
	assert(counter.effects.size() >= 1)
	assert(RunState.craft_upgrade(counter))

	var room: Node = load("res://levels/rooms/room_01.tscn").instantiate()
	add_child(room)
	await get_tree().process_frame
	var player: Player = room.get_node("Entities/Player") as Player
	RunState.apply_to_player(player)
	assert(player.active_effects.size() >= 1)
	# Counter effect should open window on perfect dodge.
	for effect in player.active_effects:
		var fx := effect as UpgradeEffect
		if fx:
			fx.on_perfect_dodge(player, null)
	assert(player.counter_window > 0.0)

	RunState.choose_architecture(GameplayEnums.ArchitectureId.NANOMACHINES)
	assert(_has_upgrade(&"nano_hookshot"))
	assert(_has_upgrade(&"nano_infect"))

	room.queue_free()
	RunState.reset()
	print("PHASE_C_OK upgrades + loot parts + craft")
	get_tree().quit(0)


func _has_upgrade(id: StringName) -> bool:
	for u in RunState.get_craftable_upgrades():
		if u and u.upgrade_id == id:
			return true
	return false
