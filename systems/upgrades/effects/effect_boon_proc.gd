class_name EffectBoonProc
extends "res://systems/upgrades/upgrade_effect.gd"
## Data-driven Hades-style boon verb. `kind` selects the hook; values tune it.

@export var kind: StringName = &""
@export var value: float = 0.0
@export var value_b: float = 0.0
@export var status_id: StringName = &""

var _melee_hits: int = 0
var _second_wind_used: bool = false


func damage_multiplier(host: Node) -> float:
	var m := 1.0
	if kind == &"damage" or has_meta("damage_mult"):
		var stored := float(get_meta("damage_mult", value if kind == &"damage" else 1.0))
		if stored > 0.0:
			m *= stored
	if kind == &"low_hp_fury" and _is_low_hp(host, value):
		m *= maxf(value_b, 1.0)
	return m


func extra_crit_chance(host: Node) -> float:
	if kind == &"low_hp_fury" and _is_low_hp(host, value):
		return 0.2
	return 0.0


func _is_low_hp(host: Node, threshold: float) -> bool:
	var health = host.get("health") if host else null
	if health == null or not health.has_method("get_max_health"):
		return false
	var mx := float(health.get_max_health())
	if mx <= 0.0:
		return false
	return float(health.current_health) / mx <= threshold


func apply(host: Node) -> void:
	if host == null:
		return
	match kind:
		&"speed":
			host.move_speed_multiplier *= maxf(value, 0.1)
		&"dash_cost":
			host.dash_cost_multiplier *= maxf(value, 0.05)
		&"hp":
			if host.has_method("add_max_health"):
				host.call("add_max_health", value)
		&"incoming":
			host.set("incoming_damage_mult", float(host.get("incoming_damage_mult")) * value)
		&"lifesteal":
			host.set("_life_steal_bonus", float(host.get("_life_steal_bonus")) + value)
		&"hp_regen":
			host.set("_hp_regen_bonus", float(host.get("_hp_regen_bonus")) + value)
		&"attack_speed":
			host.set("attack_speed_bonus", float(host.get("attack_speed_bonus")) + value)
		&"crit":
			host.set("crit_chance", float(host.get("crit_chance")) + value)
		&"crit_mult":
			host.set("crit_damage", float(host.get("crit_damage")) + value)
		&"execute":
			host.set("execute_threshold", maxf(float(host.get("execute_threshold")), value))
			host.set("execute_bonus", maxf(float(host.get("execute_bonus")), value_b))
		&"adrenaline_gain":
			host.set("adrenaline_gain_mult", float(host.get("adrenaline_gain_mult")) * value)
		&"dash_iframes":
			host.set("dash_iframe_bonus", float(host.get("dash_iframe_bonus")) + value)
		&"dash_cooldown":
			host.set("dash_cooldown_mult", float(host.get("dash_cooldown_mult")) * value)
		&"pierce":
			host.set("projectile_pierce", int(host.get("projectile_pierce")) + int(value))
		&"extra_projectiles":
			host.set("extra_projectiles", int(host.get("extra_projectiles")) + int(value))
		&"block_mult":
			var hurt := host.get("hurtbox")
			if hurt:
				hurt.block_damage_mult *= value
		&"second_wind":
			host.set("second_wind_charges", int(host.get("second_wind_charges")) + int(maxf(value, 1.0)))
		&"ranged_cooldown":
			host.set("ranged_cooldown_mult", float(host.get("ranged_cooldown_mult")) * value)
		&"knockback":
			host.set("knockback_bonus", float(host.get("knockback_bonus")) + value)


func on_melee_hit(host: Node, target: Node) -> void:
	_melee_hits += 1
	_try_status(host, target)
	_try_chain(host, target)
	if kind == &"sledge" and _melee_hits % 3 == 0:
		_sledge_burst(host, target)
	if kind == &"mindshatter" and bool(host.get("last_hit_was_crit")):
		_apply_status_to(target, StatusComponent.STATUS_STAGGER, 40.0, 1.2)
	if kind == &"hit_energy" and host.has_method("restore_resource"):
		host.call("restore_resource", value)


func on_ranged_hit(host: Node, target: Node) -> void:
	_try_status(host, target)
	_try_chain(host, target)
	if kind == &"feedback" and host.has_method("refund_ranged_cooldown"):
		host.call("refund_ranged_cooldown", value)


func on_kill(host: Node, _enemy: Node) -> void:
	if host == null:
		return
	match kind:
		&"kill_heal":
			var health = host.get("health")
			if health and health.has_method("heal"):
				health.heal(value)
		&"kill_frenzy":
			if host.has_method("grant_frenzy"):
				host.call("grant_frenzy", value, value_b)
		&"kill_energy":
			if host.has_method("restore_resource"):
				host.call("restore_resource", value)
		&"kill_pulse":
			_pulse(host, value, value_b)
		&"execute_heal":
			var health2 = host.get("health")
			if health2 and health2.has_method("heal"):
				health2.heal(value)


func on_dash(host: Node, _direction: Vector2) -> void:
	if host == null:
		return
	match kind:
		&"dash_pulse":
			_pulse(host, value, value_b)
		&"dash_status":
			for enemy in _enemies_near(host, maxf(value_b, 70.0)):
				_apply_status_to(enemy, status_id, value, 1.0)
		&"dash_crit":
			if host.has_method("grant_temp_crit"):
				host.call("grant_temp_crit", value, value_b)


