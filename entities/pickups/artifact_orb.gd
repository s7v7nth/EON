class_name ArtifactOrb
extends Area2D
## Walk-over artifact. Elites drop a random rare; shops preset a named boon.

var preset_upgrade: UpgradeData
var exclusive_group: Array = []
var _claimed: bool = false
var _pulse: float = 0.0
var _visual: Polygon2D
var _label: Label
var _light: PointLight2D


static func spawn_at(parent: Node, local_pos: Vector2, preset: UpgradeData = null) -> ArtifactOrb:
	var orb := ArtifactOrb.new()
	orb.preset_upgrade = preset
	parent.add_child(orb)
	orb.position = local_pos
	return orb


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = false
	z_index = 8
	body_entered.connect(_on_body)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 26.0
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
	_label.position = Vector2(-48, -44)
	_label.add_theme_font_size_override("font_size", 12)
	_label.add_theme_color_override("font_color", Color(1, 0.9, 0.45))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_label.add_theme_constant_override("outline_size", 4)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.custom_minimum_size = Vector2(96, 18)
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
	_apply_preset_look()


func _apply_preset_look() -> void:
	if preset_upgrade == null or _visual == null:
		return
	var tint := UpgradeData.rarity_color(preset_upgrade.rarity)
	_visual.color = Color(tint.r, tint.g, tint.b, 0.95)
	if _light:
		_light.color = tint
	if _label:
		_label.text = preset_upgrade.display_name
		_label.add_theme_color_override("font_color", tint.lightened(0.15))
		_label.position = Vector2(-70, -46)
		_label.custom_minimum_size = Vector2(140, 18)


func _process(delta: float) -> void:
	_pulse += delta * 4.0
	if _visual:
		_visual.scale = Vector2.ONE * (1.0 + sin(_pulse) * 0.08)
		_visual.rotation += delta * 1.2


func _on_body(body: Node2D) -> void:
	if body is Player:
		try_claim(body as Player)


func try_claim(player: Player) -> bool:
	if _claimed or player == null:
		return false
	var pick := preset_upgrade
	if pick == null:
		pick = _roll_drop()
	if pick == null:
		queue_free()
		return false
	if not RunState.grant_upgrade(pick):
		return false
	_claimed = true
	RunState.apply_to_player(player)
	CameraFx.add_trauma(0.18)
	CameraFx.flash(UpgradeData.house_color(pick.house), 0.12)
	if _label:
		_label.text = pick.display_name
	for other in exclusive_group:
		if other == self or not is_instance_valid(other):
			continue
		(other as Node).queue_free()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.45)
	tw.tween_callback(queue_free)
	return true


func _roll_drop() -> UpgradeData:
	var pool := RunState.get_reward_upgrades()
	if pool.is_empty():
		return null
	var rares: Array[UpgradeData] = []
	for item in pool:
		if item.rarity != UpgradeData.Rarity.COMMON:
			rares.append(item)
	if rares.is_empty():
		return pool[randi() % pool.size()]
	return rares[randi() % rares.size()]
