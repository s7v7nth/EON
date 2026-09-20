extends Node
## Authoritative meta progress. Loaded from user:// on boot; class select and
## architecture equip both consult this file — not a client-side UI tick.

const SAVE_PATH := "user://eon_meta.cfg"
const SECTION := "progress"

const FLAG_HIVE := &"hive_killed"
const FLAG_WARDEN := &"warden_killed"
const FLAG_REMNANT := &"remnant_spoken"

var _flags: Dictionary = {}
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
			return "Defeat The Hive"
		GameplayEnums.ArchitectureId.ELECTRO_TRAIN:
			return "Defeat The Warden"
		GameplayEnums.ArchitectureId.NEURO_HACKER:
			return "Hear the Remnant"
		_:
			return ""


func note_boss_killed(boss_id: StringName) -> void:
	match boss_id:
		&"hive":
			set_flag(FLAG_HIVE, true)
		&"warden":
			set_flag(FLAG_WARDEN, true)


func note_remnant_spoken() -> void:
	set_flag(FLAG_REMNANT, true)


func wipe_for_tests() -> void:
	_flags.clear()
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
