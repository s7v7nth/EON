class_name CombatImpact
extends RefCounted
## Shared hit juice helpers — hitstop / trauma / KB scaled by damage fraction of max HP.


static func hp_frac(hp_damage: float, max_hp: float) -> float:
	return clampf(hp_damage / maxf(max_hp, 1.0), 0.0, 1.5)


static func apply_hit_juice(hp_damage: float, max_hp: float, attack_data: AttackData = null) -> float:
	## Returns frac used for further scaling (knockback etc.).
	var frac: float = hp_frac(hp_damage, max_hp)
	var weight: float = clampf(frac * 1.35, 0.0, 1.0)
	var ts: float = lerpf(0.08, 0.025, weight)
	var dur: float = lerpf(0.06, 0.18, weight)
	var trauma: float = lerpf(0.2, 0.82, sqrt(clampf(frac, 0.0, 1.0)))
	if attack_data != null:
		ts = minf(ts, attack_data.hit_stop_scale)
		dur = maxf(dur, attack_data.hit_stop_duration * lerpf(0.75, 1.35, weight))
		trauma = maxf(trauma, attack_data.camera_trauma * lerpf(0.6, 1.25, weight))
	HitStop.punch(ts, dur)
	CameraFx.add_trauma(trauma)
	return frac


static func knockback_scale(frac: float) -> float:
	return lerpf(0.65, 2.1, clampf(sqrt(frac), 0.0, 1.0))
