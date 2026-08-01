extends Node
## Step D smoke: weapon equip swaps primary/secondary and reach.


func _ready() -> void:
	await get_tree().process_frame
	await _run()


func _run() -> void:
	var arena_packed: PackedScene = load("res://levels/arena/arena.tscn")
	var arena: Node = arena_packed.instantiate()
	add_child(arena)
	await get_tree().process_frame

	var player: Player = arena.get_node("Entities/Player") as Player
	assert(player.weapons.size() == 3)
	assert(player.current_weapon_name() == "Blade")
	assert(player.hitbox.attack_data.damage == 10.0)

	player.equip_weapon(1)
	assert(player.current_weapon_name() == "Hammer")
	assert(player.hitbox.attack_data.damage == 22.0)
	assert(is_equal_approx(player.hitbox.position.x, 30.0))
	assert(player.ranged_attack_data != null)

	player.equip_weapon(2)
	assert(player.current_weapon_name() == "Bow")
	assert(player.hitbox.attack_data.damage == 4.0)
	assert(player.ranged_attack_data.projectile_speed > 800.0)

	var hud := arena.get_node("DebugHUD")
	var label: Label = hud.get_node("Margin/VBox/WeaponLabel")
	assert(label.text.contains("Bow"))

	print("STEP_D_OK weapons Blade/Hammer/Bow")
	get_tree().quit(0)
