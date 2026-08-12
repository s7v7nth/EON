class_name StatusDefinition
extends Resource
## Data for one elemental status: buildup gauge + scripted effects.

@export var status_id: StringName = &""
@export var display_name: String = ""
@export var damage_type: GameplayEnums.DamageType = GameplayEnums.DamageType.PHYSICAL
@export var max_buildup: float = 100.0
@export var decay_per_sec: float = 8.0
@export var tick_interval: float = 0.4
## Duration of the active window after a full-buildup proc.
@export var active_duration: float = 2.5
@export var on_proc: Resource
@export var while_active: Resource
