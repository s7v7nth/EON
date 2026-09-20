class_name Projectile
extends Area2D
## Straight-flying projectile. Returning mode flies out then home to source.

const _NanoBile := preload("res://entities/hazards/nano_bile_puddle.gd")

signal hit_landed(target: HurtboxComponent)
signal returned_to_source

var attack_data: AttackData
var direction: Vector2 = Vector2.RIGHT
var source: Node
var tint: Color = Color(1.0, 0.55, 0.35, 1.0)
## Scales outbound speed / damage feel for charged throws.
var charge: float = 1.0
## Geometry of Reflections — bounce budget filled from Synthetic economy on spawn.
var max_mirror_bounces: int = 1
var ricochet_damage_mult: float = 1.5
var extra_bounce_mult: float = 1.25
var wall_bounce_enabled: bool = false

var _lifetime: float = 0.0
var _trail_timer: float = 0.0
var _visual: Polygon2D = null
var _core: Polygon2D = null
var _returning: bool = false
var _hit_done: bool = false
var _max_range: float = 420.0
var _origin: Vector2 = Vector2.ZERO
var _mirror_bounces: int = 0
var _wall_bounces: int = 0
var _last_mirror_id: int = 0
var _last_redirect_target: Node = null
var _mirror_ignore_until: float = 0.0
var _dash_boosted: bool = false
## Extra enemy pierces for non-returning shots (Ripcurrent boon).
var extra_pierce: int = 0
## Returning blade pierces: each enemy hurtbox hit at most once per flight segment.
var _pierced_ids: Dictionary = {}
## Prismatic Trap: drop once at first enemy contact (not at end of flight).
var _prism_spawned: bool = false
var _puddle_dropped: bool = false


func _ready() -> void:
	monitoring = true
	monitorable = false
	z_index = 20
	y_sort_enabled = false
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	else:
		direction = direction.normalized()
	rotation = direction.angle()
	_origin = global_position
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	_ensure_visuals()
	_apply_visual_style()
	_fit_hitbox()
	if attack_data and attack_data.returning:
		_max_range = 300.0 + 200.0 * charge


func _fit_hitbox() -> void:
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		return
	var circle := CircleShape2D.new()
	# Returning blade throw needs a generous catch volume; other shots still larger than before.
	circle.radius = 36.0 if (attack_data and attack_data.returning) else 24.0
	shape_node.shape = circle


func _physics_process(delta: float) -> void:
	if attack_data == null:
		queue_free()
		return
	_lifetime += delta
	if _returning:
		_process_return(delta)
		return
	if _lifetime >= attack_data.projectile_lifetime:
		if attack_data.returning:
			_begin_return()
			return
		_drop_puddle_if_needed()
		queue_free()
		return
	var speed: float = attack_data.projectile_speed * (0.85 + 0.55 * charge)
	global_position += direction * speed * delta
	rotation = direction.angle()
	if attack_data.returning and global_position.distance_to(_origin) >= _max_range:
		_begin_return()
		return
	_trail_timer += delta
	if _trail_timer >= 0.035:
		_trail_timer = 0.0
		_spawn_trail()


func _process_return(delta: float) -> void:
	if source == null or not is_instance_valid(source) or not (source is Node2D):
		queue_free()
		return
	var target_pos: Vector2 = (source as Node2D).global_position + Vector2(0, -16)
	var to_src: Vector2 = target_pos - global_position
	var dist: float = to_src.length()
	if dist <= 28.0:
		returned_to_source.emit()
		queue_free()
		return
	var speed: float = attack_data.projectile_speed * 1.25
	direction = to_src / dist
	global_position += direction * speed * delta
	rotation = direction.angle()
	_trail_timer += delta
	if _trail_timer >= 0.04:
		_trail_timer = 0.0
		_spawn_trail()


func _begin_return() -> void:
	_returning = true
	_hit_done = true


func _try_spawn_prism_crystal_at(pos: Vector2) -> void:
	if _prism_spawned:
		return
	if source == null or not is_instance_valid(source):
		return
	var economy = source.get("active_economy")
	if economy != null and economy.has_method("spawn_prism_crystal"):
		_prism_spawned = true
		economy.call("spawn_prism_crystal", pos)


