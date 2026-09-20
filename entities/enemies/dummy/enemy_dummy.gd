class_name EnemyDummy
extends CharacterBody2D
## Aggro → chase → melee up close, ranged shot at mid distance.

const PROJECTILE_SCENE := preload("res://entities/projectiles/projectile.tscn")
const ENEMY_SCENE := preload("res://entities/enemies/dummy/enemy_dummy.tscn")
const HIVE_CHUNK := preload("res://resources/enemies/hive_chunk.tres")
const _ReturnHive := preload("res://systems/enemies/behaviors/behavior_return_to_hive.gd")

@export var stats: CharacterStats
@export var definition: EnemyDefinition
@export var attack_range: float = 48.0
@export var ranged_range: float = 260.0
@export var ranged_attack_data: AttackData
@export var prefers_kite: bool = false

@onready var state_machine: StateMachine = $StateMachine
@onready var health: HealthComponent = $HealthComponent
@onready var status: StatusComponent = $StatusComponent
@onready var hurtbox: HurtboxComponent = $HurtboxComponent
@onready var hitbox: HitboxComponent = $HitboxComponent
@onready var combat_visual: CombatVisualComponent = $CombatVisual
@onready var detection_area: Area2D = $DetectionArea
@onready var attack_cooldown: Timer = $AttackCooldownTimer
@onready var ranged_cooldown: Timer = $RangedCooldownTimer

var target: Node2D
var _behaviors: Array[EnemyBehavior] = []
var _room_alerted: bool = false

const KNOCKBACK_DURATION := 0.15
var _kb_dir: Vector2 = Vector2.ZERO
var _kb_force: float = 0.0
var _kb_time: float = 0.0
var _kb_duration: float = KNOCKBACK_DURATION
var _poise: float = 40.0
var _flinch_time: float = 0.0
var _stun_time: float = 0.0
var is_elite: bool = false
var _elite_action_speed: float = 1.0
## Pending move selected by Chase before transitioning into an attack state.
var pending_attack: AttackData
var boss_phase: int = 1
var _boss_phase2_fired: bool = false
var _phase_action_mult: float = 1.0
## Lunge / leap impulse applied during LeapAttack active frames.
var _lunge_vel: Vector2 = Vector2.ZERO
var _lunge_time: float = 0.0
var facing_direction: Vector2 = Vector2.RIGHT
var bonus_max_health: float = 0.0
var hive_thickness: int = 0
var _hive_shed_cd: float = 0.7


func _ready() -> void:
	motion_mode = MOTION_MODE_FLOATING
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	y_sort_enabled = true
	if definition != null:
		apply_definition(definition)
	else:
		_configure_from_stats()
	health.died.connect(_on_died)
	if not health.health_changed.is_connected(_on_health_changed):
		health.health_changed.connect(_on_health_changed)
	detection_area.body_entered.connect(_on_detection_body_entered)
	detection_area.body_exited.connect(_on_detection_body_exited)
	if hurtbox and not hurtbox.hit_received.is_connected(_on_hurtbox_hit_received):
		hurtbox.hit_received.connect(_on_hurtbox_hit_received)
	# Catch bodies already overlapping on spawn.
	call_deferred("_scan_detection_area")
	call_deferred("_fit_combat_shapes")
	add_to_group("enemies")


func _fit_combat_shapes() -> void:
	## Match hurt volume to the full stylized body; melee hitbox is placed per-swing in Attack.
	var hurt_shape := hurtbox.get_node_or_null("CollisionShape2D") as CollisionShape2D if hurtbox else null
	if hurt_shape:
		hurt_shape.position = Vector2(0, -22)
		var circle := CircleShape2D.new()
		circle.radius = 28.0
		hurt_shape.shape = circle


func _physics_process(delta: float) -> void:
	if _kb_time > 0.0:
		_kb_time = maxf(0.0, _kb_time - delta)
	if _lunge_time > 0.0:
		_lunge_time = maxf(0.0, _lunge_time - delta)
		if _lunge_time <= 0.0:
			_lunge_vel = Vector2.ZERO
	if _stun_time > 0.0:
		_stun_time = maxf(0.0, _stun_time - delta)
	if _flinch_time > 0.0:
		_flinch_time = maxf(0.0, _flinch_time - delta)
	elif _stun_time <= 0.0 and _poise < get_max_poise():
		_poise = minf(get_max_poise(), _poise + get_poise_regen() * delta)
	for behavior in _behaviors:
		if behavior:
			behavior.tick(self, delta)
	_tick_hive_shed(delta)


