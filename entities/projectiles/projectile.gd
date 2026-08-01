class_name Projectile
extends Area2D
## Straight-flying projectile. Spawner sets attack_data, direction, source, mask.

signal hit_landed(target: HurtboxComponent)

var attack_data: AttackData
var direction: Vector2 = Vector2.RIGHT
var source: Node

var _lifetime: float = 0.0


func _ready() -> void:
	monitoring = true
	monitorable = false
	rotation = direction.angle()
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if attack_data == null:
		queue_free()
		return
	_lifetime += delta
	if _lifetime >= attack_data.projectile_lifetime:
		queue_free()
		return
	global_position += direction * attack_data.projectile_speed * delta


func _on_area_entered(area: Area2D) -> void:
	if area is not HurtboxComponent:
		return
	var hurtbox := area as HurtboxComponent
	hurtbox.receive_hit(attack_data, source)
	hit_landed.emit(hurtbox)
	queue_free()


func _on_body_entered(_body: Node2D) -> void:
	# Walls and other solid bodies stop the projectile.
	queue_free()
