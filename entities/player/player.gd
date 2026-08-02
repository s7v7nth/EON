class_name Player
extends CharacterBody2D
## Greybox player root. Owns stats/component refs; states drive behaviour.

const PROJECTILE_SCENE := preload("res://entities/projectiles/projectile.tscn")
const DEFAULT_ARCH := preload("res://resources/architectures/default.tres")

@export var stats: CharacterStats
@export var ranged_attack_data: AttackData
@export var weapons: Array[WeaponData] = []
@export var architecture: ArchitectureData

@onready var state_machine: StateMachine = $StateMachine
@onready var health: HealthComponent = $HealthComponent
@onready var energy: EnergyComponent = $EnergyComponent
@onready var adrenaline: AdrenalineComponent = $AdrenalineComponent
@onready var status: StatusComponent = $StatusComponent
@onready var hurtbox: HurtboxComponent = $HurtboxComponent
@onready var hitbox: HitboxComponent = $HitboxPivot/HitboxComponent
@onready var hitbox_pivot: Node2D = $HitboxPivot
@onready var combat_visual: CombatVisualComponent = $CombatVisual
@onready var dash_cooldown: Timer = $DashCooldownTimer
@onready var attack_cooldown: Timer = $AttackCooldownTimer
@onready var ranged_cooldown: Timer = $RangedCooldownTimer
@onready var parry_cooldown: Timer = $ParryCooldownTimer

## Last non-zero move intent — used by Dash when no input held.
var facing_direction: Vector2 = Vector2.RIGHT
var weapon_index: int = 0
var damage_multiplier: float = 1.0
var move_speed_multiplier: float = 1.0
var dash_cost_multiplier: float = 1.0

## Combo
var combo_root: AttackData
var pending_combo: AttackData

## Architecture runtime
var active_economy: ResourceEconomy
var counter_window: float = 0.0
var counter_damage_bonus: float = 1.0

## Upgrade plugins (duplicated UpgradeEffect instances)
var active_effects: Array = []
var _life_steal_bonus: float = 0.0
var _hp_regen_bonus: float = 0.0

const KNOCKBACK_DURATION := 0.15
var _kb_dir: Vector2 = Vector2.ZERO
var _kb_force: float = 0.0
var _kb_time: float = 0.0


func _ready() -> void:
	motion_mode = MOTION_MODE_FLOATING
	y_sort_enabled = true
	_configure_from_stats()
	_relay_component_signals()
	if architecture == null:
		architecture = DEFAULT_ARCH
	equip_architecture(architecture)
	call_deferred("_emit_initial_bus_values")
	RunState.apply_to_player(self)
	RunState.begin_room()
	if not SignalBus.enemy_died.is_connected(_on_enemy_died_for_economy):
		SignalBus.enemy_died.connect(_on_enemy_died_for_economy)


func _physics_process(delta: float) -> void:
	if _kb_time > 0.0:
		_kb_time = maxf(0.0, _kb_time - delta)
	if counter_window > 0.0:
		counter_window = maxf(0.0, counter_window - delta)
		if counter_window <= 0.0:
			counter_damage_bonus = 1.0
	_process_architecture_economy(delta)
	_tick_upgrade_effects(delta)


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
	if status:
		SignalBus.player_statuses_changed.emit(status.get_active_ids())


func _configure_from_stats() -> void:
	if stats == null:
		push_error("Player: CharacterStats is required")
		return
	health.stats = stats
	energy.stats = stats
	adrenaline.stats = stats
	adrenaline.energy_component = energy
	hurtbox.health_component = health
	hurtbox.status_component = status
	status.health_component = health
	if dash_cooldown:
		dash_cooldown.wait_time = stats.dash_cooldown
		dash_cooldown.one_shot = true
	if parry_cooldown:
		parry_cooldown.one_shot = true


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
	hurtbox.perfect_dodged.connect(_on_perfect_dodged)
	hurtbox.parried.connect(_on_parried)
	if status:
		status.statuses_changed.connect(
			func(active: PackedStringArray) -> void:
				SignalBus.player_statuses_changed.emit(active)
		)


func _on_hurtbox_hit_received(_attack_data: AttackData, _source: Node) -> void:
	if stats:
		adrenaline.add(stats.adrenaline_gain_on_hurt)
	RunState.register_took_damage()
	if combat_visual:
		combat_visual.play_hit_flash()


func _on_perfect_dodged(_attack_data: AttackData, source: Node) -> void:
	if stats:
		adrenaline.add(stats.adrenaline_gain_on_hit * 2.0)
	HitStop.punch()
	Engine.time_scale = 0.35
	get_tree().create_timer(0.12, true, false, true).timeout.connect(
		func() -> void: Engine.time_scale = 1.0
	)
	for effect in active_effects:
		var fx := effect as UpgradeEffect
		if fx:
			fx.on_perfect_dodge(self, source)
	SignalBus.perfect_dodge.emit(source)
	SignalBus.style_action.emit(GameplayEnums.StyleAction.PERFECT_DODGE, 150)


