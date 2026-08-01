class_name CharacterStats
extends Resource
## Tunable character attributes — assign via .tres, never hardcode in scripts.

@export_group("Vitality")
@export var max_health: float = 100.0

@export_group("Movement")
@export var move_speed: float = 300.0

@export_group("Energy")
@export var max_energy: float = 100.0
@export var energy_regen_rate: float = 20.0

@export_group("Dash")
@export var dash_speed: float = 900.0
@export var dash_duration: float = 0.15
@export var dash_cost: float = 25.0
@export var dash_cooldown: float = 1.5

@export_group("Adrenaline")
@export var max_adrenaline: float = 100.0
@export var adrenaline_gain_on_hit: float = 10.0
@export var adrenaline_gain_on_hurt: float = 5.0
@export var adrenaline_decay_delay: float = 2.0
@export var adrenaline_decay_rate: float = 15.0
