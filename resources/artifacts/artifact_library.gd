class_name ArtifactLibrary
extends RefCounted
## Builds the shared Hades-style boon pool at runtime (42+ distinct artifacts).


static func all_boons() -> Array[UpgradeData]:
	var out: Array[UpgradeData] = []
	# CORE — survival / baseline verbs
	out.append(_boon(&"serrated_protocol", "Serrated Protocol", "Outgoing damage +20%.", UpgradeData.House.CORE, UpgradeData.Rarity.COMMON, [_p(&"damage", 1.2)]))
	out.append(_boon(&"kinetic_weave", "Kinetic Weave", "Move speed +15%.", UpgradeData.House.CORE, UpgradeData.Rarity.COMMON, [_p(&"speed", 1.15)]))
	out.append(_boon(&"slipstream_coil", "Slipstream Coil", "Dash energy cost −25%.", UpgradeData.House.CORE, UpgradeData.Rarity.COMMON, [_p(&"dash_cost", 0.75)]))
	out.append(_boon(&"plated_heart", "Plated Heart", "+25 max HP.", UpgradeData.House.CORE, UpgradeData.Rarity.COMMON, [_p(&"hp", 25.0)]))
	out.append(_boon(&"capacitor_mesh", "Capacitor Mesh", "Attack speed +20%.", UpgradeData.House.CORE, UpgradeData.Rarity.RARE, [_p(&"attack_speed", 0.2)]))
	out.append(_boon(&"second_dawn", "Second Dawn", "Once per room, survive a killing blow at 30% HP with a burst of i-frames.", UpgradeData.House.CORE, UpgradeData.Rarity.LEGENDARY, [_p(&"second_wind", 0.3)]))

	# SIGNAL — dash / i-frames / style
	out.append(_boon(&"umbral_step", "Umbral Step", "Dash pulses damage around you.", UpgradeData.House.SIGNAL, UpgradeData.Rarity.RARE, [_p(&"dash_pulse", 78.0, 14.0)]))
	out.append(_boon(&"afterimage_veil", "Afterimage Veil", "Dash i-frames last +0.28s after the burst.", UpgradeData.House.SIGNAL, UpgradeData.Rarity.RARE, [_p(&"dash_iframes", 0.28)]))
	out.append(_boon(&"ghost_frequency", "Ghost Frequency", "Dash cooldown −35%.", UpgradeData.House.SIGNAL, UpgradeData.Rarity.COMMON, [_p(&"dash_cooldown", 0.65)]))
	out.append(_boon(&"perfect_cadence", "Perfect Cadence", "Kills restore a burst of combat resource.", UpgradeData.House.SIGNAL, UpgradeData.Rarity.RARE, [_p(&"kill_energy", 18.0)]))
	out.append(_boon(&"echo_wake", "Echo Wake", "Dash leaves a slowing acid wake.", UpgradeData.House.SIGNAL, UpgradeData.Rarity.EPIC, [_p(&"dash_status", 28.0, 90.0, StatusComponent.STATUS_ACID)]))
	out.append(_boon(&"night_circuit", "Night Circuit", "After a dash, +25% crit for 1.2s.", UpgradeData.House.SIGNAL, UpgradeData.Rarity.EPIC, [_p(&"dash_crit", 0.25, 1.2)]))

	# FORGE — armor / knockback / commitment
	out.append(_boon(&"iron_skin", "Iron Skin", "Take 15% less damage.", UpgradeData.House.FORGE, UpgradeData.Rarity.COMMON, [_p(&"incoming", 0.85)]))
	out.append(_boon(&"sledge_rhythm", "Sledge Rhythm", "Every 3rd melee hit detonates bonus damage and knockback.", UpgradeData.House.FORGE, UpgradeData.Rarity.RARE, [_p(&"sledge", 12.0)]))
	out.append(_boon(&"anvil_guard", "Anvil Guard", "Blocking reduces even more damage.", UpgradeData.House.FORGE, UpgradeData.Rarity.RARE, [_p(&"block_mult", 0.65)]))
	out.append(_boon(&"sparks_of_labor", "Sparks of Labor", "Melee hits restore a trickle of resource.", UpgradeData.House.FORGE, UpgradeData.Rarity.RARE, [_p(&"hit_energy", 6.0)]))
	out.append(_boon(&"heavy_cadence", "Heavy Cadence", "Attacks feel heavier: +35% damage, −10% attack speed.", UpgradeData.House.FORGE, UpgradeData.Rarity.EPIC, [_p(&"damage", 1.35), _p(&"attack_speed", -0.1)]))
	out.append(_boon(&"titanbreak", "Titanbreak", "Melee hits slam stagger buildup into foes.", UpgradeData.House.FORGE, UpgradeData.Rarity.LEGENDARY, [_p(&"status_melee", 1.0, 36.0, StatusComponent.STATUS_STAGGER)]))

	# HIVE — lifesteal / acid / swarm
	out.append(_boon(&"bloodletter", "Bloodletter", "Hits return a sliver of HP.", UpgradeData.House.HIVE, UpgradeData.Rarity.COMMON, [_p(&"lifesteal", 0.08)]))
	out.append(_boon(&"neurotoxin_edge", "Neurotoxin Edge", "Melee applies Acid buildup.", UpgradeData.House.HIVE, UpgradeData.Rarity.RARE, [_p(&"status_melee", 0.85, 26.0, StatusComponent.STATUS_ACID)]))
	out.append(_boon(&"swarm_heart", "Swarm Heart", "Kills heal 10 HP.", UpgradeData.House.HIVE, UpgradeData.Rarity.COMMON, [_p(&"kill_heal", 10.0)]))
	out.append(_boon(&"biotic_bloom", "Biotic Bloom", "Regenerate 4 HP/s in combat.", UpgradeData.House.HIVE, UpgradeData.Rarity.RARE, [_p(&"hp_regen", 4.0)]))
	out.append(_boon(&"infectious_dash", "Infectious Dash", "Dash infects nearby foes with Acid.", UpgradeData.House.HIVE, UpgradeData.Rarity.EPIC, [_p(&"dash_status", 32.0, 88.0, StatusComponent.STATUS_ACID)]))
	out.append(_boon(&"queen_protocol", "Queen Protocol", "Kills erupt in a corrosive pulse.", UpgradeData.House.HIVE, UpgradeData.Rarity.LEGENDARY, [_p(&"kill_pulse", 90.0, 16.0)]))

	# VOLT — shock / chain / speed
	out.append(_boon(&"quickening", "Quickening", "Attack speed +18%.", UpgradeData.House.VOLT, UpgradeData.Rarity.COMMON, [_p(&"attack_speed", 0.18)]))
	out.append(_boon(&"arc_lash", "Arc Lash", "25% chance for hits to chain lightning.", UpgradeData.House.VOLT, UpgradeData.Rarity.RARE, [_p(&"chain", 0.25, 10.0)]))
	out.append(_boon(&"static_dash", "Static Dash", "Dash shocks everyone nearby.", UpgradeData.House.VOLT, UpgradeData.Rarity.RARE, [_p(&"dash_pulse", 86.0, 12.0), _p(&"dash_status", 24.0, 86.0, StatusComponent.STATUS_SHOCK)]))
	out.append(_boon(&"overclock_gland", "Overclock Gland", "Hits flood adrenaline faster.", UpgradeData.House.VOLT, UpgradeData.Rarity.COMMON, [_p(&"adrenaline_gain", 1.45)]))
	out.append(_boon(&"feedback_loop", "Feedback Loop", "Ranged connects refund 40% cooldown.", UpgradeData.House.VOLT, UpgradeData.Rarity.EPIC, [_p(&"feedback", 0.4)]))
	out.append(_boon(&"thunderhead", "Thunderhead", "Lightning always chains twice and staggers.", UpgradeData.House.VOLT, UpgradeData.Rarity.LEGENDARY, [_p(&"thunderhead", 2.0, 14.0)]))

	# NEURO — crit / glitch / execute
	out.append(_boon(&"nightblade", "Nightblade", "+15% critical chance.", UpgradeData.House.NEURO, UpgradeData.Rarity.COMMON, [_p(&"crit", 0.15)]))
	out.append(_boon(&"fault_injector", "Fault Injector", "Hits apply Glitch buildup.", UpgradeData.House.NEURO, UpgradeData.Rarity.RARE, [_p(&"status_hit", 0.7, 24.0, StatusComponent.STATUS_GLITCH)]))
	out.append(_boon(&"executioners_eye", "Executioner's Eye", "Foes below 25% HP take +45% damage.", UpgradeData.House.NEURO, UpgradeData.Rarity.RARE, [_p(&"execute", 0.25, 1.45)]))
	out.append(_boon(&"hyperthread", "Hyperthread", "+20% crit. Crits hit 75% harder.", UpgradeData.House.NEURO, UpgradeData.Rarity.EPIC, [_p(&"crit", 0.2), _p(&"crit_mult", 0.75)]))
	out.append(_boon(&"mindshatter", "Mindshatter", "Critical hits dump Stagger.", UpgradeData.House.NEURO, UpgradeData.Rarity.EPIC, [_p(&"mindshatter", 1.0), _p(&"crit", 0.08)]))
	out.append(_boon(&"eclipse_protocol", "Eclipse Protocol", "Below 40% HP: +50% damage and +20% crit.", UpgradeData.House.NEURO, UpgradeData.Rarity.LEGENDARY, [_p(&"low_hp_fury", 0.4, 1.5)]))

	# BLOOD — bleed / frenzy / execute-heal
	out.append(_boon(&"wound_stack", "Wound Stack", "Melee applies Bleed.", UpgradeData.House.BLOOD, UpgradeData.Rarity.COMMON, [_p(&"status_melee", 0.9, 24.0, StatusComponent.STATUS_BLEED)]))
	out.append(_boon(&"frenzy_kill", "Frenzy Kill", "Kills grant +30% move speed for 2.5s.", UpgradeData.House.BLOOD, UpgradeData.Rarity.COMMON, [_p(&"kill_frenzy", 1.3, 2.5)]))
	out.append(_boon(&"adrenal_surge", "Adrenal Surge", "Combat hits generate far more adrenaline.", UpgradeData.House.BLOOD, UpgradeData.Rarity.COMMON, [_p(&"adrenaline_gain", 1.6)]))
	out.append(_boon(&"crimson_cast", "Crimson Cast", "Kills restore a chunk of resource.", UpgradeData.House.BLOOD, UpgradeData.Rarity.RARE, [_p(&"kill_energy", 22.0)]))
	out.append(_boon(&"blood_moon", "Blood Moon", "Below 40% HP, deal +35% damage.", UpgradeData.House.BLOOD, UpgradeData.Rarity.EPIC, [_p(&"low_hp_fury", 0.4, 1.35)]))
	out.append(_boon(&"redline_harvest", "Redline Harvest", "Execute window 40%. Executing heals 18.", UpgradeData.House.BLOOD, UpgradeData.Rarity.LEGENDARY, [_p(&"execute", 0.4, 1.55), _p(&"execute_heal", 18.0)]))

	# Extra discoverables to push past 42 and fill holes
	out.append(_boon(&"prism_heart", "Prism Heart", "+40 max HP and +8% incoming reduction.", UpgradeData.House.CORE, UpgradeData.Rarity.EPIC, [_p(&"hp", 40.0), _p(&"incoming", 0.92)]))
	out.append(_boon(&"ripcurrent", "Ripcurrent", "Projectiles pierce +1 additional foe.", UpgradeData.House.SIGNAL, UpgradeData.Rarity.RARE, [_p(&"pierce", 1.0)]))
	out.append(_boon(&"high_tide", "High Tide", "Specials throw +1 extra projectile.", UpgradeData.House.VOLT, UpgradeData.Rarity.EPIC, [_p(&"extra_projectiles", 1.0)]))
	out.append(_boon(&"fortress_stance", "Fortress Stance", "Take 22% less damage, move 6% slower.", UpgradeData.House.FORGE, UpgradeData.Rarity.EPIC, [_p(&"incoming", 0.78), _p(&"speed", 0.94)]))
	out.append(_boon(&"hungering_dark", "Hungering Dark", "Kills heal 6 and restore resource.", UpgradeData.House.BLOOD, UpgradeData.Rarity.RARE, [_p(&"kill_heal", 6.0), _p(&"kill_energy", 12.0)]))
	out.append(_boon(&"sunspot", "Sunspot", "Hits apply Burn buildup.", UpgradeData.House.FORGE, UpgradeData.Rarity.RARE, [_p(&"status_hit", 0.75, 22.0, StatusComponent.STATUS_BURN)]))
	out.append(_boon(&"void_cloak", "Void Cloak", "Dash cooldown −20% and +0.12s i-frames.", UpgradeData.House.SIGNAL, UpgradeData.Rarity.EPIC, [_p(&"dash_cooldown", 0.8), _p(&"dash_iframes", 0.12)]))
	out.append(_boon(&"radiant_edge", "Radiant Edge", "+12% damage. Hits have a chance to Burn.", UpgradeData.House.CORE, UpgradeData.Rarity.RARE, [_p(&"damage", 1.12), _p(&"status_hit", 0.35, 18.0, StatusComponent.STATUS_BURN)]))

	return out


static func count() -> int:
	return all_boons().size()


static func _p(kind: StringName, value: float, value_b: float = 0.0, status_id: StringName = &"") -> EffectBoonProc:
	var fx := EffectBoonProc.new()
	fx.kind = kind
	fx.value = value
	fx.value_b = value_b
	fx.status_id = status_id
	if kind == &"damage":
		# damage_multiplier hook lives on the effect itself
		fx.set_meta("damage_mult", value)
	if kind == &"low_hp_fury":
		fx.set_meta("low_hp", value)
		fx.set_meta("low_hp_mult", value_b)
	return fx


static func _boon(
		id: StringName,
		title: String,
		desc: String,
		house: UpgradeData.House,
		rarity: UpgradeData.Rarity,
		effects: Array
	) -> UpgradeData:
	var u := UpgradeData.new()
	u.upgrade_id = id
	u.display_name = title
	u.description = desc
	u.house = house
	u.rarity = rarity
	u.reward_offerable = true
	u.any_architecture = true
	u.architecture_id = GameplayEnums.ArchitectureId.DEFAULT
	u.effects = effects
	u.grant_tags = PackedStringArray([String(id), UpgradeData.house_name(house).to_lower()])
	return u