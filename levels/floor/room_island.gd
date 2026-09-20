class_name RoomIsland
extends Node2D
## One irregular physical room: floor, walls with offset doors, occupancy.

const _IllustratedSet := preload("res://systems/worldgen/illustrated_set.gd")
const _RoomFootprint := preload("res://systems/worldgen/room_footprint.gd")
const _RemnantNpc := preload("res://entities/props/remnant_npc.gd")

const DOOR_GAP := 196.0
const WALL_THICK := 32.0

var room: DungeonRoom
var occupancy: Area2D
var entities: Node2D
var spawn_root: Node2D
var blockers: Dictionary = {} ## Vector2i → StaticBody2D
var door_sprites: Dictionary = {}
signal door_crossed(island: Node2D, dir: Vector2i, body: Node2D)

var _poly: PackedVector2Array = PackedVector2Array()


func setup(src: DungeonRoom) -> void:
	room = src
	if room.footprint == null:
		room.footprint = _RoomFootprint.make(room.footprint_id)
	position = room.world_origin
	var lp: PackedVector2Array = room.footprint.local_poly
	_poly = lp
	name = "Island_%d_%d" % [room.coord.x, room.coord.y]
	y_sort_enabled = true
	_build_floor()
	_build_walls()
	_build_occupancy()
	_build_spawns()
	entities = Node2D.new()
	entities.name = "Entities"
	entities.y_sort_enabled = true
	add_child(entities)
	_dress()
	if room.remnant or room.kind == DungeonRoom.RoomKind.REMNANT:
		_spawn_remnant()


