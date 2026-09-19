extends Node
## Persists across room scene changes for a single run.

const TUTORIAL_ROUTE := preload("res://resources/runs/tutorial_route.tres")
const CAMPAIGN_ROUTE := preload("res://resources/runs/campaign_route.tres")
const PROCEDURAL_ROUTE := preload("res://resources/runs/procedural_route.tres")
const DEFAULT_ROUTE := TUTORIAL_ROUTE
const ARCH_CATALOG := preload("res://resources/architectures/architecture_catalog.tres")
const UPGRADE_CATALOG := preload("res://resources/upgrades/upgrade_catalog.tres")
const ENEMY_CATALOG := preload("res://resources/enemies/enemy_catalog.tres")

## Fallback layouts when a route has none.
const LAYOUT_SCENES: PackedStringArray = [
	"res://levels/rooms/room_01.tscn",
	"res://levels/rooms/room_02.tscn",
	"res://levels/rooms/room_03.tscn",
]

## Near-wall inset for door / entry spawn (±800×±450 arena half-extents).
const ARENA_DOOR_OFFSET := Vector2(760, 405)

var arch_catalog: ArchitectureCatalog
var upgrade_catalog: UpgradeCatalog
var enemy_catalog: EnemyCatalog
var current_route: ActRoute

var room_index: int = 0
var act_index: int = 1
var room_in_act: int = 0
var damage_mult: float = 1.0
var speed_mult: float = 1.0
var dash_cost_mult: float = 1.0
## Soft-cap room +damage boons after 2 full picks.
var damage_boon_picks: int = 0

var architecture: ArchitectureData
var architecture_picked: bool = false
var route_picked: bool = false
var owned_tags: PackedStringArray = PackedStringArray()
var crafted_upgrades: Array[UpgradeData] = []
var inventory: Array = []
var last_loot: Array = []
var current_biome: BiomeDefinition

## Procedural dungeon (null on linear routes).
var run_seed: int = 0
var rng: RunRng
var dungeon: DungeonGraph
var current_coord: Vector2i = Vector2i.ZERO
var pending_exit_dir: Vector2i = Vector2i.ZERO
## Direction traveled into the current room (ZERO = run start).
var entry_travel_dir: Vector2i = Vector2i.ZERO

## Style score (Hotline-like)
var style_score: int = 0
var style_multiplier: float = 1.0
var peak_multiplier: float = 1.0
var room_kills: int = 0
var room_took_damage: bool = false
var _multi_kill_timer: float = 0.0
var _multi_kill_count: int = 0

var _transitioning: bool = false
var last_boon_offers: Array[UpgradeData] = []
var unlocked_combos: Array[StringName] = []
var last_combo_name: String = ""


func _ready() -> void:
	arch_catalog = ARCH_CATALOG as ArchitectureCatalog
	upgrade_catalog = UPGRADE_CATALOG as UpgradeCatalog
	enemy_catalog = ENEMY_CATALOG as EnemyCatalog
	_merge_shared_boons()
	current_route = DEFAULT_ROUTE as ActRoute
	_sync_route_cursor()
	if architecture == null:
		architecture = _default_architecture()
	if owned_tags.is_empty() and architecture:
		owned_tags = architecture.starting_tags.duplicate()
	SignalBus.style_action.connect(_on_style_action)
	SignalBus.enemy_died.connect(_on_enemy_died)
	set_process(true)


func _merge_shared_boons() -> void:
	if upgrade_catalog == null:
		return
	var existing: Dictionary = {}
	for item in upgrade_catalog.all_upgrades():
		var u := item as UpgradeData
		if u:
			existing[u.upgrade_id] = true
			if u.reward_offerable and not u.any_architecture:
				u.house = UpgradeData.House.GEOMETRY
	for boon in ArtifactLibrary.all_boons():
		if boon == null or existing.has(boon.upgrade_id):
			continue
		upgrade_catalog.upgrades.append(boon)
		existing[boon.upgrade_id] = true


