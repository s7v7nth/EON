class_name CombatImpact
extends RefCounted
## Shared hit juice helpers. Hit-stop is authored on AttackData, not victim max HP.


static func hp_frac(hp_damage: float, max_hp: float) -> float:
	return clampf(hp_damage / maxf(max_hp, 1.0), 0.0, 1.5)


static func juice_params(
	hp_damage: float,
	max_hp: float,
	attack_data: AttackData = null,
	victim_is_player: bool = false
) -> Dictionary:
	var frac: float = hp_frac(hp_damage, max_hp)
	var boost: float = lerpf(1.0, 1.5, clampf(frac * 1.35, 0.0, 1.0))
	var ts: float = attack_data.hit_stop_scale if attack_data else 0.15
	var dur: float = (attack_data.hit_stop_duration if attack_data else 0.04) * boost
	var trauma: float = (attack_data.camera_trauma if attack_data else 0.08) * boost
	if victim_is_player:
		## Shorter freeze when you take the hit. Shake + flash still fire.
		ts = minf(1.0, ts + 0.4)
		dur *= 0.42
	return {"frac": frac, "ts": ts, "dur": dur, "trauma": trauma}


static func apply_hit_juice(
	hp_damage: float,
	max_hp: float,
	attack_data: AttackData = null,
	victim_is_player: bool = false
) -> float:
	## Returns frac used for further scaling (knockback etc.).
	var p: Dictionary = juice_params(hp_damage, max_hp, attack_data, victim_is_player)
	HitStop.punch(float(p.ts), float(p.dur))
	CameraFx.add_trauma(float(p.trauma))
	return float(p.frac)


static func knockback_scale(frac: float) -> float:
	return lerpf(0.65, 2.1, clampf(sqrt(frac), 0.0, 1.0))
