class_name StylizedBodyVisual
extends Node2D
## Drawn cyber-neon body with idle/walk cycles. Duck-types Polygon2D API for CombatVisual.

enum BodyStyle {
	PLAYER,
	NANO,
	TRAIN,
	NEURO,
	SAVAGE,
	ANDROID,
	CYBORG,
	BEAST,
}

## Duck-typed for CombatVisualComponent (color / polygon / scale / modulate).
var color: Color = Color(0.55, 0.58, 0.62, 1.0):
	set(value):
		color = value
		queue_redraw()

var polygon: PackedVector2Array = PackedVector2Array():
	set(value):
		polygon = value
		queue_redraw()

@export var body_style: BodyStyle = BodyStyle.PLAYER:
	set(value):
		body_style = value
		queue_redraw()

var _phase: float = 0.0
var _walk_amount: float = 0.0
var _facing: float = 1.0
var _combat_locked: bool = false


func _ready() -> void:
	z_index = 0
	queue_redraw()


func set_body_style_name(style_name: StringName) -> void:
	match String(style_name):
		"nano", "nanomachines":
			body_style = BodyStyle.NANO
		"train", "electro_train":
			body_style = BodyStyle.TRAIN
		"neuro", "neuro_hacker":
			body_style = BodyStyle.NEURO
		"savage":
			body_style = BodyStyle.SAVAGE
		"android":
			body_style = BodyStyle.ANDROID
		"cyborg":
			body_style = BodyStyle.CYBORG
		"beast", "bio_mutant", "robo_beast":
			body_style = BodyStyle.BEAST
		_:
			body_style = BodyStyle.PLAYER


func set_combat_pose_active(active: bool) -> void:
	_combat_locked = active


func _process(delta: float) -> void:
	var speed := 0.0
	var parent_body := get_parent() as CharacterBody2D
	if parent_body:
		speed = parent_body.velocity.length()
		if absf(parent_body.velocity.x) > 8.0:
			_facing = signf(parent_body.velocity.x)
	var target_walk := clampf(speed / 180.0, 0.0, 1.0)
	_walk_amount = lerpf(_walk_amount, target_walk, 1.0 - exp(-12.0 * delta))
	var rate := lerpf(2.2, 9.0, _walk_amount)
	_phase += delta * rate
	queue_redraw()


func _draw() -> void:
	var bob := sin(_phase * TAU) * (1.2 + _walk_amount * 1.5)
	if _combat_locked:
		bob *= 0.25
	var lean := _facing * _walk_amount * 3.0
	var accent := color.lightened(0.35)
	var shade := color.darkened(0.28)
	var outline := Color(0.05, 0.07, 0.1, 0.9)

	# Ground contact shadow
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(-11, 2), Vector2(11, 2), Vector2(8, 6), Vector2(-8, 6)
		]),
		Color(0, 0, 0, 0.28)
	)

	var leg_amp := 5.0 * _walk_amount
	var leg_l := sin(_phase * TAU) * leg_amp
	var leg_r := sin(_phase * TAU + PI) * leg_amp
	_draw_leg(Vector2(-5 + lean * 0.2, -2 + bob * 0.15), leg_l, shade, outline)
	_draw_leg(Vector2(5 + lean * 0.2, -2 + bob * 0.15), leg_r, shade, outline)

	var torso_y := -8.0 + bob
	match body_style:
		BodyStyle.BEAST:
			_draw_beast(torso_y, lean, accent, shade, outline)
		BodyStyle.ANDROID:
			_draw_android(torso_y, lean, accent, shade, outline)
		BodyStyle.CYBORG:
			_draw_cyborg(torso_y, lean, accent, shade, outline)
		BodyStyle.SAVAGE:
			_draw_savage(torso_y, lean, accent, shade, outline)
		BodyStyle.TRAIN:
			_draw_train(torso_y, lean, accent, shade, outline)
		BodyStyle.NANO:
			_draw_nano(torso_y, lean, accent, shade, outline)
		BodyStyle.NEURO:
			_draw_neuro(torso_y, lean, accent, shade, outline)
		_:
			_draw_player(torso_y, lean, accent, shade, outline)


func _draw_leg(origin: Vector2, swing: float, fill: Color, outline: Color) -> void:
	var foot := origin + Vector2(swing * 0.65, 2.0 + absf(swing) * 0.15)
	var poly := PackedVector2Array([
		origin + Vector2(-3.5, -10),
		origin + Vector2(3.5, -10),
		foot + Vector2(3.2, 0),
		foot + Vector2(-3.2, 0),
	])
	draw_colored_polygon(poly, fill)
	draw_polyline(poly + PackedVector2Array([poly[0]]), outline, 1.2, true)