func _process(delta: float) -> void:
	if _multi_kill_timer > 0.0:
		_multi_kill_timer = maxf(0.0, _multi_kill_timer - delta)
		if _multi_kill_timer <= 0.0:
			_multi_kill_count = 0


func reset() -> void:
	room_index = 0
	act_index = 1
	room_in_act = 0
	damage_mult = 1.0
	speed_mult = 1.0
	dash_cost_mult = 1.0
	damage_boon_picks = 0
	architecture = _default_architecture()
	architecture_picked = false
	route_picked = false
	owned_tags = architecture.starting_tags.duplicate() if architecture else PackedStringArray(["default", "style"])
	crafted_upgrades.clear()
	inventory.clear()
	last_loot.clear()
	last_boon_offers.clear()
	unlocked_combos.clear()
	last_combo_name = ""
	current_biome = null
	current_route = DEFAULT_ROUTE as ActRoute
	run_seed = 0
	rng = null
	dungeon = null
	current_coord = Vector2i.ZERO
	pending_exit_dir = Vector2i.ZERO
	entry_travel_dir = Vector2i.ZERO
	_sync_route_cursor()
	style_score = 0
	style_multiplier = 1.0
	peak_multiplier = 1.0
	room_kills = 0
	room_took_damage = false
	_multi_kill_count = 0
	_multi_kill_timer = 0.0
	_emit_style()


func apply_to_player(player: Player) -> void:
	if player == null:
		return
	player.damage_multiplier = damage_mult * _upgrade_damage_mult()
	player.move_speed_multiplier = speed_mult
	player.dash_cost_multiplier = dash_cost_mult
	if architecture:
		player.equip_architecture(architecture)
	player.apply_run_upgrades(crafted_upgrades)


func get_architectures() -> Array[ArchitectureData]:
	if arch_catalog == null:
		arch_catalog = ARCH_CATALOG as ArchitectureCatalog
	if arch_catalog == null:
		return []
	return arch_catalog.all()


func choose_architecture(arch_id: GameplayEnums.ArchitectureId) -> void:
	var arch := _find_architecture(arch_id)
	choose_architecture_data(arch)


func choose_architecture_data(arch: ArchitectureData) -> void:
	if arch == null:
		arch = _default_architecture()
	architecture = arch
	owned_tags = arch.starting_tags.duplicate()
	architecture_picked = true
	SignalBus.architecture_changed.emit(architecture.architecture_id)


func get_available_routes() -> Array[ActRoute]:
	var routes: Array[ActRoute] = []
	var tutorial := TUTORIAL_ROUTE as ActRoute
	var campaign := CAMPAIGN_ROUTE as ActRoute
	var procedural := PROCEDURAL_ROUTE as ActRoute
	if tutorial:
		routes.append(tutorial)
	if campaign:
		routes.append(campaign)
	if procedural:
		routes.append(procedural)
	return routes


func choose_route(route: ActRoute) -> void:
	if route == null:
		route = DEFAULT_ROUTE as ActRoute
	current_route = route
	route_picked = true
	room_index = 0
	pending_exit_dir = Vector2i.ZERO
	entry_travel_dir = Vector2i.ZERO
	if current_route and current_route.is_procedural:
		run_seed = 0
		_begin_procedural_dungeon()
	else:
		dungeon = null
		rng = null
		run_seed = 0
		current_coord = Vector2i.ZERO
	_sync_route_cursor()
	SignalBus.route_chosen.emit(current_route.route_id if current_route else &"")


func begin_procedural_with_seed(seed_value: int) -> void:
	## Test / future seed-entry hook.
	run_seed = seed_value
	current_route = PROCEDURAL_ROUTE as ActRoute
	route_picked = true
	room_index = 0
	_begin_procedural_dungeon()
	_sync_route_cursor()
	SignalBus.route_chosen.emit(current_route.route_id if current_route else &"")