func on_fatal_damage(host: Node, _amount: float) -> bool:
	if kind != &"second_wind":
		return false
	if _second_wind_used:
		return false
	_second_wind_used = true
	var charges := int(host.get("second_wind_charges"))
	host.set("second_wind_charges", maxi(charges - 1, 0))
	var health = host.get("health")
	if health:
		var max_hp := float(health.get_max_health()) if health.has_method("get_max_health") else 100.0
		health.current_health = maxf(max_hp * maxf(value, 0.2), 1.0)
		health.health_changed.emit(health.current_health, max_hp)
	if host.has_method("grant_second_wind_iframes"):
		host.call("grant_second_wind_iframes")
	if host is Node2D:
		HitVFX.spawn_optic_burst(
			(host as Node2D).get_parent(),
			(host as Node2D).global_position,
			Color(1.0, 0.85, 0.4, 1),
			Vector2.UP,
			1.4
		)
	return true


func _try_status(_host: Node, target: Node) -> void:
	if kind != &"status_melee" and kind != &"status_hit":
		return
	if status_id == StringName():
		return
	if randf() > value:
		return
	_apply_status_to(target, status_id, value_b if value_b > 0.0 else 22.0, 1.0)


func _try_chain(host: Node, target: Node) -> void:
	if kind != &"chain" and kind != &"thunderhead":
		return
	var chance := value if kind == &"chain" else 0.85
	if randf() > chance:
		return
	var jumps := 1
	if kind == &"thunderhead":
		jumps = maxi(int(value), 2)
	var origin: Node2D = null
	if target is HurtboxComponent and (target as HurtboxComponent).get_parent() is Node2D:
		origin = (target as HurtboxComponent).get_parent() as Node2D
	elif target is Node2D:
		origin = target as Node2D
	if origin == null or host is not Node2D:
		return
	var dmg := 8.0 + value_b
	var from_pos := origin.global_position
	var last: Node2D = origin
	var hit_ids: Dictionary = {origin.get_instance_id(): true}
	for _i in jumps:
		var next: Node2D = null
		var best := 160.0
		for enemy in _enemies_near(host, 220.0):
			if enemy is not Node2D:
				continue
			var n2 := enemy as Node2D
			if hit_ids.has(n2.get_instance_id()):
				continue
			var d := last.global_position.distance_to(n2.global_position)
			if d < best:
				best = d
				next = n2
		if next == null:
			break
		hit_ids[next.get_instance_id()] = true
		_damage_enemy(next, dmg, host)
		_bolt(host as Node2D, from_pos, next.global_position)
		if kind == &"thunderhead":
			_apply_status_to(next, StatusComponent.STATUS_STAGGER, 28.0, 0.8)
		from_pos = next.global_position
		last = next
		dmg *= 0.85


func _sledge_burst(host: Node, target: Node) -> void:
	var body: Node = target
	if target is HurtboxComponent:
		body = (target as HurtboxComponent).get_parent()
	if body and body.has_method("apply_knockback") and host is Node2D and body is Node2D:
		var away: Vector2 = (body as Node2D).global_position - (host as Node2D).global_position
		body.call("apply_knockback", away.normalized(), 420.0, 0.22)
	_damage_enemy(body, value, host)
	if host is Node2D:
		HitVFX.spawn_optic_burst(
			(host as Node2D).get_parent(),
			(host as Node2D).global_position,
			Color(1.0, 0.6, 0.2, 1),
			Vector2.RIGHT,
			1.1
		)


func _pulse(host: Node, radius: float, damage: float) -> void:
	if host is not Node2D:
		return
	var origin := host as Node2D
	for enemy in _enemies_near(host, radius):
		_damage_enemy(enemy, damage, host)
	HitVFX.spawn_optic_burst(origin.get_parent(), origin.global_position, Color(0.55, 0.9, 1.0, 1), Vector2.UP, 1.0)


func _damage_enemy(enemy: Node, amount: float, source: Node) -> void:
	if enemy == null or amount <= 0.0:
		return
	var health = enemy.get("health")
	if health and health.has_method("take_damage"):
		health.take_damage(amount)
		SignalBus.damage_dealt.emit(amount, enemy, source)


func _apply_status_to(target: Node, sid: StringName, buildup: float, power: float) -> void:
	if sid == StringName() or target == null:
		return
	var node := target
	if target is HurtboxComponent:
		node = (target as HurtboxComponent).get_parent()
	var status = node.get_node_or_null("StatusComponent") if node else null
	if status == null:
		status = node.get("status") if node else null
	if status and status.has_method("add_buildup"):
		status.add_buildup(sid, buildup, power)


func _bolt(host: Node2D, from_pos: Vector2, to_pos: Vector2) -> void:
	var parent := host.get_parent()
	if parent == null:
		return
	var line := Line2D.new()
	line.width = 3.0
	line.default_color = Color(0.65, 0.9, 1.0, 0.95)
	line.z_index = 40
	line.points = PackedVector2Array([from_pos, to_pos])
	parent.add_child(line)
	var tw := line.create_tween()
	tw.tween_property(line, "modulate:a", 0.0, 0.18)
	tw.tween_callback(line.queue_free)
