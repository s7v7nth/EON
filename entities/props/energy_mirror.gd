class_name EnergyMirror
extends Area2D
## Synthetic Geometry of Reflections — hard-light panel that ricochets blades.
## Lifetime is action-based (no timer): fades after MAX_ACTIONS uses, or Q detonate.

## Dedicated layer so mirrors never collide with hurtbox queries (layer 16).
const MIRROR_LAYER := 1 << 5 # 32
const MIRROR_COLOR := Color(0.45, 0.85, 1.0, 0.7)
const DASH_RADIUS := 96.0
const DASH_DAMAGE := 14.0
const DASH_STAGGER := 70.0
const DASH_KNOCKBACK := 220.0
const INVULN_REFRESH := 0.2
const DASH_TOUCH_RADIUS := 28.0
const MAX_ACTIONS := 3
const MELEE_TOUCH_RADIUS := 56.0

var owner_player: Node
var field: Object
## Kept for API compatibility; timers no longer despawn mirrors.
var lifetime: float = -1.0
var explode_radius: float = DASH_RADIUS
var explode_damage: float = DASH_DAMAGE
var explode_radius_mult: float = 1.0

var _actions: int = 0
var _detonated: bool = false
var _confuse_accum: float = 0.0
var _panel: Polygon2D
var _rim: Polygon2D
var _core: Polygon2D
var _pulse: Tween
var _dash_touched: bool = false
var _melee_latch: bool = false
var _action_pips: Array[Polygon2D] = []


func _ready() -> void:
	z_index = 8
	y_sort_enabled = true
	monitoring = true
	monitorable = true
	# Layer 32 = energy mirrors; mask player body (2) for dash overlap.
	collision_layer = MIRROR_LAYER
	collision_mask = 1 << 1
	add_to_group("energy_mirror")
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)
	_ensure_visual()
	_ensure_action_pips()
	_start_pulse()


func configure(player: Node, _life: float = -1.0, econ_field: Object = null) -> void:
	owner_player = player
	lifetime = -1.0
	field = econ_field
	if econ_field != null:
		explode_radius = float(econ_field.get("dash_explode_radius") if econ_field.get("dash_explode_radius") != null else DASH_RADIUS)
		explode_damage = float(econ_field.get("dash_explode_damage") if econ_field.get("dash_explode_damage") != null else DASH_DAMAGE)
	_ensure_visual()
	_ensure_action_pips()
	_refresh_action_pips()


func _physics_process(delta: float) -> void:
	if _detonated:
		return
	# Poll every frame: body_entered misses "already overlapping then start dash".
	_try_dash_action()
	_try_melee_action()
	_tick_confuse_aura(delta)


func register_action(kind: StringName = &"generic") -> void:
	if _detonated:
		return
	_actions = mini(_actions + 1, MAX_ACTIONS)
	_refresh_action_pips()
	_pulse_on_action()
	HitVFX.spawn_optic_ring(get_parent(), global_position, Color(0.55, 0.9, 1.0, 0.7), 0.7)
	if _actions >= MAX_ACTIONS:
		if kind == &"dash":
			detonate(&"dash")
		elif kind == &"collapse":
			detonate(&"collapse")
		else:
			_fade_out()


func remaining_actions() -> int:
	return maxi(MAX_ACTIONS - _actions, 0)


func _tick_confuse_aura(delta: float) -> void:
	if field == null:
		return
	var confuse = field.get("mirror_confuse")
	if confuse == null or not confuse:
		return
	_confuse_accum += delta
	if _confuse_accum < 0.35:
		return
	_confuse_accum = 0.0
	var parent := get_parent()
	if parent == null:
		return
	for child in parent.get_children():
		if child is not Node2D or child == owner_player:
			continue
		if child.get("status") == null:
			continue
		if global_position.distance_to((child as Node2D).global_position) > 88.0:
			continue
		var status = child.get("status")
		if status and status.has_method("add_buildup"):
			status.call("add_buildup", &"glitch", 22.0, 2.5)
		# Soft confuse: jitter facing / knock lightly so AI pathing wobbles.
		if child.has_method("apply_knockback") and randf() < 0.35:
			var jitter := Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
			child.call("apply_knockback", jitter, 40.0)


func try_reflect_projectile(proj: Node) -> bool:
	if _detonated or proj == null or not is_instance_valid(proj):
		return false
	if not proj.has_method("apply_mirror_ricochet"):
		return false
	return bool(proj.call("apply_mirror_ricochet", self))


