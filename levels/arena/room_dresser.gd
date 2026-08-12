class_name RoomDresser
extends RefCounted
## Runtime floor/wall dressing + doorway carving for arena templates.


static func dress(arena: Node2D, biome: BiomeDefinition) -> void:
	if arena == null or biome == null:
		return
	_clear_named(arena, "Dressing")
	var root := Node2D.new()
	root.name = "Dressing"
	root.z_index = -15
	arena.add_child(root)

	var floor_c := biome.get_floor_color()
	var wall_c := biome.get_wall_color()
	var accent := _biome_accent(biome)

	_add_floor_grid(root, floor_c, accent)
	_add_corner_trims(root, wall_c, accent)
	_add_neon_rails(root, accent)
	_add_center_decal(root, accent, biome)
	_add_ambient_orbs(root, accent, biome)


static func carve_doorways(arena: Node2D, door_dirs: Array[Vector2i]) -> void:
	if arena == null:
		return
	var gap := 96.0
	var walls := arena.get_node_or_null("Walls") as StaticBody2D
	var visuals := arena.get_node_or_null("WallVisuals") as Node2D
	if walls:
		_rebuild_wall_collisions(walls, door_dirs, gap)
	if visuals:
		_rebuild_wall_visuals(visuals, door_dirs, gap)


static func _clear_named(arena: Node2D, node_name: String) -> void:
	var existing := arena.get_node_or_null(node_name)
	if existing:
		existing.free()


static func _biome_accent(biome: BiomeDefinition) -> Color:
	match biome.biome_id:
		GameplayEnums.BiomeId.DATA_CENTER, GameplayEnums.BiomeId.GATEWAY:
			return Color(0.35, 0.85, 1.0, 0.55)
		GameplayEnums.BiomeId.LANDFILL, GameplayEnums.BiomeId.WASTELAND:
			return Color(0.55, 0.9, 0.35, 0.45)
		GameplayEnums.BiomeId.JUNGLE, GameplayEnums.BiomeId.TAIGA:
			return Color(0.35, 0.75, 0.45, 0.45)
		GameplayEnums.BiomeId.DOWNTOWN, GameplayEnums.BiomeId.MALL, GameplayEnums.BiomeId.ALLEY:
			return Color(0.95, 0.55, 0.25, 0.45)
		GameplayEnums.BiomeId.RESIDENTIAL:
			return Color(0.7, 0.55, 0.95, 0.45)
		_:
			return Color(0.5, 0.75, 0.95, 0.4)


static func _add_poly(parent: Node2D, pts: PackedVector2Array, color: Color, z: int = 0) -> void:
	var p := Polygon2D.new()
	p.polygon = pts
	p.color = color
	p.z_index = z
	parent.add_child(p)


static func _add_floor_grid(root: Node2D, floor_c: Color, accent: Color) -> void:
	var line := Color(accent.r, accent.g, accent.b, 0.08)
	var panel := floor_c.lightened(0.04)
	panel.a = 0.35
	# Soft panels
	for ix in range(-2, 3):
		for iy in range(-1, 2):
			if (ix + iy) % 2 == 0:
				continue
			var cx := float(ix) * 280.0
			var cy := float(iy) * 220.0
			_add_poly(root, PackedVector2Array([
				Vector2(cx - 120, cy - 90), Vector2(cx + 120, cy - 90),
				Vector2(cx + 120, cy + 90), Vector2(cx - 120, cy + 90)
			]), panel, -1)
	# Grid lines (thin polys)
	for x in range(-700, 701, 140):
		_add_poly(root, PackedVector2Array([
			Vector2(x - 1, -420), Vector2(x + 1, -420),
			Vector2(x + 1, 420), Vector2(x - 1, 420)
		]), line)
	for y in range(-390, 391, 130):
		_add_poly(root, PackedVector2Array([
			Vector2(-760, y - 1), Vector2(760, y - 1),
			Vector2(760, y + 1), Vector2(-760, y + 1)
		]), line)


