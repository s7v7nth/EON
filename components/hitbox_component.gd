class_name HitboxComponent
extends Area2D
## Deals damage to HurtboxComponents while active. One hit per target per activation.

@export var attack_data: AttackData

var _hit_targets: Dictionary = {} # instance_id -> true
var _active: bool = false

signal hit_landed(target: HurtboxComponent)


func _ready() -> void:
	monitoring = false
	monitorable = false
	area_entered.connect(_on_area_entered)
	_set_shapes_disabled(true)


func activate() -> void:
	_hit_targets.clear()
	_active = true
	monitoring = true
	_set_shapes_disabled(false)


func is_active() -> bool:
	return _active


func deactivate() -> void:
	_active = false
	_hit_targets.clear()
	# Never flip monitoring inside an area_entered physics callback — defer it.
	set_deferred("monitoring", false)
	_set_shapes_disabled(true)


func _on_area_entered(area: Area2D) -> void:
	if not _active or not monitoring:
		return
	if not (area is HurtboxComponent):
		return
	var hurtbox: HurtboxComponent = area as HurtboxComponent
	var id: int = hurtbox.get_instance_id()
	if _hit_targets.has(id):
		return
	_hit_targets[id] = true
	# Defer hit resolution so receive_hit / death / queue_free can't re-enter physics.
	call_deferred("_resolve_hit", hurtbox)


func _resolve_hit(hurtbox: Node) -> void:
	if not _active:
		return
	if hurtbox == null or not is_instance_valid(hurtbox):
		return
	if not (hurtbox is HurtboxComponent):
		return
	var hb: HurtboxComponent = hurtbox as HurtboxComponent
	hb.receive_hit(attack_data, owner)
	hit_landed.emit(hb)
	# HitStop / trauma / flash are applied inside Hurtbox based on actual HP% damage.


func _set_shapes_disabled(disabled: bool) -> void:
	for child in get_children():
		if child is CollisionShape2D:
			(child as CollisionShape2D).set_deferred("disabled", disabled)
		elif child is CollisionPolygon2D:
			(child as CollisionPolygon2D).set_deferred("disabled", disabled)
