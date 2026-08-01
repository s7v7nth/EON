class_name Player
extends CharacterBody2D
## Greybox player root. Owns stats/component refs; states drive behaviour.

const PROJECTILE_SCENE := preload("res://entities/projectiles/projectile.tscn")

@export var stats: CharacterStats
@export var ranged_attack_data: AttackData

@onready var state_machine: StateMachine = $StateMachine
@onready var health: HealthComponent = $HealthComponent
@onready var energy: EnergyComponent = $EnergyComponent
@onready var adrenaline: AdrenalineComponent = $AdrenalineComponent
@onready var hurtbox: HurtboxComponent = $HurtboxComponent
@onready var hitbox: HitboxComponent = $HitboxPivot/HitboxComponent
@onready var hitbox_pivot: Node2D = $HitboxPivot
@onready var dash_cooldown: Timer = $DashCooldownTimer
@onready var attack_cooldown: Timer = $AttackCooldownTimer
@onready var ranged_cooldown: Timer = $RangedCooldownTimer

## Last non-zero move intent — used by Dash when no input held.
var facing_direction: Vector2 = Vector2.RIGHT


func _ready() -> void:
	motion_mode = MOTION_MODE_FLOATING
	y_sort_enabled = true
	_configure_from_stats()
	_relay_component_signals()
	call_deferred("_emit_initial_bus_values")


func _emit_initial_bus_values() -> void:
	if health and health.stats:
		SignalBus.player_health_changed.emit(health.current_health, health.get_max_health())
	if energy and energy.stats:
		SignalBus.player_energy_changed.emit(energy.current_energy, energy.get_max_energy())
	if adrenaline and adrenaline.stats:
		SignalBus.player_adrenaline_changed.emit(
			adrenaline.current_adrenaline, adrenaline.get_max_adrenaline()
		)


func _configure_from_stats() -> void:
	if stats == null:
		push_error("Player: CharacterStats is required")
		return
	health.stats = stats
	energy.stats = stats
	adrenaline.stats = stats
	adrenaline.energy_component = energy
	hurtbox.health_component = health
	if dash_cooldown:
		dash_cooldown.wait_time = stats.dash_cooldown
		dash_cooldown.one_shot = true


func _relay_component_signals() -> void:
	health.health_changed.connect(
		func(current: float, max_value: float) -> void:
			SignalBus.player_health_changed.emit(current, max_value)
	)
	health.died.connect(func() -> void: SignalBus.player_died.emit())
	energy.energy_changed.connect(
		func(current: float, max_value: float) -> void:
			SignalBus.player_energy_changed.emit(current, max_value)
	)
	adrenaline.adrenaline_changed.connect(
		func(current: float, max_value: float) -> void:
			SignalBus.player_adrenaline_changed.emit(current, max_value)
	)
	hurtbox.hit_received.connect(_on_hurtbox_hit_received)


func _on_hurtbox_hit_received(_attack_data: AttackData, _source: Node) -> void:
	if stats:
		adrenaline.add(stats.adrenaline_gain_on_hurt)


func get_input_direction() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")


func get_aim_direction() -> Vector2:
	var aim := get_global_mouse_position() - global_position
	if aim == Vector2.ZERO:
		return facing_direction
	return aim.normalized()


func apply_movement(direction: Vector2) -> void:
	if direction != Vector2.ZERO:
		facing_direction = direction.normalized()
	velocity = Iso.apply_velocity(direction, stats.move_speed if stats else 0.0)
	move_and_slide()


func stop_movement() -> void:
	velocity = Vector2.ZERO
	move_and_slide()


func dash_ready() -> bool:
	if stats == null:
		return false
	if dash_cooldown and not dash_cooldown.is_stopped():
		return false
	return energy.current_energy >= stats.dash_cost


func attack_ready() -> bool:
	return attack_cooldown == null or attack_cooldown.is_stopped()


func ranged_ready() -> bool:
	if ranged_attack_data == null:
		return false
	return ranged_cooldown == null or ranged_cooldown.is_stopped()


func spawn_projectile(direction: Vector2) -> void:
	var proj := PROJECTILE_SCENE.instantiate() as Projectile
	proj.attack_data = ranged_attack_data
	proj.direction = direction.normalized()
	proj.source = self
	# world + enemy_hurtbox
	proj.collision_mask = (1 << 0) | (1 << 4)
	proj.modulate = Color(0.5, 0.8, 1.0)
	get_parent().add_child(proj)
	proj.global_position = global_position + direction.normalized() * 20.0
	proj.hit_landed.connect(_on_projectile_hit_landed)


func _on_projectile_hit_landed(_target: HurtboxComponent) -> void:
	if stats:
		adrenaline.add(stats.adrenaline_gain_on_hit)