static func _add_corner_trims(root: Node2D, wall_c: Color, accent: Color) -> void:
	var trim := wall_c.lightened(0.15)
	trim.a = 0.85
	var glow := Color(accent.r, accent.g, accent.b, 0.35)
	var corners := [
		Vector2(-760, -410), Vector2(760, -410),
		Vector2(-760, 410), Vector2(760, 410)
	]
	for c in corners:
		var sx := -1.0 if c.x < 0.0 else 1.0
		var sy := -1.0 if c.y < 0.0 else 1.0
		_add_poly(root, PackedVector2Array([
			c, c + Vector2(70 * sx, 0), c + Vector2(70 * sx, 10 * sy), c + Vector2(10 * sx, 10 * sy),
			c + Vector2(10 * sx, 70 * sy), c + Vector2(0, 70 * sy)
		]), trim, 1)
		_add_poly(root, PackedVector2Array([
			c + Vector2(4 * sx, 4 * sy),
			c + Vector2(40 * sx, 4 * sy),
			c + Vector2(4 * sx, 40 * sy)
		]), glow, 2)


static func _add_neon_rails(root: Node2D, accent: Color) -> void:
	var rail := Color(accent.r, accent.g, accent.b, 0.22)
	_add_poly(root, PackedVector2Array([
		Vector2(-740, -400), Vector2(740, -400), Vector2(740, -394), Vector2(-740, -394)
	]), rail, 1)
	_add_poly(root, PackedVector2Array([
		Vector2(-740, 394), Vector2(740, 394), Vector2(740, 400), Vector2(-740, 400)
	]), rail, 1)
	_add_poly(root, PackedVector2Array([
		Vector2(-760, -380), Vector2(-754, -380), Vector2(-754, 380), Vector2(-760, 380)
	]), rail, 1)
	_add_poly(root, PackedVector2Array([
		Vector2(754, -380), Vector2(760, -380), Vector2(760, 380), Vector2(754, 380)
	]), rail, 1)


static func _add_center_decal(root: Node2D, accent: Color, biome: BiomeDefinition) -> void:
	var ring := Color(accent.r, accent.g, accent.b, 0.18)
	var inner := biome.get_floor_color().darkened(0.08)
	inner.a = 0.55
	_add_poly(root, _ring_poly(70.0, 84.0), ring, 0)
	_add_poly(root, _diamond(48.0), inner, 0)
	if biome.biome_id == GameplayEnums.BiomeId.GATEWAY or biome.biome_id == GameplayEnums.BiomeId.DATA_CENTER:
		_add_poly(root, _diamond(22.0), Color(accent.r, accent.g, accent.b, 0.35), 1)


static func _add_ambient_orbs(root: Node2D, accent: Color, biome: BiomeDefinition) -> void:
	var spots := [
		Vector2(-420, -220), Vector2(480, -180), Vector2(-360, 240),
		Vector2(420, 210), Vector2(0, -280), Vector2(200, 300)
	]
	var count := 4
	if biome.biome_id == GameplayEnums.BiomeId.DATA_CENTER:
		count = 6
	for i in count:
		var p: Vector2 = spots[i % spots.size()]
		var orb := Polygon2D.new()
		orb.polygon = _diamond(10.0 + float(i % 3) * 3.0)
		orb.position = p
		orb.color = Color(accent.r, accent.g, accent.b, 0.2)
		orb.z_index = 2
		root.add_child(orb)


static func _diamond(r: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0, -r), Vector2(r * 0.75, 0), Vector2(0, r), Vector2(-r * 0.75, 0)
	])


static func _ring_poly(inner_r: float, outer_r: float) -> PackedVector2Array:
	var pts: PackedVector2Array = []
	var steps := 16
	for i in steps:
		var a := TAU * float(i) / float(steps)
		pts.append(Vector2(cos(a), sin(a)) * outer_r)
	for i in range(steps - 1, -1, -1):
		var a := TAU * float(i) / float(steps)
		pts.append(Vector2(cos(a), sin(a)) * inner_r)
	return pts


static func _rebuild_wall_collisions(walls: StaticBody2D, door_dirs: Array[Vector2i], gap: float) -> void:
	for child in walls.get_children():
		child.free()
	var half_gap := gap * 0.5
	# Outer bounds match room templates (±800×±450 floor, walls just outside).
	_add_h_wall_segments(walls, -475.0, door_dirs.has(Vector2i(0, -1)), half_gap) # North
	_add_h_wall_segments(walls, 475.0, door_dirs.has(Vector2i(0, 1)), half_gap) # South
	_add_v_wall_segments(walls, -825.0, door_dirs.has(Vector2i(-1, 0)), half_gap) # West
	_add_v_wall_segments(walls, 825.0, door_dirs.has(Vector2i(1, 0)), half_gap) # East


