class_name UpgradeData
extends Resource
## Craftable upgrade / Hades-style artifact — verbs live in UpgradeEffect plugins.

enum Rarity { COMMON, RARE, EPIC, LEGENDARY }
enum House { CORE, SIGNAL, FORGE, HIVE, VOLT, NEURO, BLOOD, GEOMETRY }

@export var upgrade_id: StringName = &""
@export var display_name: String = "Upgrade"
@export_multiline var description: String = ""
@export var architecture_id: GameplayEnums.ArchitectureId = GameplayEnums.ArchitectureId.DEFAULT
@export var required_tags: PackedStringArray = []
@export var grant_tags: PackedStringArray = []
@export var effects: Array = []
## When true, offered in post-room Rewards (boon column) without loot-tag gating.
@export var reward_offerable: bool = false
## Shared boons can be taken by any architecture.
@export var any_architecture: bool = false
@export var rarity: Rarity = Rarity.COMMON
@export var house: House = House.CORE

@export_group("Legacy / simple mods")
## Kept for convenience; prefer EffectDamageMult in effects[].
@export var damage_mult: float = 1.0


static func rarity_name(r: Rarity) -> String:
	match r:
		Rarity.COMMON:
			return "Common"
		Rarity.RARE:
			return "Rare"
		Rarity.EPIC:
			return "Epic"
		Rarity.LEGENDARY:
			return "Legendary"
	return "Common"


static func house_name(h: House) -> String:
	match h:
		House.CORE:
			return "Core"
		House.SIGNAL:
			return "Signal"
		House.FORGE:
			return "Forge"
		House.HIVE:
			return "Hive"
		House.VOLT:
			return "Volt"
		House.NEURO:
			return "Neuro"
		House.BLOOD:
			return "Blood"
		House.GEOMETRY:
			return "Geometry"
	return "Core"


static func house_color(h: House) -> Color:
	match h:
		House.CORE:
			return Color(0.82, 0.84, 0.9)
		House.SIGNAL:
			return Color(0.35, 0.85, 1.0)
		House.FORGE:
			return Color(0.95, 0.55, 0.22)
		House.HIVE:
			return Color(0.4, 0.9, 0.42)
		House.VOLT:
			return Color(0.98, 0.88, 0.28)
		House.NEURO:
			return Color(0.72, 0.42, 0.95)
		House.BLOOD:
			return Color(0.92, 0.22, 0.32)
		House.GEOMETRY:
			return Color(0.45, 0.75, 1.0)
	return Color.WHITE


static func rarity_color(r: Rarity) -> Color:
	match r:
		Rarity.COMMON:
			return Color(0.78, 0.8, 0.84)
		Rarity.RARE:
			return Color(0.35, 0.7, 1.0)
		Rarity.EPIC:
			return Color(0.72, 0.4, 0.95)
		Rarity.LEGENDARY:
			return Color(1.0, 0.78, 0.2)
	return Color.WHITE