func is_procedural_run() -> bool:
	return current_route != null and current_route.is_procedural and dungeon != null


func current_dungeon_room() -> DungeonRoom:
	if dungeon == null:
		return null
	return dungeon.get_room(current_coord)


func set_pending_exit_dir(dir: Vector2i) -> void:
	pending_exit_dir = dir


func player_spawn_position() -> Vector2:
	if entry_travel_dir == Vector2i.ZERO:
		return Vector2(-150, 50)
	# Travelled into this room along entry_travel_dir → appear inset from opposite wall
	# so the entry door Area2D does not instantly re-trigger travel/rewards.
	var wall := -entry_travel_dir
	const SPAWN_INSET := 110.0
	return Vector2(
		float(wall.x) * (ARENA_DOOR_OFFSET.x - SPAWN_INSET),
		float(wall.y) * (ARENA_DOOR_OFFSET.y - SPAWN_INSET)
	)


func _begin_procedural_dungeon() -> void:
	if run_seed == 0:
		run_seed = _fresh_seed()
	rng = RunRng.new(run_seed)
	var count := 12
	if current_route:
		count = current_route.procedural_room_count
	dungeon = DungeonGenerator.generate(rng, count)
	current_coord = dungeon.start_coord if dungeon else Vector2i.ZERO
	pending_exit_dir = Vector2i.ZERO
	entry_travel_dir = Vector2i.ZERO
	var start_room := current_dungeon_room()
	if start_room:
		start_room.explored = true


func _fresh_seed() -> int:
	var roller := RandomNumberGenerator.new()
	roller.randomize()
	var value := roller.randi()
	if value == 0:
		value = 1
	return value


func _default_architecture() -> ArchitectureData:
	var arch := _find_architecture(GameplayEnums.ArchitectureId.DEFAULT)
	if arch:
		return arch
	return load("res://resources/architectures/default.tres") as ArchitectureData


func _find_architecture(arch_id: GameplayEnums.ArchitectureId) -> ArchitectureData:
	if arch_catalog == null:
		arch_catalog = ARCH_CATALOG as ArchitectureCatalog
	if arch_catalog:
		return arch_catalog.find_by_id(arch_id)
	return null


func choose_modifier(modifier_id: StringName) -> void:
	match modifier_id:
		&"damage":
			damage_boon_picks += 1
			# First two picks full ×1.2; further picks soft-cap to ×1.08.
			if damage_boon_picks <= 2:
				damage_mult *= 1.2
			else:
				damage_mult *= 1.08
		&"speed":
			speed_mult *= 1.15
		&"dash":
			dash_cost_mult *= 0.75
		_:
			push_warning("RunState: unknown modifier %s" % modifier_id)
			return
	SignalBus.modifier_chosen.emit(modifier_id)


func get_craftable_upgrades() -> Array[UpgradeData]:
	var result: Array[UpgradeData] = []
	if upgrade_catalog == null:
		upgrade_catalog = UPGRADE_CATALOG as UpgradeCatalog
	if upgrade_catalog == null:
		return result
	for item in upgrade_catalog.all_upgrades():
		var upgrade := item as UpgradeData
		if upgrade == null:
			continue
		if upgrade.reward_offerable:
			continue
		if _already_crafted(upgrade.upgrade_id):
			continue
		if architecture and upgrade.architecture_id != architecture.architecture_id:
			continue
		if _has_required_tags(upgrade):
			result.append(upgrade)
	return result