static func _add_h_wall_segments(walls: StaticBody2D, y: float, open: bool, half_gap: float) -> void:
	if not open:
		_add_rect_shape(walls, Vector2(0, y), Vector2(1600, 40))
		return
	var left_w := 800.0 - half_gap
	var right_w := 800.0 - half_gap
	_add_rect_shape(walls, Vector2(-(half_gap + left_w * 0.5), y), Vector2(left_w, 40))
	_add_rect_shape(walls, Vector2(half_gap + right_w * 0.5, y), Vector2(right_w, 40))


static func _add_v_wall_segments(walls: StaticBody2D, x: float, open: bool, half_gap: float) -> void:
	if not open:
		_add_rect_shape(walls, Vector2(x, 0), Vector2(40, 900))
		return
	var top_h := 450.0 - half_gap
	var bot_h := 450.0 - half_gap
	_add_rect_shape(walls, Vector2(x, -(half_gap + top_h * 0.5)), Vector2(40, top_h))
	_add_rect_shape(walls, Vector2(x, half_gap + bot_h * 0.5), Vector2(40, bot_h))


static func _add_rect_shape(walls: StaticBody2D, pos: Vector2, size: Vector2) -> void:
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	cs.shape = rect
	cs.position = pos
	walls.add_child(cs)


static func _rebuild_wall_visuals(visuals: Node2D, door_dirs: Array[Vector2i], gap: float) -> void:
	for child in visuals.get_children():
		child.free()
	var wall_color := Color(0.12, 0.13, 0.14, 1)
	var half_gap := gap * 0.5
	# North strip
	if door_dirs.has(Vector2i(0, -1)):
		_add_poly(visuals, PackedVector2Array([
			Vector2(-800, -450), Vector2(-half_gap, -450), Vector2(-half_gap, -425), Vector2(-800, -425)
		]), wall_color)
		_add_poly(visuals, PackedVector2Array([
			Vector2(half_gap, -450), Vector2(800, -450), Vector2(800, -425), Vector2(half_gap, -425)
		]), wall_color)
	else:
		_add_poly(visuals, PackedVector2Array([
			Vector2(-800, -450), Vector2(800, -450), Vector2(800, -425), Vector2(-800, -425)
		]), wall_color)
	# South
	if door_dirs.has(Vector2i(0, 1)):
		_add_poly(visuals, PackedVector2Array([
			Vector2(-800, 425), Vector2(-half_gap, 425), Vector2(-half_gap, 450), Vector2(-800, 450)
		]), wall_color)
		_add_poly(visuals, PackedVector2Array([
			Vector2(half_gap, 425), Vector2(800, 425), Vector2(800, 450), Vector2(half_gap, 450)
		]), wall_color)
	else:
		_add_poly(visuals, PackedVector2Array([
			Vector2(-800, 425), Vector2(800, 425), Vector2(800, 450), Vector2(-800, 450)
		]), wall_color)
	# West
	if door_dirs.has(Vector2i(-1, 0)):
		_add_poly(visuals, PackedVector2Array([
			Vector2(-800, -450), Vector2(-775, -450), Vector2(-775, -half_gap), Vector2(-800, -half_gap)
		]), wall_color)
		_add_poly(visuals, PackedVector2Array([
			Vector2(-800, half_gap), Vector2(-775, half_gap), Vector2(-775, 450), Vector2(-800, 450)
		]), wall_color)
	else:
		_add_poly(visuals, PackedVector2Array([
			Vector2(-800, -450), Vector2(-775, -450), Vector2(-775, 450), Vector2(-800, 450)
		]), wall_color)
	# East
	if door_dirs.has(Vector2i(1, 0)):
		_add_poly(visuals, PackedVector2Array([
			Vector2(775, -450), Vector2(800, -450), Vector2(800, -half_gap), Vector2(775, -half_gap)
		]), wall_color)
		_add_poly(visuals, PackedVector2Array([
			Vector2(775, half_gap), Vector2(800, half_gap), Vector2(800, 450), Vector2(775, 450)
		]), wall_color)
	else:
		_add_poly(visuals, PackedVector2Array([
			Vector2(775, -450), Vector2(800, -450), Vector2(800, 450), Vector2(775, 450)
		]), wall_color)