func detonate(reason: StringName = &"expire") -> void:
	if _detonated:
		return
	_detonated = true
	set_deferred("monitoring", false)
	remove_from_group("energy_mirror")
	var radius := explode_radius * explode_radius_mult
	var damage := explode_damage * explode_radius_mult
	_aoe_stagger(radius, damage)
	_spawn_shatter_fx()
	HitVFX.spawn_optic_burst(get_parent(), global_position, Color(0.55, 0.9, 1.0, 1), Vector2.UP, 1.4)
	HitVFX.spawn_optic_ring(get_parent(), global_position, Color(0.7, 0.95, 1.0, 0.9), 1.5)
	if reason == &"dash" and owner_player != null and is_instance_valid(owner_player):
		_refresh_owner_invuln()
	if reason == &"collapse":
		CameraFx.add_trauma(0.35)
	elif reason == &"dash":
		CameraFx.add_trauma(0.28)
		HitStop.punch(0.35, 0.06)
	elif reason == &"overflow":
		CameraFx.add_trauma(0.18)
	if field != null and field.has_method("unregister_mirror"):
		field.call("unregister_mirror", self)
	queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body == owner_player:
		_try_dash_action()


func _on_body_exited(body: Node2D) -> void:
	if body == owner_player:
		_dash_touched = false


func _try_dash_action() -> void:
	if _detonated or owner_player == null or not is_instance_valid(owner_player):
		return
	if not _player_is_dashing(owner_player):
		_dash_touched = false
		return
	if owner_player is not Node2D:
		return
	var touching := false
	for body in get_overlapping_bodies():
		if body == owner_player:
			touching = true
			break
	if not touching:
		var dist := global_position.distance_to((owner_player as Node2D).global_position)
		touching = dist <= DASH_TOUCH_RADIUS
	if not touching:
		return
	if _dash_touched:
		return
	_dash_touched = true
	# Each dash-through is one action; soft pulse until the last action fully detonates.
	_pulse_dash_hit()
	_refresh_owner_invuln()
	register_action(&"dash")


func _pulse_dash_hit() -> void:
	## Non-final dash: smaller stagger pop so dash-through still pays off.
	if _actions + 1 >= MAX_ACTIONS:
		return
	_aoe_stagger(explode_radius * 0.55, explode_damage * 0.45)
	HitVFX.spawn_optic_ring(get_parent(), global_position, Color(0.55, 0.9, 1.0, 0.75), 0.95)
	CameraFx.add_trauma(0.12)


func _try_melee_action() -> void:
	if _detonated or owner_player == null or not is_instance_valid(owner_player):
		return
	var hitbox = owner_player.get("hitbox")
	if hitbox == null:
		return
	var active := false
	if hitbox.has_method("is_active"):
		active = bool(hitbox.call("is_active"))
	elif "monitoring" in hitbox:
		active = bool(hitbox.monitoring)
	if not active:
		_melee_latch = false
		return
	if hitbox is not Node2D:
		return
	if global_position.distance_to((hitbox as Node2D).global_position) > MELEE_TOUCH_RADIUS:
		return
	if _melee_latch:
		return
	_melee_latch = true
	register_action(&"attack")


func _player_is_dashing(player: Node) -> bool:
	var sm = player.get("state_machine")
	if sm != null:
		var state = sm.get("current_state")
		if state != null and String(state.name) == "Dash":
			return true
	return false


func _refresh_owner_invuln() -> void:
	var hurtbox = owner_player.get("hurtbox")
	if hurtbox == null or not hurtbox.has_method("set_invincible"):
		return
	hurtbox.call("set_invincible", true, true)
	var tree := get_tree()
	if tree == null:
		return
	tree.create_timer(INVULN_REFRESH).timeout.connect(func () -> void:
		if owner_player == null or not is_instance_valid(owner_player):
			return
		if _player_is_dashing(owner_player):
			return
		var hb = owner_player.get("hurtbox")
		if hb != null and hb.has_method("set_invincible"):
			hb.call("set_invincible", false, false)
	, CONNECT_ONE_SHOT)


func _aoe_stagger(radius: float, damage: float) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var origin := global_position
	for child in parent.get_children():
		if child is not Node2D:
			continue
		if child == owner_player:
			continue
		if child.is_in_group("energy_mirror"):
			continue
		if child.get("health") == null and not child.has_method("apply_knockback"):
			continue
		if origin.distance_to((child as Node2D).global_position) > radius:
			continue
		var health = child.get("health")
		if health and health.has_method("take_damage"):
			health.call("take_damage", damage)
		var status = child.get("status")
		if status and status.has_method("add_buildup"):
			status.call("add_buildup", &"stagger", DASH_STAGGER, 5.0)
		elif status and status.has_method("apply_status"):
			status.call("apply_status", &"stagger", 8.0, 1.0)
		if child.has_method("apply_hard_stun"):
			child.call("apply_hard_stun", 0.55)
		elif child.has_method("interrupt_attack"):
			child.call("interrupt_attack")
		if child.has_method("apply_knockback"):
			var dir := ((child as Node2D).global_position - origin).normalized()
			if dir == Vector2.ZERO:
				dir = Vector2.RIGHT
			child.call("apply_knockback", dir, DASH_KNOCKBACK)
	SignalBus.style_action.emit(GameplayEnums.StyleAction.ELEMENT_CASCADE, 80)


