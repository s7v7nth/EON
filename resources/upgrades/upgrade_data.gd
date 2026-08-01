class_name UpgradeData
extends Resource
## Craftable upgrade — one verb/rule per upgrade. Tagged by architecture.

@export var upgrade_id: StringName = &""
@export var display_name: String = "Upgrade"
@export_multiline var description: String = ""
@export var architecture_id: GameplayEnums.ArchitectureId = GameplayEnums.ArchitectureId.DEFAULT
@export var required_tags: PackedStringArray = []
@export var grant_tags: PackedStringArray = []

@export_group("Effects")
@export var damage_mult: float = 1.0
@export var life_steal_bonus: float = 0.0
@export var hp_regen_bonus: float = 0.0
@export var enable_hookshot: bool = false
@export var enable_room_infect: bool = false
@export var enable_proximity_pulse: bool = false
@export var proximity_damage: float = 0.0
@export var infect_tick_damage: float = 0.0
