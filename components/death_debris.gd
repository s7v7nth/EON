class_name DeathDebris
extends RefCounted
## Body shatter + blood puddles that linger on the arena floor.


static func burst(
	world: Node,
	origin: Vector2,
	body_color: Color = Color(0.7, 0.2, 0.25, 1),
	chunk_count: int = 12
) -> void:
	if world == null:
		return
	_spawn_blood_puddle(world, origin, body_color)
	_spawn_blood_spray(world, origin)
	_spawn_splat(world, origin)
	for _i in maxi(chunk_count, 4):
		_spawn_chunk(world, origin, body_color)


static func _spawn_blood_puddle(world: Node, origin: Vector2, body_color: Color) -> void:
	var puddle := Polygon2D.new()
	var radius: float = randf_range(18.0, 34.0)
	puddle.polygon = _blob_poly(radius)
	puddle.color = Color(
		lerpf(0.45, body_color.r, 0.35),
		lerpf(0.02, body_color.g, 0.15),
		lerpf(0.05, body_color.b, 0.15),
		0.85
	)
	puddle.z_index = -5
	puddle.z_as_relative = false
	world.add_child(puddle)
	puddle.global_position = origin + Vector2(randf_range(-6, 6), randf_range(2, 10))
	puddle.rotation = randf() * TAU
	puddle.scale = Vector2(0.2, 0.2)
	var tween := puddle.create_tween()
	tween.tween_property(puddle, "scale", Vector2(1.0, 0.72), 0.18)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Linger, then slowly fade so arenas don't fill forever.
	tween.tween_interval(18.0)
	tween.tween_property(puddle, "modulate:a", 0.0, 2.5)
	tween.tween_callback(puddle.queue_free)


static func _spawn_splat(world: Node, origin: Vector2) -> void:
	var names := ["splat00", "splat01", "splat03", "splat05"]
	var tex := ArtBank.tex("res://assets/kenney/splat/%s.png" % names[randi() % names.size()])
	if tex == null:
		tex = ArtBank.particle("smoke_08")
	if tex == null:
		return
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.centered = true
	spr.z_index = -5
	spr.modulate = Color(0.55, 0.08, 0.1, 0.75)
	spr.rotation = randf() * TAU
	spr.scale = Vector2.ONE * randf_range(0.16, 0.28)
	world.add_child(spr)
	spr.global_position = origin + Vector2(randf_range(-6, 6), randf_range(2, 10))
	var tw := spr.create_tween()
	tw.tween_interval(16.0)
	tw.tween_property(spr, "modulate:a", 0.0, 2.4)
	tw.tween_callback(spr.queue_free)


static func _spawn_blood_spray(world: Node, origin: Vector2) -> void:
	for _i in 18:
		var drop := Polygon2D.new()
		var s: float = randf_range(1.5, 4.0)
		drop.polygon = PackedVector2Array([
			Vector2(s, 0), Vector2(-s * 0.5, -s * 0.6), Vector2(-s * 0.2, 0), Vector2(-s * 0.5, s * 0.6)
		])
		drop.color = Color(0.65, 0.05, 0.1, 1)
		drop.z_index = 8
		world.add_child(drop)
		drop.global_position = origin + Vector2(0, -18)
		var dir: Vector2 = Vector2.from_angle(randf() * TAU)
		var dist: float = randf_range(30.0, 110.0)
		var end_pos: Vector2 = origin + dir * dist + Vector2(0, randf_range(10, 40))
		var life: float = randf_range(0.25, 0.55)
		var tween := drop.create_tween()
		tween.tween_property(drop, "global_position", end_pos, life)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(drop, "modulate:a", 0.55, life)
		# Stick as a stain.
		tween.tween_callback(func() -> void:
			drop.z_index = -4
			drop.color.a = 0.7
		)
		tween.tween_interval(14.0)
		tween.tween_property(drop, "modulate:a", 0.0, 2.0)
		tween.tween_callback(drop.queue_free)


static func _spawn_chunk(world: Node, origin: Vector2, body_color: Color) -> void:
	var chunk := Polygon2D.new()
	var s: float = randf_range(4.0, 10.0)
	chunk.polygon = PackedVector2Array([
		Vector2(s, 0),
		Vector2(s * 0.2, -s * 0.8),
		Vector2(-s * 0.7, -s * 0.3),
		Vector2(-s * 0.5, s * 0.6),
		Vector2(s * 0.3, s * 0.5)
	])
	chunk.color = Color(
		clampf(body_color.r + randf_range(-0.1, 0.1), 0, 1),
		clampf(body_color.g + randf_range(-0.08, 0.08), 0, 1),
		clampf(body_color.b + randf_range(-0.08, 0.08), 0, 1),
		1
	)
	chunk.z_index = 6
	world.add_child(chunk)
	chunk.global_position = origin + Vector2(0, -20)
	chunk.rotation = randf() * TAU
	var dir: Vector2 = Vector2.from_angle(randf_range(-PI, 0.0)) # mostly outward/up
	var speed: float = randf_range(90.0, 260.0)
	var air: float = randf_range(0.18, 0.4)
	var peak: Vector2 = chunk.global_position + dir * speed * air + Vector2(0, -randf_range(20, 70))
	var land: Vector2 = origin + Vector2(randf_range(-70, 70), randf_range(4, 28))
	var tween := chunk.create_tween()
	tween.tween_property(chunk, "global_position", peak, air)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(chunk, "rotation", chunk.rotation + randf_range(-4, 4), air)
	tween.tween_property(chunk, "global_position", land, air * 1.1)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(chunk, "rotation", chunk.rotation + randf_range(-2, 2), air * 1.1)
	tween.tween_callback(func() -> void:
		chunk.z_index = -3
	)
	tween.tween_interval(22.0)
	tween.tween_property(chunk, "modulate:a", 0.0, 2.5)
	tween.tween_callback(chunk.queue_free)


static func _blob_poly(radius: float) -> PackedVector2Array:
	var pts: PackedVector2Array = []
	var steps := 10
	for i in steps:
		var a: float = TAU * float(i) / float(steps)
		var r: float = radius * randf_range(0.7, 1.15)
		pts.append(Vector2(cos(a), sin(a) * 0.55) * r)
	return pts
