class_name AllyDrone
extends CharacterBody2D
## Neuro-hacker dummy drone — chases nearest enemy and chips HP. Does not emit enemy_died.

@export var move_speed: float = 230.0
@export var attack_range: float = 28.0
@export var attack_damage: float = 6.0
@export var attack_cooldown: float = 0.55
@export var max_health: float = 18.0

var owner_player: Node
var economy: ResourceEconomy
var lifetime: float = 18.0

var _hp: float = 18.0
var _cooldown: float = 0.0
var _life_left: float = 18.0
var _pulse_left: float = 0.0
var _pulse_dmg: float = 1.0
var _pulse_spd: float = 1.0
var _base_damage: float = 6.0
var _base_speed: float = 230.0


func _ready() -> void:
	motion_mode = MOTION_MODE_FLOATING
	y_sort_enabled = true
	add_to_group("ally_drone")
	collision_layer = 0
	collision_mask = 1
	_hp = max_health
	_ensure_visual()


func configure(player: Node, econ: ResourceEconomy, life: float) -> void:
	owner_player = player
	economy = econ
	lifetime = life
	_life_left = life
	apply_economy_boosts(econ)


func apply_economy_boosts(econ: ResourceEconomy) -> void:
	if econ == null:
		return
	var dmg := float(econ.get("drone_damage_mult") if econ.get("drone_damage_mult") != null else 1.0)
	var spd := float(econ.get("drone_speed_mult") if econ.get("drone_speed_mult") != null else 1.0)
	_base_damage = 6.0 * maxf(dmg, 0.1)
	_base_speed = 230.0 * maxf(spd, 0.1)
	_refresh_combat_stats()


## Sync Blade / temporary melee-linked overclock.
func apply_overclock_pulse(speed_boost: float, damage_boost: float, duration: float) -> void:
	_pulse_spd = maxf(speed_boost, 1.0)
	_pulse_dmg = maxf(damage_boost, 1.0)
	_pulse_left = maxf(duration, 0.1)
	_refresh_combat_stats()


func _refresh_combat_stats() -> void:
	var pulse_on := _pulse_left > 0.0
	attack_damage = _base_damage * (_pulse_dmg if pulse_on else 1.0)
	move_speed = _base_speed * (_pulse_spd if pulse_on else 1.0)


func _physics_process(delta: float) -> void:
	_life_left -= delta
	if _life_left <= 0.0 or _hp <= 0.0:
		_die()
		return
	if _pulse_left > 0.0:
		_pulse_left = maxf(0.0, _pulse_left - delta)
		if _pulse_left <= 0.0:
			_pulse_dmg = 1.0
			_pulse_spd = 1.0
			_refresh_combat_stats()
	if _cooldown > 0.0:
		_cooldown = maxf(0.0, _cooldown - delta)
	var enemy := _nearest_enemy()
	if enemy == null:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	var dist := global_position.distance_to(enemy.global_position)
	if dist <= attack_range:
		velocity = Vector2.ZERO
		move_and_slide()
		if _cooldown <= 0.0:
			_strike(enemy)
			_cooldown = attack_cooldown
		return
	var dir := global_position.direction_to(enemy.global_position)
	velocity = Iso.apply_velocity(dir, move_speed)
	move_and_slide()


func take_damage(amount: float) -> void:
	if amount <= 0.0:
		return
	_hp = maxf(_hp - amount, 0.0)
	if _hp <= 0.0:
		_die()


func _strike(enemy: Node2D) -> void:
	var health: HealthComponent = enemy.get("health") as HealthComponent
	if health:
		health.take_damage(attack_damage)
	var glitch := 0.0
	if economy:
		glitch = float(economy.get("drone_glitch_buildup") if economy.get("drone_glitch_buildup") != null else 0.0)
	if glitch > 0.0:
		var status: StatusComponent = enemy.get("status") as StatusComponent
		if status:
			status.add_buildup(StatusComponent.STATUS_GLITCH, glitch, 2.5)
		if enemy is Node2D:
			HitVFX.spawn_optic_burst(
				(enemy as Node2D).get_parent(),
				(enemy as Node2D).global_position,
				Color(0.75, 0.4, 1.0, 1),
				Vector2.UP,
				0.7
			)


func _nearest_enemy() -> Node2D:
	var parent := get_parent()
	if parent == null:
		return null
	var best: Node2D = null
	var best_d := INF
	for child in parent.get_children():
		if child == self or child is not Node2D:
			continue
		if child is Player:
			continue
		if child.is_in_group("ally_drone"):
			continue
		if not child.has_method("apply_chase_movement"):
			continue
		var d := global_position.distance_to((child as Node2D).global_position)
		if d < best_d:
			best_d = d
			best = child as Node2D
	return best


func _die() -> void:
	if economy and economy.has_method("release_drone"):
		economy.call("release_drone", self)
	queue_free()


func _ensure_visual() -> void:
	var visual := get_node_or_null("Visual") as Node2D
	if visual is Polygon2D:
		visual.visible = false
	var spr := get_node_or_null("Sprite") as Sprite2D
	if spr == null:
		spr = Sprite2D.new()
		spr.name = "Sprite"
		spr.centered = true
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(spr)
	spr.texture = ArtBank.space("satelliteDish_SE")
	if spr.texture == null:
		spr.texture = ArtBank.rts_unit(8)
	ArtBank.fit_height(spr, 76.0, true)
	spr.modulate = Color(0.82, 0.58, 1.0, 1)
	var ring := get_node_or_null("Halo") as Sprite2D
	if ring == null:
		ring = Sprite2D.new()
		ring.name = "Halo"
		ring.centered = true
		ring.z_index = -1
		ring.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(ring)
		move_child(ring, 0)
	ring.texture = ArtBank.particle("circle_05")
	if ring.texture:
		ArtBank.fit_height(ring, 54.0, false)
	ring.modulate = Color(0.72, 0.42, 1.0, 0.55)
