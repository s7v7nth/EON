class_name DamagePop
extends RefCounted
## Floating damage readout for combat readability.


static func spawn_at(
	world: Node,
	global_pos: Vector2,
	amount: float,
	is_crit: bool = false
) -> void:
	if world == null or amount <= 0.0:
		return
	var root := Node2D.new()
	root.z_index = 40
	var label := Label.new()
	label.text = str(int(round(amount)))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_crit:
		label.add_theme_font_size_override("font_size", 22)
		label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.25, 1))
		root.scale = Vector2(1.2, 1.2)
	else:
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.92, 1))
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 4)
	label.position = Vector2(-14, -18)
	root.add_child(label)
	world.add_child(root)
	root.global_position = global_pos + Vector2(randf_range(-8.0, 8.0), -8.0)
	var end_pos := root.global_position + Vector2(randf_range(-16.0, 16.0), -40.0)
	var tween := root.create_tween()
	tween.tween_property(root, "global_position", end_pos, 0.55)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(root, "modulate:a", 0.0, 0.55)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if is_crit:
		tween.parallel().tween_property(root, "scale", Vector2.ONE, 0.2)
	tween.tween_callback(root.queue_free)


static func spawn_label(
	world: Node,
	global_pos: Vector2,
	text: String,
	color: Color = Color(1.0, 0.86, 0.28, 1),
	font_size: int = 16
) -> void:
	if world == null or text == "":
		return
	var root := Node2D.new()
	root.z_index = 40
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 5)
	var font := ArtBank.ui_font()
	if font:
		label.add_theme_font_override("font", font)
	label.position = Vector2(-28, -18)
	root.add_child(label)
	world.add_child(root)
	root.global_position = global_pos
	var end_pos := root.global_position + Vector2(randf_range(-10.0, 10.0), -46.0)
	var tween := root.create_tween()
	tween.tween_property(root, "global_position", end_pos, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(root, "modulate:a", 0.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(root.queue_free)
