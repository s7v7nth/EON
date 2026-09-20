class_name ArtifactCombos
extends RefCounted
## Named boon+boon combos. Unlocked when both ids are owned; extra verbs stack.

const RECIPES: Array[Dictionary] = [
	{
		"id": &"storm_step",
		"name": "Storm Step",
		"need": [&"arc_lash", &"static_dash"],
		"desc": "Dash lightning jumps an extra time.",
		"kind": &"thunderhead",
		"value": 1.0,
		"value_b": 8.0,
	},
	{
		"id": &"mercy_kill",
		"name": "Mercy Kill",
		"need": [&"bloodletter", &"executioners_eye"],
		"desc": "Executes heal you.",
		"kind": &"execute_heal",
		"value": 14.0,
	},
	{
		"id": &"phantom_strike",
		"name": "Phantom Strike",
		"need": [&"umbral_step", &"afterimage_veil"],
		"desc": "Dash pulse hits harder and i-frames stretch.",
		"kind": &"dash_pulse",
		"value": 96.0,
		"value_b": 10.0,
	},
	{
		"id": &"spreading_blight",
		"name": "Spreading Blight",
		"need": [&"neurotoxin_edge", &"wound_stack"],
		"desc": "Acid + Bleed on every melee — Napalm Rend bait.",
		"kind": &"status_melee",
		"value": 1.0,
		"value_b": 18.0,
		"status": &"burn",
	},
	{
		"id": &"deadeye",
		"name": "Deadeye",
		"need": [&"nightblade", &"hyperthread"],
		"desc": "Crit chance stacks again.",
		"kind": &"crit",
		"value": 0.12,
	},
	{
		"id": &"fortress",
		"name": "Fortress",
		"need": [&"iron_skin", &"plated_heart"],
		"desc": "Another slab of HP and armor.",
		"kind": &"hp",
		"value": 20.0,
	},
	{
		"id": &"speed_demon",
		"name": "Speed Demon",
		"need": [&"quickening", &"frenzy_kill"],
		"desc": "Permanent attack-speed drip.",
		"kind": &"attack_speed",
		"value": 0.12,
	},
	{
		"id": &"contagion_arc",
		"name": "Contagion Arc",
		"need": [&"infectious_dash", &"arc_lash"],
		"desc": "Dash wakes chain to a nearby foe.",
		"kind": &"dash_pulse",
		"value": 100.0,
		"value_b": 9.0,
	},
	{
		"id": &"last_stand",
		"name": "Last Stand",
		"need": [&"second_dawn", &"eclipse_protocol"],
		"desc": "Second Dawn also grants a brief frenzy.",
		"kind": &"kill_frenzy",
		"value": 1.25,
		"value_b": 2.0,
	},
	{
		"id": &"sun_forge",
		"name": "Sun Forge",
		"need": [&"sunspot", &"sledge_rhythm"],
		"desc": "Heavy third hits ignite.",
		"kind": &"status_hit",
		"value": 1.0,
		"value_b": 28.0,
		"status": &"burn",
	},
	{
		"id": &"ion_phase",
		"name": "Ion Phase",
		"need": [&"phase_capacitor", &"ion_bloom"],
		"desc": "Ranged cadence goes frantic.",
		"kind": &"ranged_cooldown",
		"value": 0.75,
	},
]


static var _last_proc_ms: Dictionary = {}


static func unlocked_for(owned_ids: Array[StringName]) -> Array[Dictionary]:
	var have := {}
	for id in owned_ids:
		have[id] = true
	var out: Array[Dictionary] = []
	for recipe in RECIPES:
		var ok := true
		for need in recipe["need"]:
			if not have.has(need):
				ok = false
				break
		if ok:
			out.append(recipe)
	return out


static func recipe_named(combo_id: StringName) -> Dictionary:
	for recipe in RECIPES:
		if StringName(str(recipe.get("id", &""))) == combo_id:
			return recipe
	return {}


static func completing_partner(owned_ids: Array[StringName], prefer_combo: StringName = &"") -> StringName:
	## Missing half of a recipe the player already owns a piece of.
	var have := {}
	for id in owned_ids:
		have[id] = true
	var fallback := &""
	for recipe in RECIPES:
		var missing: Array[StringName] = []
		for need in recipe["need"]:
			var nid := StringName(str(need))
			if not have.has(nid):
				missing.append(nid)
		if missing.size() != 1:
			continue
		var cid := StringName(str(recipe.get("id", &"")))
		if prefer_combo != &"" and cid == prefer_combo:
			return missing[0]
		if fallback == &"":
			fallback = missing[0]
	return fallback


static func combo_name_if_granted(owned_ids: Array[StringName], new_id: StringName) -> String:
	if new_id == &"":
		return ""
	var before := {}
	for recipe in unlocked_for(owned_ids):
		before[StringName(str(recipe.get("id", &"")))] = true
	var next: Array[StringName] = owned_ids.duplicate()
	next.append(new_id)
	for recipe in unlocked_for(next):
		var cid := StringName(str(recipe.get("id", &"")))
		if not before.has(cid):
			return str(recipe.get("name", "Combo"))
	return ""


static func signature_combo_id(arch_id: int) -> StringName:
	match arch_id:
		GameplayEnums.ArchitectureId.NANOMACHINES:
			return &"mercy_kill"
		GameplayEnums.ArchitectureId.ELECTRO_TRAIN:
			return &"sun_forge"
		GameplayEnums.ArchitectureId.NEURO_HACKER:
			return &"ion_phase"
		_:
			return &"storm_step"


static func signature_seed_id(arch_id: int) -> StringName:
	match arch_id:
		GameplayEnums.ArchitectureId.NANOMACHINES:
			return &"bloodletter"
		GameplayEnums.ArchitectureId.ELECTRO_TRAIN:
			return &"sunspot"
		GameplayEnums.ArchitectureId.NEURO_HACKER:
			return &"phase_capacitor"
		_:
			return &"arc_lash"


static func synergy_title(recipe_id: StringName) -> String:
	match recipe_id:
		&"napalm_rend":
			return "Napalm Rend"
		&"system_crash":
			return "System Crash"
		&"chemical_short":
			return "Chemical Short"
		&"concussive_ignition":
			return "Concussive Ignition"
		_:
			var pretty := String(recipe_id).replace("_", " ")
			if pretty.is_empty():
				return "Combo"
			return pretty.capitalize()


static func synergy_blurb(recipe_id: StringName) -> String:
	match recipe_id:
		&"napalm_rend":
			return "Burn + Bleed ignites the cluster."
		&"system_crash":
			return "Glitch + Shock hard-reboots robots."
		&"chemical_short":
			return "Acid + Shock paralyzes the pack."
		&"concussive_ignition":
			return "Burn + Stagger detonates a stun blast."
		_:
			return "Pairing fired."


static func announce_proc(combo_name: String, description: String, cooldown_ms: int = 900) -> void:
	if combo_name.strip_edges() == "":
		return
	var now := Time.get_ticks_msec()
	var last := int(_last_proc_ms.get(combo_name, 0))
	if now - last < cooldown_ms:
		return
	_last_proc_ms[combo_name] = now
	SignalBus.combo_proc.emit(combo_name, description)