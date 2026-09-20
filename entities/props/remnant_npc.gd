class_name RemnantNpc
extends Area2D
## Hades-style scrap of who you were. Talking writes the Neuro unlock flag.

const LINES: PackedStringArray = [
	"You left a tooth in the wall. I kept it warm.",
	"The city still has your name in its mouth. It is chewing.",
	"I am the leftover. The architecture walked on. I stayed.",
	"Jack the remnant. Remember the hands that wired you.",
]

var _spoken: bool = false
var _plaque: PanelContainer
var _body: Label
var _prompt: Label


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = false
	z_index = 8
	_build_look()
	body_entered.connect(_on_body_entered)


func _build_look() -> void:
	var spr := Sprite2D.new()
	spr.name = "Body"
	spr.centered = true
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	spr.texture = ArtBank.illustrated_facing("hero", Vector2(1, 1))
	if spr.texture == null:
		spr.texture = ArtBank.illustrated("hero_SE")
	if spr.texture:
		ArtBank.fit_height(spr, 96.0, true)
	spr.modulate = Color(0.7, 0.88, 1.0, 0.92)
	add_child(spr)
	var halo := Sprite2D.new()
	halo.texture = ArtBank.particle("circle_05")
	halo.centered = true
	halo.z_index = -1
	halo.modulate = Color(0.35, 0.55, 0.7, 0.45)
	if halo.texture:
		ArtBank.fit_height(halo, 70.0, false)
	add_child(halo)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 54.0
	shape.shape = circle
	add_child(shape)
	_plaque = PanelContainer.new()
	_plaque.position = Vector2(-150, -148)
	_plaque.custom_minimum_size = Vector2(300, 72)
	_plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plaque.add_theme_stylebox_override("panel", ArtBank.panel_style(&"card", Color(0.16, 0.14, 0.12, 0.94)))
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(280, 48)
	_body.add_theme_font_size_override("font_size", 14)
	_body.add_theme_color_override("font_color", Color(0.82, 0.74, 0.58))
	_body.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_body.add_theme_constant_override("outline_size", 4)
	var font := ArtBank.body_font()
	if font:
		_body.add_theme_font_override("font", font)
	_body.text = "A remnant of you. Walk close."
	_plaque.add_child(_body)
	add_child(_plaque)
	_prompt = Label.new()
	_prompt.position = Vector2(-70, 28)
	_prompt.add_theme_font_size_override("font_size", 13)
	_prompt.add_theme_color_override("font_color", Color(0.72, 0.55, 0.32))
	_prompt.text = "E  listen"
	add_child(_prompt)


func _unhandled_input(event: InputEvent) -> void:
	if _spoken:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if key.physical_keycode == KEY_E or key.physical_keycode == KEY_F:
			var player := get_tree().get_first_node_in_group("player") as Node2D
			if player and player.global_position.distance_to(global_position) <= 90.0:
				speak()
				get_viewport().set_input_as_handled()


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		speak()


func speak() -> void:
	if _spoken:
		return
	_spoken = true
	var line := LINES[randi() % LINES.size()]
	_body.text = line
	_prompt.text = "remembered"
	if FeelAudio:
		FeelAudio.play_ui()
	MetaSave.note_remnant_spoken()
	SignalBus.remnant_spoken.emit()
	DamagePop.spawn_label(self, Vector2(0, -40), "Neuro unlocked", Color(0.55, 0.82, 1.0, 1), 14)