func _draw_player(torso_y: float, lean: float, accent: Color, shade: Color, outline: Color) -> void:
	var torso := PackedVector2Array([
		Vector2(-10 + lean, torso_y),
		Vector2(10 + lean, torso_y),
		Vector2(12 + lean * 0.6, torso_y - 22),
		Vector2(7 + lean * 0.4, torso_y - 34),
		Vector2(-7 + lean * 0.4, torso_y - 34),
		Vector2(-12 + lean * 0.6, torso_y - 22),
	])
	draw_colored_polygon(torso, color)
	draw_polyline(torso + PackedVector2Array([torso[0]]), outline, 1.4, true)
	_draw_head(Vector2(lean * 0.5, torso_y - 40), 8.5, accent, shade, outline, true)
	# Chest plate neon
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(-4 + lean, torso_y - 10),
			Vector2(4 + lean, torso_y - 10),
			Vector2(3 + lean, torso_y - 20),
			Vector2(-3 + lean, torso_y - 20),
		]),
		Color(accent.r, accent.g, accent.b, 0.55)
	)


func _draw_nano(torso_y: float, lean: float, accent: Color, shade: Color, outline: Color) -> void:
	var torso := PackedVector2Array([
		Vector2(-11 + lean, torso_y),
		Vector2(11 + lean, torso_y),
		Vector2(15 + lean * 0.5, torso_y - 18),
		Vector2(9 + lean * 0.3, torso_y - 36),
		Vector2(-8 + lean * 0.3, torso_y - 38),
		Vector2(-15 + lean * 0.5, torso_y - 20),
	])
	draw_colored_polygon(torso, color)
	draw_polyline(torso + PackedVector2Array([torso[0]]), outline, 1.3, true)
	_draw_head(Vector2(lean * 0.4, torso_y - 42), 8.0, accent, shade, outline, true)
	# Swarm motes
	for i in 3:
		var a := _phase * TAU + float(i) * 2.1
		var p := Vector2(cos(a) * 14.0 + lean, torso_y - 18.0 + sin(a * 1.3) * 6.0)
		draw_circle(p, 2.2, Color(accent.r, accent.g, accent.b, 0.65))


func _draw_train(torso_y: float, lean: float, accent: Color, shade: Color, outline: Color) -> void:
	var torso := PackedVector2Array([
		Vector2(-9 + lean, torso_y),
		Vector2(11 + lean, torso_y),
		Vector2(16 + lean * 0.4, torso_y - 12),
		Vector2(12 + lean * 0.3, torso_y - 36),
		Vector2(-7 + lean * 0.3, torso_y - 34),
		Vector2(-14 + lean * 0.4, torso_y - 14),
	])
	draw_colored_polygon(torso, color)
	draw_polyline(torso + PackedVector2Array([torso[0]]), outline, 1.4, true)
	_draw_head(Vector2(2 + lean * 0.4, torso_y - 40), 8.0, accent, shade, outline, true)
	# Rail glow stripe
	draw_line(
		Vector2(-6 + lean, torso_y - 8),
		Vector2(10 + lean, torso_y - 30),
		Color(accent.r, accent.g, accent.b, 0.85),
		2.5
	)


func _draw_neuro(torso_y: float, lean: float, accent: Color, shade: Color, outline: Color) -> void:
	_draw_player(torso_y, lean, accent, shade, outline)
	# Antenna / neural fin
	var tip := Vector2(lean * 0.3, torso_y - 54)
	draw_line(Vector2(lean * 0.3, torso_y - 46), tip, accent, 1.8)
	draw_circle(tip, 2.4, Color(accent.r, accent.g, accent.b, 0.9))


func _draw_savage(torso_y: float, lean: float, accent: Color, shade: Color, outline: Color) -> void:
	var torso := PackedVector2Array([
		Vector2(-12 + lean, torso_y),
		Vector2(12 + lean, torso_y),
		Vector2(14 + lean * 0.4, torso_y - 28),
		Vector2(0 + lean * 0.2, torso_y - 40),
		Vector2(-14 + lean * 0.4, torso_y - 28),
	])
	draw_colored_polygon(torso, color)
	draw_polyline(torso + PackedVector2Array([torso[0]]), outline, 1.4, true)
	_draw_head(Vector2(lean * 0.3, torso_y - 42), 9.0, accent, shade, outline, false)
	# Jaw spikes
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(-6 + lean, torso_y - 36),
			Vector2(-1 + lean, torso_y - 36),
			Vector2(-4 + lean, torso_y - 30),
		]),
		shade
	)


