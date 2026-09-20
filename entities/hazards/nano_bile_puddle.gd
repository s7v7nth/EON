extends Area2D
## Lasting olive spit. Walk around it. Standing in last spit eats HP.

var _damage: float = 5.0
var _duration: float = 6.0
var _radius: float = 46.0
var _tick: float = 0.0
var _player: Player


func setup(damage: float, duration: float, radius: float = 46.0) -> void:
	_damage = damage
	_duration = duration
	_radius = radius


func _ready() -> void:
	z_index = -6
	z_as_relative = false
	monitoring = true
	monitorable = false
	collision_layer = 0
	collision_mask = 2
	add_to_group("nano_bile")
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)
	_build_look()
	call_deferred("_scan")


func _process(delta: float) -> void:
	_duration -= delta
	_tick += delta
	if _player != null and _tick >= 0.4:
		_tick = 0.0
		_eat()
	if _duration <= 0.0:
		queue_free()


func _eat() -> void:
	if _player == null or not is_instance_valid(_player):
		_player = null
		return
	if _player.hurtbox and _player.hurtbox.is_invincible():
		return
	var dmg := _damage
	if _player.energy:
		dmg = _player.energy.absorb_damage(_damage)
	if dmg > 0.0 and _player.health:
		_player.health.take_damage(dmg)
	if _player.status:
		_player.status.add_buildup(StatusComponent.STATUS_ACID, 10.0, 1.6)


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		_player = body as Player
		_tick = 0.35


func _on_body_exited(body: Node2D) -> void:
	if body == _player:
		_player = null


func _scan() -> void:
	for body in get_overlapping_bodies():
		_on_body_entered(body as Node2D)


func _build_look() -> void:
	# Distinct from the room's neon-green drain stains: olive-rust slurry + rust rim.
	var fill := Polygon2D.new()
	fill.name = "Slurry"
	fill.polygon = _iso_disk(_radius)
	fill.color = Color(0.28, 0.32, 0.08, 0.88)
	add_child(fill)
	var rim := Line2D.new()
	rim.name = "RustRim"
	rim.width = 4.0
	rim.default_color = Color(0.62, 0.28, 0.1, 0.95)
	rim.closed = true
	rim.points = _iso_disk(_radius)
	add_child(rim)
	var splat := Sprite2D.new()
	splat.name = "Splat"
	splat.centered = true
	splat.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	splat.texture = ArtBank.illustrated("floor_toxic")
	if splat.texture == null:
		splat.texture = ArtBank.tex("res://assets/kenney/splat/splat05.png")
	if splat.texture:
		ArtBank.fit_height(splat, maxf(_radius * 1.35, 40.0), false)
	splat.modulate = Color(0.32, 0.36, 0.1, 0.7)
	splat.rotation = randf() * TAU
	add_child(splat)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = _radius
	shape.shape = circle
	add_child(shape)
	var pulse := create_tween().set_loops()
	pulse.tween_property(fill, "color:a", 0.98, 0.45)
	pulse.tween_property(fill, "color:a", 0.72, 0.45)


func _iso_disk(r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := 18
	for i in n:
		var a := TAU * float(i) / float(n)
		pts.append(Vector2(cos(a) * r, sin(a) * r * 0.55))
	return pts
