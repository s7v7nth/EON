class_name RoomFootprint
extends RefCounted
## Irregular walkable island: polygon + cardinal wall segments for offset doors.

var id: String = "box"
var local_poly: PackedVector2Array = PackedVector2Array()
## Vector2i dir → PackedVector2Array[2] wall endpoints (local).
var edges: Dictionary = {}


func door_local(dir: Vector2i, t: float) -> Vector2:
	var pair: PackedVector2Array = edges.get(dir, PackedVector2Array())
	if pair.size() < 2:
		return Vector2.ZERO
	var u := clampf(t, 0.12, 0.88)
	return pair[0].lerp(pair[1], u)


func world_poly(origin: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in local_poly:
		out.append(p + origin)
	return out


func aabb(origin: Vector2 = Vector2.ZERO) -> Rect2:
	if local_poly.is_empty():
		return Rect2(origin, Vector2.ONE)
	var min_p := local_poly[0] + origin
	var max_p := min_p
	for p in local_poly:
		var w := p + origin
		min_p.x = minf(min_p.x, w.x)
		min_p.y = minf(min_p.y, w.y)
		max_p.x = maxf(max_p.x, w.x)
		max_p.y = maxf(max_p.y, w.y)
	return Rect2(min_p, max_p - min_p)


static func make(shape_id: String) -> RoomFootprint:
	match shape_id:
		"l_wing":
			return _l_wing()
		"t_stub":
			return _t_stub()
		"wedge":
			return _wedge()
		"notch":
			return _notch()
		"octa":
			return _octa()
		"skew":
			return _skew()
		_:
			return _notch()


static func pool() -> PackedStringArray:
	return PackedStringArray(["l_wing", "t_stub", "wedge", "notch", "octa", "skew"])


static func _edge(a: Vector2, b: Vector2) -> PackedVector2Array:
	return PackedVector2Array([a, b])


static func _l_wing() -> RoomFootprint:
	var fp := RoomFootprint.new()
	fp.id = "l_wing"
	fp.local_poly = PackedVector2Array([
		Vector2(-620, -360), Vector2(520, -360), Vector2(520, -40),
		Vector2(-80, -40), Vector2(-80, 420), Vector2(-620, 420)
	])
	fp.edges[Vector2i(0, -1)] = _edge(Vector2(-580, -360), Vector2(480, -360))
	fp.edges[Vector2i(1, 0)] = _edge(Vector2(520, -320), Vector2(520, -80))
	fp.edges[Vector2i(0, 1)] = _edge(Vector2(-580, 420), Vector2(-120, 420))
	fp.edges[Vector2i(-1, 0)] = _edge(Vector2(-620, -320), Vector2(-620, 380))
	return fp


static func _t_stub() -> RoomFootprint:
	var fp := RoomFootprint.new()
	fp.id = "t_stub"
	fp.local_poly = PackedVector2Array([
		Vector2(-700, -320), Vector2(700, -320), Vector2(700, 40),
		Vector2(180, 40), Vector2(180, 460), Vector2(-180, 460),
		Vector2(-180, 40), Vector2(-700, 40)
	])
	fp.edges[Vector2i(0, -1)] = _edge(Vector2(-640, -320), Vector2(640, -320))
	fp.edges[Vector2i(1, 0)] = _edge(Vector2(700, -280), Vector2(700, 0))
	fp.edges[Vector2i(0, 1)] = _edge(Vector2(-140, 460), Vector2(140, 460))
	fp.edges[Vector2i(-1, 0)] = _edge(Vector2(-700, -280), Vector2(-700, 0))
	return fp


static func _wedge() -> RoomFootprint:
	var fp := RoomFootprint.new()
	fp.id = "wedge"
	fp.local_poly = PackedVector2Array([
		Vector2(-420, -380), Vector2(380, -380), Vector2(720, 420),
		Vector2(-680, 420)
	])
	fp.edges[Vector2i(0, -1)] = _edge(Vector2(-360, -380), Vector2(320, -380))
	fp.edges[Vector2i(1, 0)] = _edge(Vector2(560, -80), Vector2(700, 360))
	fp.edges[Vector2i(0, 1)] = _edge(Vector2(-620, 420), Vector2(660, 420))
	fp.edges[Vector2i(-1, 0)] = _edge(Vector2(-660, 360), Vector2(-500, -80))
	return fp


static func _notch() -> RoomFootprint:
	var fp := RoomFootprint.new()
	fp.id = "notch"
	fp.local_poly = PackedVector2Array([
		Vector2(-640, -400), Vector2(640, -400), Vector2(640, 80),
		Vector2(220, 80), Vector2(220, 400), Vector2(-640, 400)
	])
	fp.edges[Vector2i(0, -1)] = _edge(Vector2(-580, -400), Vector2(580, -400))
	fp.edges[Vector2i(1, 0)] = _edge(Vector2(640, -360), Vector2(640, 40))
	fp.edges[Vector2i(0, 1)] = _edge(Vector2(-580, 400), Vector2(180, 400))
	fp.edges[Vector2i(-1, 0)] = _edge(Vector2(-640, -360), Vector2(-640, 360))
	return fp


static func _octa() -> RoomFootprint:
	var fp := RoomFootprint.new()
	fp.id = "octa"
	fp.local_poly = PackedVector2Array([
		Vector2(-280, -420), Vector2(260, -420), Vector2(620, -140),
		Vector2(620, 180), Vector2(240, 440), Vector2(-260, 440),
		Vector2(-620, 160), Vector2(-620, -160)
	])
	fp.edges[Vector2i(0, -1)] = _edge(Vector2(-220, -420), Vector2(200, -420))
	fp.edges[Vector2i(1, 0)] = _edge(Vector2(620, -100), Vector2(620, 140))
	fp.edges[Vector2i(0, 1)] = _edge(Vector2(-200, 440), Vector2(180, 440))
	fp.edges[Vector2i(-1, 0)] = _edge(Vector2(-620, -120), Vector2(-620, 120))
	return fp


static func _skew() -> RoomFootprint:
	var fp := RoomFootprint.new()
	fp.id = "skew"
	fp.local_poly = PackedVector2Array([
		Vector2(-520, -360), Vector2(480, -280), Vector2(640, 360),
		Vector2(-640, 300)
	])
	fp.edges[Vector2i(0, -1)] = _edge(Vector2(-460, -350), Vector2(420, -286))
	fp.edges[Vector2i(1, 0)] = _edge(Vector2(520, -180), Vector2(620, 280))
	fp.edges[Vector2i(0, 1)] = _edge(Vector2(-580, 304), Vector2(580, 352))
	fp.edges[Vector2i(-1, 0)] = _edge(Vector2(-600, 240), Vector2(-540, -280))
	return fp
