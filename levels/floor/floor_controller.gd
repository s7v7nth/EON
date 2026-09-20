class_name FloorController
extends Node2D
## One physical floor: irregular islands, offset doors, hallways, per-room combat.

const _FloorPlacer := preload("res://systems/worldgen/floor_placer.gd")
const _Island := preload("res://levels/floor/room_island.gd")

const ENEMY_SCENE := preload("res://entities/enemies/dummy/enemy_dummy.tscn")
const DEFAULT_WAVES := preload("res://resources/waves/default_waves.tres")
const BOSS_WAVE_SET := preload("res://resources/waves/boss_encounter_waves.tres")
const HIVE_WAVE_SET := preload("res://resources/waves/hive_boss_waves.tres")
const _ReturnHive := preload("res://systems/enemies/behaviors/behavior_return_to_hive.gd")
const BLISTER := preload("res://resources/enemies/blister_host.tres")
const PLAYER_SCENE := preload("res://entities/player/player.tscn")

@export var use_faction_weights: bool = true

var _islands: Dictionary = {}
var _current: Node2D
var _wave_index: int = -1
var _alive_enemies: int = 0
var _spawning: bool = false
var _room_cleared: bool = false
var _revisit_cleared: bool = false
var _spawn_cursor: int = 0
var _elite_presented: bool = false
var _exit_latch: bool = false
var _player: Player


func _ready() -> void:
	SignalBus.enemy_died.connect(_on_enemy_died)
	SignalBus.enemy_despawned.connect(_on_enemy_died)
	SignalBus.enemy_spawned.connect(_on_enemy_spawned)
	SignalBus.player_died.connect(_on_player_died)
	if RunState.dungeon == null:
		if not RunState.route_picked:
			var routes := RunState.get_available_routes()
			if not routes.is_empty():
				RunState.choose_route(routes[0])
	_build_floor()
	_place_player()
	_tune_camera()
	call_deferred("_enter_current_room")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if key.physical_keycode == KEY_F9:
			force_clear_room()
			get_viewport().set_input_as_handled()
		elif key.physical_keycode == KEY_E:
			if _try_clerk_talk():
				get_viewport().set_input_as_handled()


func _try_clerk_talk() -> bool:
	if _current == null or _player == null:
		return false
	var npc := _current.find_child("Remnant", true, false)
	if npc == null or not npc.has_method("speak"):
		return false
	if _player.global_position.distance_to((npc as Node2D).global_position) > 280.0:
		return false
	npc.call("speak")
	return true


func _build_floor() -> void:
	var graph := RunState.dungeon
	if graph == null:
		push_error("FloorController: no dungeon graph")
		return
	if graph.get_room(graph.start_coord) and graph.get_room(graph.start_coord).world_origin == Vector2.INF:
		_FloorPlacer.place(graph)
	var islands := Node2D.new()
	islands.name = "Islands"
	islands.y_sort_enabled = true
	add_child(islands)
	for room in graph.all_rooms():
		var island := _Island.new()
		island.setup(room)
		islands.add_child(island)
		_islands[room.coord] = island
		island.door_crossed.connect(_on_door_crossed)
		if island.occupancy:
			island.occupancy.body_entered.connect(_on_occupancy.bind(island))
	_build_hallways()
	_add_floor_atmosphere()
	var start: Node2D = _islands.get(graph.start_coord)
	_current = start


func _build_hallways() -> void:
	var root := Node2D.new()
	root.name = "Hallways"
	root.z_index = -18
	add_child(root)
	var seen: Dictionary = {}
	var graph := RunState.dungeon
	for room in graph.all_rooms():
		for dir in room.door_dirs():
			var key := "%d,%d:%d,%d" % [room.coord.x, room.coord.y, dir.x, dir.y]
			var rkey := "%d,%d:%d,%d" % [room.coord.x + dir.x, room.coord.y + dir.y, -dir.x, -dir.y]
			if seen.has(key) or seen.has(rkey):
				continue
			seen[key] = true
			var neighbor: DungeonRoom = graph.get_room(room.coord + dir)
			if neighbor == null:
				continue
			_make_hall(root, room, neighbor, dir)


