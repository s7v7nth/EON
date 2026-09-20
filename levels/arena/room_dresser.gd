class_name RoomDresser
extends RefCounted
## Authored isometric floors, walls, and props. No cartesian grid overlay.


static func dress(arena: Node2D, biome: BiomeDefinition) -> void:
	if arena == null or biome == null:
		return
	_clear_named(arena, "Dressing")
	_clear_iso_walls(arena)
	var root := Node2D.new()
	root.name = "Dressing"
	root.z_index = -12
	arena.add_child(root)

	var floor_c := biome.get_floor_color()
	var accent := _biome_accent(biome)
	_paint_underlay(arena, floor_c)
	_hide_box_walls(arena)
	_add_backdrop(root, biome)
	_add_iso_floor(root, biome)
	_add_floor_decals(root, biome, accent)
	_add_edge_walls(arena, biome)
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


static func _clear_iso_walls(arena: Node2D) -> void:
	_clear_named(arena, "IsoWalls")
	var entities := arena.get_node_or_null("Entities")
	if entities:
		for child in entities.get_children():
			if String(child.name).begins_with("IsoWall"):
				child.free()


static func _kenney_iso_offset(tex: Texture2D) -> Vector2:
	## Kenney 2:1 iso tiles sit on a padded canvas. Snap the diamond center to the node.
	if tex == null:
		return Vector2.ZERO
	var h := float(tex.get_height())
	var w := float(tex.get_width())
	var diamond_h := w * 0.5
	return Vector2(0.0, -(h * 0.5 - diamond_h * 0.5))


static func _biome_accent(biome: BiomeDefinition) -> Color:
	match biome.biome_id:
		GameplayEnums.BiomeId.DATA_CENTER, GameplayEnums.BiomeId.GATEWAY:
			return Color(0.28, 0.38, 0.42, 0.4)
		GameplayEnums.BiomeId.LANDFILL, GameplayEnums.BiomeId.WASTELAND:
			return Color(0.42, 0.32, 0.18, 0.4)
		GameplayEnums.BiomeId.JUNGLE, GameplayEnums.BiomeId.TAIGA:
			return Color(0.22, 0.32, 0.2, 0.4)
		GameplayEnums.BiomeId.DOWNTOWN, GameplayEnums.BiomeId.MALL, GameplayEnums.BiomeId.ALLEY:
			return Color(0.55, 0.28, 0.14, 0.4)
		GameplayEnums.BiomeId.RESIDENTIAL:
			return Color(0.32, 0.26, 0.3, 0.4)
		_:
			return Color(0.35, 0.3, 0.24, 0.35)


static func _paint_underlay(arena: Node2D, floor_c: Color) -> void:
	var floor_poly := arena.get_node_or_null("Floor") as Polygon2D
	if floor_poly:
		var c := floor_c.darkened(0.78)
		c.a = 1.0
		floor_poly.color = Color(0.08, 0.07, 0.06, 1)
		floor_poly.z_index = -22


static func _hide_box_walls(arena: Node2D) -> void:
	var visuals := arena.get_node_or_null("WallVisuals") as Node2D
	if visuals:
		visuals.visible = false


static func _add_backdrop(root: Node2D, biome: BiomeDefinition) -> void:
	var path := "res://assets/kenney/space-shooter/bg/darkPurple.png"
	match biome.biome_id:
		GameplayEnums.BiomeId.LANDFILL, GameplayEnums.BiomeId.WASTELAND:
			path = "res://assets/kenney/space-shooter/bg/black.png"
		GameplayEnums.BiomeId.DATA_CENTER, GameplayEnums.BiomeId.GATEWAY:
			path = "res://assets/kenney/space-shooter/bg/black.png"
		GameplayEnums.BiomeId.JUNGLE, GameplayEnums.BiomeId.TAIGA:
			path = "res://assets/kenney/space-shooter/bg/black.png"
		GameplayEnums.BiomeId.DOWNTOWN, GameplayEnums.BiomeId.MALL, GameplayEnums.BiomeId.ALLEY:
			path = "res://assets/kenney/space-shooter/bg/black.png"
		_:
			path = "res://assets/kenney/space-shooter/bg/darkPurple.png"
	var tex := ArtBank.tex(path)
	if tex == null:
		return
	var bg := Sprite2D.new()
	bg.name = "NightSky"
	bg.texture = tex
	bg.centered = true
	bg.z_index = -18
	bg.scale = Vector2(7.2, 4.6)
	bg.modulate = Color(0.12, 0.1, 0.09, 1)
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	root.add_child(bg)
	var grit_path := "res://assets/kenney/patterns/pattern08.png"
	if int(biome.biome_id) % 2 == 0:
		grit_path = "res://assets/kenney/patterns/pattern03.png"
	var grit := ArtBank.tex(grit_path)
	if grit:
		var overlay := Sprite2D.new()
		overlay.texture = grit
		overlay.centered = true
		overlay.z_index = -17
		overlay.scale = Vector2(14.0, 10.0)
		overlay.modulate = Color(0.1, 0.08, 0.07, 0.42)
		root.add_child(overlay)


