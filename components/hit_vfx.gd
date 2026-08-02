class_name HitVFX
extends RefCounted
## Greybox hit feedback — dense blood / sparks / acid flecks.


static func spawn_at(
	world: Node,
	global_pos: Vector2,
	damage_type: GameplayEnums.DamageType = GameplayEnums.DamageType.PHYSICAL,
	impact_dir: Vector2 = Vector2.RIGHT,
	impact_scale: float = 1.0
) -> void:
	if world == null:
		return
	var dir: Vector2 = impact_dir.normalized() if impact_dir != Vector2.ZERO else Vector2.RIGHT
	var s: float = maxf(impact_scale, 0.35)
	_flash_ring(world, global_pos, damage_type, s)
	match damage_type:
		GameplayEnums.DamageType.ELECTRICITY:
			_burst(world, global_pos, dir, Color(0.45, 0.9, 1.0, 1), int(22 * s), 160.0 * s, 0.38, true, 1.6 * s)
			_burst(world, global_pos, dir, Color(1.0, 1.0, 1.0, 1), int(12 * s), 120.0 * s, 0.28, true, 1.1 * s)
		GameplayEnums.DamageType.CORROSION:
			_burst(world, global_pos, dir, Color(0.4, 0.95, 0.25, 1), int(20 * s), 130.0 * s, 0.45, false, 1.7 * s)
			_burst(world, global_pos, dir, Color(0.7, 1.0, 0.35, 1), int(10 * s), 80.0 * s, 0.35, false, 1.2 * s)
		GameplayEnums.DamageType.FIRE:
			_burst(world, global_pos, dir, Color(1.0, 0.4, 0.1, 1), int(20 * s), 140.0 * s, 0.4, true, 1.7 * s)
			_burst(world, global_pos, dir, Color(1.0, 0.85, 0.25, 1), int(12 * s), 100.0 * s, 0.3, true, 1.2 * s)
		GameplayEnums.DamageType.BLEED, GameplayEnums.DamageType.PHYSICAL:
			_burst(world, global_pos, dir, Color(0.7, 0.05, 0.1, 1), int(26 * s), 180.0 * s, 0.5, false, 2.0 * s)
			_burst(world, global_pos, dir, Color(0.95, 0.15, 0.2, 1), int(16 * s), 120.0 * s, 0.38, false, 1.5 * s)
			_burst(world, global_pos, dir, Color(0.45, 0.02, 0.06, 1), int(10 * s), 70.0 * s, 0.55, false, 1.8 * s)
		_:
			_burst(world, global_pos, dir, Color(0.9, 0.92, 1.0, 1), int(16 * s), 120.0 * s, 0.32, true, 1.4 * s)


static func _flash_ring(
	world: Node,
	origin: Vector2,
	damage_type: GameplayEnums.DamageType,
	impact_scale: float = 1.0
) -> void:
	var col := Color(1, 1, 1, 0.85)
	match damage_type:
		GameplayEnums.DamageType.ELECTRICITY:
			col = Color(0.55, 0.95, 1.0, 0.9)
		GameplayEnums.DamageType.CORROSION:
			col = Color(0.5, 1.0, 0.35, 0.85)
		GameplayEnums.DamageType.FIRE:
			col = Color(1.0, 0.55, 0.2, 0.9)
		GameplayEnums.DamageType.BLEED, GameplayEnums.DamageType.PHYSICAL:
			col = Color(0.95, 0.2, 0.25, 0.8)
	var ring := Polygon2D.new()
	ring.polygon = _circle_poly(10.0 * impact_scale)
	ring.color = col
	ring.z_index = 29
	world.add_child(ring)
	ring.global_position = origin
	var tween := ring.create_tween()
	var end_scale := 3.2 * clampf(impact_scale, 0.7, 1.8)
	tween.tween_property(ring, "scale", Vector2(end_scale, end_scale), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.16)
	tween.tween_callback(ring.queue_free)


static func _burst(
	world: Node,
	origin: Vector2,
	base_dir: Vector2,
	color: Color,
	count: int,
	speed: float,
	lifetime: float,
	sparks: bool,
	size_mult: float
) -> void:
	for _i in maxi(count, 1):
		var shard := Polygon2D.new()
		var s := size_mult * randf_range(0.85, 1.35)
		if sparks:
			shard.polygon = PackedVector2Array([
				Vector2(7 * s, 0),
				Vector2(-3 * s, -2.2 * s),
				Vector2(-1.5 * s, 0),
				Vector2(-3 * s, 2.2 * s)
			])
		else:
			shard.polygon = PackedVector2Array([
				Vector2(6 * s, 0),
				Vector2(-3 * s, -4 * s),
				Vector2(-1.5 * s, 0),
				Vector2(-3 * s, 4 * s)
			])
		shard.color = Color(color.r, color.g, color.b, 1.0)
		shard.z_index = 30
		world.add_child(shard)
		shard.global_position = origin + Vector2(randf_range(-4, 4), randf_range(-6, 2))
		var spread := randf_range(-1.15, 1.15)
		var vel := base_dir.rotated(spread) * randf_range(speed * 0.4, speed)
		# Extra upward kick so sprays read clearly against the floor.
		vel += Vector2(randf_range(-35, 35), randf_range(-90, -25))
		shard.rotation = vel.angle()
		var fade := lifetime * randf_range(0.75, 1.25)
		var end_pos := origin + vel * fade + Vector2(0, 40.0 * fade * fade)
		var tween := shard.create_tween()
		tween.tween_property(shard, "global_position", end_pos, fade)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(shard, "modulate:a", 0.0, fade)
		tween.parallel().tween_property(shard, "scale", Vector2(0.2, 0.2), fade)
		tween.parallel().tween_property(shard, "rotation", shard.rotation + randf_range(-2.5, 2.5), fade)
		tween.tween_callback(shard.queue_free)


static func _circle_poly(radius: float) -> PackedVector2Array:
	var pts: PackedVector2Array = []
	var steps := 10
	for i in steps:
		var a := TAU * float(i) / float(steps)
		pts.append(Vector2(cos(a), sin(a)) * radius)
	return pts
