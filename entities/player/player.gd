class_name Player
extends CharacterBody2D
## Greybox player root. Owns stats/component refs; states drive behaviour.

const PROJECTILE_SCENE := preload("res://entities/projectiles/projectile.tscn")

@export var stats: CharacterStats
@export var ranged_attack_data: AttackData
@export var weapons: Array[WeaponData] = []

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
var weapon_index: int = 0
var damage_multiplier: float = 1.0
var move_speed_multiplier: float = 1.0
var dash_cost_multiplier: float = 1.0

const KNOCKBACK_DURATION := 0.15
var _kb_dir: Vector2 = Vector2.ZERO
var _kb_force: float = 0.0
var _kb_time: float = 0.0


func _ready() -> void:
	motion_mode = MOTION_MODE_FLOATING
	y_sort_enabled = true
	_configure_from_stats()
	_relay_component_signals()
	_ensure_default_weapons()
	equip_weapon(0)
	call_deferred("_emit_initial_bus_values")
	RunState.apply_to_player(self)


func _physics_process(delta: float) -> void:
	if _kb_time > 0.0:
		_kb_time = maxf(0.0, _kb_time - delta)


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
	velocity = Iso.apply_velocity(direction, (stats.move_speed if stats else 0.0) * move_speed_multiplier)
	velocity += _knockback_vector()
	move_and_slide()


func stop_movement() -> void:
	velocity = _knockback_vector()
	move_and_slide()


func dash_ready() -> bool:
	if stats == null:
		return false
	if dash_cooldown and not dash_cooldown.is_stopped():
		return false
	return energy.current_energy >= stats.dash_cost * dash_cost_multiplier


func try_spend_dash() -> bool:
	if stats == null:
		return false
	return energy.try_spend(stats.dash_cost * dash_cost_multiplier)


func attack_ready() -> bool:
	if hitbox == null or hitbox.attack_data == null:
		return false
	return attack_cooldown == null or attack_cooldown.is_stopped()


func ranged_ready() -> bool:
	if ranged_attack_data == null:
		return false
	return ranged_cooldown == null or ranged_cooldown.is_stopped()


func _ensure_default_weapons() -> void:
	if not weapons.is_empty():
		return
	weapons = [
		load("res://resources/weapons/blade.tres") as WeaponData,
		load("res://resources/weapons/hammer.tres") as WeaponData,
		load("res://resources/weapons/bow.tres") as WeaponData,
	]


func equip_weapon(index: int) -> void:
	if weapons.is_empty():
		return
	weapon_index = clampi(index, 0, weapons.size() - 1)
	var weapon := weapons[weapon_index]
	if weapon == null:
		return
	if hitbox:
		hitbox.attack_data = weapon.primary
		hitbox.position = Vector2(weapon.hitbox_reach, 0.0)
	ranged_attack_data = weapon.secondary
	var visual := get_node_or_null("Visual") as Polygon2D
	if visual:
		visual.color = weapon.visual_tint
	SignalBus.weapon_changed.emit(weapon.display_name)


func current_weapon_name() -> String:
	if weapons.is_empty() or weapon_index < 0 or weapon_index >= weapons.size():
		return ""
	var weapon := weapons[weapon_index]
	return weapon.display_name if weapon else ""


func handle_weapon_hotkeys() -> bool:
	if Input.is_action_just_pressed("weapon_1"):
		equip_weapon(0)
		return true
	if Input.is_action_just_pressed("weapon_2"):
		equip_weapon(1)
		return true
	if Input.is_action_just_pressed("weapon_3"):
		equip_weapon(2)
		return true
	return false


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
