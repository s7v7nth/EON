class_name ArenaController
extends Node2D
## Spawns waves into Entities, tracks clears, emits SignalBus wave/run events.

const _RoomDresser = preload("res://levels/arena/room_dresser.gd")
const BOSS_WAVE_SET = preload("res://resources/waves/boss_encounter_waves.tres")

@export var wave_set: WaveSet
@export var biome: BiomeDefinition
@export var entities_path: NodePath = ^"Entities"
@export var spawn_points_path: NodePath = ^"SpawnPoints"
@export var player_path: NodePath = ^"Entities/Player"
@export var is_final_room: bool = false
@export var exit_marker_path: NodePath = ^"ExitMarker"
## When true, biome faction_weights may replace wave enemy definitions.
@export var use_faction_weights: bool = true

const DOOR_SIZE := Vector2(72, 40)
const DOOR_COLORS := {
	Vector2i(0, -1): Color(0.35, 0.7, 0.95, 0.75),
	Vector2i(1, 0): Color(0.35, 0.85, 0.55, 0.75),
	Vector2i(0, 1): Color(0.3, 0.75, 0.45, 0.75),
	Vector2i(-1, 0): Color(0.9, 0.7, 0.35, 0.75),
}

var _wave_index: int = -1
var _alive_enemies: int = 0
var _spawning: bool = false
var _room_cleared: bool = false
## True when this visit restores an already-cleared procedural room (no reward loop).
var _revisit_cleared: bool = false
## Door at the wall we spawned on; ignored until the player leaves it.
var _blocked_entry_dir: Vector2i = Vector2i.ZERO
var _exit_latch: bool = false
var _spawn_cursor: int = 0
var _door_nodes: Array[Area2D] = []

@onready var _entities: Node2D = get_node(entities_path)
@onready var _spawn_points: Node2D = get_node(spawn_points_path)


func _ready() -> void:
	SignalBus.enemy_died.connect(_on_enemy_died)
	SignalBus.enemy_spawned.connect(_on_enemy_spawned)
	SignalBus.player_died.connect(_on_player_died)
	SignalBus.route_chosen.connect(_on_route_chosen)
	SignalBus.architecture_changed.connect(_on_architecture_changed)
	_apply_biome()
	is_final_room = RunState.is_last_room()
	_place_player()
	_setup_exits()
	call_deferred("_try_start_combat")


func _on_route_chosen(_route_id: StringName) -> void:
	## Route pick happens after Arena _ready — rebuild biome paint + exits.
	_clear_live_enemies()
	_wave_index = -1
	_alive_enemies = 0
	_spawning = false
	_room_cleared = false
	_revisit_cleared = false
	_blocked_entry_dir = Vector2i.ZERO
	_exit_latch = false
	_spawn_cursor = 0
	_apply_biome()
	is_final_room = RunState.is_last_room()
	_setup_exits()
	_try_start_combat()


func _on_architecture_changed(_architecture_id: int) -> void:
	_try_start_combat()


func _try_start_combat() -> void:
	if not RunState.architecture_picked:
		return
	if _wave_index >= 0 or _room_cleared or _spawning:
		return
	if _current_room_already_cleared():
		_restore_cleared_room()
		return
	if _try_start_special_room():
		return
	_start_first_wave()


func _try_start_special_room() -> bool:
	if not RunState.is_procedural_run():
		return false
	var room := RunState.current_dungeon_room()
	if room == null:
		return false
	match room.kind:
		DungeonRoom.RoomKind.SHOP, DungeonRoom.RoomKind.TREASURE, DungeonRoom.RoomKind.SECRET:
			_wave_index = 0
			RunState.grant_special_room_loot(room.kind)
			_spawn_special_marker(room.kind)
			_spawn_special_artifacts(room.kind)
			_finish_special_room()
			return true
		_:
			return false


func _finish_special_room() -> void:
	## Clear without style-rank loot re-roll (special loot already granted).
	_room_cleared = true
	_spawning = false
	_alive_enemies = 0
	RunState.mark_current_room_cleared()
	SignalBus.room_cleared.emit()
	_show_exit()


