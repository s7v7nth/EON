extends SceneTree


func _initialize() -> void:
	var player_stats: CharacterStats = load("res://resources/stats/player_stats.tres") as CharacterStats
	var enemy_stats: CharacterStats = load("res://resources/stats/enemy_dummy_stats.tres") as CharacterStats
	var player_attack: AttackData = load("res://resources/attacks/player_basic_attack.tres") as AttackData
	var enemy_attack: AttackData = load("res://resources/attacks/enemy_dummy_attack.tres") as AttackData

	assert(player_stats != null and player_stats.max_health == 100.0)
	assert(enemy_stats != null and enemy_stats.max_health == 50.0)
	assert(player_attack != null and player_attack.damage == 10.0)
	assert(enemy_attack != null and enemy_attack.damage == 8.0)
	assert(player_stats.dash_cost == 25.0)
	assert(player_attack.active_duration == 0.15)

	print("TASK2_OK player_hp=", player_stats.max_health, " enemy_hp=", enemy_stats.max_health)
	print("TASK2_OK player_dmg=", player_attack.damage, " dash_cost=", player_stats.dash_cost)
	quit(0)
