class_name EnemyDummy
extends CharacterBody2D
## Simple aggro → chase → attack dummy for the vertical slice.

@export var stats: CharacterStats
@export var attack_range: float = 36.0

@onready var state_machine: StateMachine = $StateMachine
@onready var health: HealthComponent = $HealthComponent
@onready var hurtbox: HurtboxComponent = $HurtboxComponent
@onready var hitbox: HitboxComponent = $HitboxComponent
@onready var detection_area: Area2D = $DetectionArea
@onready var attack_cooldown: Timer = $AttackCooldownTimer

var target: Node2D


func _ready() -> void:
	motion_mode = MOTION_MODE_FLOATING
	y_sort_enabled = true
	_configure_from_stats()
	health.died.connect(_on_died)
	detection_area.body_entered.connect(_on_detection_body_entered)
	detection_area.body_exited.connect(_on_detection_body_exited)
	# Catch bodies already overlapping on spawn.
	call_deferred("_scan_detection_area")


func _scan_detection_area() -> void:
	for body in detection_area.get_overlapping_bodies():
		_on_detection_body_entered(body)


func _configure_from_stats() -> void:
	if stats == null:
		push_error("EnemyDummy: CharacterStats is required")
		return
	health.stats = stats
	hurtbox.health_component = health


func _on_detection_body_entered(body: Node2D) -> void:
	if body is Player:
		target = body


func _on_detection_body_exited(body: Node2D) -> void:
	if body == target:
		target = null


func _on_died() -> void:
	SignalBus.enemy_died.emit(self)
	SignalBus.entity_died.emit(self)
	queue_free()


func apply_chase_movement() -> void:
	if target == null or stats == null:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	var direction := global_position.direction_to(target.global_position)
	velocity = Iso.apply_velocity(direction, stats.move_speed)
	move_and_slide()


func stop_movement() -> void:
	velocity = Vector2.ZERO
	move_and_slide()


func distance_to_target() -> float:
	if target == null:
		return INF
	return global_position.distance_to(target.global_position)


func is_target_in_attack_range() -> bool:
	return distance_to_target() <= attack_range
