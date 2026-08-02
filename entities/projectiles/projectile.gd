class_name Projectile
extends Area2D
## Straight-flying projectile. Returning mode flies out then home to source.

signal hit_landed(target: HurtboxComponent)
signal returned_to_source

var attack_data: AttackData
var direction: Vector2 = Vector2.RIGHT
var source: Node
var tint: Color = Color(1.0, 0.55, 0.35, 1.0)
## Scales outbound speed / damage feel for charged throws.
var charge: float = 1.0

var _lifetime: float = 0.0
var _trail_timer: float = 0.0
var _visual: Polygon2D
var _core: Polygon2D
var _returning: bool = false
var _hit_done: bool = false
var _max_range: float = 420.0
var _origin: Vector2 = Vector2.ZERO


func _ready() -> void:
	monitoring = true
	monitorable = false
	z_index = 20
	y_sort_enabled = false
	rotation = direction.angle()
	_origin = global_position
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	_ensure_visuals()
	_apply_visual_style()
	_fit_hitbox()
	if attack_data and attack_data.returning:
		_max_range = 280.0 + 220.0 * charge


func _fit_hitbox() -> void:
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		return
	var circle := CircleShape2D.new()
	# Returning blade throw needs a generous catch volume; other shots still larger than before.
	circle.radius = 30.0 if (attack_data and attack_data.returning) else 24.0
	shape_node.shape = circle


func _physics_process(delta: float) -> void:
	if attack_data == null:
		queue_free()
		return
	_lifetime += delta
	if _returning:
		_process_return(delta)
		return
	if _lifetime >= attack_data.projectile_lifetime:
		if attack_data.returning:
			_begin_return()
			return
		queue_free()
		return
	var speed := attack_data.projectile_speed * (0.7 + 0.5 * charge)
	global_position += direction * speed * delta
	rotation = direction.angle()
	if attack_data.returning and global_position.distance_to(_origin) >= _max_range:
		_begin_return()
		return
	_trail_timer += delta
	if _trail_timer >= 0.04:
		_trail_timer = 0.0
		_spawn_trail()


func _process_return(delta: float) -> void:
	if source == null or not is_instance_valid(source) or source is not Node2D:
		queue_free()
		return
	var target_pos := (source as Node2D).global_position
	var to_src := target_pos - global_position
	var dist := to_src.length()
	if dist <= 18.0:
		returned_to_source.emit()
		queue_free()
		return
	var speed := attack_data.projectile_speed * 1.15
	direction = to_src / dist
	global_position += direction * speed * delta
	rotation = direction.angle()
	_trail_timer += delta
	if _trail_timer >= 0.04:
		_trail_timer = 0.0
		_spawn_trail()


func _begin_return() -> void:
	_returning = true
	_hit_done = true


func _ensure_visuals() -> void:
	_visual = get_node_or_null("Visual") as Polygon2D
	if _visual == null:
		_visual = Polygon2D.new()
		_visual.name = "Visual"
		add_child(_visual)
	_core = get_node_or_null("Core") as Polygon2D
	if _core == null:
		_core = Polygon2D.new()
		_core.name = "Core"
		add_child(_core)


func _apply_visual_style() -> void:
	var col := tint
	if col.a <= 0.0 or col.r + col.g + col.b < 0.35:
		col = Color(1.0, 0.55, 0.35, 1.0)
	_visual.color = Color(col.r, col.g, col.b, 1.0)
	_visual.modulate = Color.WHITE
	_visual.z_index = 1
	_visual.polygon = PackedVector2Array([
		Vector2(28, 0), Vector2(-14, -12), Vector2(-6, 0), Vector2(-14, 12)
	])
	_core.color = Color(1, 1, 1, 0.95)
	_core.modulate = Color.WHITE
	_core.z_index = 2
	_core.polygon = PackedVector2Array([
		Vector2(16, 0), Vector2(-4, -6), Vector2(2, 0), Vector2(-4, 6)
	])
	modulate = Color.WHITE
	if attack_data and attack_data.returning:
		_visual.polygon = PackedVector2Array([
			Vector2(32, 0), Vector2(-16, -14), Vector2(-6, 0), Vector2(-16, 14)
		])
		_core.polygon = PackedVector2Array([
			Vector2(18, 0), Vector2(-4, -7), Vector2(2, 0), Vector2(-4, 7)
		])


func _spawn_trail() -> void:
	if _visual == null or get_parent() == null:
		return
	var ghost := Polygon2D.new()
	ghost.polygon = _visual.polygon
	ghost.color = Color(_visual.color.r, _visual.color.g, _visual.color.b, 0.55)
	ghost.z_index = 19
	get_parent().add_child(ghost)
	ghost.global_position = global_position
	ghost.global_rotation = global_rotation
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "color:a", 0.0, 0.14)
	tween.parallel().tween_property(ghost, "scale", Vector2(0.4, 0.4), 0.14)
	tween.tween_callback(ghost.queue_free)


func _on_area_entered(area: Area2D) -> void:
	if area is not HurtboxComponent:
		return
	if source != null and area.get_parent() == source:
		return
	if _returning or _hit_done:
		return
	var hurtbox := area as HurtboxComponent
	hurtbox.receive_hit(attack_data, source)
	hit_landed.emit(hurtbox)
	HitStop.punch(0.2, 0.03)
	if attack_data and attack_data.returning:
		_begin_return()
	else:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if source != null and body == source:
		return
	if _returning:
		return
	if attack_data and attack_data.returning:
		_begin_return()
	else:
		queue_free()
