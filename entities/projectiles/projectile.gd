class_name Projectile
extends Area2D
## Straight-flying projectile. Spawner sets attack_data, direction, source, mask.

signal hit_landed(target: HurtboxComponent)

var attack_data: AttackData
var direction: Vector2 = Vector2.RIGHT
var source: Node
## Set before add_child — _ready copies this onto the polygon colors.
var tint: Color = Color(1.0, 0.55, 0.35, 1.0)

var _lifetime: float = 0.0
var _trail_timer: float = 0.0
var _visual: Polygon2D
var _core: Polygon2D


func _ready() -> void:
	monitoring = true
	monitorable = false
	z_index = 20
	y_sort_enabled = false
	rotation = direction.angle()
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	_ensure_visuals()
	_apply_visual_style()


func _physics_process(delta: float) -> void:
	if attack_data == null:
		queue_free()
		return
	_lifetime += delta
	if _lifetime >= attack_data.projectile_lifetime:
		queue_free()
		return
	global_position += direction * attack_data.projectile_speed * delta
	_trail_timer += delta
	if _trail_timer >= 0.04:
		_trail_timer = 0.0
		_spawn_trail()


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
	# Force strong opaque colors on the polygons themselves.
	_visual.color = Color(col.r, col.g, col.b, 1.0)
	_visual.modulate = Color.WHITE
	_visual.z_index = 1
	_visual.polygon = PackedVector2Array([
		Vector2(18, 0), Vector2(-8, -10), Vector2(-4, 0), Vector2(-8, 10)
	])
	_core.color = Color(1, 1, 1, 0.95)
	_core.modulate = Color.WHITE
	_core.z_index = 2
	_core.polygon = PackedVector2Array([
		Vector2(10, 0), Vector2(-2, -4), Vector2(0, 0), Vector2(-2, 4)
	])
	modulate = Color.WHITE


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
	# Ignore own hurtbox / friendly fire by source ownership when possible.
	if source != null and area.get_parent() == source:
		return
	var hurtbox := area as HurtboxComponent
	hurtbox.receive_hit(attack_data, source)
	hit_landed.emit(hurtbox)
	HitStop.punch(0.2, 0.03)
	queue_free()


func _on_body_entered(body: Node2D) -> void:
	# Don't die on the shooter collision capsule if we overlap at spawn.
	if source != null and body == source:
		return
	queue_free()