func _make_hall(root: Node2D, a: DungeonRoom, b: DungeonRoom, dir: Vector2i) -> void:
	var p0 := _FloorPlacer.door_world(a, dir)
	var p1 := _FloorPlacer.door_world(b, -dir)
	var delta := p1 - p0
	var length := delta.length()
	if length < 8.0:
		return
	var mid := (p0 + p1) * 0.5
	var hall := Node2D.new()
	hall.position = mid
	hall.rotation = delta.angle()
	root.add_child(hall)
	var floor := Polygon2D.new()
	floor.z_index = -19
	var hw := 78.0
	var hl := length * 0.5
	floor.polygon = PackedVector2Array([
		Vector2(-hl, -hw), Vector2(hl, -hw), Vector2(hl, hw), Vector2(-hl, hw)
	])
	floor.color = Color(0.10, 0.08, 0.09, 1)
	hall.add_child(floor)
	var tile := Sprite2D.new()
	tile.texture = ArtBank.illustrated("floor_ruin")
	if tile.texture:
		tile.centered = true
		tile.z_index = -18
		tile.modulate = Color(1.06, 0.98, 0.9, 1)
		hall.add_child(tile)
		var sz := ArtBank.apply_opaque_region(tile)
		tile.scale = Vector2((length + 36.0) / maxf(sz.x, 1.0), (hw * 2.2) / maxf(sz.y, 1.0))
	var walls := StaticBody2D.new()
	walls.collision_layer = 1
	walls.collision_mask = 0
	hall.add_child(walls)
	for side in [-1, 1]:
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(length, 18.0)
		shape.shape = rect
		shape.position = Vector2(0, float(side) * (hw + 10.0))
		walls.add_child(shape)


func _add_floor_atmosphere() -> void:
	if get_node_or_null("Atmosphere") != null:
		return
	var layer := Node2D.new()
	layer.name = "Atmosphere"
	add_child(layer)
	var grade := CanvasModulate.new()
	grade.name = "Grade"
	grade.color = Color(0.90, 0.92, 0.97, 1)
	layer.add_child(grade)
	var moon := PointLight2D.new()
	moon.name = "Moon"
	moon.position = Vector2(-40, -180)
	moon.texture = ArtBank.radial_light()
	moon.color = Color(0.5, 0.72, 1.0, 1)
	moon.energy = 0.5
	moon.texture_scale = 6.0
	layer.add_child(moon)
	_add_floor_vignette()


func _add_floor_vignette() -> void:
	if get_node_or_null("VignetteLayer") != null:
		return
	var canvas := CanvasLayer.new()
	canvas.name = "VignetteLayer"
	canvas.layer = 4
	add_child(canvas)
	var rect := TextureRect.new()
	rect.name = "Vignette"
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0.02, 0.03, 0.06, 0.36)])
	grad.offsets = PackedFloat32Array([0.44, 1.0])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 256
	tex.height = 256
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	rect.texture = tex
	canvas.add_child(rect)


func _place_player() -> void:
	var entities := get_node_or_null("Entities") as Node2D
	if entities == null:
		entities = Node2D.new()
		entities.name = "Entities"
		entities.y_sort_enabled = true
		add_child(entities)
	_player = entities.get_node_or_null("Player") as Player
	if _player == null:
		_player = PLAYER_SCENE.instantiate() as Player
		_player.name = "Player"
		entities.add_child(_player)
	if _current:
		var local := Vector2(-80, 40)
		if not bool(_current.call("contains_point", _current.position + local)):
			local = Vector2(0, 20)
		_player.global_position = _current.position + local
	RunState.apply_to_player(_player)


func _tune_camera() -> void:
	if _player == null:
		return
	var cam := _player.get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		cam = Camera2D.new()
		cam.name = "Camera2D"
		_player.add_child(cam)
	cam.enabled = true
	cam.make_current()
	cam.limit_enabled = false
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 7.5


func _on_occupancy(body: Node2D, island: Node2D) -> void:
	if body is not Player:
		return
	if island == _current:
		return
	_switch_room(island)


func _switch_room(island: Node2D) -> void:
	_current = island
	var room: DungeonRoom = island.get("room") as DungeonRoom
	if room == null:
		return
	RunState.current_coord = room.coord
	if RunState.dungeon:
		RunState.room_index = RunState.dungeon.index_of(room.coord)
	RunState.begin_room()
	_wave_index = -1
	_alive_enemies = 0
	_spawning = false
	_elite_presented = false
	_spawn_cursor = 0
	_exit_latch = false
	_room_cleared = room.cleared
	_revisit_cleared = room.cleared
	_apply_biome(room)
	if room.cleared:
		island.set_doors_locked(false)
		return
	_try_start_combat()


func _enter_current_room() -> void:
	if _current == null:
		return
	_switch_room(_current)


