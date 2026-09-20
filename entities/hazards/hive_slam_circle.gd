extends Node2D
## Dark floor circle for The Hive slam. Leave it before the mass comes down.

var radius: float = 128.0
var locked: bool = false
var _follow: Node2D
var _fill: Polygon2D
var _rim: Line2D


func setup(circle_radius: float) -> void:
	radius = maxf(circle_radius, 48.0)
	z_index = -8
	z_as_relative = false
	_ensure_visuals()
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.14)
	var pulse := create_tween().set_loops()
	pulse.tween_property(_rim, "width", 8.0, 0.22)
	pulse.tween_property(_rim, "width", 5.5, 0.22)


func follow(node: Node2D) -> void:
	_follow = node
	locked = false
	_snap_to_follow()


func lock_here() -> void:
	locked = true
	_follow = null


func strike() -> void:
	if _fill:
		_fill.color = Color(0.04, 0.03, 0.02, 0.92)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.08, 0.78), 0.08)
	tw.tween_property(self, "modulate:a", 0.0, 0.28)
	tw.tween_callback(queue_free)


func _process(_delta: float) -> void:
	if locked:
		return
	_snap_to_follow()


func _snap_to_follow() -> void:
	if _follow == null or not is_instance_valid(_follow):
		return
	global_position = _follow.global_position


func _ensure_visuals() -> void:
	_fill = Polygon2D.new()
	_fill.name = "Fill"
	_fill.polygon = _iso_disk(radius)
	# Muddy stain on blue-grey night tiles — black-on-black does not read.
	_fill.color = Color(0.16, 0.1, 0.04, 0.82)
	add_child(_fill)
	_rim = Line2D.new()
	_rim.name = "Rim"
	_rim.width = 6.5
	_rim.default_color = Color(0.92, 0.38, 0.12, 1.0)
	_rim.closed = true
	_rim.points = _iso_disk(radius)
	add_child(_rim)
	var inner := Line2D.new()
	inner.name = "OliveRim"
	inner.width = 3.0
	inner.default_color = Color(0.58, 0.78, 0.18, 0.98)
	inner.closed = true
	inner.points = _iso_disk(radius * 0.78)
	add_child(inner)
	scale = Vector2(1.0, 0.62)


func _iso_disk(r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := 22
	for i in n:
		var a := TAU * float(i) / float(n)
		pts.append(Vector2(cos(a) * r, sin(a) * r * 0.55))
	return pts