## Post-room Rewards column: always-offerable Geometry upgrades (no loot tags).
func get_reward_upgrades() -> Array[UpgradeData]:
	var result: Array[UpgradeData] = []
	if upgrade_catalog == null:
		upgrade_catalog = UPGRADE_CATALOG as UpgradeCatalog
		_merge_shared_boons()
	if upgrade_catalog == null:
		return result
	for item in upgrade_catalog.all_upgrades():
		var upgrade := item as UpgradeData
		if upgrade == null or not upgrade.reward_offerable:
			continue
		if _already_crafted(upgrade.upgrade_id):
			continue
		if not _upgrade_matches_arch(upgrade):
			continue
		result.append(upgrade)
	return result


func _upgrade_matches_arch(upgrade: UpgradeData) -> bool:
	if upgrade == null:
		return false
	if upgrade.any_architecture:
		return true
	if architecture == null:
		return true
	return upgrade.architecture_id == architecture.architecture_id


func roll_boon_offers(count: int = 3) -> Array[UpgradeData]:
	var pool := get_reward_upgrades()
	var picked: Array[UpgradeData] = []
	var used_houses: Dictionary = {}
	var used_ids: Dictionary = {}
	for _pass in range(2):
		if picked.size() >= count:
			break
		var weighted: Array = []
		for upgrade in pool:
			if used_ids.has(upgrade.upgrade_id):
				continue
			if _pass == 0 and used_houses.has(upgrade.house) and pool.size() > count:
				continue
			var w := _rarity_weight(upgrade.rarity)
			for _i in w:
				weighted.append(upgrade)
		while picked.size() < count and not weighted.is_empty():
			var choice: UpgradeData = weighted[_loot_index(weighted.size())]
			if used_ids.has(choice.upgrade_id):
				weighted.erase(choice)
				continue
			picked.append(choice)
			used_ids[choice.upgrade_id] = true
			used_houses[choice.house] = true
			var cleaned: Array = []
			for item in weighted:
				if (item as UpgradeData).upgrade_id != choice.upgrade_id:
					cleaned.append(item)
			weighted = cleaned
	last_boon_offers = picked
	return picked


func _rarity_weight(rarity: UpgradeData.Rarity) -> int:
	match rarity:
		UpgradeData.Rarity.COMMON:
			return 55
		UpgradeData.Rarity.RARE:
			return 28
		UpgradeData.Rarity.EPIC:
			return 12
		UpgradeData.Rarity.LEGENDARY:
			return 4
	return 20


func owned_upgrade_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for upgrade in crafted_upgrades:
		if upgrade:
			ids.append(upgrade.upgrade_id)
	return ids


func craft_upgrade(upgrade: UpgradeData) -> bool:
	if upgrade == null:
		return false
	if upgrade not in get_craftable_upgrades():
		return false
	return _append_upgrade(upgrade)


func grant_upgrade(upgrade: UpgradeData) -> bool:
	## Tag-bypass grant for reward_offerable Geometry picks and shared boons.
	if upgrade == null:
		return false
	if _already_crafted(upgrade.upgrade_id):
		return false
	if not _upgrade_matches_arch(upgrade):
		return false
	return _append_upgrade(upgrade)


func _append_upgrade(upgrade: UpgradeData) -> bool:
	crafted_upgrades.append(upgrade)
	for tag in upgrade.grant_tags:
		_add_tag(String(tag))
	SignalBus.upgrade_crafted.emit(upgrade.upgrade_id)
	_unlock_new_combos()
	return true


func _unlock_new_combos() -> void:
	for recipe in ArtifactCombos.unlocked_for(owned_upgrade_ids()):
		var cid: StringName = recipe["id"]
		if unlocked_combos.has(cid) or _already_crafted(cid):
			continue
		unlocked_combos.append(cid)
		last_combo_name = str(recipe.get("name", "Combo"))
		var combo_upgrade := UpgradeData.new()
		combo_upgrade.upgrade_id = cid
		combo_upgrade.display_name = last_combo_name
		combo_upgrade.description = str(recipe.get("desc", ""))
		combo_upgrade.any_architecture = true
		combo_upgrade.reward_offerable = false
		combo_upgrade.house = UpgradeData.House.CORE
		combo_upgrade.rarity = UpgradeData.Rarity.EPIC
		var fx := EffectBoonProc.new()
		fx.kind = recipe.get("kind", &"damage")
		fx.value = float(recipe.get("value", 1.0))
		fx.value_b = float(recipe.get("value_b", 0.0))
		if recipe.has("status"):
			fx.status_id = recipe["status"]
		combo_upgrade.effects = [fx]
		crafted_upgrades.append(combo_upgrade)
		SignalBus.combo_unlocked.emit(last_combo_name, combo_upgrade.description)


