extends Node
## Step D smoke: architecture kit equips primary/secondary from first primitive.


func _ready() -> void:
	await get_tree().process_frame
	await _run()


func _run() -> void:
	RunState.reset()
	RunState.choose_architecture(GameplayEnums.ArchitectureId.DEFAULT)
	var arena_packed: PackedScene = load("res://levels/arena/arena.tscn")
	var arena: Node = arena_packed.instantiate()
	add_child(arena)
	await get_tree().process_frame

	var player: Player = arena.get_node("Entities/Player") as Player
	RunState.apply_to_player(player)
	# One kit per architecture: LMB primary + RMB secondary.
	assert(player.weapons.size() == 1)
	assert(player.weapons[0] != null)
	assert(player.hitbox.attack_data != null)
	assert(player.ranged_attack_data != null)
	assert(player.active_economy != null)
	assert(player.active_economy.policy == GameplayEnums.EconomyPolicy.ENERGY_ADRENALINE)

	print("STEP_D_OK architecture kit + economy")
	get_tree().quit(0)