func _apply_biome(room: DungeonRoom) -> void:
	if room.biome:
		RunState.current_biome = room.biome
		SignalBus.biome_changed.emit(room.biome.biome_id)


func _try_start_combat() -> void:
	if not RunState.architecture_picked:
		return
	if _wave_index >= 0 or _room_cleared or _spawning:
		return
	if _current == null or _current.get("room") == null:
		return
	var room: DungeonRoom = _current.get("room") as DungeonRoom
	if room.cleared:
		_current.call("set_doors_locked", false)
		_room_cleared = true
		return
	match room.kind:
		DungeonRoom.RoomKind.SHOP, DungeonRoom.RoomKind.TREASURE, DungeonRoom.RoomKind.SECRET:
			_start_special(room.kind)
			return
		DungeonRoom.RoomKind.REMNANT:
			_open_quiet_room()
			return
		_:
			pass
	_current.call("set_doors_locked", true)
	_start_first_wave()


func _open_quiet_room() -> void:
	_room_cleared = true
	_wave_index = 0
	if _current:
		_current.call("set_doors_locked", false)
		var droom: DungeonRoom = _current.get("room") as DungeonRoom
		if droom:
			droom.cleared = true
			droom.explored = true
	if _player and _player.status:
		_player.status.clear_all()
	if _player and _player.health:
		_player.health.heal(_player.health.get_max_health() * 0.35)
	SignalBus.room_cleared.emit()


func _start_special(kind: int) -> void:
	_wave_index = 0
	RunState.grant_special_room_loot(kind)
	if kind == DungeonRoom.RoomKind.SHOP and RunState.gold < 22:
		RunState.add_gold(22 - RunState.gold)
	_spawn_orbs(kind)
	_open_quiet_room()


func _spawn_orbs(kind: int) -> void:
	if _current == null:
		return
	var count := 3 if kind == DungeonRoom.RoomKind.SHOP else 1
	var offers := RunState.roll_boon_offers(count)
	var orbs: Array[ArtifactOrb] = []
	var spacing := 160.0
	var start_x := -spacing * float(offers.size() - 1) * 0.5
	for i in offers.size():
		var pos := _current.position + Vector2(start_x + spacing * float(i), 36.0)
		orbs.append(ArtifactOrb.spawn_at(_current.get("entities") as Node2D, pos, offers[i]))
	if kind != DungeonRoom.RoomKind.SHOP:
		return
	for orb in orbs:
		orb.exclusive_group = orbs
		orb.price_gold = RunState.shop_price_for(orb.preset_upgrade)
		orb._refresh_price()


func _wave_set_for(room: DungeonRoom) -> WaveSet:
	if room.boss_id == &"hive":
		return HIVE_WAVE_SET
	if room.kind == DungeonRoom.RoomKind.BOSS or room.boss_id == &"warden":
		return BOSS_WAVE_SET
	if room.biome and room.biome.wave_set:
		return room.biome.wave_set
	return DEFAULT_WAVES


func _start_first_wave() -> void:
	var waves: WaveSet = _wave_set_for(_current.get("room") as DungeonRoom)
	if waves == null or waves.wave_count() == 0:
		force_clear_room()
		return
	_begin_wave(waves, 0)


func _begin_wave(waves: WaveSet, index: int) -> void:
	_wave_index = index
	var wave := waves.get_wave(index)
	if wave == null:
		_on_all_waves_cleared()
		return
	_spawning = true
	SignalBus.wave_started.emit(index, waves.wave_count())
	if wave.delay > 0.0:
		await get_tree().create_timer(wave.delay).timeout
		if not is_inside_tree():
			return
	_spawn_wave(wave)
	_spawning = false
	if _alive_enemies <= 0:
		_on_wave_cleared(waves)