func _spawn_special_marker(kind: int) -> void:
	if _entities == null:
		return
	var marker := Node2D.new()
	marker.name = "SpecialRoomMarker"
	marker.z_index = 5
	var poly := Polygon2D.new()
	poly.name = "Visual"
	match kind:
		DungeonRoom.RoomKind.SHOP:
			poly.color = Color(0.35, 0.85, 0.55, 0.85)
			poly.polygon = PackedVector2Array([Vector2(-18, -14), Vector2(18, -14), Vector2(18, 14), Vector2(-18, 14)])
		DungeonRoom.RoomKind.TREASURE:
			poly.color = Color(0.95, 0.8, 0.25, 0.9)
			poly.polygon = PackedVector2Array([Vector2(0, -20), Vector2(16, 0), Vector2(0, 16), Vector2(-16, 0)])
		_:
			poly.color = Color(0.7, 0.45, 1.0, 0.85)
			poly.polygon = PackedVector2Array([
				Vector2(-4, -18), Vector2(4, -18), Vector2(4, 4), Vector2(-4, 4),
				Vector2(-4, 10), Vector2(4, 10), Vector2(4, 18), Vector2(-4, 18)
			])
	marker.add_child(poly)
	var hint := Label.new()
	hint.position = Vector2(-90, -48)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.custom_minimum_size = Vector2(180, 20)
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	hint.add_theme_constant_override("outline_size", 4)
	match kind:
		DungeonRoom.RoomKind.SHOP:
			hint.text = "SHOP — pick one artifact"
			hint.add_theme_color_override("font_color", Color(0.55, 1.0, 0.7))
		DungeonRoom.RoomKind.TREASURE:
			hint.text = "CACHE — walk over to claim"
			hint.add_theme_color_override("font_color", Color(1.0, 0.88, 0.4))
		_:
			hint.text = "SECRET — walk over to claim"
			hint.add_theme_color_override("font_color", Color(0.82, 0.65, 1.0))
	marker.add_child(hint)
	_entities.add_child(marker)
	marker.position = Vector2.ZERO


func _spawn_special_artifacts(kind: int) -> void:
	if _entities == null:
		return
	var count := 1
	if kind == DungeonRoom.RoomKind.SHOP:
		count = 3
	var offers := RunState.roll_boon_offers(count)
	if offers.is_empty():
		return
	var orbs: Array[ArtifactOrb] = []
	var spacing := 96.0
	var start_x := -spacing * float(offers.size() - 1) * 0.5
	for i in offers.size():
		var pos := Vector2(start_x + spacing * float(i), 48.0)
		orbs.append(ArtifactOrb.spawn_at(_entities, pos, offers[i]))
	if kind != DungeonRoom.RoomKind.SHOP:
		return
	for orb in orbs:
		orb.exclusive_group = orbs


func _current_room_already_cleared() -> bool:
	if not RunState.is_procedural_run():
		return false
	var room := RunState.current_dungeon_room()
	return room != null and room.cleared


func _restore_cleared_room() -> void:
	## Revisit: keep the room empty, doors open, no loot/reward re-grant.
	_room_cleared = true
	_revisit_cleared = true
	_wave_index = 0
	_alive_enemies = 0
	_spawning = false
	_exit_latch = false
	# Ignore the doorway we just walked through until the player leaves it.
	_blocked_entry_dir = -RunState.entry_travel_dir if RunState.entry_travel_dir != Vector2i.ZERO else Vector2i.ZERO
	_clear_live_enemies()
	_show_exit()


func _clear_live_enemies() -> void:
	if _entities == null:
		return
	for child in _entities.get_children():
		if child is Player:
			continue
		child.queue_free()


func _place_player() -> void:
	if player_path == NodePath() or not has_node(player_path):
		return
	var player := get_node(player_path) as Node2D
	if player == null:
		return
	player.position = RunState.player_spawn_position()


