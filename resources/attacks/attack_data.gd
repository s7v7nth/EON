class_name AttackData
extends Resource
## Tunable attack properties — future weapon modules = new AttackData resources.

enum PatternKind {
	SLASH,
	OVERHEAD_SLAM,
	LUNGE,
	COMBO,
	CHARGE_SHOT,
	FAN_SHOT,
}

@export var damage: float = 10.0
@export var cooldown: float = 0.5
@export var windup: float = 0.05
@export var active_duration: float = 0.15
@export var knockback_force: float = 0.0

@export_group("Elements")
@export var damage_type: GameplayEnums.DamageType = GameplayEnums.DamageType.PHYSICAL
@export_range(0.0, 1.0, 0.01) var status_chance: float = 0.0
@export var status_power: float = 0.0
@export var status_duration: float = 2.0

@export_group("Combo")
## Optional next hit in a melee string (null = end of combo).
@export var combo_next: AttackData
@export var combo_scale: float = 1.0
## When true, hitbox is centered on the owner as a circular AoE.
@export var circular: bool = false
@export var circular_radius: float = 72.0

@export_group("Pattern")
## Hostile move vocabulary — drives telegraphs + AI state selection.
@export var pattern_kind: PatternKind = PatternKind.SLASH
## Gap-close impulse distance for LUNGE / leap states.
@export var lunge_distance: float = 0.0
## Fraction of windup after which aim locks (Souls-style commit). 1 = lock only at active.
@export_range(0.0, 1.0, 0.01) var commit_lock_early: float = 0.7
## AI pick weight when selecting from a moveset.
@export var select_weight: float = 1.0
## Preferred engagement band for moveset picking.
@export var min_range: float = 0.0
@export var max_range: float = 9999.0

@export_group("Projectile")
## 0 = melee attack; > 0 = ranged, projectile flies at this speed.
@export var projectile_speed: float = 0.0
@export var projectile_lifetime: float = 1.2
## When true, projectile returns to source after hit or max range.
@export var returning: bool = false
## Volley size for FAN_SHOT / multi-charge.
@export var projectile_count: int = 1
## Total spread in degrees across the volley (0 = all same direction).
@export var spread_deg: float = 0.0
## Delay between projectiles in a volley.
@export var projectile_delay: float = 0.0

@export_group("Cost")
## Energy spent to perform this attack (architecture may override).
@export var energy_cost: float = 0.0

@export_group("Feel")
## Endlag after active when the string does not continue.
@export var recovery: float = 0.0
## Locomotion multiplier during windup / active / recover (1 = full speed).
@export_range(0.0, 1.0, 0.01) var move_mult: float = 1.0
## Self-impulse toward aim when the hitbox activates.
@export var lunge_force: float = 0.0
## Engine.time_scale during HitStop.punch (lower = heavier).
@export var hit_stop_scale: float = 0.12
@export var hit_stop_duration: float = 0.045
## How long knockback fades on the target.
@export var knockback_duration: float = 0.15
## Camera shake amount on connect (0 = none).
@export var camera_trauma: float = 0.0
## Poise damage applied to enemies on hit (flinch breaker).
@export var poise_damage: float = 10.0
## Multiplier for HitVFX burst density / size.
@export var impact_scale: float = 1.0


func is_ranged_pattern() -> bool:
	return (
		pattern_kind == PatternKind.CHARGE_SHOT
		or pattern_kind == PatternKind.FAN_SHOT
		or projectile_speed > 0.0
	)


func is_leap_pattern() -> bool:
	return pattern_kind == PatternKind.LUNGE


func in_range_band(distance: float) -> bool:
	return distance >= min_range and distance <= max_range