func apply_knockback(direction: Vector2, force: float, duration: float = KNOCKBACK_DURATION) -> void:
	if direction == Vector2.ZERO or force <= 0.0:
		return
	_kb_dir = direction.normalized()
	_kb_force = force
	_kb_duration = maxf(duration, 0.01)
	_kb_time = _kb_duration


func _knockback_vector() -> Vector2:
	if _kb_time <= 0.0 or _kb_force <= 0.0:
		return Vector2.ZERO
	var strength := _kb_force * (_kb_time / _kb_duration)
	return Iso.apply_velocity(_kb_dir, strength)


func get_max_poise() -> float:
	if definition:
		return maxf(definition.max_poise, 1.0)
	return 40.0


func get_poise_regen() -> float:
	if definition:
		return maxf(definition.poise_regen, 0.0)
	return 18.0


func is_flinching() -> bool:
	return _flinch_time > 0.0


func is_stunned() -> bool:
	return _stun_time > 0.0


func apply_hard_stun(duration: float = 1.0) -> void:
	## Full combat stun (parry / heavy stagger) — interrupt + stars.
	_stun_time = maxf(_stun_time, maxf(duration, 0.15))
	_flinch_time = maxf(_flinch_time, 0.12)
	interrupt_attack()
	stop_movement()
	if combat_visual:
		combat_visual.play_hit_flash()
		combat_visual.play_stun_stars(_stun_time)


func apply_poise_hit(poise_damage: float) -> bool:
	if poise_damage <= 0.0:
		return false
	_poise -= poise_damage
	if _poise > 0.0:
		return false
	_poise = get_max_poise()
	_flinch_time = clampf(0.08 + poise_damage * 0.0035, 0.08, 0.22)
	interrupt_attack()
	stop_movement()
	if combat_visual:
		combat_visual.play_flinch()
	return true


func _scan_detection_area() -> void:
	for body in detection_area.get_overlapping_bodies():
		_on_detection_body_entered(body)


func _configure_from_stats() -> void:
	if stats == null:
		push_error("EnemyDummy: CharacterStats is required")
		return
	health.apply_stats(stats)
	hurtbox.health_component = health
	hurtbox.status_component = status
	if status:
		status.health_component = health


func apply_definition(def: EnemyDefinition) -> void:
	if def == null:
		return
	definition = def
	if def.stats:
		stats = def.stats
	attack_range = def.attack_range
	ranged_range = def.ranged_range
	prefers_kite = def.prefers_kite
	ranged_attack_data = def.ranged_attack
	if hitbox:
		hitbox.attack_data = def.melee_attack
	_configure_from_stats()
	_install_behaviors(def)
	var visual := get_node_or_null("Visual") as Node2D
	if visual:
		visual.visible = true
		visual.modulate = Color.WHITE
		if "color" in visual:
			visual.color = Color(def.visual_color.r, def.visual_color.g, def.visual_color.b, 1.0)
	if combat_visual:
		combat_visual.apply_faction_look(def.faction, def.visual_color)
		if def.visual_stem != "":
			var vis_body := get_node_or_null("Visual") as Node2D
			if vis_body and vis_body.has_method("apply_custom_stem"):
				vis_body.call("apply_custom_stem", def.visual_stem, def.visual_height)
	_poise = get_max_poise()
	_flinch_time = 0.0
	boss_phase = 1
	_boss_phase2_fired = false
	_phase_action_mult = 1.0
	if definition and definition.is_boss:
		var hp_bar_boss := get_node_or_null("HealthBar") as HealthBarComponent
		if hp_bar_boss:
			hp_bar_boss.visible = false
		var vis_boss := get_node_or_null("Visual") as Node2D
		if vis_boss:
			if definition.boss_id == &"hive":
				vis_boss.scale = Vector2(1.22, 1.22)
			else:
				vis_boss.scale = Vector2(1.28, 1.28)
	if is_hive_chunk():
		var vis_chunk := get_node_or_null("Visual") as Node2D
		if vis_chunk:
			vis_chunk.scale = Vector2(0.78, 0.78)
			vis_chunk.modulate = Color(0.55, 0.95, 0.45, 1)
		var chunk_bar := get_node_or_null("HealthBar") as HealthBarComponent
		if chunk_bar:
			chunk_bar.set_label("Hive chunk")
			chunk_bar.hide_when_full = false
			chunk_bar.bar_size = Vector2(46, 7)
			chunk_bar.fill_color = Color(0.42, 0.92, 0.35, 0.95)
	var vis := get_node_or_null("Visual") as Node2D
	if vis and def:
		var swarm := false
		for tag in def.tags:
			if String(tag) == "swarm":
				swarm = true
				break
		if swarm and not is_hive_chunk():
			vis.scale = Vector2(0.78, 0.78)
	var hp_bar := get_node_or_null("HealthBar") as HealthBarComponent
	if hp_bar and not (definition and definition.is_boss):
		hp_bar.set_label(def.display_name if def.display_name != "" else "Enemy")
	var detect_shape := detection_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if detect_shape and detect_shape.shape is CircleShape2D:
		(detect_shape.shape as CircleShape2D).radius = def.detection_radius


