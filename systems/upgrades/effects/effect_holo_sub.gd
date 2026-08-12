class_name EffectHoloSub
extends "res://systems/upgrades/upgrade_effect.gd"
## Fatal hit swaps you with a hologram that detonates (AoE stagger) and grants brief i-frames.

@export var cooldown: float = 18.0
@export var heal_amount: float = 18.0
@export var invuln_time: float = 0.65

var _cd_left: float = 0.0


func tick(_host: Node, delta: float) -> void:
	if _cd_left > 0.0:
		_cd_left = maxf(0.0, _cd_left - delta)


func on_fatal_damage(host: Node, _amount: float) -> bool:
	if _cd_left > 0.0:
		return false
	if host is not Node2D:
		return false
	_cd_left = cooldown
	var health = host.get("health")
	if health != null:
		health.current_health = maxf(float(health.current_health), 1.0) + heal_amount
		if health.has_method("get_max_health"):
			health.current_health = minf(float(health.current_health), float(health.call("get_max_health")))
		if health.has_signal("health_changed"):
			health.emit_signal("health_changed", health.current_health, health.call("get_max_health") if health.has_method("get_max_health") else health.current_health)
	var hurtbox = host.get("hurtbox")
	if hurtbox != null and hurtbox.has_method("set_invincible"):
		hurtbox.call("set_invincible", true, true)
		var tree := host.get_tree()
		if tree:
			tree.create_timer(invuln_time).timeout.connect(func () -> void:
				if is_instance_valid(host):
					var hb = host.get("hurtbox")
					if hb != null and hb.has_method("set_invincible"):
						hb.call("set_invincible", false, false)
			, CONNECT_ONE_SHOT)
	_spawn_holo_burst(host as Node2D)
	CameraFx.flash(Color(0.7, 0.95, 1.0, 0.55), 0.12)
	CameraFx.add_trauma(0.55)
	HitStop.punch(0.3, 0.08)
	SignalBus.style_action.emit(GameplayEnums.StyleAction.PERFECT_DODGE, 150)
	return true


func _spawn_holo_burst(host: Node2D) -> void:
	var parent := host.get_parent()
	if parent == null:
		return
	var origin := host.global_position
	# Visual decoy
	var ghost := Polygon2D.new()
	var src := host.get_node_or_null("Visual") as Node2D
	if src and "polygon" in src and not (src.polygon as PackedVector2Array).is_empty():
		ghost.polygon = src.polygon
		ghost.color = Color(0.55, 0.9, 1.0, 0.85)
	else:
		ghost.polygon = PackedVector2Array([Vector2(-10, 0), Vector2(10, 0), Vector2(10, -36), Vector2(-10, -36)])
		ghost.color = Color(0.55, 0.9, 1.0, 0.85)
	ghost.z_index = 15
	parent.add_child(ghost)
	ghost.global_position = origin
	var tw := ghost.create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, 0.35)
	tw.parallel().tween_property(ghost, "scale", Vector2(1.6, 1.6), 0.35)
	tw.tween_callback(ghost.queue_free)
	# AoE stagger
	for child in parent.get_children():
		if child is not Node2D or child == host:
			continue
		if child.get("health") == null:
			continue
		if origin.distance_to((child as Node2D).global_position) > 110.0:
			continue
		var health = child.get("health")
		if health and health.has_method("take_damage"):
			health.call("take_damage", 16.0)
		var status = child.get("status")
		if status and status.has_method("add_buildup"):
			status.call("add_buildup", &"stagger", 80.0, 5.0)
			status.call("add_buildup", &"glitch", 40.0, 3.0)
		if child.has_method("apply_hard_stun"):
			child.call("apply_hard_stun", 0.7)
		if child.has_method("apply_knockback"):
			var dir := ((child as Node2D).global_position - origin).normalized()
			if dir == Vector2.ZERO:
				dir = Vector2.RIGHT
			child.call("apply_knockback", dir, 280.0)