static func _door_dirs() -> Array[Vector2i]:
	var dirs: Array[Vector2i] = []
	if not RunState.is_procedural_run():
		return dirs
	var room := RunState.current_dungeon_room()
	if room:
		dirs = room.door_dirs()
	return dirs


static func _is_boss_room() -> bool:
	return RunState.is_boss_room()


static func _add_iso_floor(root: Node2D, biome: BiomeDefinition) -> void:
	var tiles := Node2D.new()
	tiles.name = "FloorTiles"
	tiles.z_index = -2
	root.add_child(tiles)
	var stems := _floor_stems(biome)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(biome.biome_id) * 7919 + 42
	# Kenney iso diamonds are 256×128 once the padded canvas is cropped.
	var tile_scale := 0.84
	var tw := 256.0 * tile_scale
	var th := 128.0 * tile_scale
	for ix in range(-11, 12):
		for iy in range(-10, 11):
			var p := Vector2((ix - iy) * tw * 0.5, (ix + iy) * th * 0.5)
			if absf(p.x) > 860.0 or absf(p.y) > 500.0:
				continue
			var stem: String = stems[rng.randi() % stems.size()]
			var tex := ArtBank.dungeon_facing(stem, Vector2(0, 1))
			if tex == null:
				tex = ArtBank.dungeon(stem + "_S")
			if tex == null:
				tex = ArtBank.space("terrain_SE")
			_place_iso_piece(tiles, tex, p, tile_scale, _floor_modulate(biome, rng), 0)


static func _floor_stems(biome: BiomeDefinition) -> PackedStringArray:
	match biome.biome_id:
		GameplayEnums.BiomeId.LANDFILL, GameplayEnums.BiomeId.WASTELAND:
			return PackedStringArray(["dirt", "dirtTiles", "stoneUneven", "stone"])
		GameplayEnums.BiomeId.DATA_CENTER, GameplayEnums.BiomeId.GATEWAY:
			return PackedStringArray(["stoneTile", "stone", "stoneUneven"])
		GameplayEnums.BiomeId.JUNGLE, GameplayEnums.BiomeId.TAIGA:
			return PackedStringArray(["dirt", "dirtTiles", "planks"])
		GameplayEnums.BiomeId.DOWNTOWN, GameplayEnums.BiomeId.MALL, GameplayEnums.BiomeId.ALLEY:
			return PackedStringArray(["stoneTile", "stone", "stoneUneven"])
		GameplayEnums.BiomeId.RESIDENTIAL:
			return PackedStringArray(["stoneTile", "planks", "stone"])
		_:
			return PackedStringArray(["stoneTile", "stone", "stoneUneven", "dirtTiles"])


static func _floor_modulate(biome: BiomeDefinition, rng: RandomNumberGenerator) -> Color:
	var base := Color(0.3, 0.26, 0.22)
	match biome.biome_id:
		GameplayEnums.BiomeId.LANDFILL, GameplayEnums.BiomeId.WASTELAND:
			base = Color(0.32, 0.26, 0.18)
		GameplayEnums.BiomeId.DATA_CENTER, GameplayEnums.BiomeId.GATEWAY:
			base = Color(0.26, 0.26, 0.28)
		GameplayEnums.BiomeId.JUNGLE, GameplayEnums.BiomeId.TAIGA:
			base = Color(0.22, 0.26, 0.16)
		GameplayEnums.BiomeId.DOWNTOWN, GameplayEnums.BiomeId.MALL, GameplayEnums.BiomeId.ALLEY:
			base = Color(0.34, 0.24, 0.18)
		GameplayEnums.BiomeId.RESIDENTIAL:
			base = Color(0.28, 0.24, 0.22)
	var j := rng.randf_range(-0.05, 0.05)
	return Color(clampf(base.r + j, 0.12, 0.7), clampf(base.g + j, 0.12, 0.7), clampf(base.b + j * 0.4, 0.1, 0.65))


