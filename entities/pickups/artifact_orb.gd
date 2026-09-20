class_name ArtifactOrb
extends Area2D
## Walk-over artifact. Elites drop a random rare; shops preset a named boon for gold.

var preset_upgrade: UpgradeData
var exclusive_group: Array = []
var price_gold: int = 0
var _claimed: bool = false
var _pulse: float = 0.0
var _sprite: Sprite2D
var _label: Label
var _price_label: Label
var _light: PointLight2D
var _deny_flash: float = 0.0


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
	circle.radius = 28.0
	shape.shape = circle
	add_child(shape)
	_sprite = Sprite2D.new()
	_sprite.texture = _pick_texture()
	_sprite.centered = true
	_sprite.scale = Vector2(0.85, 0.85)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_sprite)
	_label = Label.new()
	_label.text = "ARTIFACT"
	_label.position = Vector2(-70, -58)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.custom_minimum_size = Vector2(140, 18)
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_color", Color(1, 0.9, 0.45))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_label.add_theme_constant_override("outline_size", 4)
	var font := ArtBank.ui_font()
	if font:
		_label.add_theme_font_override("font", font)
	add_child(_label)
	_price_label = Label.new()
	_price_label.position = Vector2(-70, 22)
	_price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_price_label.custom_minimum_size = Vector2(140, 16)
	_price_label.add_theme_font_size_override("font_size", 12)
	_price_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_price_label.add_theme_constant_override("outline_size", 4)
	if font:
		_price_label.add_theme_font_override("font", font)
	add_child(_price_label)
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
	_refresh_price()


func _pick_texture() -> Texture2D:
	var tex := ArtBank.shooter("powerupYellow_star")
	if tex:
		return tex
	tex = ArtBank.icon("star")
	if tex:
		return tex
	return ArtBank.particle("star_08")


func _apply_preset_look() -> void:
	if preset_upgrade == null:
		return
	var tint := UpgradeData.rarity_color(preset_upgrade.rarity)
	if _sprite:
		match preset_upgrade.rarity:
			UpgradeData.Rarity.LEGENDARY:
				_sprite.texture = ArtBank.shooter("powerupRed_star")
			UpgradeData.Rarity.EPIC:
				_sprite.texture = ArtBank.shooter("powerupBlue_star")
			UpgradeData.Rarity.RARE:
				_sprite.texture = ArtBank.shooter("powerupGreen_star")
			_:
				_sprite.texture = ArtBank.shooter("powerupYellow_star")
		_sprite.modulate = Color.WHITE.lerp(tint, 0.25)
	if _light:
		_light.color = tint
	if _label:
		_label.text = preset_upgrade.display_name
		_label.add_theme_color_override("font_color", tint.lightened(0.15))


func _refresh_price() -> void:
	if _price_label == null:
		return
	if price_gold <= 0:
		_price_label.text = "FREE"
		_price_label.add_theme_color_override("font_color", Color(0.75, 0.9, 0.7))
		_price_label.visible = false
		return
	_price_label.visible = true
	_price_label.text = "%d G" % price_gold
	_price_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.32))


func _process(delta: float) -> void:
	_pulse += delta * 4.0
	if _sprite:
		_sprite.scale = Vector2.ONE * (0.85 + sin(_pulse) * 0.06)
		_sprite.rotation = sin(_pulse * 0.5) * 0.15
	if _deny_flash > 0.0:
		_deny_flash = maxf(0.0, _deny_flash - delta)
		modulate = Color(1.0, 0.45, 0.4, 1.0) if fmod(_deny_flash, 0.12) > 0.06 else Color.WHITE
		if _deny_flash <= 0.0:
			modulate = Color.WHITE


func _on_body(body: Node2D) -> void:
	if body is Player:
		call_deferred("try_claim", body)


func try_claim(player: Player) -> bool:
	if _claimed or player == null:
		return false
	var pick := preset_upgrade
	if pick == null:
		pick = _roll_drop()
	if pick == null:
		queue_free()
		return false
	if price_gold > 0 and not RunState.try_spend_gold(price_gold):
		_deny_flash = 0.45
		if _price_label:
			_price_label.text = "NEED %d G" % price_gold
			_price_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.32))
		if FeelAudio:
			FeelAudio.play_error()
		return false
	if not RunState.grant_upgrade(pick):
		if price_gold > 0:
			RunState.add_gold(price_gold)
		return false
	_claimed = true
	RunState.apply_to_player(player)
	CameraFx.add_trauma(0.18)
	CameraFx.flash(UpgradeData.house_color(pick.house), 0.12)
	if FeelAudio:
		FeelAudio.play_pickup()
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
