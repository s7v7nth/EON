extends Node
## Authoritative meta progress. Loaded from user:// on boot; class select and
## architecture equip both consult this file — not a client-side UI tick.

const SAVE_PATH := "user://eon_meta.cfg"
const SECTION := "progress"

const FLAG_HIVE := &"hive_killed"
const FLAG_WARDEN := &"warden_killed"
const FLAG_REMNANT := &"remnant_spoken"
const KEY_CLERK := "clerk_scrap"

const LOCK_SYNTHETIC := "You're already steel. That's what washed up."
const LOCK_HIVE := "The sweeper still has the swarm. Take it off The Hive."
const LOCK_PAROVOZ := "Roundhouse is sealed. Warden's sitting on the last heat valve."
const LOCK_NEURO := "Core bricked the wires. The stall has the last live node. Talk first."

var _flags: Dictionary = {}
var _clerk_scrap: int = 0
var _loaded: bool = false


func _ready() -> void:
	reload()


func reload() -> void:
	_flags.clear()
	var cf := ConfigFile.new()
	var err := cf.load(SAVE_PATH)
	if err == OK:
		var packed: PackedStringArray = cf.get_value(SECTION, "flags", PackedStringArray())
		for flag in packed:
			if String(flag) != "":
				_flags[StringName(flag)] = true
		_clerk_scrap = int(cf.get_value(SECTION, KEY_CLERK, 0))
	else:
		_clerk_scrap = 0
	_loaded = true


func save() -> void:
	var cf := ConfigFile.new()
	cf.load(SAVE_PATH)
	var packed := PackedStringArray()
	var keys: Array = _flags.keys()
	keys.sort_custom(func(a, b): return String(a) < String(b))
	for key in keys:
		if _flags[key]:
			packed.append(String(key))
	cf.set_value(SECTION, "flags", packed)
	cf.set_value(SECTION, KEY_CLERK, _clerk_scrap)
	cf.save(SAVE_PATH)


func has_flag(flag: StringName) -> bool:
	if not _loaded:
		reload()
	return bool(_flags.get(flag, false))


func set_flag(flag: StringName, value: bool = true) -> void:
	if flag == StringName():
		return
	if not _loaded:
		reload()
	var prev := bool(_flags.get(flag, false))
	if value:
		_flags[flag] = true
	else:
		_flags.erase(flag)
	if prev != value:
		save()
		SignalBus.meta_progress_changed.emit()


func is_architecture_unlocked(arch_id: int) -> bool:
	match arch_id:
		GameplayEnums.ArchitectureId.DEFAULT:
			return true
		GameplayEnums.ArchitectureId.NANOMACHINES:
			return has_flag(FLAG_HIVE)
		GameplayEnums.ArchitectureId.ELECTRO_TRAIN:
			return has_flag(FLAG_WARDEN)
		GameplayEnums.ArchitectureId.NEURO_HACKER:
			return has_flag(FLAG_REMNANT)
		_:
			return false


func unlock_requirement(arch_id: int) -> String:
	match arch_id:
		GameplayEnums.ArchitectureId.NANOMACHINES:
			return LOCK_HIVE
		GameplayEnums.ArchitectureId.ELECTRO_TRAIN:
			return LOCK_PAROVOZ
		GameplayEnums.ArchitectureId.NEURO_HACKER:
			return LOCK_NEURO
		GameplayEnums.ArchitectureId.DEFAULT:
			return LOCK_SYNTHETIC
		_:
			return ""


func note_boss_killed(boss_id: StringName) -> void:
	match boss_id:
		&"hive":
			set_flag(FLAG_HIVE, true)
		&"warden":
			set_flag(FLAG_WARDEN, true)


func clerk_scrap_index() -> int:
	if not _loaded:
		reload()
	return _clerk_scrap


func advance_clerk_scrap() -> int:
	if not _loaded:
		reload()
	_clerk_scrap += 1
	save()
	return _clerk_scrap


func note_remnant_spoken() -> void:
	if not _loaded:
		reload()
	if _clerk_scrap < 12:
		_clerk_scrap = 12
	var already := has_flag(FLAG_REMNANT)
	set_flag(FLAG_REMNANT, true)
	if already:
		save()


func wipe_for_tests() -> void:
	_flags.clear()
	_clerk_scrap = 0
	save()
	SignalBus.meta_progress_changed.emit()


func unlock_architecture_for_tests(arch_id: int) -> void:
	match arch_id:
		GameplayEnums.ArchitectureId.NANOMACHINES:
			set_flag(FLAG_HIVE, true)
		GameplayEnums.ArchitectureId.ELECTRO_TRAIN:
			set_flag(FLAG_WARDEN, true)
		GameplayEnums.ArchitectureId.NEURO_HACKER:
			set_flag(FLAG_REMNANT, true)


func unlock_all_for_tests() -> void:
	set_flag(FLAG_HIVE, true)
	set_flag(FLAG_WARDEN, true)
	set_flag(FLAG_REMNANT, true)