## Elite wrapper: denser HP, speed bump, faster actions, gold rim, HP-bar label.
func apply_elite(hp_mult: float = 2.0, move_mult: float = 1.12, action_speed: float = 1.15) -> void:
	is_elite = true
	_elite_action_speed = maxf(action_speed, 1.0)
	if stats != null:
		var dup := stats.duplicate(true) as CharacterStats
		if dup != null:
			dup.max_health = maxf(dup.max_health * maxf(hp_mult, 1.0), dup.max_health)
			dup.move_speed = dup.move_speed * maxf(move_mult, 1.0)
			stats = dup
			_configure_from_stats()
	attack_range *= 1.08
	_poise = get_max_poise() * 1.35
	var vis := get_node_or_null("Visual") as Node2D
	if vis:
		vis.modulate = Color(1.18, 0.92, 0.48, 1.0)
	if combat_visual:
		combat_visual.modulate = Color(1.12, 0.88, 0.42, 1.0)
	# Light elite threat aura: nearby status pressure via meta (read by hitbox path).
	set_meta("elite_pressure", 1.12)
	var hp_bar := get_node_or_null("HealthBar") as HealthBarComponent
	if hp_bar:
		var base := definition.display_name if definition != null and definition.display_name != "" else "Enemy"
		hp_bar.set_label("Elite · " + base)
		hp_bar.bar_size = Vector2(72, 9)
		hp_bar.fill_color = Color(0.95, 0.72, 0.15, 0.95)
		hp_bar.hide_when_full = false
		hp_bar.queue_redraw()
	if vis:
		vis.scale = Vector2(1.32, 1.32)
	var spr := get_node_or_null("Sprite") as Sprite2D
	if spr:
		spr.scale *= 1.18
	var ring := get_node_or_null("EliteHalo") as Sprite2D
	if ring == null:
		ring = Sprite2D.new()
		ring.name = "EliteHalo"
		ring.centered = true
		ring.z_index = -1
		ring.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(ring)
		move_child(ring, 0)
	ring.texture = ArtBank.particle("circle_05")
	if ring.texture:
		ArtBank.fit_height(ring, 88.0, false)
	ring.modulate = Color(1.0, 0.78, 0.18, 0.62)


func apply_route_pressure(pressure: float) -> void:
	## Campaign / procedural densify HP so tutorial stays teachable.
	var p := maxf(pressure, 1.0)
	set_meta("combat_pressure", p)
	if p <= 1.02 or stats == null:
		return
	var dup := stats.duplicate(true) as CharacterStats
	if dup == null:
		return
	dup.max_health = maxf(dup.max_health * p, dup.max_health)
	stats = dup
	_configure_from_stats()


func _install_behaviors(def: EnemyDefinition) -> void:
	_behaviors.clear()
	for module in def.behavior_modules:
		if module == null:
			continue
		var instance := module.duplicate(true) as EnemyBehavior
		if instance == null:
			continue
		_behaviors.append(instance)
		instance.on_ready(self)