static func _add_floor_decals(root: Node2D, biome: BiomeDefinition, accent: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(biome.biome_id) * 1337 + 9
	var spots := [
		Vector2(-220, -80), Vector2(260, 40), Vector2(-40, 160),
		Vector2(180, -180), Vector2(-340, 120), Vector2(90, 240),
		Vector2(-120, -240), Vector2(320, -120)
	]
	for i in spots.size():
		var splat_idx := 1 + ((int(biome.biome_id) + i * 2) % 8)
		var splat := ArtBank.tex("res://assets/kenney/splat/splat%02d.png" % splat_idx)
		if splat == null:
			splat = ArtBank.tex("res://assets/kenney/splat/splat03.png")
		var spr := ArtBank.add_fitted(root, splat, spots[i] + Vector2(rng.randf_range(-22, 22), rng.randf_range(-16, 16)), rng.randf_range(38.0, 58.0), 1, false)
		if spr:
			spr.modulate = Color(0.28, 0.16, 0.1, 0.55)
			spr.modulate.a = 0.38
			spr.rotation = rng.randf_range(-0.4, 0.4)


static func _add_edge_walls(arena: Node2D, biome: BiomeDefinition) -> void:
	var walls := Node2D.new()
	walls.name = "IsoWalls"
	walls.y_sort_enabled = true
	walls.z_as_relative = false
	walls.z_index = 1
	arena.add_child(walls)
	var doors := _door_dirs()
	var tile_scale := 0.84
	var tw := 256.0 * tile_scale
	var th := 128.0 * tile_scale
	# Inscribe the wall diamond in the camera (±800 x, ±450 y) so edges meet on-screen.
	var n := 4
	var rng := RandomNumberGenerator.new()
	rng.seed = int(biome.biome_id) * 9103 + 17
	_iso_corner(walls, biome, _iso_cell(-n, -n, tw, th), "N", tile_scale)
	_iso_corner(walls, biome, _iso_cell(n, -n, tw, th), "E", tile_scale)
	_iso_corner(walls, biome, _iso_cell(n, n, tw, th), "S", tile_scale)
	_iso_corner(walls, biome, _iso_cell(-n, n, tw, th), "W", tile_scale)
	for iy in range(-n + 1, n):
		var p_nw := _iso_cell(-n, iy, tw, th)
		if _iso_door_gap(doors, p_nw):
			_iso_arch(walls, biome, p_nw, "N", tile_scale)
		else:
			_iso_wall(walls, biome, p_nw, "N", tile_scale, rng)
		var p_se := _iso_cell(n, iy, tw, th)
		if _iso_door_gap(doors, p_se):
			_iso_arch(walls, biome, p_se, "S", tile_scale)
		else:
			_iso_wall(walls, biome, p_se, "S", tile_scale, rng)
	for ix in range(-n + 1, n):
		var p_ne := _iso_cell(ix, -n, tw, th)
		if _iso_door_gap(doors, p_ne):
			_iso_arch(walls, biome, p_ne, "E", tile_scale)
		else:
			_iso_wall(walls, biome, p_ne, "E", tile_scale, rng)
		var p_sw := _iso_cell(ix, n, tw, th)
		if _iso_door_gap(doors, p_sw):
			_iso_arch(walls, biome, p_sw, "W", tile_scale)
		else:
			_iso_wall(walls, biome, p_sw, "W", tile_scale, rng)


static func _iso_cell(ix: int, iy: int, tw: float, th: float) -> Vector2:
	return Vector2((ix - iy) * tw * 0.5, (ix + iy) * th * 0.5)


static func _iso_door_gap(doors: Array[Vector2i], pos: Vector2) -> bool:
	## Tutorial/campaign south door sits near (0, +Y). Other dirs for procedural.
	if doors.is_empty():
		return pos.y > 210.0 and absf(pos.x) < 130.0
	for dir in doors:
		if dir == Vector2i(0, 1) and pos.y > 180.0 and absf(pos.x) < 140.0:
			return true
		if dir == Vector2i(0, -1) and pos.y < -180.0 and absf(pos.x) < 140.0:
			return true
		if dir == Vector2i(1, 0) and pos.x > 280.0 and absf(pos.y) < 120.0:
			return true
		if dir == Vector2i(-1, 0) and pos.x < -280.0 and absf(pos.y) < 120.0:
			return true
	return false


static func _iso_wall(
	parent: Node2D,
	biome: BiomeDefinition,
	pos: Vector2,
	facing: String,
	tile_scale: float,
	rng: RandomNumberGenerator
) -> void:
	var stem := "stoneWall"
	var roll := rng.randf()
	if roll < 0.18:
		stem = "stoneWallBroken"
	elif roll < 0.4:
		stem = "stoneWallAged"
	var tex := ArtBank.dungeon("%s_%s" % [stem, facing])
	if tex == null:
		tex = ArtBank.dungeon("stoneWall_%s" % facing)
	_place_iso_piece(parent, tex, pos, tile_scale, _wall_modulate(biome), 1)


static func _iso_corner(
	parent: Node2D,
	biome: BiomeDefinition,
	pos: Vector2,
	facing: String,
	tile_scale: float
) -> void:
	var tex := ArtBank.dungeon("stoneWallCorner_%s" % facing)
	_place_iso_piece(parent, tex, pos, tile_scale, _wall_modulate(biome), 1)


static func _iso_arch(
	parent: Node2D,
	biome: BiomeDefinition,
	pos: Vector2,
	facing: String,
	tile_scale: float
) -> void:
	var tex := ArtBank.dungeon("stoneWallArchway_%s" % facing)
	if tex == null:
		tex = ArtBank.dungeon("stoneWallDoorOpen_%s" % facing)
	_place_iso_piece(parent, tex, pos, tile_scale, _wall_modulate(biome), 1)


static func _place_iso_piece(
	parent: Node2D,
	tex: Texture2D,
	pos: Vector2,
	tile_scale: float,
	modulate: Color,
	z: int = 0
) -> Sprite2D:
	if parent == null or tex == null:
		return null
	var s := Sprite2D.new()
	s.name = "IsoWall" if z > 0 else "IsoFloor"
	s.texture = tex
	s.position = pos
	s.centered = true
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	s.region_enabled = false
	s.offset = _kenney_iso_offset(tex)
	s.scale = Vector2(tile_scale, tile_scale)
	s.modulate = modulate
	s.z_index = z
	parent.add_child(s)
	return s


static func _wall_modulate(biome: BiomeDefinition) -> Color:
	match biome.biome_id:
		GameplayEnums.BiomeId.DATA_CENTER, GameplayEnums.BiomeId.GATEWAY:
			return Color(0.32, 0.34, 0.36, 1)
		GameplayEnums.BiomeId.LANDFILL, GameplayEnums.BiomeId.WASTELAND:
			return Color(0.38, 0.3, 0.22, 1)
		GameplayEnums.BiomeId.JUNGLE, GameplayEnums.BiomeId.TAIGA:
			return Color(0.28, 0.32, 0.22, 1)
		GameplayEnums.BiomeId.DOWNTOWN, GameplayEnums.BiomeId.MALL, GameplayEnums.BiomeId.ALLEY:
			return Color(0.4, 0.28, 0.2, 1)
		_:
			return Color(0.36, 0.32, 0.26, 1)


static func _gap_blocks(doors: Array[Vector2i], dir: Vector2i, pos: Vector2, gap: float) -> bool:
	if not doors.has(dir):
		return false
	if dir.x == 0:
		return absf(pos.x) < gap
	return absf(pos.y) < gap


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
		Vector2(520, 80), Vector2(-180, -300), Vector2(420, -40)
	]
	if _is_boss_room():
		# Keep the pit clear for the warden.
		clusters = [Vector2(-520, -240), Vector2(530, -230), Vector2(-500, 250), Vector2(510, 240)]
	for i in clusters.size():
		_scatter_cluster(props, biome, clusters[i], rng, accent, i)
	_add_landmarks(props, biome)


