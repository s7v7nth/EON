class_name IllustratedSet
extends RefCounted
## EON dying-city pack. Wet concrete, shopfronts, readable night — not acid floors, not dungeon ruin, not a 1:1 street clone.

const TILE_SCALE := 1.0
const TILE_W := 256.0
const TILE_H := 128.0


static func floor_tex(rng: RandomNumberGenerator, _want_toxic: bool = false) -> Texture2D:
	## Wet concrete only. Acid tiles are hazards / boss tells, never the room floor.
	var roll := rng.randf() if rng else randf()
	if roll < 0.38:
		var city := ArtBank.illustrated("floor_city")
		if city:
			return city
	if roll < 0.7:
		var city_b := ArtBank.illustrated("floor_city_b")
		if city_b:
			return city_b
	var city_c := ArtBank.illustrated("floor_city_c")
	if city_c:
		return city_c
	var b := ArtBank.illustrated("floor_street_b")
	if b:
		return b
	return ArtBank.illustrated("floor_ruin_b")


static func place_floor(
	parent: Node2D,
	biome: BiomeDefinition,
	allow: Callable,
	seed_value: int = 1
) -> void:
	if parent == null:
		return
	var tiles := Node2D.new()
	tiles.name = "FloorTiles"
	tiles.z_index = -2
	parent.add_child(tiles)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for ix in range(-12, 13):
		for iy in range(-11, 12):
			var p := Vector2((ix - iy) * TILE_W * 0.5, (ix + iy) * TILE_H * 0.5)
			if not bool(allow.call(p)):
				continue
			var tex := floor_tex(rng, false)
			_floor_sprite(tiles, tex, p)


static func place_dressing(
	parent: Node2D,
	biome: BiomeDefinition,
	seed_value: int = 1,
	keep_center_clear: bool = false
) -> void:
	if parent == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	_scrap(parent, rng, biome, keep_center_clear)
	_lamps(parent, rng, biome, keep_center_clear)
	_pylons(parent, rng, biome, keep_center_clear)
	_ruin_growth(parent, rng, biome, keep_center_clear)


static func wall_tex(facing: String) -> Texture2D:
	var tex := ArtBank.illustrated("wall_slab_%s" % facing)
	if tex:
		return tex
	if facing in ["NE", "NW"]:
		tex = ArtBank.illustrated("wall_slab_N")
		if tex:
			return tex
	return ArtBank.illustrated("wall_slab_SE")


static func dusk_sky() -> Texture2D:
	return ArtBank.illustrated("sky_dusk")


static func _toxic_chance(_biome: BiomeDefinition) -> float:
	return 0.0


static func _is_data(biome: BiomeDefinition) -> bool:
	return biome != null and (
		biome.biome_id == GameplayEnums.BiomeId.DATA_CENTER
		or biome.biome_id == GameplayEnums.BiomeId.GATEWAY
	)


static func _is_organic(biome: BiomeDefinition) -> bool:
	return biome != null and (
		biome.biome_id == GameplayEnums.BiomeId.LANDFILL
		or biome.biome_id == GameplayEnums.BiomeId.WASTELAND
		or biome.biome_id == GameplayEnums.BiomeId.JUNGLE
		or biome.biome_id == GameplayEnums.BiomeId.TAIGA
	)


static func _scrap(parent: Node2D, rng: RandomNumberGenerator, biome: BiomeDefinition, keep_center_clear: bool) -> void:
	var tex := ArtBank.illustrated("prop_scrap")
	var spots: Array[Vector2] = [
		Vector2(-520, -180), Vector2(510, -150), Vector2(-470, 210),
		Vector2(490, 190), Vector2(-220, -310), Vector2(240, 250)
	]
	if _is_data(biome):
		spots = [Vector2(-540, -40), Vector2(530, 50), Vector2(-40, 280)]
	for i in spots.size():
		var p: Vector2 = spots[i]
		if keep_center_clear and p.length() < 190.0:
			continue
		p += Vector2(rng.randf_range(-22, 22), rng.randf_range(-12, 12))
		var spr := ArtBank.add_fitted(parent, tex, p, rng.randf_range(78.0, 118.0), 3, true)
		if spr:
			spr.modulate = Color.WHITE


static func _lamps(parent: Node2D, rng: RandomNumberGenerator, biome: BiomeDefinition, keep_center_clear: bool) -> void:
	var tex := ArtBank.illustrated("prop_lamp")
	var spots: Array[Vector2] = [Vector2(-380, 40), Vector2(410, -30), Vector2(60, -260)]
	if _is_data(biome):
		spots = [Vector2(-300, 80)]
	for p in spots:
		if keep_center_clear and p.length() < 160.0:
			continue
		p += Vector2(rng.randf_range(-10, 10), rng.randf_range(-8, 8))
		ArtBank.add_fitted(parent, tex, p, rng.randf_range(110.0, 138.0), 4, true)


static func _pylons(parent: Node2D, rng: RandomNumberGenerator, biome: BiomeDefinition, keep_center_clear: bool) -> void:
	if not _is_data(biome) and biome and biome.biome_id != GameplayEnums.BiomeId.MALL:
		if rng.randf() > 0.35:
			return
	var tex := ArtBank.illustrated("prop_pylon")
	var spots: Array[Vector2] = [Vector2(-560, -20), Vector2(570, 10)]
	if _is_data(biome):
		spots = [Vector2(-580, -30), Vector2(590, 20), Vector2(20, -300)]
	for p in spots:
		if keep_center_clear and p.length() < 170.0:
			continue
		ArtBank.add_fitted(parent, tex, p, rng.randf_range(128.0, 168.0), 4, true)


static func _ruin_growth(parent: Node2D, rng: RandomNumberGenerator, biome: BiomeDefinition, keep_center_clear: bool) -> void:
	if not _is_organic(biome):
		return
	var tex := ArtBank.illustrated("dead_tree")
	var spots: Array[Vector2] = [Vector2(-600, -160), Vector2(620, -140), Vector2(-90, 300)]
	for p in spots:
		if keep_center_clear and p.length() < 200.0:
			continue
		if rng.randf() < 0.22:
			continue
		ArtBank.add_fitted(parent, tex, p, rng.randf_range(140.0, 190.0), 3, true)


static func _toxic_pools(_parent: Node2D, _rng: RandomNumberGenerator, _biome: BiomeDefinition, _keep_center_clear: bool = false) -> void:
	## Acid is a hazard tell, not room dressing.
	return


static func _floor_sprite(
	parent: Node2D,
	tex: Texture2D,
	pos: Vector2,
	width_scale: float = 1.0,
	z: int = 0
) -> Sprite2D:
	if parent == null or tex == null:
		return null
	var s := Sprite2D.new()
	s.texture = tex
	s.position = pos
	s.centered = true
	s.z_index = z
	s.modulate = Color.WHITE
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	parent.add_child(s)
	var sz := ArtBank.apply_opaque_region(s)
	var sc := (TILE_W * TILE_SCALE * width_scale) / maxf(sz.x, 1.0)
	s.scale = Vector2(sc, sc)
	return s


static func _point_light(parent: Node2D, pos: Vector2, color: Color, energy: float, tex_scale: float) -> void:
	var light := PointLight2D.new()
	light.position = pos
	light.texture = radial()
	light.color = color
	light.energy = energy
	light.texture_scale = tex_scale
	parent.add_child(light)


static func radial() -> Texture2D:
	return ArtBank.radial_light()
