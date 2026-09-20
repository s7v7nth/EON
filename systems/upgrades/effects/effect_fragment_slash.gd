class_name EffectFragmentSlash
extends "res://systems/upgrades/upgrade_effect.gd"
## Neuro melee: on hit, fire short-range holo shard projectiles toward nearby foes.

const PROJECTILE_SCENE := preload("res://entities/projectiles/projectile.tscn")

@export var shard_count: int = 3
@export var shard_damage: float = 5.0
@export var shard_speed: float = 480.0
@export var shard_lifetime: float = 0.28
@export var search_radius: float = 160.0


func on_melee_hit(host: Node, target: Node) -> void:
	if host is not Node2D:
		return
	var parent := host.get_parent()
	if parent == null:
		return
	var origin := (host as Node2D).global_position
	var primary := target.get_parent() if target is HurtboxComponent else target
	var dirs: Array[Vector2] = []
	if primary is Node2D:
		var to_primary := ((primary as Node2D).global_position - origin)
		if to_primary != Vector2.ZERO:
			dirs.append(to_primary.normalized())
	for enemy in _enemies_near(host, search_radius):
		if enemy == primary:
			continue
		var to := ((enemy as Node2D).global_position - origin)
		if to == Vector2.ZERO:
			continue
		dirs.append(to.normalized())
		if dirs.size() >= shard_count:
			break
	while dirs.size() < shard_count:
		var angle := TAU * float(dirs.size()) / float(shard_count)
		dirs.append(Vector2.from_angle(angle))
	var attack := AttackData.new()
	attack.damage = shard_damage
	attack.projectile_speed = shard_speed
	attack.projectile_lifetime = shard_lifetime
	attack.returning = false
	attack.damage_type = GameplayEnums.DamageType.ELECTRICITY
	attack.status_chance = 0.45
	attack.status_power = 3.0
	attack.status_duration = 1.2
	for i in mini(shard_count, dirs.size()):
		var proj := PROJECTILE_SCENE.instantiate() as Projectile
		proj.attack_data = attack
		proj.direction = dirs[i]
		proj.source = host
		proj.tint = Color(0.72, 0.45, 1.0, 0.95)
		proj.collision_mask = (1 << 0) | (1 << 4)
		proj.max_mirror_bounces = 0
		parent.add_child(proj)
		proj.global_position = origin + dirs[i] * 18.0
