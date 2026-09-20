class_name RoomDresser
extends RefCounted
## Illustrated isometric floors, walls, and EON ruin props. No Kenney voxel wash.

const _IllustratedSet := preload("res://systems/worldgen/illustrated_set.gd")


static func dress(arena: Node2D, biome: BiomeDefinition) -> void:
	if arena == null or biome == null:
		return
	_clear_named(arena, "Dressing")
	_clear_iso_walls(arena)
	var root := Node2D.new()
	root.name = "Dressing"
	root.z_index = -12
	arena.add_child(root)

	_paint_underlay(arena)
	_hide_box_walls(arena)
	_add_backdrop(root)
	_IllustratedSet.place_floor(
		root,
		biome,
		func(p: Vector2) -> bool: return absf(p.x) <= 860.0 and absf(p.y) <= 500.0,
		int(biome.biome_id) * 7919 + 42
	)
	_add_edge_walls(arena, biome)
	_IllustratedSet.place_dressing(root, biome, int(biome.biome_id) * 4243 + 88, _is_boss_room())
	_add_lighting(arena, biome)


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


static func _paint_underlay(arena: Node2D) -> void:
	var floor_poly := arena.get_node_or_null("Floor") as Polygon2D
	if floor_poly:
		floor_poly.color = Color(0.05, 0.045, 0.06, 1)
		floor_poly.z_index = -22


static func _hide_box_walls(arena: Node2D) -> void:
	var visuals := arena.get_node_or_null("WallVisuals") as Node2D
	if visuals:
		visuals.visible = false


static func _add_backdrop(root: Node2D) -> void:
	var tex := _IllustratedSet.dusk_sky()
	if tex == null:
		return
	var bg := Sprite2D.new()
	bg.name = "NightSky"
	bg.texture = tex
	bg.centered = true
	bg.z_index = -18
	bg.scale = Vector2(2.15, 2.15)
	bg.modulate = Color.WHITE
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	root.add_child(bg)


static func _door_dirs() -> Array[Vector2i]:
	var dirs: Array[Vector2i] = []
	if RunState.dungeon == null:
		return dirs
	var room := RunState.current_dungeon_room()
	if room:
		dirs = room.door_dirs()
	return dirs


static func _is_boss_room() -> bool:
	return RunState.is_boss_room()


static func _add_edge_walls(arena: Node2D, biome: BiomeDefinition) -> void:
	var walls := Node2D.new()
	walls.name = "IsoWalls"
	walls.y_sort_enabled = true
	walls.z_as_relative = false
	walls.z_index = 1
	arena.add_child(walls)
	var doors := _door_dirs()
	var tile_scale := 0.72
	var tw := _IllustratedSet.TILE_W
	var th := _IllustratedSet.TILE_H
	var n := 4
	_iso_corner(walls, biome, _iso_cell(-n, -n, tw, th), "N", tile_scale)
	_iso_corner(walls, biome, _iso_cell(n, -n, tw, th), "E", tile_scale)
	_iso_corner(walls, biome, _iso_cell(n, n, tw, th), "S", tile_scale)
	_iso_corner(walls, biome, _iso_cell(-n, n, tw, th), "W", tile_scale)
	for iy in range(-n + 1, n):
		var p_nw := _iso_cell(-n, iy, tw, th)
		if _iso_door_gap(doors, p_nw):
			_iso_arch(walls, biome, p_nw, "N", tile_scale)
		else:
			_iso_wall(walls, biome, p_nw, "N", tile_scale)
		var p_se := _iso_cell(n, iy, tw, th)
		if _iso_door_gap(doors, p_se):
			_iso_arch(walls, biome, p_se, "S", tile_scale)
		else:
			_iso_wall(walls, biome, p_se, "S", tile_scale)
	for ix in range(-n + 1, n):
		var p_ne := _iso_cell(ix, -n, tw, th)
		if _iso_door_gap(doors, p_ne):
			_iso_arch(walls, biome, p_ne, "E", tile_scale)
		else:
			_iso_wall(walls, biome, p_ne, "E", tile_scale)
		var p_sw := _iso_cell(ix, n, tw, th)
		if _iso_door_gap(doors, p_sw):
			_iso_arch(walls, biome, p_sw, "W", tile_scale)
		else:
			_iso_wall(walls, biome, p_sw, "W", tile_scale)


