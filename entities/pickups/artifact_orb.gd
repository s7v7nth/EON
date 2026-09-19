class_name ArtifactOrb
extends Area2D
## Elite drop — walk over to instantly claim a random unowned boon.

var _claimed: bool = false
var _pulse: float = 0.0
var _visual: Polygon2D
var _label: Label
var _light: PointLight2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = false
	z_index = 8
	body_entered.connect(_on_body)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 22.0
	shape.shape = circle
	add_child(shape)
	_visual = Polygon2D.new()
	_visual.polygon = PackedVector2Array([
		Vector2(0, -18), Vector2(14, 0), Vector2(0, 18), Vector2(-14, 0)
	])
	_visual.color = Color(1.0, 0.82, 0.28, 0.95)
	add_child(_visual)
	_label = Label.new()
	_label.text = "ARTIFACT"
	_label.position = Vector2(-36, -40)
	_label.add_theme_font_size_override("font_size", 11)
	_label.add_theme_color_override("font_color", Color(1, 0.9, 0.45))
	add_child(_label)
	_light = PointLight2D.new()
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(1, 0.85, 0.4, 1), Color(1, 0.85, 0.4, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 128
	tex.height = 128
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	_light.texture = tex
	_light.energy = 1.1
	_light.texture_scale = 1.4
	_light.color = Color(1.0, 0.8, 0.35)
	add_child(_light)


func _process(delta: float) -> void:
	_pulse += delta * 4.0
	if _visual:
		_visual.scale = Vector2.ONE * (1.0 + sin(_pulse) * 0.08)
		_visual.rotation += delta * 1.2


func _on_body(body: Node2D) -> void:
	if _claimed or body is not Player:
		return
	var pool := RunState.get_reward_upgrades()
	if pool.is_empty():
		queue_free()
		return
	# Prefer rare-or-better from elites.
	var rares: Array[UpgradeData] = []
	for item in pool:
		if item.rarity != UpgradeData.Rarity.COMMON:
			rares.append(item)
	var pick := rares[randi() % rares.size()] if not rares.is_empty() else pool[randi() % pool.size()]
	if not RunState.grant_upgrade(pick):
		return
	_claimed = true
	RunState.apply_to_player(body as Player)
	CameraFx.add_trauma(0.18)
	CameraFx.flash(UpgradeData.house_color(pick.house), 0.12)
	_label.text = pick.display_name
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.45)
	tw.tween_callback(queue_free)