func grant_loot_for_room_rank() -> void:
	last_loot.clear()
	var rank := current_room_rank()
	var rolls := 0
	match rank:
		"S":
			rolls = 3
		"A":
			rolls = 2
		"B":
			rolls = 1
		_:
			rolls = 0
	# Always grant a soft style tag on B+ for craft pacing.
	if rank == "B" or rank == "A" or rank == "S":
		_add_tag("style")
	var biome_tags := PackedStringArray()
	if current_biome:
		biome_tags = current_biome.loot_tags
	if upgrade_catalog == null:
		upgrade_catalog = UPGRADE_CATALOG as UpgradeCatalog
	var pool: Array = []
	if upgrade_catalog:
		pool = upgrade_catalog.parts_for_biome_tags(biome_tags)
	if pool.is_empty() and upgrade_catalog:
		pool = upgrade_catalog.all_parts()
	for _i in rolls:
		if pool.is_empty():
			break
		var part := pool[_loot_index(pool.size())] as LootPart
		if part == null:
			continue
		grant_part(part)
	# Fallback: if no parts rolled but biome has tags, grant one biome tag.
	if last_loot.is_empty() and not biome_tags.is_empty() and rank != "C":
		_add_tag(String(biome_tags[0]))
	if not last_loot.is_empty():
		SignalBus.loot_gained.emit(loot_summary())


func grant_special_room_loot(kind: int) -> void:
	## Shop / treasure / secret: guaranteed parts + style tag, independent of combat rank.
	last_loot.clear()
	_add_tag("style")
	if upgrade_catalog == null:
		upgrade_catalog = UPGRADE_CATALOG as UpgradeCatalog
	var pool: Array = []
	if upgrade_catalog:
		pool = upgrade_catalog.all_parts()
	var rolls := 1
	match kind:
		DungeonRoom.RoomKind.TREASURE:
			rolls = 2
		DungeonRoom.RoomKind.SHOP:
			rolls = 1
			_add_tag("magnet")
		DungeonRoom.RoomKind.SECRET:
			rolls = 1
			_add_tag("code")
		_:
			rolls = 1
	for _i in rolls:
		if pool.is_empty():
			break
		var part := pool[_loot_index(pool.size())] as LootPart
		if part == null:
			continue
		grant_part(part)
	if not last_loot.is_empty():
		SignalBus.loot_gained.emit(loot_summary())


func grant_part(part: LootPart) -> void:
	inventory.append(part)
	last_loot.append(part)
	for tag in part.tags:
		_add_tag(String(tag))


func loot_summary() -> String:
	var names: PackedStringArray = []
	for item in last_loot:
		var part := item as LootPart
		if part:
			names.append(part.display_name)
	return ", ".join(names)


func current_room_rank() -> String:
	if room_took_damage and peak_multiplier < 2.0:
		return "C"
	if peak_multiplier >= 4.0 and room_kills >= 3 and not room_took_damage:
		return "S"
	if peak_multiplier >= 3.0:
		return "A"
	if peak_multiplier >= 2.0:
		return "B"
	return "C"