func apply_lens_amplify(mult: float) -> bool:
	if _returning or attack_data == null:
		return false
	var dup := attack_data.duplicate(true) as AttackData
	if dup == null:
		return false
	dup.damage *= maxf(mult, 1.0)
	attack_data = dup
	charge = minf(charge + 0.25, 1.5)
	_flash_ricochet()
	HitVFX.spawn_optic_burst(get_parent(), global_position, Color(0.7, 0.95, 1.0, 1), direction, 0.9)
	return true


func apply_dash_intercept() -> bool:
	## Kinetic Ping-Pong: dash through flying blade → redirect + damage boost.
	if _returning or _dash_boosted or attack_data == null:
		return false
	_dash_boosted = true
	_pierced_ids.clear()
	var target := _nearest_enemy(global_position, _last_redirect_target)
	if target != null:
		direction = _lead_direction(global_position, target, _flight_speed())
		_last_redirect_target = target
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	global_position += direction * 24.0
	rotation = direction.angle()
	_origin = global_position
	_hit_done = false
	if attack_data:
		_lifetime = minf(_lifetime, maxf(attack_data.projectile_lifetime - 0.7, 0.0))
	var dup := attack_data.duplicate(true) as AttackData
	if dup:
		dup.damage *= 2.0
		attack_data = dup
	charge = minf(charge + 0.35, 1.6)
	_flash_ricochet()
	HitVFX.spawn_optic_burst(get_parent(), global_position, Color(0.55, 0.9, 1.0, 1), direction, 1.35)
	HitVFX.spawn_optic_ring(get_parent(), global_position, Color(0.7, 0.95, 1.0, 0.9), 1.4)
	CameraFx.add_trauma(0.25)
	return true


func _ensure_visuals() -> void:
	_visual = get_node_or_null("Visual") as Polygon2D
	if _visual == null:
		_visual = Polygon2D.new()
		_visual.name = "Visual"
		add_child(_visual)
	_core = get_node_or_null("Core") as Polygon2D
	if _core == null:
		_core = Polygon2D.new()
		_core.name = "Core"
		add_child(_core)
	var bolt := get_node_or_null("Bolt") as Sprite2D
	if bolt == null:
		bolt = Sprite2D.new()
		bolt.name = "Bolt"
		bolt.centered = true
		bolt.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(bolt)
	var shard := ArtBank.shooter("meteorGrey_small1")
	if shard == null:
		shard = ArtBank.shooter("meteorBrown_small1")
	if attack_data and attack_data.returning:
		shard = ArtBank.shooter("meteorGrey_med2")
	bolt.texture = shard
	ArtBank.apply_opaque_region(bolt)
	bolt.rotation = 0.0
	ArtBank.fit_height(bolt, 22.0 if (attack_data and attack_data.returning) else 16.0, false)
	bolt.modulate = Color(0.55, 0.46, 0.34, 1)
	if attack_data and attack_data.damage_type == GameplayEnums.DamageType.GLITCH:
		bolt.modulate = Color(0.48, 0.3, 0.36, 1)
	if attack_data and attack_data.leaves_puddle:
		var glob := ArtBank.particle("circle_05")
		if glob:
			bolt.texture = glob
			ArtBank.fit_height(bolt, 30.0, false)
		bolt.modulate = Color(0.42, 0.58, 0.1, 1.0)
	if _visual:
		_visual.modulate.a = 0.0
	if _core:
		_core.modulate.a = 0.0


func _apply_visual_style() -> void:
	var col: Color = tint
	if col.a <= 0.0 or col.r + col.g + col.b < 0.35:
		col = Color(1.0, 0.55, 0.35, 1.0)
	_visual.color = Color(col.r * 0.45, col.g * 0.4, col.b * 0.32, 0.0)
	_visual.modulate = Color.WHITE
	_visual.z_index = 1
	_visual.polygon = PackedVector2Array([
		Vector2(16, 0), Vector2(-8, -5), Vector2(-4, 0), Vector2(-8, 5)
	])
	_core.color = Color(0.55, 0.42, 0.28, 0.0)
	_core.modulate = Color.WHITE
	_core.z_index = 2
	_core.polygon = PackedVector2Array([
		Vector2(12, 0), Vector2(-3, -3), Vector2(1, 0), Vector2(-3, 3)
	])
	modulate = Color.WHITE
	if attack_data and attack_data.returning:
		_core.polygon = PackedVector2Array([
			Vector2(18, 0), Vector2(-6, -5), Vector2(2, 0), Vector2(-6, 5)
		])


