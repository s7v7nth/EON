class_name RoomDresser
extends RefCounted
## Authored isometric floors, walls, and props. No cartesian grid overlay.


static func dress(arena: Node2D, biome: BiomeDefinition) -> void:
	if arena == null or biome == null:
		return
	_clear_named(arena, "Dressing")
	var root := Node2D.new()
	root.name = "Dressing"
	root.z_index = -12
	arena.add_child(root)

	var floor_c := biome.get_floor_color()
	var accent := _biome_accent(biome)
	_paint_underlay(arena, floor_c)
	_add_iso_floor(root, biome)
	_add_floor_decals(root, biome, accent)
	_add_edge_walls(root, biome)
	_add_props(root, biome, accent)
	_add_centerpiece(root, biome, accent)
	_add_lighting(arena, accent, biome)


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


static func _paint_underlay(arena: Node2D, floor_c: Color) -> void:
	var floor_poly := arena.get_node_or_null("Floor") as Polygon2D
	if floor_poly:
		var c := floor_c.darkened(0.45)
		c.a = 1.0
		floor_poly.color = c
		floor_poly.z_index = -22


static func _door_dirs() -> Array[Vector2i]:
	var dirs: Array[Vector2i] = []
	if not RunState.is_procedural_run():
		return dirs
	var room := RunState.current_dungeon_room()
	if room:
		dirs = room.door_dirs()
	return dirs


static func _is_boss_room() -> bool:
	if not RunState.is_procedural_run():
		return false
	var room := RunState.current_dungeon_room()
	return room != null and room.kind == DungeonRoom.RoomKind.BOSS


static func _add_iso_floor(root: Node2D, biome: BiomeDefinition) -> void:
	var tiles := Node2D.new()
	tiles.name = "FloorTiles"
	tiles.z_index = -2
	root.add_child(tiles)
	var stems := _floor_stems(biome)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(biome.biome_id) * 7919 + 42
	# Diamond lattice — reads as an isometric plane, not a square grid.
	var tw := 148.0
	var th := 86.0
	for ix in range(-9, 10):
		for iy in range(-8, 9):
			var p := Vector2((ix - iy) * tw * 0.5, (ix + iy) * th * 0.5)
			if absf(p.x) > 820.0 or absf(p.y) > 470.0:
				continue
			var stem: String = stems[rng.randi() % stems.size()]
			var tex := ArtBank.dungeon_facing(stem, Vector2(0, 1))
			if tex == null:
				tex = ArtBank.dungeon(stem + "_S")
			if tex == null:
				tex = ArtBank.space("terrain_SE")
			var spr := ArtBank.add_sprite(tiles, tex, p, 0.58, 0, true)
			if spr:
				spr.modulate = _floor_modulate(biome, rng)


static func _floor_stems(biome: BiomeDefinition) -> PackedStringArray:
	match biome.biome_id:
		GameplayEnums.BiomeId.LANDFILL, GameplayEnums.BiomeId.WASTELAND:
			return PackedStringArray(["dirt", "dirtTiles", "stoneUneven", "stone"])
		GameplayEnums.BiomeId.DATA_CENTER, GameplayEnums.BiomeId.GATEWAY:
			return PackedStringArray(["stoneTile", "stone", "stoneUneven"])
		GameplayEnums.BiomeId.JUNGLE, GameplayEnums.BiomeId.TAIGA:
			return PackedStringArray(["dirt", "dirtTiles", "planks"])
		GameplayEnums.BiomeId.RESIDENTIAL:
			return PackedStringArray(["stoneTile", "planks", "stone"])
		_:
			return PackedStringArray(["stoneTile", "stone", "stoneUneven", "dirtTiles"])


static func _floor_modulate(biome: BiomeDefinition, rng: RandomNumberGenerator) -> Color:
	var base := Color(0.78, 0.8, 0.84)
	match biome.biome_id:
		GameplayEnums.BiomeId.LANDFILL, GameplayEnums.BiomeId.WASTELAND:
			base = Color(0.62, 0.7, 0.48)
		GameplayEnums.BiomeId.DATA_CENTER, GameplayEnums.BiomeId.GATEWAY:
			base = Color(0.55, 0.68, 0.82)
		GameplayEnums.BiomeId.JUNGLE, GameplayEnums.BiomeId.TAIGA:
			base = Color(0.5, 0.68, 0.46)
		GameplayEnums.BiomeId.DOWNTOWN, GameplayEnums.BiomeId.MALL, GameplayEnums.BiomeId.ALLEY:
			base = Color(0.72, 0.58, 0.5)
		GameplayEnums.BiomeId.RESIDENTIAL:
			base = Color(0.7, 0.62, 0.78)
	var j := rng.randf_range(-0.06, 0.06)
	return Color(clampf(base.r + j, 0.2, 1.0), clampf(base.g + j, 0.2, 1.0), clampf(base.b + j * 0.5, 0.2, 1.0))