func begin_room() -> void:
	room_kills = 0
	room_took_damage = false
	peak_multiplier = maxf(peak_multiplier * 0.5, 1.0)
	style_multiplier = maxf(style_multiplier * 0.5, 1.0)
	_sync_route_cursor()
	_emit_style()
	if is_procedural_run():
		var room := current_dungeon_room()
		if room:
			room.explored = true
		SignalBus.room_entered.emit(current_coord)
	else:
		SignalBus.room_entered.emit(Vector2i(room_index, 0))


func register_took_damage() -> void:
	room_took_damage = true
	style_multiplier = 1.0
	_on_style_action(GameplayEnums.StyleAction.TOOK_DAMAGE, 0)


func room_count() -> int:
	if is_procedural_run():
		return dungeon.room_count()
	if current_route:
		return maxi(current_route.total_rooms(), 1)
	return LAYOUT_SCENES.size()


func is_last_room() -> bool:
	if is_procedural_run():
		var room := current_dungeon_room()
		return room != null and room.kind == DungeonRoom.RoomKind.BOSS
	return room_index >= room_count() - 1


func biome_for_current_room() -> BiomeDefinition:
	_sync_route_cursor()
	return current_biome


func seek_room(index: int) -> void:
	room_index = maxi(index, 0)
	_sync_route_cursor()


func layout_scene_for_current_room() -> String:
	if is_procedural_run():
		var room := current_dungeon_room()
		if room and room.layout_path != "":
			return room.layout_path
	if current_route:
		return current_route.layout_scene_at(room_index)
	var idx := clampi(room_index, 0, LAYOUT_SCENES.size() - 1)
	return LAYOUT_SCENES[idx]


func pick_enemy_for_biome(fallback: EnemyDefinition) -> EnemyDefinition:
	if enemy_catalog == null:
		enemy_catalog = ENEMY_CATALOG as EnemyCatalog
	if enemy_catalog == null or current_biome == null:
		return fallback
	var spawn_rng: RandomNumberGenerator = rng.spawn if rng else null
	return enemy_catalog.pick_for_biome(current_biome, fallback, spawn_rng)


func advance_to_next_room() -> void:
	if is_last_room() or _transitioning:
		return
	if is_procedural_run():
		if pending_exit_dir == Vector2i.ZERO:
			return
		_advance_through_door(pending_exit_dir)
		return
	room_index += 1
	_sync_route_cursor()
	_change_scene(layout_scene_for_current_room())


func finish_room_reward() -> void:
	## Called after craft/boon on room clear. Wins on last room instead of advancing.
	if is_procedural_run():
		mark_current_room_cleared()
		var room := current_dungeon_room()
		if room and room.kind == DungeonRoom.RoomKind.BOSS:
			SignalBus.run_won.emit()
			return
		if pending_exit_dir == Vector2i.ZERO or _transitioning:
			return
		_advance_through_door(pending_exit_dir)
		return
	if is_last_room():
		SignalBus.run_won.emit()
		return
	advance_to_next_room()


func mark_current_room_cleared() -> void:
	if not is_procedural_run():
		return
	var room := current_dungeon_room()
	if room:
		room.cleared = true
		room.explored = true


func _advance_through_door(dir: Vector2i) -> void:
	if dungeon == null or _transitioning:
		return
	var next := current_coord + dir
	if dungeon.get_room(next) == null:
		return
	entry_travel_dir = dir
	current_coord = next
	pending_exit_dir = Vector2i.ZERO
	room_index += 1
	_sync_route_cursor()
	_change_scene(layout_scene_for_current_room())


func restart_run() -> void:
	if _transitioning:
		return
	var keep_arch := architecture
	var keep_route := current_route
	var had_arch := architecture_picked
	var had_route := route_picked
	reset()
	if had_route and keep_route:
		choose_route(keep_route)
	if had_arch and keep_arch:
		choose_architecture_data(keep_arch)
	_change_scene(layout_scene_for_current_room())


func return_to_class_select() -> void:
	if _transitioning:
		return
	reset()
	_change_scene("res://ui/class_select.tscn")


