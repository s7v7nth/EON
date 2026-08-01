extends SceneTree
## Hitbox/Hurtbox overlap smoke test for Task 4.


func _initialize() -> void:
	var world := Node2D.new()
	world.name = "CombatTest"
	root.add_child(world)

	var stats := CharacterStats.new()
	stats.max_health = 100.0

	var health := HealthComponent.new()
	health.stats = stats
	world.add_child(health)

	var hurtbox := HurtboxComponent.new()
	hurtbox.name = "Hurtbox"
	hurtbox.health_component = health
	hurtbox.collision_layer = 1 << 4 # enemy_hurtbox (layer 5)
	hurtbox.collision_mask = 0
	world.add_child(hurtbox)
	_add_circle(hurtbox, 16.0)

	var attack := AttackData.new()
	attack.damage = 10.0

	var hitbox := HitboxComponent.new()
	hitbox.name = "Hitbox"
	hitbox.attack_data = attack
	hitbox.collision_layer = 0
	hitbox.collision_mask = 1 << 4 # scan enemy_hurtbox
	world.add_child(hitbox)
	_add_circle(hitbox, 16.0)

	await process_frame
	await process_frame

	assert(is_equal_approx(health.current_health, 100.0))

	hitbox.activate()
	# Allow physics to detect overlap.
	await physics_frame
	await physics_frame
	await physics_frame

	assert(is_equal_approx(health.current_health, 90.0))

	# Same activation must not double-hit.
	await physics_frame
	assert(is_equal_approx(health.current_health, 90.0))

	hitbox.deactivate()
	hurtbox.set_invincible(true)

	hitbox.activate()
	await physics_frame
	await physics_frame
	assert(is_equal_approx(health.current_health, 90.0))

	hitbox.deactivate()
	hurtbox.set_invincible(false)

	hitbox.activate()
	await physics_frame
	await physics_frame
	assert(is_equal_approx(health.current_health, 80.0))

	print("TASK4_OK hitbox/hurtbox combat passed")
	quit(0)


func _add_circle(parent: Area2D, radius: float) -> void:
	var shape_node := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape_node.shape = circle
	parent.add_child(shape_node)
