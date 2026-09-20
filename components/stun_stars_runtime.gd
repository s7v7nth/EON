extends Node2D
## Temporary Tom & Jerry stun stars. Self-frees after duration.

var duration: float = 1.0
var _elapsed: float = 0.0
var _stars: Array[Polygon2D] = []


func _ready() -> void:
	z_index = 25
	for i in 5:
		var star := Polygon2D.new()
		star.polygon = _star_poly(5.5)
		star.color = Color(1.0, 0.92, 0.25, 1.0)
		add_child(star)
		_stars.append(star)


func _process(delta: float) -> void:
	# Wall-clock-ish: don't stretch forever under hitstop.
	var step: float = delta / maxf(Engine.time_scale, 0.05)
	_elapsed += step
	var orbit := 16.0
	for i in _stars.size():
		var star: Polygon2D = _stars[i]
		var a: float = _elapsed * 6.0 + TAU * float(i) / float(_stars.size())
		star.position = Vector2(cos(a), sin(a) * 0.55) * orbit
		star.rotation = a
	if _elapsed >= duration:
		queue_free()


func _star_poly(radius: float) -> PackedVector2Array:
	var pts: PackedVector2Array = []
	for i in 10:
		var a: float = -PI * 0.5 + TAU * float(i) / 10.0
		var r: float = radius if i % 2 == 0 else radius * 0.4
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts
