class_name EnemyDummy
extends CharacterBody2D
## Aggro → chase → melee up close, ranged shot at mid distance.

const PROJECTILE_SCENE := preload("res://entities/projectiles/projectile.tscn")

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


func _ready() -> void:
	motion_mode = MOTION_MODE_FLOATING
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
	_poise = get_max_poise()
	_flinch_time = 0.0
	boss_phase = 1
	_boss_phase2_fired = false
	_phase_action_mult = 1.0
	if definition and definition.is_boss:
		var hp_bar_boss := get_node_or_null("HealthBar") as HealthBarComponent
		if hp_bar_boss:
			hp_bar_boss.set_label("BOSS " + (def.display_name if def.display_name != "" else "Enemy"))
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
	var visual := get_node_or_null("Visual") as Node2D
	if visual:
		visual.modulate = Color(1.15, 0.95, 0.55, 1.0)
	if combat_visual:
		combat_visual.modulate = Color(1.1, 0.9, 0.5, 1.0)
	# Light elite threat aura: nearby status pressure via meta (read by hitbox path).
	set_meta("elite_pressure", 1.12)
	var hp_bar := get_node_or_null("HealthBar") as HealthBarComponent
	if hp_bar:
		var base := definition.display_name if definition != null and definition.display_name != "" else "Enemy"
		hp_bar.set_label("ELITE " + base)
		hp_bar.bar_size = Vector2(64, 8)
		hp_bar.fill_color = Color(0.95, 0.72, 0.15, 0.95)
		hp_bar.queue_redraw()


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
	var direction := global_position.direction_to(target.global_position)
	# Glitch robots may briefly retarget / jitter.
	if is_glitched() and get_meta("glitch_robot", false):
		direction = direction.rotated(randf_range(-0.7, 0.7))
	velocity = Iso.apply_velocity(direction, effective_move_speed())
	velocity += _knockback_vector()
	move_and_slide()


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
				proj.tint = Color(0.35, 0.85, 1.0, 1)
			GameplayEnums.DamageType.CORROSION:
				proj.tint = Color(0.45, 1.0, 0.3, 1)
			_:
				proj.tint = Color(1.0, 0.4, 0.25, 1)
	else:
		proj.tint = Color(1.0, 0.4, 0.25, 1)
	get_parent().add_child(proj)
	proj.global_position = global_position + direction.normalized() * 28.0


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
	_summon_boss_adds()


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