func _spawn_trail() -> void:
	if get_parent() == null:
		return
	var bolt := get_node_or_null("Bolt") as Sprite2D
	if bolt and bolt.texture:
		var ghost := ArtBank.clone_sprite_look(bolt)
		ghost.modulate = Color(bolt.modulate.r, bolt.modulate.g, bolt.modulate.b, 0.45)
		ghost.z_index = 19
		get_parent().add_child(ghost)
		ghost.global_position = global_position
		ghost.global_rotation = global_rotation
		var tween := ghost.create_tween()
		tween.tween_property(ghost, "modulate:a", 0.0, 0.14)
		tween.parallel().tween_property(ghost, "scale", ghost.scale * 0.4, 0.14)
		tween.tween_callback(ghost.queue_free)
		return
	if _visual == null:
		return
	var poly := Polygon2D.new()
	poly.polygon = _visual.polygon
	poly.color = Color(_visual.color.r, _visual.color.g, _visual.color.b, 0.55)
	poly.z_index = 19
	get_parent().add_child(poly)
	poly.global_position = global_position
	poly.global_rotation = global_rotation
	var tween_poly := poly.create_tween()
	tween_poly.tween_property(poly, "color:a", 0.0, 0.14)
	tween_poly.parallel().tween_property(poly, "scale", Vector2(0.4, 0.4), 0.14)
	tween_poly.tween_callback(poly.queue_free)


func apply_mirror_ricochet(mirror: Node2D) -> bool:
	## Redirect toward nearest enemy (lead aim) without entering return mode.
	if _returning or mirror == null or not is_instance_valid(mirror):
		return false
	if max_mirror_bounces <= 0 or _mirror_bounces >= max_mirror_bounces:
		return false
	if mirror.get_instance_id() == _last_mirror_id:
		return false
	if _lifetime < _mirror_ignore_until:
		return false
	# Fresh segment after bounce — can hit pierced enemies again.
	_pierced_ids.clear()
	_hit_done = false
	var target := _nearest_enemy(mirror.global_position, _last_redirect_target)
	var new_dir := direction
	if target != null:
		new_dir = _lead_direction(mirror.global_position, target, _flight_speed() * 1.05)
		_last_redirect_target = target
	else:
		# No enemy: bounce away from mirror so the throw isn't eaten.
		var away := (global_position - mirror.global_position).normalized()
		if away == Vector2.ZERO:
			away = direction
		new_dir = direction.bounce(away)
		if new_dir == Vector2.ZERO:
			new_dir = -direction
	if new_dir == Vector2.ZERO:
		new_dir = Vector2.RIGHT
	_mirror_bounces += 1
	_last_mirror_id = mirror.get_instance_id()
	direction = new_dir
	# Clear the mirror volume so we don't soft-lock inside the Area2D.
	global_position = mirror.global_position + direction * 40.0
	rotation = direction.angle()
	_origin = global_position
	_mirror_ignore_until = _lifetime + 0.08
	# Grant remaining flight time after each bounce.
	if attack_data:
		_lifetime = minf(_lifetime, maxf(attack_data.projectile_lifetime - 0.55, 0.0))
	if target != null:
		_apply_ricochet_damage()
	_flash_ricochet()
	HitVFX.spawn_optic_burst(get_parent(), mirror.global_position, Color(0.5, 0.9, 1.0, 1), direction, 1.15)
	HitVFX.spawn_optic_ring(get_parent(), mirror.global_position, Color(0.65, 0.95, 1.0, 0.85), 1.1)
	if mirror.has_method("register_action"):
		mirror.call("register_action", &"ricochet")
	return true


func _flight_speed() -> float:
	if attack_data == null:
		return 500.0
	return attack_data.projectile_speed * (0.85 + 0.55 * charge)


func _aim_point_of(target: Node2D) -> Vector2:
	## Prefer torso / hurtbox over feet so lead doesn't skim under.
	if target == null:
		return Vector2.ZERO
	var hurt = target.get("hurtbox")
	if hurt is Node2D and is_instance_valid(hurt):
		return (hurt as Node2D).global_position
	return target.global_position + Vector2(0, -18)


