class_name BiomeTrap
extends Area2D
## Floor hazard — Kenney splat only, no greybox polygons.

@export var damage_per_tick: float = 4.0
@export var tick_interval: float = 0.45
@export var status_id: StringName = &""
@export var status_buildup: float = 18.0
@export var trap_color: Color = Color(0.9, 0.35, 0.2, 0.55)

var _accum: float = 0.0
var _player: Player
var _pulse: Tween
var _splat: Sprite2D


func _ready() -> void:
	z_index = -1
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = 2 # player
	add_to_group("biome_traps")
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
	var fill := get_node_or_null("Fill") as CanvasItem
	if fill:
		fill.visible = false
	var rim := get_node_or_null("Rim") as CanvasItem
	if rim:
		rim.visible = false
	var legacy := get_node_or_null("Visual") as CanvasItem
	if legacy:
		legacy.visible = false

	_splat = get_node_or_null("Splat") as Sprite2D
	if _splat == null:
		_splat = Sprite2D.new()
		_splat.name = "Splat"
		_splat.centered = true
		_splat.z_index = 2
		_splat.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(_splat)
	var splat_path := "res://assets/kenney/splat/splat03.png"
	if trap_color.g > trap_color.r:
		splat_path = "res://assets/kenney/splat/splat05.png"
	elif trap_color.b > trap_color.r:
		splat_path = "res://assets/kenney/splat/splat01.png"
	_splat.texture = ArtBank.tex(splat_path)
	if _splat.texture == null:
		_splat.texture = ArtBank.particle("smoke_06")
	if _splat.texture:
		ArtBank.fit_height(_splat, 68.0, false)
		_splat.modulate = Color(trap_color.r, trap_color.g, trap_color.b, 0.88)
		_splat.rotation = 0.35
		_splat.visible = true

	var shape_node := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape_node == null:
		shape_node = CollisionShape2D.new()
		shape_node.name = "CollisionShape2D"
		add_child(shape_node)
	var rect := shape_node.shape as RectangleShape2D
	if rect == null:
		rect = RectangleShape2D.new()
		shape_node.shape = rect
	rect.size = Vector2(48, 30)


func _start_pulse() -> void:
	if _splat == null:
		return
	if _pulse:
		_pulse.kill()
	_splat.scale = _splat.scale
	var base := _splat.scale
	_pulse = create_tween().set_loops()
	_pulse.tween_property(_splat, "scale", base * 1.08, 0.7).set_trans(Tween.TRANS_SINE)
	_pulse.parallel().tween_property(_splat, "modulate:a", 0.98, 0.7)
	_pulse.tween_property(_splat, "scale", base * 0.94, 0.7).set_trans(Tween.TRANS_SINE)
	_pulse.parallel().tween_property(_splat, "modulate:a", 0.72, 0.7)


func _flash_hit() -> void:
	if _splat == null:
		return
	var base := _splat.modulate
	var t := create_tween()
	t.tween_property(_splat, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.05)
	t.tween_property(_splat, "modulate", base, 0.14)
