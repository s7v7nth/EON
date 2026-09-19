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
]


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