func has_behavior(behavior_id: StringName) -> bool:
	for behavior in _behaviors:
		if behavior and behavior.behavior_id == behavior_id:
			return true
	return false


func try_behavior_dodge(attack: AttackData, source: Node) -> bool:
	for behavior in _behaviors:
		if behavior and behavior.try_dodge_projectile(self, attack, source):
			return true
	return false


func effective_move_speed() -> float:
	var speed := stats.move_speed if stats else 0.0
	for behavior in _behaviors:
		if behavior:
			speed = behavior.modify_move_speed(self, speed)
	return speed


func is_panicking() -> bool:
	return has_meta("panicking") and bool(get_meta("panicking"))


func is_glitched() -> bool:
	return has_meta("glitched") and bool(get_meta("glitched"))


func apply_retreat_movement() -> void:
	if target == null or stats == null:
		velocity = _knockback_vector()
		move_and_slide()
		return
	var away := global_position.direction_to(target.global_position) * -1.0
	velocity = Iso.apply_velocity(away, effective_move_speed())
	velocity += _knockback_vector()
	if away != Vector2.ZERO:
		facing_direction = away.normalized()
	move_and_slide()


func _on_detection_body_entered(body: Node2D) -> void:
	if body is Player:
		_alert_room(body as Player)


func _on_hurtbox_hit_received(_attack_data: AttackData, source: Node, _hp_damage: float) -> void:
	## Melee and ranged hits aggro the room even outside detection radius.
	var player := _player_from_hit_source(source)
	if player:
		_alert_room(player)


func _player_from_hit_source(source: Node) -> Player:
	if source is Player:
		return source as Player
	if source is Node and source.get_parent() is Player:
		return source.get_parent() as Player
	return null


func _on_detection_body_exited(body: Node2D) -> void:
	## Once anyone in the room spotted the player, keep chase until death.
	if body == target and not _room_alerted:
		target = null


func receive_room_alert(player: Node2D) -> void:
	if player == null:
		return
	target = player
	_room_alerted = true


func _alert_room(player: Player) -> void:
	receive_room_alert(player)
	var parent := get_parent()
	if parent == null:
		return
	for sibling in parent.get_children():
		if sibling == self:
			continue
		if sibling is EnemyDummy:
			(sibling as EnemyDummy).receive_room_alert(player)


func _on_died() -> void:
	for behavior in _behaviors:
		if behavior:
			behavior.on_death(self)
	if definition and definition.on_death_effect:
		definition.on_death_effect.on_proc(self, {"power": 1.0})
	if definition:
		if definition.boss_id != StringName():
			MetaSave.note_boss_killed(definition.boss_id)
		elif definition.unlock_flag == MetaSave.FLAG_HIVE:
			MetaSave.note_boss_killed(&"hive")
		elif definition.unlock_flag == MetaSave.FLAG_WARDEN:
			MetaSave.note_boss_killed(&"warden")
		else:
			for tag in definition.tags:
				if String(tag) == "hive_boss":
					MetaSave.note_boss_killed(&"hive")
				elif String(tag) == "warden":
					MetaSave.note_boss_killed(&"warden")
	var world := get_parent()
	var col := Color(0.7, 0.2, 0.25, 1)
	if definition:
		col = definition.visual_color
	elif combat_visual and combat_visual.body:
		col = combat_visual.body.color
	DeathDebris.burst(world, global_position + Vector2(0, -8), col, 14)
	CameraFx.add_trauma(0.32)
	HitStop.punch(0.07, 0.07)
	SignalBus.enemy_died.emit(self)
	SignalBus.entity_died.emit(self)
	queue_free()


func get_action_speed_multiplier() -> float:
	var mult := 1.0
	if status:
		mult = maxf(status.get_action_speed_multiplier(), 0.15)
	return mult * _elite_action_speed * _phase_action_mult


func interrupt_attack() -> void:
	_lunge_vel = Vector2.ZERO
	_lunge_time = 0.0
	pending_attack = null
	if state_machine and state_machine.has_method("transition_to"):
		if target != null:
			state_machine.transition_to(&"Chase")
		else:
			state_machine.transition_to(&"Idle")


