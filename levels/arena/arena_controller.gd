class_name ArenaController
extends Node2D
## Spawns waves into Entities, tracks clears, emits SignalBus wave/run events.

@export var wave_set: WaveSet
@export var biome: BiomeDefinition
@export var entities_path: NodePath = ^"Entities"
@export var spawn_points_path: NodePath = ^"SpawnPoints"
@export var player_path: NodePath = ^"Entities/Player"
@export var is_final_room: bool = true
@export var exit_marker_path: NodePath = ^"ExitMarker"

var _wave_index: int = -1
var _alive_enemies: int = 0
var _spawning: bool = false
var _room_cleared: bool = false
var _spawn_cursor: int = 0

@onready var _entities: Node2D = get_node(entities_path)
@onready var _spawn_points: Node2D = get_node(spawn_points_path)


func _ready() -> void:
	SignalBus.enemy_died.connect(_on_enemy_died)
	SignalBus.player_died.connect(_on_player_died)
	_apply_biome()
	if exit_marker_path != NodePath() and has_node(exit_marker_path):
		var exit_node := get_node(exit_marker_path)
		exit_node.visible = false
		if exit_node.has_signal("body_entered"):
			exit_node.body_entered.connect(_on_exit_body_entered)
	call_deferred("_start_first_wave")


func _apply_biome() -> void:
	if biome == null:
		return
	if biome.wave_set:
		wave_set = biome.wave_set
	var floor_poly := get_node_or_null("Floor") as Polygon2D
	if floor_poly:
		floor_poly.color = biome.get_floor_color()
	var wall_visuals := get_node_or_null("WallVisuals")
	if wall_visuals:
		for child in wall_visuals.get_children():
			if child is Polygon2D:
				(child as Polygon2D).color = biome.get_wall_color()
	for tag in biome.loot_tags:
		if not RunState.owned_tags.has(tag):
			# Soft hint tags available in biome; actual grant on clear still rank-gated.
			pass
	SignalBus.biome_changed.emit(biome.biome_id)


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
			if group.enemy_definition != null and enemy.has_method("apply_definition"):
				enemy.call("apply_definition", group.enemy_definition)
			_alive_enemies += 1


func _on_enemy_died(_enemy: Node) -> void:
	_alive_enemies = maxi(_alive_enemies - 1, 0)
	if _spawning:
		return
	if _alive_enemies <= 0 and _wave_index >= 0 and not _room_cleared:
		_on_wave_cleared()


func _on_wave_cleared() -> void:
	SignalBus.wave_cleared.emit(_wave_index)
	var next := _wave_index + 1
	if next >= wave_set.wave_count():
		_on_all_waves_cleared()
	else:
		_begin_wave(next)


func _on_all_waves_cleared() -> void:
	_room_cleared = true
	if biome:
		for tag in biome.loot_tags:
			if not RunState.owned_tags.has(tag):
				RunState.owned_tags.append(tag)
	SignalBus.room_cleared.emit()
	if is_final_room:
		SignalBus.run_won.emit()
	else:
		_show_exit()


func force_clear_room() -> void:
	_spawning = false
	_alive_enemies = 0
	_on_all_waves_cleared()


func _show_exit() -> void:
	if exit_marker_path == NodePath() or not has_node(exit_marker_path):
		return
	var exit_node: Node2D = get_node(exit_marker_path) as Node2D
	exit_node.visible = true
	if exit_node is Area2D:
		(exit_node as Area2D).monitoring = true


func _on_exit_body_entered(body: Node2D) -> void:
	if not _room_cleared:
		return
	if body is Player:
		SignalBus.exit_reached.emit()


func _on_player_died() -> void:
	_spawning = true