static func _add_landmarks(props: Node2D, biome: BiomeDefinition) -> void:
	if _is_boss_room():
		return
	var spots: Array[Vector2] = [Vector2(-560, -40), Vector2(570, 30), Vector2(40, -340)]
	match biome.biome_id:
		GameplayEnums.BiomeId.DATA_CENTER, GameplayEnums.BiomeId.GATEWAY:
			var tech: PackedStringArray = PackedStringArray(["machine_generatorLarge", "satelliteDish", "desk_computer"])
			for i in spots.size():
				var tex := ArtBank.space_facing(tech[i % tech.size()], Vector2(1, 1))
				ArtBank.add_fitted(props, tex, spots[i], 92.0, 2, true)
		GameplayEnums.BiomeId.DOWNTOWN, GameplayEnums.BiomeId.MALL, GameplayEnums.BiomeId.ALLEY:
			var urban: PackedStringArray = PackedStringArray(["structure", "machine_generatorLarge", "craft_speederA"])
			for i in spots.size():
				var tex := ArtBank.space_facing(urban[i % urban.size()], Vector2(1, 1))
				ArtBank.add_fitted(props, tex, spots[i], 88.0, 2, true)
		GameplayEnums.BiomeId.LANDFILL, GameplayEnums.BiomeId.WASTELAND:
			var junk: PackedStringArray = PackedStringArray(["woodenCrate", "barrels", "woodenPile"])
			for i in spots.size():
				var stem: String = junk[i % junk.size()]
				var tex := ArtBank.dungeon_facing(stem, Vector2(0, 1))
				if tex == null:
					tex = ArtBank.space_facing("meteor", Vector2(1, 1))
				ArtBank.add_fitted(props, tex, spots[i], 86.0, 2, true)
		GameplayEnums.BiomeId.JUNGLE, GameplayEnums.BiomeId.TAIGA:
			var wild: PackedStringArray = PackedStringArray(["woodenPile", "stoneColumn", "woodenSupports"])
			for i in spots.size():
				var tex := ArtBank.dungeon_facing(wild[i % wild.size()], Vector2(0, 1))
				if tex == null:
					tex = ArtBank.space_facing("rock_crystals", Vector2(1, 1))
				ArtBank.add_fitted(props, tex, spots[i], 90.0, 2, true)
		_:
			for i in spots.size():
				var tex := ArtBank.dungeon_facing("woodenCrate", Vector2(0, 1))
				if tex == null:
					tex = ArtBank.space_facing("desk_chair", Vector2(1, 1))
				ArtBank.add_fitted(props, tex, spots[i], 78.0, 2, true)


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
	var organic := biome.biome_id == GameplayEnums.BiomeId.LANDFILL \
			or biome.biome_id == GameplayEnums.BiomeId.WASTELAND \
			or biome.biome_id == GameplayEnums.BiomeId.JUNGLE \
			or biome.biome_id == GameplayEnums.BiomeId.TAIGA \
			or biome.biome_id == GameplayEnums.BiomeId.RESIDENTIAL
	for j in count:
		var offset := Vector2(rng.randf_range(-46, 46), rng.randf_range(-30, 30))
		var stem: String = kit[(salt + j) % kit.size()]
		var tex: Texture2D = null
		if organic:
			tex = ArtBank.dungeon_facing(stem, Vector2(0, 1))
			if tex == null:
				tex = ArtBank.space_facing(stem, Vector2(1, 1))
		else:
			tex = ArtBank.space_facing(stem, Vector2(1, 1))
			if tex == null:
				tex = ArtBank.dungeon_facing(stem, Vector2(0, 1))
		var spr := ArtBank.add_fitted(props, tex, origin + offset, rng.randf_range(52.0, 78.0), 0, true)
		if spr:
			spr.modulate = Color(0.48, 0.42, 0.34).lerp(accent, 0.2)


