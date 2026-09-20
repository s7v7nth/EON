class_name HitVFX
extends RefCounted
## Impact dust / rust / blood using Kenney splat and spark sheets.


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
	_sprite_impact(world, global_pos, dir, damage_type, s)
	match damage_type:
		GameplayEnums.DamageType.ELECTRICITY:
			_burst(world, global_pos, dir, Color(0.55, 0.52, 0.38, 1), int(10 * s), 120.0 * s, 0.28, true, 1.1 * s)
		GameplayEnums.DamageType.CORROSION:
			_burst(world, global_pos, dir, Color(0.38, 0.45, 0.22, 1), int(10 * s), 100.0 * s, 0.32, false, 1.1 * s)
		GameplayEnums.DamageType.FIRE:
			_burst(world, global_pos, dir, Color(0.85, 0.32, 0.1, 1), int(12 * s), 120.0 * s, 0.32, true, 1.2 * s)
		GameplayEnums.DamageType.BLEED, GameplayEnums.DamageType.PHYSICAL:
			_burst(world, global_pos, dir, Color(0.45, 0.08, 0.08, 1), int(8 * s), 90.0 * s, 0.32, false, 0.9 * s)
			_burst(world, global_pos, dir, Color(0.22, 0.05, 0.04, 1), int(5 * s), 50.0 * s, 0.36, false, 0.85 * s)
		_:
			_burst(world, global_pos, dir, Color(0.55, 0.48, 0.38, 1), int(8 * s), 90.0 * s, 0.26, true, 1.0 * s)


static func spawn_optic_burst(
	world: Node,
	global_pos: Vector2,
	color: Color = Color(0.55, 0.9, 1.0, 1),
	impact_dir: Vector2 = Vector2.RIGHT,
	impact_scale: float = 1.0
) -> void:
	if world == null:
		return
	var dir: Vector2 = impact_dir.normalized() if impact_dir != Vector2.ZERO else Vector2.RIGHT
	var s: float = maxf(impact_scale, 0.4)
	_burst(world, global_pos, dir, color, int(16 * s), 150.0 * s, 0.32, true, 1.4 * s)
	_burst(world, global_pos, dir, Color(1, 1, 1, 1), int(8 * s), 110.0 * s, 0.22, true, 1.0 * s)


static func spawn_optic_ring(
	world: Node,
	origin: Vector2,
	color: Color = Color(0.55, 0.9, 1.0, 0.85),
	impact_scale: float = 1.0
) -> void:
	if world == null:
		return
	var ring := Polygon2D.new()
	ring.polygon = _circle_poly(8.0 * maxf(impact_scale, 0.5))
	ring.color = color
	ring.z_index = 29
	world.add_child(ring)
	ring.global_position = origin
	var tween := ring.create_tween()
	var end_scale := 3.4 * clampf(impact_scale, 0.6, 2.0)
	tween.tween_property(ring, "scale", Vector2(end_scale, end_scale), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.18)
	tween.tween_callback(ring.queue_free)


static func spawn_prism_explode(world: Node, origin: Vector2, color: Color = Color(0.75, 0.5, 1.0, 1)) -> void:
	if world == null:
		return
	spawn_optic_ring(world, origin, Color(color.r, color.g, color.b, 0.9), 1.6)
	_burst(world, origin, Vector2.UP, color, 22, 180.0, 0.4, true, 1.7)
	_burst(world, origin, Vector2.RIGHT, Color(1, 1, 1, 1), 12, 130.0, 0.28, true, 1.2)
	_sprite_impact(world, origin, Vector2.UP, GameplayEnums.DamageType.GLITCH, 1.4)


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


static func _sprite_impact(
	world: Node,
	origin: Vector2,
	dir: Vector2,
	damage_type: GameplayEnums.DamageType,
	impact_scale: float
) -> void:
	var stem := "smoke_08"
	var tint := Color(0.45, 0.38, 0.3, 1)
	match damage_type:
		GameplayEnums.DamageType.ELECTRICITY:
			stem = "spark_05"
			tint = Color(0.62, 0.55, 0.38, 1)
		GameplayEnums.DamageType.CORROSION:
			stem = "smoke_06"
			tint = Color(0.38, 0.45, 0.22, 1)
		GameplayEnums.DamageType.FIRE:
			stem = "flame_04"
			tint = Color(0.85, 0.38, 0.14, 1)
		GameplayEnums.DamageType.BLEED, GameplayEnums.DamageType.PHYSICAL:
			stem = "smoke_08"
			tint = Color(0.42, 0.12, 0.1, 1)
		_:
			stem = "smoke_01"
			tint = Color(0.5, 0.44, 0.36, 1)
	var tex := ArtBank.particle(stem)
	if tex == null:
		tex = ArtBank.particle("spark_01")
	if tex == null:
		return
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.modulate = tint
	spr.z_index = 31
	spr.centered = true
	spr.rotation = dir.angle()
	spr.scale = Vector2.ONE * (0.08 * impact_scale)
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	world.add_child(spr)
	spr.global_position = origin
	var tween := spr.create_tween()
	tween.tween_property(spr, "scale", Vector2.ONE * (0.14 * impact_scale), 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(spr, "modulate:a", 0.0, 0.22)
	tween.tween_callback(spr.queue_free)
	if damage_type == GameplayEnums.DamageType.PHYSICAL or damage_type == GameplayEnums.DamageType.BLEED:
		var splat_names := ["splat00", "splat01", "splat03", "splat05", "splat07"]
		var splat := ArtBank.tex("res://assets/kenney/splat/%s.png" % splat_names[randi() % splat_names.size()])
		if splat:
			var stain := Sprite2D.new()
			stain.texture = splat
			stain.modulate = Color(0.7, 0.08, 0.1, 0.7)
			stain.z_index = -4
			stain.centered = true
			stain.rotation = randf() * TAU
			stain.scale = Vector2.ONE * randf_range(0.22, 0.38) * impact_scale
			world.add_child(stain)
			stain.global_position = origin + Vector2(randf_range(-8, 8), randf_range(4, 14))
			var fade := stain.create_tween()
			fade.tween_interval(10.0)
			fade.tween_property(stain, "modulate:a", 0.0, 2.0)
			fade.tween_callback(stain.queue_free)


static func _circle_poly(radius: float) -> PackedVector2Array:
	var pts: PackedVector2Array = []
	var steps := 10
	for i in steps:
		var a := TAU * float(i) / float(steps)
		pts.append(Vector2(cos(a), sin(a)) * radius)
	return pts