func distance_to_target() -> float:
	if target == null:
		return INF
	return global_position.distance_to(target.global_position)


func is_target_in_attack_range() -> bool:
	return distance_to_target() <= attack_range


func ranged_ready() -> bool:
	if target == null:
		return false
	if not ranged_cooldown.is_stopped():
		return false
	var atk := _best_ranged_candidate()
	if atk == null:
		return false
	return distance_to_target() <= maxf(ranged_range, atk.max_range if atk.max_range < 9000.0 else ranged_range)


func pick_and_begin_attack() -> bool:
	## Chase entry: pick a moveset attack and transition to the right state.
	if target == null:
		return false
	var dist := distance_to_target()
	var melee_cd_ready := attack_cooldown.is_stopped()
	var ranged_cd_ready := ranged_cooldown.is_stopped()
	var candidates: Array[AttackData] = []
	var weights: Array[float] = []
	for atk in _all_moves():
		if atk == null:
			continue
		if not atk.in_range_band(dist):
			# Soft fallback: melee inside attack_range, ranged inside ranged_range.
			if atk.is_ranged_pattern():
				if dist > ranged_range:
					continue
			else:
				if dist > attack_range * 1.35 and not atk.is_leap_pattern():
					continue
				if atk.is_leap_pattern() and dist > maxf(atk.max_range, attack_range * 2.4):
					continue
		if atk.is_ranged_pattern():
			if not ranged_cd_ready:
				continue
		else:
			if not melee_cd_ready:
				continue
		candidates.append(atk)
		weights.append(maxf(atk.select_weight, 0.05))
	if candidates.is_empty():
		return false
	var picked := _weighted_pick(candidates, weights)
	if picked == null:
		return false
	pending_attack = picked
	if hitbox and not picked.is_ranged_pattern():
		hitbox.attack_data = picked
	if picked.is_leap_pattern():
		if picked.pattern_kind == AttackData.PatternKind.HOOK or picked.hook_pull:
			state_machine.transition_to(&"HookAttack", {"attack": picked})
		else:
			state_machine.transition_to(&"LeapAttack", {"attack": picked})
	elif picked.is_ranged_pattern():
		ranged_attack_data = picked
		state_machine.transition_to(&"RangedAttack", {"attack": picked})
	else:
		state_machine.transition_to(&"Attack", {"attack": picked})
	return true


func _all_moves() -> Array[AttackData]:
	var result: Array[AttackData] = []
	if definition and not definition.moveset.is_empty():
		for m in definition.moveset:
			if m:
				result.append(m)
		return result
	if definition:
		if definition.melee_attack:
			result.append(definition.melee_attack)
		if definition.ranged_attack:
			result.append(definition.ranged_attack)
	elif hitbox and hitbox.attack_data:
		result.append(hitbox.attack_data)
	if ranged_attack_data and not result.has(ranged_attack_data):
		result.append(ranged_attack_data)
	return result


func _best_ranged_candidate() -> AttackData:
	for atk in _all_moves():
		if atk and atk.is_ranged_pattern():
			return atk
	return ranged_attack_data


func _weighted_pick(candidates: Array[AttackData], weights: Array[float]) -> AttackData:
	var total := 0.0
	for w in weights:
		total += w
	if total <= 0.0 or candidates.is_empty():
		return null
	var roll := randf() * total
	var acc := 0.0
	for i in candidates.size():
		acc += weights[i]
		if roll <= acc:
			return candidates[i]
	return candidates[candidates.size() - 1]


func clear_lunge() -> void:
	_lunge_vel = Vector2.ZERO
	_lunge_time = 0.0


func begin_lunge(direction: Vector2, distance: float, duration: float) -> void:
	if direction == Vector2.ZERO or distance <= 0.0:
		return
	var dur := maxf(duration, 0.05)
	_lunge_vel = Iso.apply_velocity(direction.normalized(), distance / dur)
	_lunge_time = dur


func _lunge_vector() -> Vector2:
	if _lunge_time <= 0.0:
		return Vector2.ZERO
	return _lunge_vel


func stop_movement() -> void:
	velocity = _knockback_vector() + _lunge_vector()
	move_and_slide()