static func _iso_cell(ix: int, iy: int, tw: float, th: float) -> Vector2:
	return Vector2((ix - iy) * tw * 0.5, (ix + iy) * th * 0.5)


static func _iso_door_gap(doors: Array[Vector2i], pos: Vector2) -> bool:
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


static func _iso_wall(parent: Node2D, biome: BiomeDefinition, pos: Vector2, facing: String, tile_scale: float) -> void:
	_place_iso_piece(parent, _IllustratedSet.wall_tex(facing), pos, tile_scale, _wall_modulate(biome), 1)


static func _iso_corner(parent: Node2D, biome: BiomeDefinition, pos: Vector2, facing: String, tile_scale: float) -> void:
	_place_iso_piece(parent, _IllustratedSet.wall_tex(facing), pos, tile_scale, _wall_modulate(biome), 1)


static func _iso_arch(parent: Node2D, biome: BiomeDefinition, pos: Vector2, facing: String, tile_scale: float) -> void:
	var spr := _place_iso_piece(parent, _IllustratedSet.wall_tex(facing), pos, tile_scale * 0.92, Color(0.55, 0.9, 1.0, 1), 1)
	if spr:
		var light := PointLight2D.new()
		light.position = pos + Vector2(0, -20)
		light.texture = ArtBank.radial_light()
		light.color = Color(0.4, 0.85, 1.0, 1)
		light.energy = 0.85
		light.texture_scale = 1.6
		parent.add_child(light)


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
	s.modulate = modulate
	s.z_index = z
	parent.add_child(s)
	ArtBank.fit_height(s, 102.0 * tile_scale, true)
	return s


static func _wall_modulate(biome: BiomeDefinition) -> Color:
	if biome == null:
		return Color.WHITE
	match biome.biome_id:
		GameplayEnums.BiomeId.DATA_CENTER, GameplayEnums.BiomeId.GATEWAY:
			return Color(0.82, 0.92, 1.0, 1)
		GameplayEnums.BiomeId.LANDFILL, GameplayEnums.BiomeId.WASTELAND:
			return Color(0.95, 0.88, 0.72, 1)
		GameplayEnums.BiomeId.JUNGLE, GameplayEnums.BiomeId.TAIGA:
			return Color(0.78, 0.92, 0.7, 1)
		_:
			return Color.WHITE


static func _add_lighting(arena: Node2D, biome: BiomeDefinition) -> void:
	_clear_named(arena, "Atmosphere")
	var layer := Node2D.new()
	layer.name = "Atmosphere"
	arena.add_child(layer)
	var grade := CanvasModulate.new()
	grade.name = "Grade"
	## Slight cool night, never a crushed voxel wash.
	grade.color = Color(0.90, 0.92, 0.97, 1)
	if biome and (biome.biome_id == GameplayEnums.BiomeId.LANDFILL or biome.biome_id == GameplayEnums.BiomeId.WASTELAND):
		grade.color = Color(0.92, 0.90, 0.86, 1)
	layer.add_child(grade)
	var tex := ArtBank.radial_light()
	var moon := PointLight2D.new()
	moon.name = "Moon"
	moon.position = Vector2(-80, -220)
	moon.texture = tex
	moon.color = Color(0.55, 0.72, 1.0, 1)
	moon.energy = 0.55
	moon.texture_scale = 5.2
	layer.add_child(moon)
	var neon := PointLight2D.new()
	neon.name = "Neon"
	neon.position = Vector2(220, 40)
	neon.texture = tex
	neon.color = Color(0.35, 0.85, 1.0, 1)
	neon.energy = 0.7 if not _is_boss_room() else 0.9
	neon.texture_scale = 2.8
	layer.add_child(neon)
	if _is_boss_room():
		var ember := PointLight2D.new()
		ember.position = Vector2(0, 20)
		ember.texture = tex
		ember.color = Color(0.95, 0.22, 0.18, 1)
		ember.energy = 0.85
		ember.texture_scale = 3.2
		layer.add_child(ember)
	_add_vignette(arena)


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
	grad.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0.02, 0.03, 0.05, 0.38)])
	grad.offsets = PackedFloat32Array([0.42, 1.0])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 256
	tex.height = 256
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	rect.texture = tex
	canvas.add_child(rect)


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
