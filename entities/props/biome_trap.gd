class_name BiomeTrap
extends Area2D
## Greybox biome hazard — ticks damage/status on the player while overlapping.

@export var damage_per_tick: float = 4.0
@export var tick_interval: float = 0.45
@export var status_id: StringName = &""
@export var status_buildup: float = 18.0
@export var trap_color: Color = Color(0.9, 0.35, 0.2, 0.55)

var _accum: float = 0.0
var _player: Player
var _pulse: Tween
var _fill: Polygon2D
var _rim: Polygon2D


func _ready() -> void:
	z_index = -1
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = 2 # player
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)
	_ensure_visual()
	_start_pulse()
	call_deferred("_scan_overlap")


func configure(color: Color, dmg: float, status: StringName, buildup: float) -> void:
	trap_color = color
	damage_per_tick = dmg
	status_id = status
	status_buildup = buildup
	_ensure_visual()
	_start_pulse()


func _physics_process(delta: float) -> void:
	if _player == null:
		return
	_accum += delta
	if _accum < tick_interval:
		return
	_accum = 0.0
	if _player.health:
		_player.health.take_damage(damage_per_tick)
	if status_id != StringName() and _player.status:
		_player.status.add_buildup(status_id, status_buildup, 2.0)
	_flash_hit()


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		_player = body as Player
		_accum = tick_interval # first tick soon after stepping in


func _on_body_exited(body: Node2D) -> void:
	if body == _player:
		_player = null


func _scan_overlap() -> void:
	for body in get_overlapping_bodies():
		_on_body_entered(body as Node2D)


func _ensure_visual() -> void:
	# Legacy solid rect from early greybox — replace with puddle fill + rim.
	var legacy := get_node_or_null("Visual") as Polygon2D
	if legacy and legacy.name == "Visual":
		legacy.name = "Fill"
	_fill = get_node_or_null("Fill") as Polygon2D
	if _fill == null:
		_fill = Polygon2D.new()
		_fill.name = "Fill"
		add_child(_fill)
	_rim = get_node_or_null("Rim") as Polygon2D
	if _rim == null:
		_rim = Polygon2D.new()
		_rim.name = "Rim"
		add_child(_rim)
		move_child(_rim, 0)

	var puddle := _puddle_poly()
	_fill.polygon = puddle
	_fill.color = Color(trap_color.r, trap_color.g, trap_color.b, clampf(trap_color.a, 0.35, 0.65))
	_fill.z_index = 0

	_rim.polygon = _ring_poly(puddle, 4.0)
	_rim.color = Color(trap_color.r, trap_color.g, trap_color.b, 0.9).lightened(0.25)
	_rim.z_index = 1

	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		shape_node = CollisionShape2D.new()
		shape_node.name = "CollisionShape2D"
		add_child(shape_node)
	var rect := shape_node.shape as RectangleShape2D
	if rect == null:
		rect = RectangleShape2D.new()
		shape_node.shape = rect
	rect.size = Vector2(52, 34)


func _start_pulse() -> void:
	if _fill == null:
		return
	if _pulse:
		_pulse.kill()
	_fill.scale = Vector2.ONE
	var base_a := _fill.color.a
	_pulse = create_tween().set_loops()
	_pulse.tween_property(_fill, "scale", Vector2(1.05, 1.03), 0.65).set_trans(Tween.TRANS_SINE)
	_pulse.parallel().tween_property(_fill, "color:a", minf(base_a + 0.12, 0.75), 0.65)
	_pulse.tween_property(_fill, "scale", Vector2(0.97, 0.98), 0.65).set_trans(Tween.TRANS_SINE)
	_pulse.parallel().tween_property(_fill, "color:a", base_a, 0.65)


func _flash_hit() -> void:
	if _fill == null:
		return
	var base := _fill.color
	var flash := Color(1.0, 1.0, 1.0, minf(base.a + 0.35, 0.95))
	var t := create_tween()
	t.tween_property(_fill, "color", flash, 0.05)
	t.tween_property(_fill, "color", base, 0.12)


func _puddle_poly() -> PackedVector2Array:
	## Irregular iso puddle — reads as a floor hazard, not a debug tile.
	return PackedVector2Array([
		Vector2(-8, -16),
		Vector2(10, -14),
		Vector2(24, -6),
		Vector2(26, 6),
		Vector2(14, 15),
		Vector2(-6, 16),
		Vector2(-22, 8),
		Vector2(-26, -2),
		Vector2(-18, -12),
	])


func _ring_poly(inner: PackedVector2Array, outset: float) -> PackedVector2Array:
	## Simple outward offset of the puddle silhouette for a bright rim.
	var out := PackedVector2Array()
	var center := Vector2.ZERO
	for p in inner:
		center += p
	center /= float(inner.size())
	for p in inner:
		var dir := (p - center).normalized()
		out.append(p + dir * outset)
	return out