func _on_parried(attack_data: AttackData, source: Node) -> void:
	if stats:
		adrenaline.add(stats.adrenaline_gain_on_hit * 1.5)
	energy.current_energy = minf(energy.current_energy + 20.0, energy.get_max_energy())
	energy.energy_changed.emit(energy.current_energy, energy.get_max_energy())
	if source is EnemyDummy:
		var enemy := source as EnemyDummy
		if enemy.status:
			enemy.status.apply_status(StatusComponent.STATUS_STAGGER, 8.0, 0.7)
		enemy.apply_knockback(
			(enemy.global_position - global_position).normalized(),
			220.0
		)
	HitStop.punch()
	for effect in active_effects:
		var fx := effect as UpgradeEffect
		if fx:
			fx.on_parry(self, source)
	SignalBus.parry_success.emit(source)
	SignalBus.style_action.emit(GameplayEnums.StyleAction.PARRY, 200)
	# Reflect small chip if attack had damage.
	if source is EnemyDummy and attack_data:
		var eh := (source as EnemyDummy).health
		if eh:
			eh.take_damage(attack_data.damage * 0.35)


func get_resist(damage_type: GameplayEnums.DamageType) -> float:
	var base := 0.0
	if stats:
		base = stats.get_resist(damage_type)
	if architecture:
		base += architecture.get_resist(damage_type)
	return clampf(base, -1.0, 0.9)


func equip_architecture(arch: ArchitectureData) -> void:
	if arch == null:
		return
	if active_economy:
		active_economy.on_unequip(self)
	architecture = arch
	# Duplicate so heat / runtime fields are not shared across runs.
	active_economy = arch.economy.duplicate(true) as ResourceEconomy if arch.economy else null
	# One kit per architecture: LMB primary + RMB secondary. No hotkey swapping.
	weapons.clear()
	if not arch.primitives.is_empty() and arch.primitives[0]:
		weapons.append(arch.primitives[0])
	if active_economy:
		active_economy.on_equip(self)
	elif energy:
		energy.unlock_regen(1.0)
	if combat_visual:
		combat_visual.apply_architecture_look(arch)
	equip_weapon(0)
	SignalBus.architecture_changed.emit(arch.architecture_id)
	_emit_economy_hud()


func apply_run_upgrades(upgrades: Array[UpgradeData]) -> void:
	for effect in active_effects:
		var fx := effect as UpgradeEffect
		if fx:
			fx.remove(self)
	active_effects.clear()
	_life_steal_bonus = 0.0
	_hp_regen_bonus = 0.0
	for upgrade in upgrades:
		if upgrade == null:
			continue
		for item in upgrade.effects:
			var template := item as UpgradeEffect
			if template == null:
				continue
			var instance := template.duplicate(true) as UpgradeEffect
			if instance == null:
				continue
			active_effects.append(instance)
			instance.apply(self)
	if not SignalBus.enemy_died.is_connected(_on_enemy_died_for_upgrades):
		SignalBus.enemy_died.connect(_on_enemy_died_for_upgrades)


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
	if active_economy and active_economy.is_action_locked(self):
		return false
	if dash_cooldown and not dash_cooldown.is_stopped():
		return false
	if active_economy:
		return active_economy.can_afford(self, &"dash", stats.dash_cost * dash_cost_multiplier)
	return energy.current_energy >= stats.dash_cost * dash_cost_multiplier


func try_spend_dash() -> bool:
	if stats == null:
		return false
	if active_economy:
		return active_economy.spend(self, &"dash", stats.dash_cost * dash_cost_multiplier)
	return energy.try_spend(stats.dash_cost * dash_cost_multiplier)


func parry_ready() -> bool:
	if active_economy and active_economy.is_action_locked(self):
		return false
	if parry_cooldown and not parry_cooldown.is_stopped():
		return false
	if active_economy:
		return active_economy.can_afford(self, &"parry", 0.0)
	return true


func try_spend_parry() -> bool:
	if active_economy:
		return active_economy.spend(self, &"parry", 0.0)
	return true


func attack_ready() -> bool:
	if active_economy and active_economy.is_action_locked(self):
		return false
	if hitbox == null or hitbox.attack_data == null:
		return false
	return attack_cooldown == null or attack_cooldown.is_stopped()


func ranged_ready() -> bool:
	if active_economy and active_economy.is_action_locked(self):
		return false
	if ranged_attack_data == null:
		return false
	return ranged_cooldown == null or ranged_cooldown.is_stopped()


func try_spend_attack_energy(attack: AttackData) -> bool:
	if attack == null:
		return false
	var action := &"attack"
	if attack == ranged_attack_data:
		action = &"ranged"
	var cost := attack.energy_cost
	if active_economy:
		return active_economy.spend(self, action, cost)
	if cost <= 0.0:
		return true
	return energy.try_spend(cost)