static func _prop_stems(biome: BiomeDefinition) -> PackedStringArray:
	match biome.biome_id:
		GameplayEnums.BiomeId.DATA_CENTER, GameplayEnums.BiomeId.GATEWAY:
			return PackedStringArray([
				"desk_computer", "desk_chair", "machine_generator", "machine_wireless",
				"satelliteDish", "barrel", "turret_single"
			])
		GameplayEnums.BiomeId.LANDFILL, GameplayEnums.BiomeId.WASTELAND:
			return PackedStringArray([
				"barrel", "barrels", "woodenCrate", "woodenPile", "woodenCrates"
			])
		GameplayEnums.BiomeId.JUNGLE, GameplayEnums.BiomeId.TAIGA:
			return PackedStringArray(["woodenPile", "stoneColumn", "woodenCrate", "barrel", "woodenSupports"])
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
	var scale_h := 110.0 if boss else 78.0
	var spr := ArtBank.add_fitted(root, plat, Vector2(0, 18), scale_h, 1, false)
	if spr:
		spr.modulate = Color(0.55, 0.5, 0.42).lerp(accent, 0.25)
	if biome.biome_id == GameplayEnums.BiomeId.LANDFILL or biome.biome_id == GameplayEnums.BiomeId.WASTELAND:
		var pile := ArtBank.dungeon_facing("barrels", Vector2(0, 1))
		if pile == null:
			pile = ArtBank.space_facing("barrels", Vector2(1, 1))
		ArtBank.add_fitted(root, pile, Vector2(-70, 8), 54.0, 2, true)
		var crate := ArtBank.dungeon_facing("woodenCrate", Vector2(0, 1))
		ArtBank.add_fitted(root, crate, Vector2(64, 14), 50.0, 2, true)
	elif biome.biome_id == GameplayEnums.BiomeId.JUNGLE or biome.biome_id == GameplayEnums.BiomeId.TAIGA:
		var wood := ArtBank.dungeon_facing("woodenPile", Vector2(0, 1))
		ArtBank.add_fitted(root, wood, Vector2(-62, 10), 58.0, 2, true)
		var col := ArtBank.dungeon_facing("stoneColumn", Vector2(0, 1))
		ArtBank.add_fitted(root, col, Vector2(70, 12), 72.0, 2, true)
	elif biome.biome_id == GameplayEnums.BiomeId.DOWNTOWN or biome.biome_id == GameplayEnums.BiomeId.MALL:
		var table := ArtBank.dungeon_facing("tableRound", Vector2(0, 1))
		ArtBank.add_fitted(root, table, Vector2(-8, 12), 48.0, 2, true)
	if boss:
		var ring := ArtBank.particle("circle_05")
		var glow := ArtBank.add_sprite(root, ring, Vector2(0, 8), 1.8, 2, true)
		if glow:
			glow.modulate = Color(0.55, 0.12, 0.08, 0.4)
		var dish := ArtBank.space("satelliteDish_large_SE")
		ArtBank.add_fitted(root, dish, Vector2(0, -40), 96.0, 3, true)


