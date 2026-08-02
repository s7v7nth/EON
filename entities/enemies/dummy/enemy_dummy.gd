class_name EnemyDummy
extends CharacterBody2D
## Aggro → chase → melee up close, ranged shot at mid distance.

const PROJECTILE_SCENE := preload("res://entities/projectiles/projectile.tscn")

@export var stats: CharacterStats
@export var definition: EnemyDefinition
@export var attack_range: float = 36.0
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


func _ready() -> void:
	motion_mode = MOTION_MODE_FLOATING
	y_sort_enabled = true
	if definition != null:
		apply_definition(definition)
	else:
		_configure_from_stats()
	health.died.connect(_on_died)
	detection_area.body_entered.connect(_on_detection_body_entered)
	detection_area.body_exited.connect(_on_detection_body_exited)
	# Catch bodies already overlapping on spawn.
	call_deferred("_scan_detection_area")
	call_deferred("_fit_combat_shapes")


func _fit_combat_shapes() -> void:
	## Match hurt/hit volumes to the full greybox body, not just the feet circle.
	var hurt_shape := hurtbox.get_node_or_null("CollisionShape2D") as CollisionShape2D if hurtbox else null
	if hurt_shape:
		hurt_shape.position = Vector2(0, -22)
		var circle := CircleShape2D.new()
		circle.radius = 26.0
		hurt_shape.shape = circle
	var hit_shape := hitbox.get_node_or_null("CollisionShape2D") as CollisionShape2D if hitbox else null
	if hit_shape:
		var rect := RectangleShape2D.new()
		rect.size = Vector2(48, 44)
		hit_shape.shape = rect


func _physics_process(delta: float) -> void:
	if _kb_time > 0.0:
		_kb_time = maxf(0.0, _kb_time - delta)
	for behavior in _behaviors:
		if behavior:
			behavior.tick(self, delta)


func apply_knockback(direction: Vector2, force: float) -> void:
	if direction == Vector2.ZERO or force <= 0.0:
		return
	_kb_dir = direction.normalized()
	_kb_force = force
	_kb_time = KNOCKBACK_DURATION


func _knockback_vector() -> Vector2:
	if _kb_time <= 0.0 or _kb_force <= 0.0:
		return Vector2.ZERO
	var strength := _kb_force * (_kb_time / KNOCKBACK_DURATION)
	return Iso.apply_velocity(_kb_dir, strength)


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
	var visual := get_node_or_null("Visual") as Polygon2D
	if visual:
		visual.visible = true
		visual.modulate = Color.WHITE
		visual.color = Color(def.visual_color.r, def.visual_color.g, def.visual_color.b, 1.0)
	if combat_visual:
		combat_visual.apply_faction_look(def.faction, def.visual_color)
	var hp_bar := get_node_or_null("HealthBar") as HealthBarComponent
	if hp_bar:
		hp_bar.set_label(def.display_name if def.display_name != "" else "Enemy")
	var detect_shape := detection_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if detect_shape and detect_shape.shape is CircleShape2D:
		(detect_shape.shape as CircleShape2D).radius = def.detection_radius


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
	SignalBus.enemy_died.emit(self)
	SignalBus.entity_died.emit(self)
	queue_free()


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


func stop_movement() -> void:
	velocity = _knockback_vector()
	move_and_slide()


func get_action_speed_multiplier() -> float:
	if status:
		return maxf(status.get_action_speed_multiplier(), 0.15)
	return 1.0


func interrupt_attack() -> void:
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
	if ranged_attack_data == null or target == null:
		return false
	if not ranged_cooldown.is_stopped():
		return false
	return distance_to_target() <= ranged_range


func spawn_projectile(direction: Vector2) -> void:
	var proj := PROJECTILE_SCENE.instantiate() as Projectile
	proj.attack_data = ranged_attack_data
	proj.direction = direction.normalized()
	proj.source = self
	# world + player_hurtbox
	proj.collision_mask = (1 << 0) | (1 << 3)
	if ranged_attack_data:
		match ranged_attack_data.damage_type:
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
