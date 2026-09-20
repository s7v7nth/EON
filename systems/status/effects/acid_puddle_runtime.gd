extends Area2D
## Short-lived acid zone spawned by EffectArmorShred on death.

var _damage: float = 6.0
var _duration: float = 2.5
var _radius: float = 56.0
var _tick: float = 0.0


func setup(damage: float, duration: float, radius: float = 56.0) -> void:
	_damage = damage
	_duration = duration
	_radius = radius


func _ready() -> void:
	z_index = -1
	var spr := Sprite2D.new()
	spr.name = "Splat"
	spr.centered = true
	spr.texture = ArtBank.tex("res://assets/kenney/splat/splat05.png")
	if spr.texture == null:
		spr.texture = ArtBank.tex("res://assets/kenney/splat/splat03.png")
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if spr.texture:
		ArtBank.fit_height(spr, 72.0, false)
	spr.modulate = Color(0.45, 0.95, 0.28, 0.82)
	spr.rotation = randf() * TAU
	add_child(spr)


func _process(delta: float) -> void:
	_duration -= delta
	_tick += delta
	if _tick >= 0.35:
		_tick = 0.0
		_pulse()
	if _duration <= 0.0:
		queue_free()


func _pulse() -> void:
	var parent := get_parent()
	if parent == null:
		return
	for child in parent.get_children():
		if child == self or child is not Node2D:
			continue
		if child is Player or child.is_in_group("player") or child.is_in_group("ally_drone"):
			continue
		if not child.is_in_group("enemies"):
			continue
		if child.get("health") == null and not child.has_method("apply_knockback"):
			continue
		if global_position.distance_to((child as Node2D).global_position) > _radius:
			continue
		var health = child.get("health")
		if health and health.has_method("take_damage"):
			health.call("take_damage", _damage)
