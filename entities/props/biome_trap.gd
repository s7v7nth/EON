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


func _ready() -> void:
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = 2 # player
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_ensure_visual()


func configure(color: Color, dmg: float, status: StringName, buildup: float) -> void:
	trap_color = color
	damage_per_tick = dmg
	status_id = status
	status_buildup = buildup
	_ensure_visual()


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


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		_player = body as Player


func _on_body_exited(body: Node2D) -> void:
	if body == _player:
		_player = null


func _ensure_visual() -> void:
	var visual := get_node_or_null("Visual") as Polygon2D
	if visual == null:
		visual = Polygon2D.new()
		visual.name = "Visual"
		add_child(visual)
	visual.color = trap_color
	visual.polygon = PackedVector2Array([
		Vector2(-22, -14), Vector2(22, -14), Vector2(22, 14), Vector2(-22, 14)
	])
	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		shape_node = CollisionShape2D.new()
		shape_node.name = "CollisionShape2D"
		var rect := RectangleShape2D.new()
		rect.size = Vector2(44, 28)
		shape_node.shape = rect
		add_child(shape_node)