static func _add_lighting(arena: Node2D, accent: Color, biome: BiomeDefinition) -> void:
	_clear_named(arena, "Atmosphere")
	var layer := Node2D.new()
	layer.name = "Atmosphere"
	arena.add_child(layer)
	var grade := CanvasModulate.new()
	grade.name = "Grade"
	grade.color = Color(0.42, 0.36, 0.3, 1)
	if biome.biome_id == GameplayEnums.BiomeId.DATA_CENTER or biome.biome_id == GameplayEnums.BiomeId.GATEWAY:
		grade.color = Color(0.38, 0.4, 0.42, 1)
	layer.add_child(grade)
	var tex := _radial_light_texture()
	var moon := PointLight2D.new()
	moon.name = "Moon"
	moon.position = Vector2(-80, -220)
	moon.texture = tex
	moon.color = Color(0.42, 0.48, 0.55, 1)
	moon.energy = 0.22
	moon.texture_scale = 4.6
	layer.add_child(moon)
	var sodium := PointLight2D.new()
	sodium.name = "Sodium"
	sodium.position = Vector2(220, 40)
	sodium.texture = tex
	sodium.color = Color(0.78, 0.38, 0.12, 1).lerp(Color(accent.r, accent.g, accent.b, 1), 0.15)
	sodium.energy = 0.34 if not _is_boss_room() else 0.55
	sodium.texture_scale = 2.4
	layer.add_child(sodium)
	if _is_boss_room():
		var ember := PointLight2D.new()
		ember.position = Vector2(0, 20)
		ember.texture = tex
		ember.color = Color(0.75, 0.22, 0.12, 1)
		ember.energy = 0.55
		ember.texture_scale = 3.0
		layer.add_child(ember)
	_add_fog(layer)
	_add_vignette(arena)


static func _add_fog(layer: Node2D) -> void:
	var smoke := ArtBank.particle("smoke_08")
	if smoke == null:
		smoke = ArtBank.particle("smoke_01")
	if smoke == null:
		return
	var spots := [Vector2(-480, 80), Vector2(460, 120), Vector2(-200, 220), Vector2(80, -180)]
	for i in spots.size():
		var spr := Sprite2D.new()
		spr.texture = smoke
		spr.centered = true
		spr.position = spots[i]
		spr.scale = Vector2(2.4, 1.6)
		spr.modulate = Color(0.08, 0.07, 0.06, 0.45)
		spr.z_index = 12
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		layer.add_child(spr)


static func _add_vignette(arena: Node2D) -> void:
	var existing := arena.get_node_or_null("VignetteLayer")
	if existing:
		existing.free()
	var canvas := CanvasLayer.new()
	canvas.name = "VignetteLayer"
	canvas.layer = 4
	arena.add_child(canvas)
	var rect := TextureRect.new()
	rect.name = "Vignette"
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0.02, 0.012, 0.008, 0.88)])
	grad.offsets = PackedFloat32Array([0.28, 1.0])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 256
	tex.height = 256
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	rect.texture = tex
	canvas.add_child(rect)


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
