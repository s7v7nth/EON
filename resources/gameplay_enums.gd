class_name GameplayEnums
extends RefCounted
## Shared ids for damage, factions, biomes, architectures. Data-only — no runtime state.


enum DamageType {
	PHYSICAL,
	ELECTRICITY,
	CORROSION,
	FIRE,
	BLEED,
}

enum Faction {
	SAVAGE,
	CYBORG,
	ANDROID,
	ROBO_BEAST,
}

enum BiomeId {
	JUNGLE,
	DATA_CENTER,
	DOWNTOWN,
	RESIDENTIAL,
	TAIGA,
	ALLEY,
	LANDFILL,
	MALL,
	WASTELAND,
	GATEWAY,
}

enum ArchitectureId {
	DEFAULT,
	NANOMACHINES,
	ELECTRO_TRAIN,
}

enum EconomyPolicy {
	## Spend energy on non-move actions; adrenaline boosts regen.
	ENERGY_ADRENALINE,
	## Energy feeds the swarm (drain); HP regenerates / vamp.
	NANO_SWARM,
	## Burst window then overheat cooldown.
	OVERHEAT,
}

enum StyleAction {
	HIT,
	KILL,
	PERFECT_DODGE,
	PARRY,
	COMBO,
	MULTI_KILL,
	ELEMENT_CASCADE,
	TOOK_DAMAGE,
}


static func damage_type_name(t: DamageType) -> String:
	match t:
		DamageType.PHYSICAL:
			return "Physical"
		DamageType.ELECTRICITY:
			return "Electricity"
		DamageType.CORROSION:
			return "Corrosion"
		DamageType.FIRE:
			return "Fire"
		DamageType.BLEED:
			return "Bleed"
	return "Unknown"


static func architecture_name(a: ArchitectureId) -> String:
	match a:
		ArchitectureId.DEFAULT:
			return "Default"
		ArchitectureId.NANOMACHINES:
			return "Nanomachines"
		ArchitectureId.ELECTRO_TRAIN:
			return "Electro-Train"
	return "Unknown"