func _sync_route_cursor() -> void:
	if current_route == null:
		current_route = DEFAULT_ROUTE as ActRoute
	if current_route == null:
		return
	if is_procedural_run():
		var room := current_dungeon_room()
		act_index = 1
		room_in_act = room_index
		if room and room.biome:
			current_biome = room.biome
		return
	var resolved := current_route.resolve_room(room_index)
	act_index = int(resolved.get("act_index", 1))
	room_in_act = int(resolved.get("room_in_act", 0))
	var biome := resolved.get("biome") as BiomeDefinition
	if biome:
		current_biome = biome


func _loot_index(pool_size: int) -> int:
	if pool_size <= 0:
		return 0
	if rng:
		return rng.loot.randi() % pool_size
	return randi() % pool_size


func spawn_roll() -> float:
	if rng:
		return rng.spawn.randf()
	return randf()


func _change_scene(path: String) -> void:
	_transitioning = true
	Engine.time_scale = 1.0
	get_tree().paused = false
	if RoomTransition and RoomTransition.has_method("go_to"):
		RoomTransition.go_to(path)
		call_deferred("_clear_transition_flag_delayed")
	else:
		get_tree().call_deferred("change_scene_to_file", path)
		call_deferred("_clear_transition_flag")


func _clear_transition_flag() -> void:
	_transitioning = false


func _clear_transition_flag_delayed() -> void:
	## Keep gate until fade finishes so double-door triggers don't stack.
	await get_tree().create_timer(0.35).timeout
	_transitioning = false


func _on_enemy_died(_enemy: Node) -> void:
	room_kills += 1
	_multi_kill_count += 1
	_multi_kill_timer = 1.2
	var points := 100
	if _multi_kill_count >= 2:
		points += 50 * (_multi_kill_count - 1)
		_on_style_action(GameplayEnums.StyleAction.MULTI_KILL, points)
	else:
		_on_style_action(GameplayEnums.StyleAction.KILL, points)


func _on_style_action(action: int, points: int) -> void:
	match action:
		GameplayEnums.StyleAction.TOOK_DAMAGE:
			style_multiplier = 1.0
		GameplayEnums.StyleAction.PERFECT_DODGE:
			style_multiplier = minf(style_multiplier + 0.5, 6.0)
		GameplayEnums.StyleAction.PARRY:
			style_multiplier = minf(style_multiplier + 0.75, 6.0)
		GameplayEnums.StyleAction.COMBO:
			style_multiplier = minf(style_multiplier + 0.15, 6.0)
		GameplayEnums.StyleAction.KILL, GameplayEnums.StyleAction.MULTI_KILL:
			style_multiplier = minf(style_multiplier + 0.25, 6.0)
		GameplayEnums.StyleAction.HIT:
			style_multiplier = minf(style_multiplier + 0.05, 6.0)
		GameplayEnums.StyleAction.ELEMENT_CASCADE:
			style_multiplier = minf(style_multiplier + 0.4, 6.0)
	peak_multiplier = maxf(peak_multiplier, style_multiplier)
	if points > 0:
		style_score += int(round(float(points) * style_multiplier))
	_emit_style()


func _emit_style() -> void:
	SignalBus.style_score_changed.emit(style_score, style_multiplier, current_room_rank())


func _upgrade_damage_mult() -> float:
	var m := 1.0
	for upgrade in crafted_upgrades:
		if upgrade:
			m *= upgrade.damage_mult
	return m


func _already_crafted(id: StringName) -> bool:
	for upgrade in crafted_upgrades:
		if upgrade and upgrade.upgrade_id == id:
			return true
	return false


func _has_required_tags(upgrade: UpgradeData) -> bool:
	for tag in upgrade.required_tags:
		if not owned_tags.has(tag):
			return false
	return true


func _add_tag(tag: String) -> void:
	if tag == "" or owned_tags.has(tag):
		return
	owned_tags.append(tag)