func try_special() -> bool:
	if active_economy == null:
		return false
	if active_economy.is_action_locked(self):
		return false
	return active_economy.try_special(self)


func get_attack_speed_multiplier() -> float:
	var m := 1.0
	if status:
		m *= status.get_action_speed_multiplier()
	if active_economy:
		m *= active_economy.attack_speed_multiplier(self)
	return maxf(m, 0.2)


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
		_resize_melee_hitbox(weapon.hitbox_reach)
	combo_root = weapon.primary
	pending_combo = null
	ranged_attack_data = weapon.secondary
	if combat_visual:
		combat_visual.apply_weapon_look(weapon, architecture)
	SignalBus.weapon_changed.emit(weapon.display_name)


func _resize_melee_hitbox(reach: float) -> void:
	if hitbox == null:
		return
	var shape_node := hitbox.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null or shape_node.shape == null:
		return
	if shape_node.shape is RectangleShape2D:
		var rect := (shape_node.shape as RectangleShape2D).duplicate() as RectangleShape2D
		rect.size = Vector2(maxf(reach * 1.15, 36.0), 28.0)
		shape_node.shape = rect


func spawn_projectile(direction: Vector2) -> void:
	var proj := PROJECTILE_SCENE.instantiate() as Projectile
	proj.attack_data = ranged_attack_data
	proj.direction = direction.normalized()
	proj.source = self
	proj.collision_mask = (1 << 0) | (1 << 4)
	if ranged_attack_data:
		proj.tint = _projectile_color(ranged_attack_data.damage_type)
	get_parent().add_child(proj)
	proj.global_position = global_position + direction.normalized() * 28.0
	proj.hit_landed.connect(_on_projectile_hit_landed)


func _projectile_color(damage_type: GameplayEnums.DamageType) -> Color:
	match damage_type:
		GameplayEnums.DamageType.ELECTRICITY:
			return Color(0.45, 0.85, 1.0, 1)
		GameplayEnums.DamageType.CORROSION:
			return Color(0.4, 0.95, 0.35, 1)
		GameplayEnums.DamageType.FIRE:
			return Color(1.0, 0.5, 0.2, 1)
		GameplayEnums.DamageType.BLEED:
			return Color(0.95, 0.25, 0.3, 1)
		_:
			return Color(0.85, 0.9, 1.0, 1)


func _on_projectile_hit_landed(target: HurtboxComponent) -> void:
	_on_offensive_hit(target)
	if target and get_parent():
		var pos := target.global_position
		if target.get_parent() is Node2D:
			pos = (target.get_parent() as Node2D).global_position + Vector2(0, -22)
		var dtype := GameplayEnums.DamageType.PHYSICAL
		if ranged_attack_data:
			dtype = ranged_attack_data.damage_type
		HitVFX.spawn_at(get_parent(), pos, dtype, pos - global_position)
	for effect in active_effects:
		var fx := effect as UpgradeEffect
		if fx:
			fx.on_ranged_hit(self, target)


func on_melee_hit(target: HurtboxComponent) -> void:
	_on_offensive_hit(target)
	for effect in active_effects:
		var fx := effect as UpgradeEffect
		if fx:
			fx.on_melee_hit(self, target)


func _on_offensive_hit(target: HurtboxComponent) -> void:
	if stats:
		adrenaline.add(stats.adrenaline_gain_on_hit)
	SignalBus.style_action.emit(GameplayEnums.StyleAction.HIT, 20)
	if active_economy:
		active_economy.on_hit(self, target)
	if _life_steal_bonus > 0.0:
		health.heal(4.0 * _life_steal_bonus * 10.0)


func effective_damage_multiplier() -> float:
	var m := damage_multiplier
	if counter_window > 0.0:
		m *= counter_damage_bonus
	if active_economy:
		m *= active_economy.damage_multiplier(self)
	for effect in active_effects:
		var fx := effect as UpgradeEffect
		if fx:
			m *= fx.damage_multiplier(self)
	return m


func _tick_upgrade_effects(delta: float) -> void:
	for effect in active_effects:
		var fx := effect as UpgradeEffect
		if fx:
			fx.tick(self, delta)


func _on_enemy_died_for_upgrades(enemy: Node) -> void:
	for effect in active_effects:
		var fx := effect as UpgradeEffect
		if fx:
			fx.on_kill(self, enemy)


func _process_architecture_economy(delta: float) -> void:
	if active_economy:
		active_economy.tick(self, delta)
		if _hp_regen_bonus > 0.0 and health:
			health.heal(_hp_regen_bonus * delta)
	_emit_economy_hud()


func _emit_economy_hud() -> void:
	if active_economy == null:
		return
	var vals := active_economy.get_hud_values(self)
	SignalBus.player_economy_hud_changed.emit(
		vals.get("primary", {}),
		vals.get("secondary", {})
	)


func _on_enemy_died_for_economy(enemy: Node) -> void:
	if active_economy:
		active_economy.on_kill(self, enemy)
