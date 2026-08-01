class_name HurtboxComponent
extends Area2D
## Receives hits and forwards damage to HealthComponent. Supports i-frames / parry / perfect dodge.

@export var health_component: HealthComponent
@export var status_component: StatusComponent

var _invincible: bool = false
var _parrying: bool = false
## When true, invincible frames still receive hit callbacks (for perfect dodge).
var _detect_while_invincible: bool = false

signal hit_received(attack_data: AttackData, source: Node)
signal perfect_dodged(attack_data: AttackData, source: Node)
signal parried(attack_data: AttackData, source: Node)


func _ready() -> void:
	monitoring = false
	monitorable = true
	if status_component == null:
		var sibling := get_parent().get_node_or_null("StatusComponent")
		if sibling is StatusComponent:
			status_component = sibling


func receive_hit(attack_data: AttackData, source: Node) -> bool:
	## Returns false if the hit was fully negated (dodge/parry/invuln without detect).
	if attack_data == null:
		return false

	if _parrying:
		parried.emit(attack_data, source)
		return false

	if _invincible:
		if _detect_while_invincible:
			perfect_dodged.emit(attack_data, source)
		return false

	if health_component == null:
		push_warning("%s: no HealthComponent assigned" % name)
		return false

	var damage := _compute_damage(attack_data, source)
	health_component.take_damage(damage)
	_try_apply_status(attack_data)
	_apply_knockback(attack_data, source)
	hit_received.emit(attack_data, source)
	return true


func _compute_damage(attack_data: AttackData, source: Node) -> float:
	var damage := attack_data.damage * maxf(attack_data.combo_scale, 0.01)
	if source is Player:
		var player := source as Player
		damage *= player.effective_damage_multiplier()
	var resist := _resolve_resist(attack_data.damage_type)
	if status_component:
		resist = clampf(resist - status_component.get_resist_shred(), -1.0, 0.9)
	var mult := clampf(1.0 - resist, 0.05, 2.0)
	# Elemental instant modifiers.
	match attack_data.damage_type:
		GameplayEnums.DamageType.FIRE:
			mult *= 1.1
		GameplayEnums.DamageType.ELECTRICITY:
			if _is_android_like():
				mult *= 1.25
		GameplayEnums.DamageType.BLEED:
			mult *= 0.85
	return damage * mult


func _resolve_resist(damage_type: GameplayEnums.DamageType) -> float:
	var owner_node := get_parent()
	if owner_node is EnemyDummy:
		var enemy := owner_node as EnemyDummy
		if enemy.definition:
			return enemy.definition.get_resist(damage_type)
	if owner_node is Player:
		var player := owner_node as Player
		return player.get_resist(damage_type)
	if health_component and health_component.stats:
		return health_component.stats.get_resist(damage_type)
	return 0.0


func _is_android_like() -> bool:
	var owner_node := get_parent()
	if owner_node is EnemyDummy:
		var def := (owner_node as EnemyDummy).definition
		if def:
			return def.faction == GameplayEnums.Faction.ANDROID \
				or def.faction == GameplayEnums.Faction.CYBORG
	return false


func _try_apply_status(attack_data: AttackData) -> void:
	if status_component == null:
		return
	if attack_data.status_chance <= 0.0 or attack_data.status_power <= 0.0:
		return
	var resist := _resolve_resist(attack_data.damage_type)
	var chance := attack_data.status_chance * (1.0 - resist * 0.5)
	if randf() > chance:
		return
	var status_id := _status_for_type(attack_data.damage_type)
	if status_id == StringName():
		return
	status_component.apply_status(status_id, attack_data.status_power, attack_data.status_duration)


func _status_for_type(damage_type: GameplayEnums.DamageType) -> StringName:
	match damage_type:
		GameplayEnums.DamageType.FIRE:
			return StatusComponent.STATUS_BURN
		GameplayEnums.DamageType.BLEED:
			return StatusComponent.STATUS_BLEED
		GameplayEnums.DamageType.CORROSION:
			return StatusComponent.STATUS_ACID
		GameplayEnums.DamageType.ELECTRICITY:
			return StatusComponent.STATUS_SHOCK
		GameplayEnums.DamageType.PHYSICAL:
			return StatusComponent.STATUS_STAGGER
	return StringName()


func _apply_knockback(attack_data: AttackData, source: Node) -> void:
	if attack_data.knockback_force <= 0.0:
		return
	var body := get_parent()
	if body == null or not body.has_method("apply_knockback"):
		return
	var away := Vector2.RIGHT
	if source is Node2D and body is Node2D:
		away = (body as Node2D).global_position - (source as Node2D).global_position
		if away == Vector2.ZERO:
			away = Vector2.RIGHT
	body.call("apply_knockback", away.normalized(), attack_data.knockback_force)


func set_invincible(on: bool, detect_hits: bool = false) -> void:
	_invincible = on
	_detect_while_invincible = detect_hits
	if detect_hits:
		# Keep hurtbox receivable so perfect-dodge can fire.
		monitorable = true
		_set_shapes_disabled(false)
		return
	monitorable = not on
	_set_shapes_disabled(on)


func set_parrying(on: bool) -> void:
	_parrying = on


func is_invincible() -> bool:
	return _invincible


func is_parrying() -> bool:
	return _parrying


func _set_shapes_disabled(disabled: bool) -> void:
	for child in get_children():
		if child is CollisionShape2D:
			(child as CollisionShape2D).set_deferred("disabled", disabled)
		elif child is CollisionPolygon2D:
			(child as CollisionPolygon2D).set_deferred("disabled", disabled)