func contains_point(world: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(world - position, _poly)


func spawn_markers() -> Array[Node2D]:
	var out: Array[Node2D] = []
	if spawn_root == null:
		return out
	for child in spawn_root.get_children():
		if child is Node2D:
			out.append(child as Node2D)
	return out


func set_doors_locked(locked: bool) -> void:
	for dir in blockers.keys():
		var body: StaticBody2D = blockers[dir]
		if body:
			body.collision_layer = 1 if locked else 0
			body.visible = locked
		var sprs: Variant = door_sprites.get(dir)
		if sprs is Array:
			for spr in sprs:
				var sprite := spr as Sprite2D
				if sprite == null:
					continue
				sprite.modulate = Color(0.45, 0.9, 1.0, 1) if not locked else Color(0.35, 0.22, 0.2, 1)


func door_local(dir: Vector2i) -> Vector2:
	return room.footprint.door_local(dir, room.door_offset(dir))


func _build_floor() -> void:
	var floor := Polygon2D.new()
	floor.name = "Floor"
	floor.z_index = -20
	floor.polygon = _poly
	floor.color = Color(0.05, 0.045, 0.055, 1)
	add_child(floor)


func _build_walls() -> void:
	var walls := StaticBody2D.new()
	walls.name = "Walls"
	walls.collision_layer = 1
	walls.collision_mask = 0
	add_child(walls)
	var n := _poly.size()
	for i in n:
		var a := _poly[i]
		var b := _poly[(i + 1) % n]
		_add_edge_with_doors(walls, a, b)
	for dir in room.door_dirs():
		_add_door_prop(dir)
		_add_blocker(dir)
		_add_door_sensor(dir)


func _add_edge_with_doors(walls: StaticBody2D, a: Vector2, b: Vector2) -> void:
	var gaps: Array[Vector2] = []
	for dir in room.door_dirs():
		var dpos := door_local(dir)
		if _point_on_segment(dpos, a, b, 48.0):
			gaps.append(dpos)
	if gaps.is_empty():
		_add_segment(walls, a, b)
		return
	# Split the wall around each door gap.
	var along := (b - a)
	var len := along.length()
	if len < 8.0:
		return
	var dirv := along / len
	var cuts: Array[float] = [0.0, 1.0]
	for g in gaps:
		var t := clampf((g - a).dot(dirv) / len, 0.0, 1.0)
		var half := (DOOR_GAP * 0.5) / len
		cuts.append(clampf(t - half, 0.0, 1.0))
		cuts.append(clampf(t + half, 0.0, 1.0))
	cuts.sort()
	var i := 0
	while i + 1 < cuts.size():
		var t0: float = cuts[i]
		var t1: float = cuts[i + 1]
		if t1 - t0 > 0.02:
			_add_segment(walls, a.lerp(b, t0), a.lerp(b, t1))
		i += 2


func _add_segment(walls: StaticBody2D, a: Vector2, b: Vector2) -> void:
	var mid := (a + b) * 0.5
	var delta := b - a
	var length := delta.length()
	if length < 6.0:
		return
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(length, WALL_THICK)
	shape.shape = rect
	shape.position = mid
	shape.rotation = delta.angle()
	walls.add_child(shape)


func _add_door_prop(dir: Vector2i) -> void:
	## Posts sit beside the hole so the gap itself stays visually walkable.
	var tangent := Vector2(float(-dir.y), float(dir.x))
	var posts: Array[Sprite2D] = []
	for side in [-1, 1]:
		var spr := Sprite2D.new()
		spr.name = "DoorPost_%d_%d_%d" % [dir.x, dir.y, side]
		spr.centered = true
		spr.z_index = 2
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		spr.position = door_local(dir) + tangent * (DOOR_GAP * 0.46) * float(side)
		spr.texture = _IllustratedSet.wall_tex(_facing_name(dir))
		ArtBank.fit_height(spr, 88.0, true)
		spr.modulate = Color(0.45, 0.9, 1.0, 1)
		add_child(spr)
		posts.append(spr)
	door_sprites[dir] = posts
	_add_door_sill(dir)


func _add_door_sill(dir: Vector2i) -> void:
	var p := door_local(dir)
	var outward := Vector2(float(dir.x), float(dir.y))
	var tangent := Vector2(float(-dir.y), float(dir.x))
	var half := DOOR_GAP * 0.46
	var poly := Polygon2D.new()
	poly.name = "Sill_%d_%d" % [dir.x, dir.y]
	poly.z_index = -16
	poly.color = Color(0.13, 0.11, 0.12, 1)
	poly.polygon = PackedVector2Array([
		p + tangent * -half + outward * -22.0,
		p + tangent * half + outward * -22.0,
		p + tangent * half + outward * 78.0,
		p + tangent * -half + outward * 78.0
	])
	add_child(poly)
	var tile := Sprite2D.new()
	tile.texture = ArtBank.illustrated("floor_ruin")
	if tile.texture:
		tile.centered = true
		tile.z_index = -15
		tile.position = p + outward * 36.0
		tile.modulate = Color(1.05, 0.98, 0.92, 1)
		add_child(tile)
		var sz := ArtBank.apply_opaque_region(tile)
		tile.scale = Vector2((DOOR_GAP + 24.0) / maxf(sz.x, 1.0), 110.0 / maxf(sz.y, 1.0))


func _add_blocker(dir: Vector2i) -> void:
	var body := StaticBody2D.new()
	body.name = "Blocker_%d_%d" % [dir.x, dir.y]
	## Quiet rooms never start a fight, so doors stay walkable from the hallway
	## until occupancy locks a combat room.
	body.collision_layer = 0
	body.collision_mask = 0
	body.visible = false
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	if dir.x == 0:
		rect.size = Vector2(DOOR_GAP, 28.0)
	else:
		rect.size = Vector2(28.0, DOOR_GAP)
	shape.shape = rect
	body.position = door_local(dir)
	body.add_child(shape)
	add_child(body)
	blockers[dir] = body


func _add_door_sensor(dir: Vector2i) -> void:
	var area := Area2D.new()
	area.name = "DoorSense_%d_%d" % [dir.x, dir.y]
	area.collision_layer = 0
	area.collision_mask = 2
	area.monitoring = true
	area.monitorable = false
	area.position = door_local(dir)
	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	if dir.x == 0:
		rect.size = Vector2(DOOR_GAP - 8.0, 46.0)
	else:
		rect.size = Vector2(46.0, DOOR_GAP - 8.0)
	col.shape = rect
	area.add_child(col)
	area.body_entered.connect(func(body: Node2D) -> void:
		door_crossed.emit(self, dir, body)
	)
	add_child(area)


func _build_occupancy() -> void:
	occupancy = Area2D.new()
	occupancy.name = "Occupancy"
	occupancy.collision_layer = 0
	occupancy.collision_mask = 2
	occupancy.monitoring = true
	occupancy.monitorable = false
	var col := CollisionPolygon2D.new()
	col.polygon = _poly
	occupancy.add_child(col)
	add_child(occupancy)


func _build_spawns() -> void:
	spawn_root = Node2D.new()
	spawn_root.name = "SpawnPoints"
	add_child(spawn_root)
	var pts: Array[Vector2] = [
		Vector2(160, -80), Vector2(240, 90), Vector2(-180, 120), Vector2(-80, -140),
		Vector2(40, 160), Vector2(-240, -40)
	]
	var i := 0
	for p in pts:
		if not Geometry2D.is_point_in_polygon(p, _poly):
			continue
		var m := Marker2D.new()
		m.name = "Spawn%d" % i
		m.position = p
		spawn_root.add_child(m)
		i += 1
	if spawn_root.get_child_count() == 0:
		var m := Marker2D.new()
		m.position = Vector2(80, 40)
		spawn_root.add_child(m)


func _dress() -> void:
	var root := Node2D.new()
	root.name = "Dressing"
	root.z_index = -12
	add_child(root)
	var seed_value := int(room.coord.x * 7919 + room.coord.y * 104729 + 11)
	var sky := _IllustratedSet.dusk_sky()
	if sky:
		var bg := Sprite2D.new()
		bg.name = "NightSky"
		bg.texture = sky
		bg.centered = true
		bg.z_index = -18
		bg.scale = Vector2(1.7, 1.7)
		bg.modulate = Color.WHITE
		bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		root.add_child(bg)
	_IllustratedSet.place_floor(
		root,
		room.biome,
		func(p: Vector2) -> bool: return Geometry2D.is_point_in_polygon(p, _poly),
		seed_value
	)
	_add_edge_walls(root)
	_IllustratedSet.place_dressing(
		root,
		room.biome,
		seed_value + 17,
		room.kind == DungeonRoom.RoomKind.BOSS
	)
	if room.kind == DungeonRoom.RoomKind.BOSS:
		_add_boss_stain(root)


func _add_edge_walls(root: Node2D) -> void:
	var n := _poly.size()
	for i in n:
		var a := _poly[i]
		var b := _poly[(i + 1) % n]
		var mid := (a + b) * 0.5
		var skip := false
		for dir in room.door_dirs():
			if _point_on_segment(door_local(dir), a, b, 40.0):
				skip = true
				break
		if skip:
			continue
		if rng_skip(mid):
			continue
		var spr := Sprite2D.new()
		spr.centered = true
		spr.z_index = -1
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var facing := (b - a).orthogonal().normalized()
		spr.texture = _IllustratedSet.wall_tex(ArtBank.dir4_from(facing))
		if spr.texture:
			ArtBank.fit_height(spr, 88.0, true)
			spr.position = mid
			spr.modulate = Color.WHITE
			root.add_child(spr)


func rng_skip(mid: Vector2) -> bool:
	return int(absf(mid.x) + absf(mid.y)) % 3 == 0


func _facing_name(dir: Vector2i) -> String:
	if dir.y < 0:
		return "N"
	if dir.y > 0:
		return "S"
	if dir.x > 0:
		return "E"
	return "W"


func _add_boss_stain(root: Node2D) -> void:
	var stain := Sprite2D.new()
	stain.texture = ArtBank.illustrated("floor_toxic")
	if stain.texture == null:
		return
	stain.centered = true
	stain.modulate = Color(0.95, 0.2, 0.18, 0.55)
	stain.scale = Vector2(1.4, 0.9)
	stain.z_index = -3
	root.add_child(stain)
	var glow := PointLight2D.new()
	glow.texture = ArtBank.radial_light()
	glow.color = Color(0.95, 0.18, 0.12, 1)
	glow.energy = 0.9
	glow.texture_scale = 2.8
	root.add_child(glow)


func _spawn_remnant() -> void:
	var npc := _RemnantNpc.new()
	npc.name = "Remnant"
	npc.position = Vector2(-40, -30)
	if not Geometry2D.is_point_in_polygon(npc.position, _poly):
		npc.position = Vector2(0, 20)
	add_child(npc)


func _point_on_segment(p: Vector2, a: Vector2, b: Vector2, slop: float) -> bool:
	var ab := b - a
	var len := ab.length()
	if len < 1.0:
		return p.distance_to(a) <= slop
	var t := clampf((p - a).dot(ab) / (len * len), 0.0, 1.0)
	return p.distance_to(a + ab * t) <= slop