func apply_chase_movement() -> void:
	if target == null or stats == null:
		velocity = _knockback_vector()
		move_and_slide()
		return
	var direction := global_position.direction_to(target.global_position) + _crowd_separate()
	# Glitch robots may briefly retarget / jitter.
	if is_glitched() and get_meta("glitch_robot", false):
		direction = direction.rotated(randf_range(-0.7, 0.7))
	if direction != Vector2.ZERO:
		direction = direction.normalized()
	velocity = Iso.apply_velocity(direction, effective_move_speed())
	velocity += _knockback_vector()
	if direction != Vector2.ZERO:
		facing_direction = direction
	move_and_slide()


func _crowd_separate() -> Vector2:
	if not is_inside_tree():
		return Vector2.ZERO
	var push := Vector2.ZERO
	for node in get_tree().get_nodes_in_group("enemies"):
		if node == self or node is not Node2D:
			continue
		var d: Vector2 = global_position - (node as Node2D).global_position
		var dist := d.length()
		if dist < 1.0 or dist > 38.0:
			continue
		push += d.normalized() * ((38.0 - dist) / 38.0)
	return push * 0.85


func spawn_projectile(direction: Vector2, attack: AttackData = null) -> void:
	var data := attack if attack else ranged_attack_data
	var proj := PROJECTILE_SCENE.instantiate() as Projectile
	proj.attack_data = data
	proj.direction = direction.normalized()
	proj.source = self
	# world + player_hurtbox
	proj.collision_mask = (1 << 0) | (1 << 3)
	if data:
		match data.damage_type:
			GameplayEnums.DamageType.ELECTRICITY:
				proj.tint = Color(0.55, 0.48, 0.32, 1)
			GameplayEnums.DamageType.CORROSION:
				if data.leaves_puddle:
					proj.tint = Color(0.46, 0.62, 0.18, 1)
				else:
					proj.tint = Color(0.4, 0.45, 0.22, 1)
			_:
				proj.tint = Color(0.7, 0.38, 0.18, 1)
	else:
		proj.tint = Color(0.7, 0.38, 0.18, 1)
	get_parent().add_child(proj)
	var muzzle := direction.normalized() * 28.0 + Vector2(0, -18)
	if combat_visual and combat_visual.has_method("muzzle_offset"):
		muzzle = combat_visual.call("muzzle_offset", direction)
	proj.global_position = global_position + muzzle


func spawn_projectile_volley(aim: Vector2, attack: AttackData) -> void:
	if attack == null:
		return
	var count := maxi(attack.projectile_count, 1)
	var spread := deg_to_rad(attack.spread_deg)
	var base := aim.normalized()
	if count == 1 or spread <= 0.0:
		spawn_projectile(base, attack)
		return
	var start := -spread * 0.5
	var step := spread / float(count - 1)
	for i in count:
		spawn_projectile(base.rotated(start + step * float(i)), attack)


func _on_health_changed(current: float, max_value: float) -> void:
	if definition and definition.is_boss:
		var nm := definition.display_name if definition.display_name != "" else "BOSS"
		SignalBus.boss_health_changed.emit(current, max_value, nm)
	if definition == null or not definition.is_boss:
		return
	if _boss_phase2_fired or max_value <= 0.0:
		return
	if current / max_value > definition.boss_phase2_hp_ratio:
		return
	_enter_boss_phase2()


func _enter_boss_phase2() -> void:
	_boss_phase2_fired = true
	boss_phase = 2
	_phase_action_mult = maxf(definition.boss_phase2_action_speed, 1.0) if definition else 1.25
	if combat_visual:
		combat_visual.play_hit_flash()
		CameraFx.add_trauma(0.45)
		HitStop.punch(0.08, 0.08)
	var hp_bar := get_node_or_null("HealthBar") as HealthBarComponent
	if hp_bar and definition:
		hp_bar.set_label("BOSS " + definition.display_name + " II")
	if FeelAudio:
		FeelAudio.play_boss()
	CameraFx.flash(Color(1.0, 0.2, 0.15, 0.5), 0.16)
	var nm := definition.display_name if definition and definition.display_name != "" else "BOSS"
	SignalBus.boss_phase.emit(2, nm)
	if is_hive_boss():
		shed_hive_chunk(3)
	else:
		_summon_boss_adds()


