extends Node
## Combat review smokes: AttackData hit-stop, cone magnet, buffers, collisions.


func _ready() -> void:
	await get_tree().process_frame
	await _run()


func _run() -> void:
	_assert_hit_stop()
	_assert_buffer()
	_assert_health_fuel()
	_assert_collisions()
	await _assert_aim_lock()
	print("COMBAT_FEEL_OK")
	get_tree().quit(0)


func _assert_hit_stop() -> void:
	var atk := load("res://resources/attacks/player_basic_attack.tres") as AttackData
	assert(atk != null)
	assert(atk.hit_stop_duration <= 0.045)
	var swarm: Dictionary = CombatImpact.juice_params(10.0, 22.0, atk, false)
	## Authored 0.04s * mild boost — never the old 0.13s+ victim-HP freeze.
	assert(float(swarm.dur) <= atk.hit_stop_duration * 1.51 + 0.0001)
	assert(float(swarm.dur) >= atk.hit_stop_duration * 0.99)
	var dummy: Dictionary = CombatImpact.juice_params(10.0, 50.0, atk, false)
	assert(float(dummy.dur) < 0.10)
	var you: Dictionary = CombatImpact.juice_params(10.0, 100.0, atk, true)
	assert(float(you.dur) < float(dummy.dur))
	assert(float(you.ts) > float(dummy.ts))
	var finisher := load("res://resources/attacks/player_basic_attack_3.tres") as AttackData
	var hard: Dictionary = CombatImpact.juice_params(18.0, 50.0, finisher, false)
	assert(float(hard.dur) >= finisher.hit_stop_duration * 0.99)


func _assert_buffer() -> void:
	var buf := InputBuffer.new()
	buf.name = "TestBuffer"
	add_child(buf)
	buf.buffer(&"attack")
	assert(buf.peek(&"attack"))
	assert(buf.consume(&"attack"))
	assert(not buf.consume(&"attack"))
	buf.queue_free()


func _assert_health_fuel() -> void:
	var stats := load("res://resources/stats/player_stats.tres") as CharacterStats
	var hp := HealthComponent.new()
	hp.stats = stats
	add_child(hp)
	await get_tree().process_frame
	var before := hp.current_health
	hp.spend_as_fuel(12.0, 8.0)
	assert(hp.last_reason == &"fuel")
	assert(hp.current_health < before)
	hp.heal(4.0)
	assert(hp.last_reason == &"heal")
	hp.take_damage(3.0)
	assert(hp.last_reason == &"hurt")
	hp.queue_free()


func _assert_collisions() -> void:
	var enemy_ps: PackedScene = load("res://entities/enemies/dummy/enemy_dummy.tscn")
	var player_ps: PackedScene = load("res://entities/player/player.tscn")
	var enemy := enemy_ps.instantiate() as CharacterBody2D
	var player := player_ps.instantiate() as CharacterBody2D
	assert(enemy.collision_layer == 4)
	assert(enemy.collision_mask == 7)
	assert(player.collision_layer == 2)
	assert(player.collision_mask == 5)
	enemy.free()
	player.free()


func _assert_aim_lock() -> void:
	var packed: PackedScene = load("res://entities/player/player.tscn")
	var player: Player = packed.instantiate() as Player
	add_child(player)
	await get_tree().process_frame
	player.lock_aim(Vector2.LEFT)
	assert(player.get_aim_direction().x < -0.9)
	player.unlock_aim()
	player.queue_free()
