extends Node
## Persists across room scene changes for a single run.

const ROOM_SCENES: PackedStringArray = [
	"res://levels/rooms/room_01.tscn",
	"res://levels/rooms/room_02.tscn",
	"res://levels/rooms/room_03.tscn",
]

const ARCH_DEFAULT := preload("res://resources/architectures/default.tres")
const ARCH_NANO := preload("res://resources/architectures/nanomachines.tres")
const ARCH_TRAIN := preload("res://resources/architectures/electro_train.tres")

var _upgrade_pool: Array[UpgradeData] = []

var room_index: int = 0
var damage_mult: float = 1.0
var speed_mult: float = 1.0
var dash_cost_mult: float = 1.0

var architecture: ArchitectureData
var architecture_picked: bool = false
var owned_tags: PackedStringArray = PackedStringArray()
var crafted_upgrades: Array[UpgradeData] = []

## Style score (Hotline-like)
var style_score: int = 0
var style_multiplier: float = 1.0
var peak_multiplier: float = 1.0
var room_kills: int = 0
var room_took_damage: bool = false
var _multi_kill_timer: float = 0.0
var _multi_kill_count: int = 0

var _transitioning: bool = false


func _ready() -> void:
	if architecture == null:
		architecture = ARCH_DEFAULT
	if owned_tags.is_empty():
		owned_tags = PackedStringArray(["default", "style"])
	_ensure_upgrade_pool()
	SignalBus.style_action.connect(_on_style_action)
	SignalBus.enemy_died.connect(_on_enemy_died)
	set_process(true)


func _process(delta: float) -> void:
	if _multi_kill_timer > 0.0:
		_multi_kill_timer = maxf(0.0, _multi_kill_timer - delta)
		if _multi_kill_timer <= 0.0:
			_multi_kill_count = 0


func _ensure_upgrade_pool() -> void:
	if not _upgrade_pool.is_empty():
		return
	_upgrade_pool.append(load("res://resources/upgrades/default_counter.tres") as UpgradeData)
	_upgrade_pool.append(load("res://resources/upgrades/nano_hookshot.tres") as UpgradeData)
	_upgrade_pool.append(load("res://resources/upgrades/nano_infect.tres") as UpgradeData)
	_upgrade_pool.append(load("res://resources/upgrades/nano_proximity.tres") as UpgradeData)


func reset() -> void:
	room_index = 0
	damage_mult = 1.0
	speed_mult = 1.0
	dash_cost_mult = 1.0
	architecture = ARCH_DEFAULT
	architecture_picked = false
	owned_tags = PackedStringArray(["default", "style"])
	crafted_upgrades.clear()
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


func choose_architecture(arch_id: GameplayEnums.ArchitectureId) -> void:
	match arch_id:
		GameplayEnums.ArchitectureId.NANOMACHINES:
			architecture = ARCH_NANO
			owned_tags = PackedStringArray(["nano", "whip", "toad", "swarm", "proximity"])
		GameplayEnums.ArchitectureId.ELECTRO_TRAIN:
			architecture = ARCH_TRAIN
			owned_tags = PackedStringArray(["train", "plasma"])
		_:
			architecture = ARCH_DEFAULT
			owned_tags = PackedStringArray(["default", "style"])
	architecture_picked = true
	SignalBus.architecture_changed.emit(architecture.architecture_id)


func choose_modifier(modifier_id: StringName) -> void:
	match modifier_id:
		&"damage":
			damage_mult *= 1.2
		&"speed":
			speed_mult *= 1.15
		&"dash":
			dash_cost_mult *= 0.75
		_:
			push_warning("RunState: unknown modifier %s" % modifier_id)
			return
	SignalBus.modifier_chosen.emit(modifier_id)


func get_craftable_upgrades() -> Array[UpgradeData]:
	_ensure_upgrade_pool()
	var result: Array[UpgradeData] = []
	for upgrade in _upgrade_pool:
		if upgrade == null:
			continue
		if _already_crafted(upgrade.upgrade_id):
			continue
		if architecture and upgrade.architecture_id != architecture.architecture_id:
			continue
		if _has_required_tags(upgrade):
			result.append(upgrade)
	return result


func craft_upgrade(upgrade: UpgradeData) -> bool:
	if upgrade == null:
		return false
	if upgrade not in get_craftable_upgrades():
		return false
	crafted_upgrades.append(upgrade)
	for tag in upgrade.grant_tags:
		if not owned_tags.has(tag):
			owned_tags.append(tag)
	SignalBus.upgrade_crafted.emit(upgrade.upgrade_id)
	return true


func grant_loot_for_room_rank() -> void:
	var rank := current_room_rank()
	var biome_tags := PackedStringArray()
	match rank:
		"S":
			_add_tag("style")
			_add_tag("swarm")
			_add_tag("proximity")
		"A":
			_add_tag("style")
			_add_tag("whip")
		"B":
			_add_tag("style")
		_:
			pass
	for tag in biome_tags:
		_add_tag(tag)


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
	_emit_style()


func register_took_damage() -> void:
	room_took_damage = true
	style_multiplier = 1.0
	_on_style_action(GameplayEnums.StyleAction.TOOK_DAMAGE, 0)


func is_last_room() -> bool:
	return room_index >= ROOM_SCENES.size() - 1


func advance_to_next_room() -> void:
	if is_last_room() or _transitioning:
		return
	grant_loot_for_room_rank()
	room_index += 1
	_change_scene(ROOM_SCENES[room_index])


func restart_run() -> void:
	if _transitioning:
		return
	reset()
	_change_scene(ROOM_SCENES[0])


func _change_scene(path: String) -> void:
	_transitioning = true
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().call_deferred("change_scene_to_file", path)
	call_deferred("_clear_transition_flag")


func _clear_transition_flag() -> void:
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
	if not owned_tags.has(tag):
		owned_tags.append(tag)