func _setup_exits() -> void:
	_clear_procedural_doors()
	if exit_marker_path != NodePath() and has_node(exit_marker_path):
		var exit_node := get_node(exit_marker_path)
		exit_node.visible = false
		if exit_node is Area2D:
			(exit_node as Area2D).monitoring = false
			# Avoid duplicate connections across route re-picks / refresh.
			if exit_node.body_entered.is_connected(_on_exit_body_entered):
				exit_node.body_entered.disconnect(_on_exit_body_entered)
		if exit_node.has_signal("body_entered") and not RunState.is_procedural_run():
			exit_node.body_entered.connect(_on_exit_body_entered)
	if RunState.is_procedural_run():
		_build_procedural_doors()


func _clear_procedural_doors() -> void:
	_door_nodes.clear()
	var root := get_node_or_null("Doors")
	if root:
		remove_child(root)
		root.free()


func _build_procedural_doors() -> void:
	var room := RunState.current_dungeon_room()
	if room == null:
		return
	var root := Node2D.new()
	root.name = "Doors"
	add_child(root)
	for dir in room.door_dirs():
		var door := _make_door(dir)
		root.add_child(door)
		_door_nodes.append(door)


func _make_door(dir: Vector2i) -> Area2D:
	var door := Area2D.new()
	door.name = "Door_%d_%d" % [dir.x, dir.y]
	door.monitoring = false
	door.monitorable = false
	door.collision_layer = 0
	door.collision_mask = 2
	door.visible = true
	door.position = Vector2(float(dir.x) * RunState.ARENA_DOOR_OFFSET.x, float(dir.y) * RunState.ARENA_DOOR_OFFSET.y)
	door.set_meta("dir", dir)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = DOOR_SIZE if dir.x == 0 else Vector2(DOOR_SIZE.y, DOOR_SIZE.x)
	shape.shape = rect
	door.add_child(shape)
	var half := rect.size * 0.5
	var frame_col := DOOR_COLORS.get(dir, Color(0.3, 0.75, 0.45, 0.7)) as Color
	# Outer frame always visible so doorways read as connected corridors.
	var frame := Polygon2D.new()
	frame.name = "DoorFrame"
	frame.polygon = PackedVector2Array([
		Vector2(-half.x - 8, -half.y - 8),
		Vector2(half.x + 8, -half.y - 8),
		Vector2(half.x + 8, half.y + 8),
		Vector2(-half.x - 8, half.y + 8),
	])
	frame.color = Color(frame_col.r, frame_col.g, frame_col.b, 0.35)
	door.add_child(frame)
	var visual := Polygon2D.new()
	visual.name = "DoorVisual"
	visual.polygon = PackedVector2Array([
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y),
	])
	visual.color = Color(frame_col.r * 0.35, frame_col.g * 0.35, frame_col.b * 0.35, 0.55)
	door.add_child(visual)
	# Threshold glow into the carved wall gap.
	var threshold := Polygon2D.new()
	threshold.name = "DoorThreshold"
	if dir.x == 0:
		threshold.polygon = PackedVector2Array([
			Vector2(-half.x - 4, -6), Vector2(half.x + 4, -6),
			Vector2(half.x + 4, 6), Vector2(-half.x - 4, 6)
		])
	else:
		threshold.polygon = PackedVector2Array([
			Vector2(-6, -half.y - 4), Vector2(6, -half.y - 4),
			Vector2(6, half.y + 4), Vector2(-6, half.y + 4)
		])
	threshold.color = Color(frame_col.r, frame_col.g, frame_col.b, 0.2)
	door.add_child(threshold)
	door.body_entered.connect(_on_door_body_entered.bind(dir))
	door.body_exited.connect(_on_door_body_exited.bind(dir))
	return door


func _apply_biome() -> void:
	var resolved := RunState.biome_for_current_room()
	if resolved:
		biome = resolved
	if biome == null:
		return
	RunState.current_biome = biome
	if biome.wave_set:
		wave_set = biome.wave_set
	# Boss rooms get a dedicated denser encounter pack.
	if RunState.is_procedural_run():
		var room := RunState.current_dungeon_room()
		if room != null and room.kind == DungeonRoom.RoomKind.BOSS and BOSS_WAVE_SET != null:
			wave_set = BOSS_WAVE_SET
	_apply_doorway_geometry()
	var floor_poly := get_node_or_null("Floor") as Polygon2D
	if floor_poly:
		floor_poly.color = biome.get_floor_color()
	_tint_wall_visuals()
	_RoomDresser.dress(self, biome)
	_spawn_biome_traps()
	SignalBus.biome_changed.emit(biome.biome_id)