func _target_velocity(target: Node2D) -> Vector2:
	if target is CharacterBody2D:
		return (target as CharacterBody2D).velocity
	if "velocity" in target:
		var v = target.get("velocity")
		if v is Vector2:
			return v
	return Vector2.ZERO


func _lead_direction(from: Vector2, target: Node2D, projectile_speed: float) -> Vector2:
	## Aim where the target will be, not where it is now.
	var aim := _aim_point_of(target)
	var vel := _target_velocity(target)
	var speed := maxf(projectile_speed, 1.0)
	var predicted := aim
	var t := from.distance_to(aim) / speed
	for _i in 4:
		predicted = aim + vel * t
		t = from.distance_to(predicted) / speed
		t = clampf(t, 0.0, 1.25)
	var dir := predicted - from
	if dir.length_squared() < 0.0001:
		dir = aim - from
	if dir == Vector2.ZERO:
		return Vector2.RIGHT
	return dir.normalized()


func _apply_ricochet_damage() -> void:
	if attack_data == null:
		return
	var dup := attack_data.duplicate(true) as AttackData
	if dup == null:
		return
	var mult := ricochet_damage_mult if _mirror_bounces <= 1 else extra_bounce_mult
	dup.damage *= mult
	attack_data = dup


func _nearest_enemy(origin: Vector2, exclude: Node = null) -> Node2D:
	var parent := get_parent()
	if parent == null:
		return null
	var best: Node2D = null
	var best_d := INF
	for child in parent.get_children():
		if child is not Node2D:
			continue
		if child == source or child == exclude:
			continue
		if child.is_in_group("energy_mirror") or child.is_in_group("ally_drone"):
			continue
		# Avoid Player class_name cycle; player has energy + adrenaline.
		if child.get("adrenaline") != null and child.get("energy") != null:
			continue
		if child.get("health") == null:
			continue
		if child.get("hurtbox") == null:
			continue
		var health = child.get("health")
		if health != null and float(health.get("current_health")) <= 0.0:
			continue
		var d := origin.distance_to(_aim_point_of(child as Node2D))
		if d < best_d:
			best_d = d
			best = child as Node2D
	return best


func _flash_ricochet() -> void:
	if CameraFx:
		CameraFx.flash(Color(0.55, 0.9, 1.0, 0.35), 0.05)
	if _visual:
		var base := _visual.color
		var tw := create_tween()
		tw.tween_property(_visual, "color", Color(1, 1, 1, 1), 0.04)
		tw.tween_property(_visual, "color", base, 0.1)


func _on_area_entered(area: Area2D) -> void:
	if _returning or _hit_done:
		return
	if area != null and area.is_in_group("focus_lens"):
		if area.has_method("try_amplify_projectile"):
			area.call("try_amplify_projectile", self)
		return
	if area != null and area.is_in_group("energy_mirror"):
		if area.has_method("try_reflect_projectile") and bool(area.call("try_reflect_projectile", self)):
			return
		# Bounce budget spent or ignore window — pass through, don't eat the throw.
		return
	if not (area is HurtboxComponent):
		return
	if source != null and area.get_parent() == source:
		return
	# Ignore own-team player hurtboxes if any other source.
	if area.get_parent() != null and area.get_parent().get("adrenaline") != null \
			and area.get_parent().get("energy") != null and area.get_parent() != source:
		return
	# Returning blade pierces enemies so it can still reach mirrors behind them.
	if attack_data != null and attack_data.returning:
		call_deferred("_resolve_pierce_hit", area)
		return
	if extra_pierce > 0:
		call_deferred("_resolve_bonus_pierce", area)
		return
	_hit_done = true
	# Defer so we never queue_free / toggle Area2D state inside the physics callback.
	call_deferred("_resolve_hit", area)


func _resolve_pierce_hit(hurtbox: Node) -> void:
	if _returning or _hit_done:
		return
	if hurtbox == null or not is_instance_valid(hurtbox):
		return
	if not (hurtbox is HurtboxComponent):
		return
	var owner_node := hurtbox.get_parent()
	var pierce_key := owner_node.get_instance_id() if owner_node != null else hurtbox.get_instance_id()
	if _pierced_ids.has(pierce_key):
		return
	_pierced_ids[pierce_key] = true
	var hb: HurtboxComponent = hurtbox as HurtboxComponent
	hb.receive_hit(attack_data, source)
	hit_landed.emit(hb)
	var pos := hb.global_position
	if owner_node is Node2D:
		pos = (owner_node as Node2D).global_position + Vector2(0, -18)
	HitVFX.spawn_optic_burst(get_parent(), pos, Color(0.55, 0.9, 1.0, 1), direction, 1.0)
	HitVFX.spawn_optic_ring(get_parent(), pos, Color(0.7, 0.95, 1.0, 0.75), 0.85)
	# Prismatic Trap drops at first enemy contact, not at max range / wall return.
	_try_spawn_prism_crystal_at(pos)
	# Keep flying — do not begin return / do not set _hit_done.


