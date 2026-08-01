class_name HurtboxComponent
extends Area2D
## Receives hits and forwards damage to HealthComponent. Supports i-frames.

@export var health_component: HealthComponent

var _invincible: bool = false

signal hit_received(attack_data: AttackData, source: Node)


func _ready() -> void:
	monitoring = false
	monitorable = true
	# Collision shape stays enabled; invincibility toggles monitorable.


func receive_hit(attack_data: AttackData, source: Node) -> void:
	if _invincible or attack_data == null:
		return
	if health_component == null:
		push_warning("%s: no HealthComponent assigned" % name)
		return
	var damage := attack_data.damage
	if source is Player:
		damage *= (source as Player).damage_multiplier
	health_component.take_damage(damage)
	_apply_knockback(attack_data, source)
	hit_received.emit(attack_data, source)


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


func set_invincible(on: bool) -> void:
	_invincible = on
	monitorable = not on
	# Also disable shapes so Area2D overlap is fully suppressed.
	for child in get_children():
		if child is CollisionShape2D:
			(child as CollisionShape2D).set_deferred("disabled", on)
		elif child is CollisionPolygon2D:
			(child as CollisionPolygon2D).set_deferred("disabled", on)


func is_invincible() -> bool:
	return _invincible