func _apply_doorway_geometry() -> void:
	var dirs: Array[Vector2i] = []
	if RunState.is_procedural_run():
		var room := RunState.current_dungeon_room()
		if room:
			dirs = room.door_dirs()
	if dirs.is_empty():
		return
	_RoomDresser.carve_doorways(self, dirs)
	_tint_wall_visuals()


func _tint_wall_visuals() -> void:
	if biome == null:
		return
	var wall_visuals := get_node_or_null("WallVisuals")
	if wall_visuals == null:
		return
	var wall_c := biome.get_wall_color()
	for child in wall_visuals.get_children():
		if child is Polygon2D:
			(child as Polygon2D).color = wall_c


func _spawn_biome_traps() -> void:
	if biome == null or biome.trap_scene == null or biome.trap_count <= 0:
		return
	if _spawn_points == null:
		return
	var points := _spawn_points.get_children()
	if points.is_empty():
		return
	var traps_root := get_node_or_null("Traps") as Node2D
	if traps_root == null:
		traps_root = Node2D.new()
		traps_root.name = "Traps"
		add_child(traps_root)
	for i in biome.trap_count:
		var marker: Node2D = points[i % points.size()] as Node2D
		var trap := biome.trap_scene.instantiate() as Node2D
		traps_root.add_child(trap)
		# Offset from enemy spawns so traps aren't stacked on markers.
		var offset := Vector2(-90 + (i % 3) * 40, 70 + (i % 2) * 36)
		trap.global_position = marker.global_position + offset
		if trap.has_method("configure"):
			trap.call(
				"configure",
				biome.trap_color,
				biome.trap_damage,
				biome.trap_status_id,
				biome.trap_status_buildup
			)


func _start_first_wave() -> void:
	if wave_set == null or wave_set.wave_count() == 0:
		push_error("ArenaController: WaveSet is empty")
		return
	_begin_wave(0)


func _begin_wave(index: int) -> void:
	_wave_index = index
	var wave := wave_set.get_wave(index)
	if wave == null:
		_on_all_waves_cleared()
		return
	_spawning = true
	SignalBus.wave_started.emit(index, wave_set.wave_count())
	if wave.delay > 0.0:
		await get_tree().create_timer(wave.delay).timeout
	if not is_inside_tree():
		return
	_spawn_wave(wave)
	_spawning = false
	if _alive_enemies <= 0:
		_on_wave_cleared()


func _spawn_wave(wave: WaveDefinition) -> void:
	var points := _spawn_points.get_children()
	if points.is_empty():
		push_error("ArenaController: no spawn points")
		return
	for group in wave.spawns:
		if group == null or group.enemy_scene == null:
			continue
		for _i in group.count:
			var marker: Node2D = points[_spawn_cursor % points.size()] as Node2D
			_spawn_cursor += 1
			var enemy := group.enemy_scene.instantiate() as Node2D
			_entities.add_child(enemy)
			enemy.global_position = marker.global_position
			var def := group.enemy_definition
			# Soft remix: keep authored defs most of the time, pressure via weights sometimes.
			if use_faction_weights and biome and biome.has_faction_weights() and RunState.spawn_roll() < 0.4:
				def = RunState.pick_enemy_for_biome(def)
			if def != null and enemy.has_method("apply_definition"):
				enemy.call("apply_definition", def)
			if group.is_elite and enemy.has_method("apply_elite"):
				enemy.call(
					"apply_elite",
					group.elite_hp_mult,
					group.elite_move_mult,
					group.elite_action_speed
				)
			_alive_enemies += 1


func _on_enemy_spawned(_enemy: Node) -> void:
	## Mid-fight summons (boss phase adds) count toward room clear.
	if _room_cleared:
		return
	_alive_enemies += 1