func _resolve_bonus_pierce(hurtbox: Node) -> void:
	if _hit_done:
		return
	if hurtbox == null or not is_instance_valid(hurtbox):
		return
	if not (hurtbox is HurtboxComponent):
		return
	var owner_node := hurtbox.get_parent()
	var pierce_key := owner_node.get_instance_id() if owner_node != null else hurtbox.get_instance_id()
	if _pierced_ids.has(pierce_key):
		return
	_pierced_ids[pierce_key] = true
	var hb: HurtboxComponent = hurtbox as HurtboxComponent
	hb.receive_hit(attack_data, source)
	hit_landed.emit(hb)
	extra_pierce -= 1
	if extra_pierce < 0:
		_hit_done = true
		call_deferred("_finish_after_hit")


func _resolve_hit(hurtbox: Node) -> void:
	if hurtbox == null or not is_instance_valid(hurtbox):
		_finish_after_hit()
		return
	if not (hurtbox is HurtboxComponent):
		_finish_after_hit()
		return
	var hb: HurtboxComponent = hurtbox as HurtboxComponent
	hb.receive_hit(attack_data, source)
	hit_landed.emit(hb)
	if attack_data and attack_data.returning:
		var pos := hb.global_position
		if hb.get_parent() is Node2D:
			pos = (hb.get_parent() as Node2D).global_position + Vector2(0, -18)
		HitVFX.spawn_optic_burst(get_parent(), pos, Color(0.55, 0.9, 1.0, 1), direction, 1.0)
		HitVFX.spawn_optic_ring(get_parent(), pos, Color(0.7, 0.95, 1.0, 0.75), 0.85)
	_finish_after_hit()


func _finish_after_hit() -> void:
	_drop_puddle_if_needed()
	if attack_data != null and attack_data.returning:
		_begin_return()
		return
	set_deferred("monitoring", false)
	queue_free()


func _drop_puddle_if_needed() -> void:
	if _puddle_dropped:
		return
	if attack_data == null or not attack_data.leaves_puddle:
		return
	if attack_data.returning:
		return
	var parent := get_parent()
	if parent == null:
		return
	_puddle_dropped = true
	var puddle := _NanoBile.new()
	parent.add_child(puddle)
	puddle.global_position = global_position
	puddle.call(
		"setup",
		maxf(attack_data.damage * 0.45, 4.0),
		maxf(attack_data.puddle_duration, 2.5),
		maxf(attack_data.puddle_radius, 36.0)
	)


func _on_body_entered(body: Node2D) -> void:
	if source != null and body == source:
		return
	if _returning or _hit_done:
		return
	if attack_data != null and attack_data.returning and wall_bounce_enabled and _wall_bounces < 2:
		var normal := (global_position - body.global_position).normalized()
		if normal == Vector2.ZERO:
			normal = -direction
		var bounced := direction.bounce(normal)
		if bounced == Vector2.ZERO:
			bounced = -direction
		direction = bounced.normalized()
		_wall_bounces += 1
		_hit_done = false
		_pierced_ids.clear()
		global_position += direction * 22.0
		rotation = direction.angle()
		_origin = global_position
		if attack_data:
			_lifetime = minf(_lifetime, maxf(attack_data.projectile_lifetime - 0.5, 0.0))
		_flash_ricochet()
		HitVFX.spawn_optic_burst(get_parent(), global_position, Color(0.6, 0.9, 1.0, 1), direction, 1.0)
		HitVFX.spawn_optic_ring(get_parent(), global_position, Color(0.55, 0.85, 1.0, 0.8), 0.9)
		return
	if attack_data != null and attack_data.returning:
		_begin_return()
		return
	_hit_done = true
	_drop_puddle_if_needed()
	set_deferred("monitoring", false)
	queue_free()