func _draw_android(torso_y: float, lean: float, accent: Color, shade: Color, outline: Color) -> void:
	var torso := PackedVector2Array([
		Vector2(-10 + lean, torso_y),
		Vector2(10 + lean, torso_y),
		Vector2(10 + lean * 0.5, torso_y - 26),
		Vector2(5 + lean * 0.3, torso_y - 38),
		Vector2(-5 + lean * 0.3, torso_y - 38),
		Vector2(-10 + lean * 0.5, torso_y - 26),
	])
	draw_colored_polygon(torso, color)
	draw_polyline(torso + PackedVector2Array([torso[0]]), outline, 1.3, true)
	_draw_head(Vector2(lean * 0.3, torso_y - 44), 7.5, accent, shade, outline, true)
	# Optic bar
	draw_line(
		Vector2(-5 + lean * 0.3, torso_y - 44),
		Vector2(5 + lean * 0.3, torso_y - 44),
		Color(accent.r, accent.g, accent.b, 0.95),
		2.0
	)


func _draw_cyborg(torso_y: float, lean: float, accent: Color, shade: Color, outline: Color) -> void:
	var torso := PackedVector2Array([
		Vector2(-12 + lean, torso_y),
		Vector2(12 + lean, torso_y),
		Vector2(14 + lean * 0.5, torso_y - 20),
		Vector2(8 + lean * 0.3, torso_y - 36),
		Vector2(-5 + lean * 0.3, torso_y - 38),
		Vector2(-14 + lean * 0.5, torso_y - 22),
	])
	draw_colored_polygon(torso, color)
	draw_polyline(torso + PackedVector2Array([torso[0]]), outline, 1.3, true)
	_draw_head(Vector2(lean * 0.35, torso_y - 42), 8.0, accent, shade, outline, true)
	# Shoulder plate
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(6 + lean, torso_y - 18),
			Vector2(16 + lean, torso_y - 16),
			Vector2(14 + lean, torso_y - 26),
			Vector2(7 + lean, torso_y - 28),
		]),
		shade.lightened(0.1)
	)


func _draw_beast(torso_y: float, lean: float, accent: Color, shade: Color, outline: Color) -> void:
	var torso := PackedVector2Array([
		Vector2(-15 + lean, torso_y + 2),
		Vector2(16 + lean, torso_y + 2),
		Vector2(18 + lean * 0.4, torso_y - 16),
		Vector2(6 + lean * 0.2, torso_y - 30),
		Vector2(-6 + lean * 0.2, torso_y - 32),
		Vector2(-16 + lean * 0.4, torso_y - 18),
	])
	draw_colored_polygon(torso, color)
	draw_polyline(torso + PackedVector2Array([torso[0]]), outline, 1.4, true)
	_draw_head(Vector2(4 + lean * 0.4, torso_y - 34), 9.5, accent, shade, outline, false)
	# Horn
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(2 + lean, torso_y - 40),
			Vector2(8 + lean, torso_y - 40),
			Vector2(10 + lean, torso_y - 50),
		]),
		shade
	)


func _draw_head(center: Vector2, radius: float, accent: Color, shade: Color, outline: Color, visor: bool) -> void:
	var pts: PackedVector2Array = []
	var steps := 10
	for i in steps:
		var a := -PI * 0.15 + PI * 1.3 * float(i) / float(steps - 1)
		pts.append(center + Vector2(cos(a), sin(a) * 1.05) * radius)
	# Close bottom jaw line
	pts.append(center + Vector2(-radius * 0.55, radius * 0.35))
	pts.append(center + Vector2(radius * 0.55, radius * 0.35))
	draw_colored_polygon(pts, shade.lightened(0.08))
	draw_polyline(pts + PackedVector2Array([pts[0]]), outline, 1.2, true)
	if visor:
		draw_colored_polygon(
			PackedVector2Array([
				center + Vector2(-radius * 0.7, -1),
				center + Vector2(radius * 0.75, -1),
				center + Vector2(radius * 0.65, 3.5),
				center + Vector2(-radius * 0.6, 3.5),
			]),
			Color(accent.r, accent.g, accent.b, 0.9)
		)
	else:
		draw_circle(center + Vector2(-radius * 0.25, 0), 1.8, accent)
		draw_circle(center + Vector2(radius * 0.3, 0), 1.8, accent)