static func _add_floor_decals(root: Node2D, biome: BiomeDefinition, accent: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(biome.biome_id) * 1337 + 9
	# Sci-fi metal plates as sparse rugs — not a repeating grid.
	var spots := [
		Vector2(-220, -80), Vector2(260, 40), Vector2(-40, 160),
		Vector2(180, -180), Vector2(-340, 120), Vector2(90, 240)
	]
	for i in spots.size():
		var idx := 1 + (int(biome.biome_id) + i * 3) % 16
		var tex := ArtBank.rts_tile(idx)
		var spr := ArtBank.add_sprite(root, tex, spots[i] + Vector2(rng.randf_range(-18, 18), rng.randf_range(-12, 12)), 1.15, 1, true)
		if spr:
			spr.modulate = Color(accent.r, accent.g, accent.b, 0.55).lightened(0.2)
			spr.modulate.a = 0.55


static func _add_edge_walls(root: Node2D, biome: BiomeDefinition) -> void:
	var doors := _door_dirs()
	var wall_stem := "stoneWall"
	if biome.biome_id == GameplayEnums.BiomeId.DATA_CENTER or biome.biome_id == GameplayEnums.BiomeId.GATEWAY:
		wall_stem = "corridor_wall"
	var gap := 110.0
	# North / south
	for x in range(-720, 721, 160):
		if _gap_blocks(doors, Vector2i(0, -1), Vector2(x, -430), gap):
			pass
		else:
			_wall_piece(root, biome, wall_stem, Vector2(x, -410), Vector2(0, -1))
		if _gap_blocks(doors, Vector2i(0, 1), Vector2(x, 430), gap):
			pass
		else:
			_wall_piece(root, biome, wall_stem, Vector2(x, 410), Vector2(0, 1))
	for y in range(-320, 321, 150):
		if not _gap_blocks(doors, Vector2i(-1, 0), Vector2(-780, y), gap):
			_wall_piece(root, biome, wall_stem, Vector2(-760, y), Vector2(-1, 0))
		if not _gap_blocks(doors, Vector2i(1, 0), Vector2(780, y), gap):
			_wall_piece(root, biome, wall_stem, Vector2(760, y), Vector2(1, 0))
	# Corner columns
	for c in [Vector2(-700, -360), Vector2(700, -360), Vector2(-700, 360), Vector2(700, 360)]:
		var col := ArtBank.dungeon_facing("stoneColumn", Vector2(0, 1))
		ArtBank.add_sprite(root, col, c, 0.55, 4, true)


static func _gap_blocks(doors: Array[Vector2i], dir: Vector2i, pos: Vector2, gap: float) -> bool:
	if not doors.has(dir):
		return false
	if dir.x == 0:
		return absf(pos.x) < gap
	return absf(pos.y) < gap


static func _wall_piece(root: Node2D, biome: BiomeDefinition, stem: String, pos: Vector2, facing: Vector2) -> void:
	var tex: Texture2D = null
	if stem == "corridor_wall":
		tex = ArtBank.space_facing("corridor_wall", facing)
	else:
		tex = ArtBank.dungeon_facing(stem, facing)
	var spr := ArtBank.add_sprite(root, tex, pos, 0.5, 3, true)
	if spr == null:
		return
	match biome.biome_id:
		GameplayEnums.BiomeId.DATA_CENTER, GameplayEnums.BiomeId.GATEWAY:
			spr.modulate = Color(0.7, 0.85, 1.0, 1)
		GameplayEnums.BiomeId.LANDFILL, GameplayEnums.BiomeId.WASTELAND:
			spr.modulate = Color(0.75, 0.82, 0.62, 1)
		_:
			spr.modulate = Color(0.86, 0.88, 0.9, 1)


static func _add_props(root: Node2D, biome: BiomeDefinition, accent: Color) -> void:
	var props := Node2D.new()
	props.name = "Props"
	props.y_sort_enabled = true
	props.z_index = 2
	root.add_child(props)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(biome.biome_id) * 4243 + 88
	var clusters: Array[Vector2] = [
		Vector2(-480, -210), Vector2(500, -190), Vector2(-430, 230),
		Vector2(460, 220), Vector2(-180, -300), Vector2(210, 310)
	]
	if _is_boss_room():
		# Keep the pit clear for the warden.
		clusters = [Vector2(-520, -240), Vector2(530, -230), Vector2(-500, 250), Vector2(510, 240)]
	for i in clusters.size():
		_scatter_cluster(props, biome, clusters[i], rng, accent, i)


static func _scatter_cluster(
	props: Node2D,
	biome: BiomeDefinition,
	origin: Vector2,
	rng: RandomNumberGenerator,
	accent: Color,
	salt: int
) -> void:
	var kit: PackedStringArray = _prop_stems(biome)
	var count := 3 + (salt % 2)
	for j in count:
		var offset := Vector2(rng.randf_range(-46, 46), rng.randf_range(-30, 30))
		var stem: String = kit[(salt + j) % kit.size()]
		var tex := ArtBank.space_facing(stem, Vector2(1, 1))
		if tex == null:
			tex = ArtBank.dungeon_facing(stem, Vector2(0, 1))
		if tex == null:
			tex = ArtBank.rts_env(1 + ((salt + j) % 18))
		var spr := ArtBank.add_sprite(props, tex, origin + offset, rng.randf_range(0.42, 0.58), 0, true)
		if spr:
			spr.modulate = Color(0.9, 0.92, 0.95).lerp(accent, 0.12)


static func _prop_stems(biome: BiomeDefinition) -> PackedStringArray:
	match biome.biome_id:
		GameplayEnums.BiomeId.DATA_CENTER, GameplayEnums.BiomeId.GATEWAY:
			return PackedStringArray([
				"desk_computer", "desk_chair", "machine_generator", "machine_wireless",
				"satelliteDish", "barrel", "turret_single"
			])
		GameplayEnums.BiomeId.LANDFILL, GameplayEnums.BiomeId.WASTELAND:
			return PackedStringArray([
				"barrel", "barrels", "rock", "meteor", "crater", "rocks_smallA", "machine_barrel"
			])
		GameplayEnums.BiomeId.JUNGLE, GameplayEnums.BiomeId.TAIGA:
			return PackedStringArray(["rock_crystals", "rock", "rocks_smallA", "barrel"])
		GameplayEnums.BiomeId.DOWNTOWN, GameplayEnums.BiomeId.MALL, GameplayEnums.BiomeId.ALLEY:
			return PackedStringArray([
				"barrels", "structure", "desk_computer", "machine_generatorLarge", "craft_speederA"
			])
		_:
			return PackedStringArray(["barrel", "desk_chair", "woodenCrate", "rock"])


static func _add_centerpiece(root: Node2D, biome: BiomeDefinition, accent: Color) -> void:
	var boss := _is_boss_room()
	var plat := ArtBank.space("platform_center_SE")
	if plat == null:
		plat = ArtBank.space("platform_large_SE")
	var scale := 0.85 if boss else 0.62
	var spr := ArtBank.add_sprite(root, plat, Vector2(0, 18), scale, 1, true)
	if spr:
		spr.modulate = Color(0.75, 0.8, 0.9).lerp(accent, 0.35)
	if boss:
		var ring := ArtBank.particle("circle_05")
		var glow := ArtBank.add_sprite(root, ring, Vector2(0, 8), 1.8, 2, true)
		if glow:
			glow.modulate = Color(1.0, 0.28, 0.22, 0.55)
		var dish := ArtBank.space("satelliteDish_large_SE")
		ArtBank.add_sprite(root, dish, Vector2(0, -40), 0.55, 3, true)


static func _add_lighting(arena: Node2D, accent: Color, biome: BiomeDefinition) -> void:
	_clear_named(arena, "Atmosphere")
	var layer := Node2D.new()
	layer.name = "Atmosphere"
	arena.add_child(layer)
	var tex := _radial_light_texture()
	var spots := [
		Vector2(-520, -260), Vector2(520, -260),
		Vector2(-520, 260), Vector2(520, 260),
		Vector2(0, 20)
	]
	var boss := _is_boss_room()
	for i in spots.size():
		var light := PointLight2D.new()
		light.position = spots[i]
		light.texture = tex
		if boss:
			light.color = Color(1.0, 0.35, 0.28, 1.0) if i < 4 else Color(1.0, 0.55, 0.4, 1.0)
			light.energy = 1.45 if i < 4 else 1.1
		else:
			light.color = Color(accent.r, accent.g, accent.b, 1.0).lightened(0.25)
			light.energy = 1.15 if i < 4 else 0.65
		light.texture_scale = 2.8
		layer.add_child(light)
	if biome.biome_id == GameplayEnums.BiomeId.DATA_CENTER:
		var extra := PointLight2D.new()
		extra.position = Vector2(0, -120)
		extra.texture = tex
		extra.color = Color(0.45, 0.85, 1.0)
		extra.energy = 0.9
		extra.texture_scale = 2.2
		layer.add_child(extra)


static func _radial_light_texture() -> Texture2D:
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 256
	tex.height = 256
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	return tex


static func _rebuild_wall_collisions(walls: StaticBody2D, door_dirs: Array[Vector2i], gap: float) -> void:
	for child in walls.get_children():
		child.free()
	var half_gap := gap * 0.5
	_add_h_wall_segments(walls, -475.0, door_dirs.has(Vector2i(0, -1)), half_gap)
	_add_h_wall_segments(walls, 475.0, door_dirs.has(Vector2i(0, 1)), half_gap)
	_add_v_wall_segments(walls, -825.0, door_dirs.has(Vector2i(-1, 0)), half_gap)
	_add_v_wall_segments(walls, 825.0, door_dirs.has(Vector2i(1, 0)), half_gap)


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


static func _add_poly(parent: Node2D, pts: PackedVector2Array, color: Color, z: int = 0) -> void:
	var p := Polygon2D.new()
	p.polygon = pts
	p.color = color
	p.z_index = z
	parent.add_child(p)


static func _rebuild_wall_visuals(visuals: Node2D, door_dirs: Array[Vector2i], gap: float) -> void:
	for child in visuals.get_children():
		child.free()
	var wall_color := Color(0.07, 0.075, 0.09, 1)
	var half_gap := gap * 0.5
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