func _fade_out() -> void:
	if _detonated:
		return
	_detonated = true
	set_deferred("monitoring", false)
	remove_from_group("energy_mirror")
	if field != null and field.has_method("unregister_mirror"):
		field.call("unregister_mirror", self)
	HitVFX.spawn_optic_ring(get_parent(), global_position, Color(0.55, 0.9, 1.0, 0.65), 1.0)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.18)
	tw.tween_callback(queue_free)


func _spawn_shatter_fx() -> void:
	var parent := get_parent()
	if parent == null:
		return
	for i in range(8):
		var shard := Polygon2D.new()
		shard.polygon = PackedVector2Array([
			Vector2(0, -10), Vector2(6, 0), Vector2(0, 8), Vector2(-5, 0)
		])
		shard.color = Color(MIRROR_COLOR.r, MIRROR_COLOR.g, MIRROR_COLOR.b, 0.95)
		shard.z_index = 12
		parent.add_child(shard)
		shard.global_position = global_position
		var angle := TAU * float(i) / 8.0
		var dest := global_position + Vector2.from_angle(angle) * (48.0 + float(i) * 4.0)
		var tw := shard.create_tween()
		tw.tween_property(shard, "global_position", dest, 0.24).set_trans(Tween.TRANS_QUAD)
		tw.parallel().tween_property(shard, "modulate:a", 0.0, 0.24)
		tw.parallel().tween_property(shard, "rotation", angle + 1.2, 0.24)
		tw.tween_callback(shard.queue_free)


func _ensure_visual() -> void:
	_panel = get_node_or_null("Panel") as Polygon2D
	if _panel == null:
		_panel = Polygon2D.new()
		_panel.name = "Panel"
		add_child(_panel)
	_rim = get_node_or_null("Rim") as Polygon2D
	if _rim == null:
		_rim = Polygon2D.new()
		_rim.name = "Rim"
		add_child(_rim)
		move_child(_rim, 0)
	_core = get_node_or_null("Core") as Polygon2D
	if _core == null:
		_core = Polygon2D.new()
		_core.name = "Core"
		add_child(_core)

	_panel.polygon = PackedVector2Array([
		Vector2(0, -28), Vector2(16, 0), Vector2(0, 28), Vector2(-16, 0)
	])
	_panel.color = MIRROR_COLOR
	_panel.z_index = 1

	_rim.polygon = PackedVector2Array([
		Vector2(0, -34), Vector2(20, 0), Vector2(0, 34), Vector2(-20, 0)
	])
	_rim.color = Color(0.75, 0.95, 1.0, 0.35)
	_rim.z_index = 0

	_core.polygon = PackedVector2Array([
		Vector2(0, -12), Vector2(6, 0), Vector2(0, 12), Vector2(-6, 0)
	])
	_core.color = Color(1.0, 1.0, 1.0, 0.9)
	_core.z_index = 2

	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		shape_node = CollisionShape2D.new()
		shape_node.name = "CollisionShape2D"
		add_child(shape_node)
	var rect := shape_node.shape as RectangleShape2D
	if rect == null:
		rect = RectangleShape2D.new()
		shape_node.shape = rect
	# Wide enough to catch blade throws and dash paths reliably.
	rect.size = Vector2(36, 56)


func _ensure_action_pips() -> void:
	if not _action_pips.is_empty():
		return
	for i in MAX_ACTIONS:
		var pip := Polygon2D.new()
		pip.name = "ActionPip_%d" % i
		pip.polygon = PackedVector2Array([
			Vector2(-3, -3), Vector2(3, -3), Vector2(3, 3), Vector2(-3, 3)
		])
		pip.color = Color(0.55, 0.9, 1.0, 0.9)
		pip.z_index = 3
		pip.position = Vector2(-10.0 + float(i) * 10.0, 34.0)
		add_child(pip)
		_action_pips.append(pip)


func _refresh_action_pips() -> void:
	for i in _action_pips.size():
		var pip := _action_pips[i]
		var spent := i < _actions
		pip.color = Color(0.15, 0.25, 0.35, 0.55) if spent else Color(0.55, 0.9, 1.0, 0.9)


func _pulse_on_action() -> void:
	if _panel == null:
		return
	var tw := create_tween()
	tw.tween_property(_panel, "scale", Vector2(1.12, 1.1), 0.05)
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.1)


func _start_pulse() -> void:
	if _panel == null:
		return
	if _pulse:
		_pulse.kill()
	_panel.scale = Vector2.ONE
	var base_a := _panel.color.a
	_pulse = create_tween().set_loops()
	_pulse.tween_property(_panel, "scale", Vector2(1.06, 1.04), 0.55).set_trans(Tween.TRANS_SINE)
	_pulse.parallel().tween_property(_panel, "color:a", minf(base_a + 0.15, 0.9), 0.55)
	_pulse.tween_property(_panel, "scale", Vector2.ONE, 0.55).set_trans(Tween.TRANS_SINE)
	_pulse.parallel().tween_property(_panel, "color:a", base_a, 0.55)
