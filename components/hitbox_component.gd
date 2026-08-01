class_name HitboxComponent
extends Area2D
## Deals damage to HurtboxComponents while active. One hit per target per activation.

@export var attack_data: AttackData

var _hit_targets: Dictionary = {} # instance_id -> true

signal hit_landed(target: HurtboxComponent)


func _ready() -> void:
	monitoring = false
	monitorable = false
	area_entered.connect(_on_area_entered)
	_set_shapes_disabled(true)


func activate() -> void:
	_hit_targets.clear()
	monitoring = true
	_set_shapes_disabled(false)


func deactivate() -> void:
	monitoring = false
	_set_shapes_disabled(true)
	_hit_targets.clear()


func _on_area_entered(area: Area2D) -> void:
	if not monitoring:
		return
	if area is not HurtboxComponent:
		return
	var hurtbox := area as HurtboxComponent
	var id := hurtbox.get_instance_id()
	if _hit_targets.has(id):
		return
	_hit_targets[id] = true
	hurtbox.receive_hit(attack_data, owner)
	hit_landed.emit(hurtbox)


func _set_shapes_disabled(disabled: bool) -> void:
	for child in get_children():
		if child is CollisionShape2D:
			(child as CollisionShape2D).set_deferred("disabled", disabled)
		elif child is CollisionPolygon2D:
			(child as CollisionPolygon2D).set_deferred("disabled", disabled)
