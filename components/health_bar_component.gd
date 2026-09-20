class_name HealthBarComponent
extends Node2D
## World-space HP bar. Appears when damaged; hides at full HP after a short delay.

@export var health_component: HealthComponent
@export var bar_size: Vector2 = Vector2(48, 6)
@export var offset: Vector2 = Vector2(0, -96)
@export var hide_when_full: bool = true
@export var hide_delay: float = 1.5
@export var fill_color: Color = Color(0.85, 0.22, 0.22, 0.95)
@export var background_color: Color = Color(0.08, 0.08, 0.1, 0.75)
@export var border_color: Color = Color(0.0, 0.0, 0.0, 0.55)
@export var label_text: String = ""
@export var label_color: Color = Color(0.92, 0.92, 0.95, 0.95)
@export var label_font_size: int = 11

var _ratio: float = 1.0
var _hide_timer: float = 0.0


func _ready() -> void:
	z_index = 20
	position = offset
	visible = false
	if health_component == null and get_parent():
		health_component = get_parent().get_node_or_null("HealthComponent") as HealthComponent
	if health_component == null:
		push_warning("%s: no HealthComponent found" % name)
		return
	health_component.health_changed.connect(_on_health_changed)
	_on_health_changed(health_component.current_health, health_component.get_max_health())


func set_label(text: String) -> void:
	label_text = text
	queue_redraw()


func _process(delta: float) -> void:
	if _hide_timer <= 0.0:
		return
	_hide_timer = maxf(0.0, _hide_timer - delta)
	if _hide_timer <= 0.0 and _ratio >= 0.999:
		visible = false


func _on_health_changed(current: float, max_value: float) -> void:
	_ratio = clampf(current / max_value, 0.0, 1.0) if max_value > 0.0 else 0.0
	if current <= 0.0:
		visible = false
		_hide_timer = 0.0
		queue_redraw()
		return
	if hide_when_full and _ratio >= 0.999:
		if visible:
			_hide_timer = hide_delay
		queue_redraw()
		return
	visible = true
	_hide_timer = 0.0
	queue_redraw()


func _draw() -> void:
	var half := bar_size * 0.5
	var bg := Rect2(-half, bar_size)
	draw_rect(bg.grow(1.0), border_color)
	draw_rect(bg, background_color)
	var fill_w := bar_size.x * _ratio
	if fill_w > 0.0:
		draw_rect(Rect2(-half.x, -half.y, fill_w, bar_size.y), fill_color)
	if label_text.is_empty():
		return
	var font := ArtBank.ui_font()
	if font == null:
		font = ThemeDB.fallback_font
	if font == null:
		return
	var text_pos := Vector2(-half.x, -half.y - 4.0)
	draw_string(
		font,
		text_pos,
		label_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		label_font_size,
		label_color
	)