func _spawn_wave(wave: WaveDefinition) -> void:
	var points: Array = _current.call("spawn_markers") if _current else []
	if points.is_empty():
		return
	for group in wave.spawns:
		if group == null or group.enemy_scene == null:
			continue
		for _i in group.count:
			var marker: Node2D = points[_spawn_cursor % points.size()]
			_spawn_cursor += 1
			var enemy := group.enemy_scene.instantiate() as Node2D
			(_current.get("entities") as Node2D).add_child(enemy)
			var def := group.enemy_definition
			var cur_room: DungeonRoom = _current.get("room") as DungeonRoom
			var is_boss := def != null and (def.is_boss or def.boss_id != StringName())
			if is_boss:
				enemy.global_position = _boss_spawn_at()
			else:
				enemy.global_position = marker.global_position
			if not is_boss and cur_room and cur_room.is_elite and not _elite_presented and BLISTER:
				def = BLISTER
			if not is_boss and use_faction_weights and RunState.current_biome and RunState.room_index > 0:
				if RunState.spawn_roll() < 0.35:
					def = RunState.pick_enemy_for_biome(def)
			if def != null and enemy.has_method("apply_definition"):
				enemy.call("apply_definition", def)
			if enemy.has_method("apply_elite"):
				if group.is_elite or (cur_room and cur_room.is_elite and not _elite_presented):
					enemy.call("apply_elite", group.elite_hp_mult, group.elite_move_mult, group.elite_action_speed)
					_elite_presented = true
			if enemy is EnemyDummy:
				(enemy as EnemyDummy).apply_route_pressure(RunState.combat_pressure())
				if (enemy as EnemyDummy).definition and (enemy as EnemyDummy).definition.is_boss:
					_present_boss(enemy as EnemyDummy)
			_alive_enemies += 1
	_alert_player()


func _boss_spawn_at() -> Vector2:
	if _current == null:
		return Vector2.ZERO
	var local := Vector2(0, 18)
	if _current.has_method("contains_point") and not bool(_current.call("contains_point", _current.position + local)):
		local = Vector2(48, 36)
	return _current.position + local


func _present_boss(enemy: EnemyDummy) -> void:
	var visual := enemy.get_node_or_null("Visual") as Node2D
	if visual and enemy.definition and enemy.definition.boss_id == &"hive":
		visual.scale = Vector2(1.18, 1.18)
		visual.modulate = Color(0.78, 0.82, 0.42, 1)
	CameraFx.add_trauma(0.65)
	CameraFx.flash(Color(0.7, 0.12, 0.1, 0.5), 0.28)
	if FeelAudio:
		FeelAudio.play_boss()
	var name_txt := "The Hive"
	if enemy.definition and enemy.definition.display_name != "":
		name_txt = enemy.definition.display_name
	SignalBus.boss_spawned.emit(name_txt)
	if enemy.health:
		SignalBus.boss_health_changed.emit(
			enemy.health.current_health, enemy.health.get_max_health(), name_txt
		)


func _alert_player() -> void:
	if _player == null or _current == null:
		return
	var ents: Node2D = _current.get("entities") as Node2D
	if ents == null:
		return
	for child in ents.get_children():
		if child is EnemyDummy:
			(child as EnemyDummy).receive_room_alert(_player)


func _on_enemy_spawned(_enemy: Node) -> void:
	if _room_cleared:
		return
	_alive_enemies += 1


func _on_enemy_died(_enemy: Node) -> void:
	_alive_enemies = maxi(_alive_enemies - 1, 0)
	if _spawning:
		return
	if _alive_enemies <= 0 and _wave_index >= 0 and not _room_cleared:
		_on_wave_cleared(_wave_set_for(_current.get("room") as DungeonRoom) if _current else DEFAULT_WAVES)


func _on_wave_cleared(waves: WaveSet) -> void:
	SignalBus.wave_cleared.emit(_wave_index)
	var next := _wave_index + 1
	if waves == null or next >= waves.wave_count():
		_on_all_waves_cleared()
	else:
		_begin_wave(waves, next)


func _on_all_waves_cleared() -> void:
	_room_cleared = true
	if _player and _player.status:
		_player.status.clear_all()
	if _player and _player.health:
		_player.health.heal(_player.health.get_max_health() * 0.08)
	RunState.mark_current_room_cleared()
	RunState.grant_loot_for_room_rank()
	if _current:
		_current.call("set_doors_locked", false)
	SignalBus.room_cleared.emit()


func force_clear_room() -> void:
	_spawning = false
	_alive_enemies = 0
	if _current:
		var ents: Node2D = _current.get("entities") as Node2D
		if ents:
			for child in ents.get_children():
				if child is EnemyDummy:
					child.queue_free()
	_on_all_waves_cleared()


func _on_door_crossed(island: Node2D, _dir: Vector2i, body: Node2D) -> void:
	if body is not Player:
		return
	var room: DungeonRoom = island.get("room") as DungeonRoom
	if room == null or not room.cleared:
		return
	if room.rewarded:
		return
	if room.kind == DungeonRoom.RoomKind.REMNANT:
		room.rewarded = true
		return
	room.rewarded = true
	if _exit_latch:
		return
	_exit_latch = true
	SignalBus.exit_reached.emit()


func _on_player_died() -> void:
	_spawning = true