func _on_enemy_died(_enemy: Node) -> void:
	_alive_enemies = maxi(_alive_enemies - 1, 0)
	if _enemy != null and _enemy.get("is_elite") and bool(_enemy.get("is_elite")):
		_spawn_artifact_orb(_enemy)
	if _spawning:
		return
	if _alive_enemies <= 0 and _wave_index >= 0 and not _room_cleared:
		_on_wave_cleared()


func _spawn_artifact_orb(enemy: Node) -> void:
	if enemy is not Node2D or _entities == null:
		return
	var orb := ArtifactOrb.spawn_at(_entities, Vector2.ZERO)
	orb.global_position = (enemy as Node2D).global_position


func _on_wave_cleared() -> void:
	SignalBus.wave_cleared.emit(_wave_index)
	var next := _wave_index + 1
	if next >= wave_set.wave_count():
		_on_all_waves_cleared()
	else:
		_begin_wave(next)


func _on_all_waves_cleared() -> void:
	_room_cleared = true
	RunState.mark_current_room_cleared()
	RunState.grant_loot_for_room_rank()
	SignalBus.room_cleared.emit()
	# Always offer exit → reward/craft, including the final room (win after reward).
	_show_exit()


func force_clear_room() -> void:
	_spawning = false
	_alive_enemies = 0
	_on_all_waves_cleared()


func _show_exit() -> void:
	if RunState.is_procedural_run():
		# Safety: route may have been picked after Arena _ready.
		if _door_nodes.is_empty():
			_build_procedural_doors()
		var any_door := false
		for door in _door_nodes:
			if is_instance_valid(door):
				door.visible = true
				door.monitoring = true
				_set_door_unlocked_look(door)
				any_door = true
		if any_door:
			return
		# Fall through to ExitMarker if graph somehow has no doors.
	if exit_marker_path == NodePath() or not has_node(exit_marker_path):
		return
	var exit_node: Node2D = get_node(exit_marker_path) as Node2D
	exit_node.visible = true
	if exit_node is Area2D:
		(exit_node as Area2D).monitoring = true
		if not exit_node.body_entered.is_connected(_on_exit_body_entered):
			exit_node.body_entered.connect(_on_exit_body_entered)


func _on_exit_body_entered(body: Node2D) -> void:
	if not _room_cleared or _exit_latch:
		return
	if body is Player:
		_exit_latch = true
		RunState.set_pending_exit_dir(Vector2i.ZERO)
		if _revisit_cleared:
			# Linear exit marker shouldn't appear in procedural, but stay safe.
			return
		SignalBus.exit_reached.emit()


func _on_door_body_entered(body: Node2D, dir: Vector2i) -> void:
	if not _room_cleared or _exit_latch:
		return
	if body is not Player:
		return
	# Standing in the door we entered from must not bounce/reward-loop.
	if dir == _blocked_entry_dir:
		return
	_exit_latch = true
	RunState.set_pending_exit_dir(dir)
	if _revisit_cleared:
		# Already cleared earlier this run — just travel, no craft/reward overlay.
		RunState.advance_to_next_room()
		return
	SignalBus.exit_reached.emit()


func _on_door_body_exited(body: Node2D, dir: Vector2i) -> void:
	if body is not Player:
		return
	if dir == _blocked_entry_dir:
		_blocked_entry_dir = Vector2i.ZERO


func _set_door_unlocked_look(door: Area2D) -> void:
	var dir: Vector2i = door.get_meta("dir", Vector2i.ZERO)
	var frame_col := DOOR_COLORS.get(dir, Color(0.3, 0.75, 0.45, 0.7)) as Color
	var visual := door.get_node_or_null("DoorVisual") as Polygon2D
	if visual:
		visual.color = Color(frame_col.r, frame_col.g, frame_col.b, 0.8)
	var frame := door.get_node_or_null("DoorFrame") as Polygon2D
	if frame:
		frame.color = Color(frame_col.r, frame_col.g, frame_col.b, 0.65)
	var threshold := door.get_node_or_null("DoorThreshold") as Polygon2D
	if threshold:
		threshold.color = Color(frame_col.r, frame_col.g, frame_col.b, 0.45)


func _on_player_died() -> void:
	_spawning = true