func is_hive_boss() -> bool:
	if definition == null:
		return false
	if definition.boss_id == &"hive":
		return true
	for tag in definition.tags:
		if String(tag) == "hive_boss":
			return true
	return false


func is_hive_chunk() -> bool:
	if definition == null:
		return false
	for tag in definition.tags:
		if String(tag) == "hive_chunk":
			return true
	return false


func find_hive_host() -> EnemyDummy:
	var parent := get_parent()
	if parent == null:
		return null
	for child in parent.get_children():
		if child == self or child is not EnemyDummy:
			continue
		var other := child as EnemyDummy
		if other.is_hive_boss() and other.health and other.health.current_health > 0.0:
			return other
	return null


func _count_hive_chunks() -> int:
	var parent := get_parent()
	if parent == null:
		return 0
	var n := 0
	for child in parent.get_children():
		if child is EnemyDummy and (child as EnemyDummy).is_hive_chunk():
			n += 1
	return n


func _tick_hive_shed(delta: float) -> void:
	if not is_hive_boss():
		return
	if health and health.current_health <= 0.0:
		return
	_hive_shed_cd -= delta
	if _hive_shed_cd > 0.0:
		return
	var cap := 4 if boss_phase < 2 else 6
	_hive_shed_cd = 7.2 if boss_phase < 2 else 4.4
	if _count_hive_chunks() >= cap:
		return
	shed_hive_chunk(1 if boss_phase < 2 else 2)


func shed_hive_chunk(count: int = 1) -> void:
	if not is_hive_boss():
		return
	var parent := get_parent()
	if parent == null or ENEMY_SCENE == null or HIVE_CHUNK == null:
		return
	var n := maxi(count, 1)
	for i in n:
		if _count_hive_chunks() >= 6:
			return
		var add := ENEMY_SCENE.instantiate() as EnemyDummy
		parent.add_child(add)
		var ang := TAU * float(i) / float(n) + randf() * 0.4
		var offset := Vector2(cos(ang), sin(ang)) * 78.0
		add.global_position = global_position + offset
		add.apply_definition(HIVE_CHUNK)
		if target:
			add.receive_room_alert(target)
		add.apply_knockback(offset.normalized(), 140.0, 0.22)
		SignalBus.enemy_spawned.emit(add)


func thicken_from_chunk() -> void:
	hive_thickness += 1
	if health:
		health.set_bonus_max(float(hive_thickness) * 22.0)
		health.heal(14.0)
	var vis := get_node_or_null("Visual") as Node2D
	if vis:
		var next := vis.scale * 1.07
		vis.scale = Vector2(minf(next.x, 1.7), minf(next.y, 1.7))
	CameraFx.add_trauma(0.12)


func absorb_into_hive() -> void:
	var hive := find_hive_host()
	if hive:
		hive.thicken_from_chunk()
	SignalBus.enemy_despawned.emit(self)
	queue_free()


func try_return_to_hive() -> bool:
	if not is_hive_chunk():
		return false
	var hive := find_hive_host()
	if hive == null:
		return false
	var to_hive := hive.global_position - global_position
	if to_hive.length() <= 44.0:
		absorb_into_hive()
		return true
	if to_hive != Vector2.ZERO:
		facing_direction = to_hive.normalized()
	velocity = Iso.apply_velocity(to_hive.normalized(), effective_move_speed())
	velocity += _knockback_vector()
	move_and_slide()
	return true


func _summon_boss_adds() -> void:
	if definition == null or definition.boss_phase2_summon == null:
		return
	var count := maxi(definition.boss_phase2_summon_count, 0)
	if count <= 0:
		return
	var parent := get_parent()
	if parent == null:
		return
	var scene := load("res://entities/enemies/dummy/enemy_dummy.tscn") as PackedScene
	if scene == null:
		return
	for i in count:
		var add := scene.instantiate() as EnemyDummy
		parent.add_child(add)
		var offset := Vector2(cos(TAU * float(i) / float(count)), sin(TAU * float(i) / float(count))) * 72.0
		add.global_position = global_position + offset
		add.apply_definition(definition.boss_phase2_summon)
		if target:
			add.receive_room_alert(target)
		SignalBus.enemy_spawned.emit(add)

