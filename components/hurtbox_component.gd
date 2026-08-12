class_name HurtboxComponent
extends Area2D
## Receives hits and forwards damage. Supports i-frames / parry / block / energy shield.

@export var health_component: HealthComponent
@export var status_component: StatusComponent
@export var energy_component: EnergyComponent
@export var block_damage_mult: float = 0.5

var _invincible: bool = false
var _parrying: bool = false
var _blocking: bool = false
## When true, invincible frames still receive hit callbacks (for perfect dodge).
var _detect_while_invincible: bool = false

signal hit_received(attack_data: AttackData, source: Node, hp_damage: float)
signal perfect_dodged(attack_data: AttackData, source: Node)
signal parried(attack_data: AttackData, source: Node)
signal blocked(attack_data: AttackData, source: Node, mitigated: float)


func _ready() -> void:
	monitoring = false
	monitorable = true
	if status_component == null:
		var sibling := get_parent().get_node_or_null("StatusComponent")
		if sibling is StatusComponent:
			status_component = sibling
	if energy_component == null:
		var energy_sib := get_parent().get_node_or_null("EnergyComponent")
		if energy_sib is EnergyComponent:
			energy_component = energy_sib


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

	var owner_node := get_parent()
	if owner_node and owner_node.has_method("try_behavior_dodge"):
		if bool(owner_node.call("try_behavior_dodge", attack_data, source)):
			return false

	if health_component == null:
		push_warning("%s: no HealthComponent assigned" % name)
		return false

	var was_crit := _is_stagger_crit_window()
	var damage := _compute_damage(attack_data, source)
	if _blocking and damage > 0.0:
		var before := damage
		damage *= block_damage_mult
		blocked.emit(attack_data, source, before - damage)

	var hp_damage := damage
	if energy_component and damage > 0.0:
		hp_damage = energy_component.absorb_damage(damage)

	if hp_damage > 0.0:
		health_component.take_damage(hp_damage)
		SignalBus.damage_dealt.emit(hp_damage, get_parent(), source)
		_spawn_damage_pop(hp_damage, was_crit)
		_apply_impact_juice(hp_damage, attack_data)
	_try_apply_status(attack_data)
	_apply_knockback(attack_data, source, hp_damage)
	_apply_poise(attack_data, source)
	hit_received.emit(attack_data, source, hp_damage)
	return true


func _compute_damage(attack_data: AttackData, source: Node) -> float:
	var damage := attack_data.damage * maxf(attack_data.combo_scale, 0.01)
	if source is Player:
		var player := source as Player
		damage *= player.effective_damage_multiplier()
	elif source != null and source.has_meta("elite_pressure"):
		damage *= maxf(float(source.get_meta("elite_pressure")), 1.0)
	var resist := _resolve_resist(attack_data.damage_type)
	if status_component:
		resist = clampf(resist - status_component.get_resist_shred(), -1.0, 0.9)
	var mult := clampf(1.0 - resist, 0.05, 2.0)
	match attack_data.damage_type:
		GameplayEnums.DamageType.FIRE:
			mult *= 1.1
		GameplayEnums.DamageType.ELECTRICITY:
			if _is_android_like():
				mult *= 1.25
		GameplayEnums.DamageType.BLEED:
			mult *= 0.85
		GameplayEnums.DamageType.GLITCH:
			if _is_android_like():
				mult *= 1.3
	damage *= mult
	var owner_node := get_parent()
	if _consume_stagger_crit(owner_node):
		damage *= float(owner_node.get_meta("stagger_crit_bonus", 1.35))
		if owner_node.has_meta("stagger_crit_bonus"):
			owner_node.remove_meta("stagger_crit_bonus")
	if status_component:
		damage = status_component.modify_incoming_damage(damage, int(attack_data.damage_type))
	return damage


func _is_stagger_crit_window() -> bool:
	var owner_node := get_parent()
	if owner_node == null or not owner_node.has_meta("stagger_crit_until"):
		return false
	return Time.get_ticks_msec() / 1000.0 <= float(owner_node.get_meta("stagger_crit_until"))


func _consume_stagger_crit(owner_node: Node) -> bool:
	if owner_node == null or not owner_node.has_meta("stagger_crit_until"):
		return false
	var until := float(owner_node.get_meta("stagger_crit_until"))
	if Time.get_ticks_msec() / 1000.0 > until:
		return false
	owner_node.remove_meta("stagger_crit_until")
	return true


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
	var buildup := attack_data.status_power * 12.0
	var owner_node := get_parent()
	if owner_node is EnemyDummy:
		var def := (owner_node as EnemyDummy).definition
		if def:
			buildup *= def.get_status_vulnerability(status_id)
	status_component.add_buildup(status_id, buildup, attack_data.status_power)


func _status_for_type(damage_type: GameplayEnums.DamageType) -> StringName:
	var catalog := StatusComponent.CATALOG as StatusCatalog
	if catalog:
		var from_catalog := catalog.status_id_for_damage_type(damage_type)
		if from_catalog != StringName():
			return from_catalog
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
		GameplayEnums.DamageType.GLITCH:
			return StatusComponent.STATUS_GLITCH
	return StringName()


func _apply_knockback(attack_data: AttackData, source: Node, hp_damage: float = 0.0) -> void:
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
	var max_hp: float = health_component.get_max_health() if health_component else 100.0
	var frac: float = CombatImpact.hp_frac(hp_damage, max_hp)
	var kb_mult: float = CombatImpact.knockback_scale(frac)
	body.call(
		"apply_knockback",
		away.normalized(),
		attack_data.knockback_force * kb_mult,
		maxf(attack_data.knockback_duration * lerpf(0.85, 1.55, clampf(frac, 0.0, 1.0)), 0.05)
	)


func _apply_impact_juice(hp_damage: float, attack_data: AttackData) -> void:
	var max_hp: float = health_component.get_max_health() if health_component else 100.0
	CombatImpact.apply_hit_juice(hp_damage, max_hp, attack_data)
	var body := get_parent()
	if body and body.get("combat_visual") is CombatVisualComponent:
		(body.get("combat_visual") as CombatVisualComponent).play_hit_flash()


func _apply_poise(attack_data: AttackData, _source: Node) -> void:
	var body := get_parent()
	if body == null or not body.has_method("apply_poise_hit"):
		return
	body.call("apply_poise_hit", attack_data.poise_damage)


func _spawn_damage_pop(amount: float, is_crit: bool) -> void:
	var body := get_parent()
	if body == null or body.get_parent() == null:
		return
	if body is not Node2D:
		return
	var pos: Vector2 = (body as Node2D).global_position + Vector2(0, -28)
	DamagePop.spawn_at(body.get_parent(), pos, amount, is_crit)


func set_invincible(on: bool, detect_hits: bool = false) -> void:
	_invincible = on
	_detect_while_invincible = detect_hits
	if detect_hits:
		monitorable = true
		_set_shapes_disabled(false)
		return
	monitorable = not on
	_set_shapes_disabled(on)


func set_parrying(on: bool) -> void:
	_parrying = on


func set_blocking(on: bool) -> void:
	_blocking = on


func is_invincible() -> bool:
	return _invincible


func is_parrying() -> bool:
	return _parrying


func is_blocking() -> bool:
	return _blocking


func _set_shapes_disabled(disabled: bool) -> void:
	for child in get_children():
		if child is CollisionShape2D:
			(child as CollisionShape2D).set_deferred("disabled", disabled)
		elif child is CollisionPolygon2D:
			(child as CollisionPolygon2D).set_deferred("disabled", disabled)
