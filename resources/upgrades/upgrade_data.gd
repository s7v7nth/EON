class_name UpgradeData
extends Resource
## Craftable upgrade — verbs live in UpgradeEffect plugins.

@export var upgrade_id: StringName = &""
@export var display_name: String = "Upgrade"
@export_multiline var description: String = ""
@export var architecture_id: GameplayEnums.ArchitectureId = GameplayEnums.ArchitectureId.DEFAULT
@export var required_tags: PackedStringArray = []
@export var grant_tags: PackedStringArray = []
@export var effects: Array = []
## When true, offered in post-room Rewards (boon column) without loot-tag gating.
@export var reward_offerable: bool = false

@export_group("Legacy / simple mods")
## Kept for convenience; prefer EffectDamageMult in effects[].
@export var damage_mult: float = 1.0
