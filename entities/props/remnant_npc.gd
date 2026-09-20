class_name RemnantNpc
extends Area2D
## Plaza clerk. One tap, one Hades scrap. The node line is the Neuro unlock.

const FIRST_VISIT: PackedStringArray = [
	"Shift's over. Has been. You're a remnant. So am I. City printed us when people stopped clocking in.",
	"Don't look for a name. I issued kits. I still issue kits. Queue's just you.",
	"Architectures were jobs, not identities. Steel for the plaza. Swarm for the drains. Heat for the rails. Wires for the Core.",
	"Синтетик is the leftover suit. Grey. Cheap. That's why you can walk without asking anyone.",
	"City didn't fall. It rotted. Maintenance first. Then the lights. Then the people. Drains last — that's where the swarm lives.",
	"The Hive is east of here. Municipal sweeper that never clocked out. Ate the crew. Ate the replacements. Still hungry.",
	"You want Улей, you take a listening swarm off that thing. Clean bodies don't get one.",
	"Паровоз is in the roundhouse with the heat killed. City did that on purpose so the last engine wouldn't cook the yards. Warden sits on the valve.",
	"Нейро is bricked. Core cut itself so the swarm couldn't ride the wires. I have a node. I don't hand it to strangers.",
	"Gold still spends. I don't know on what. Habit.",
	"You die, you come back. That's the architecture. City never learned how to fire us.",
	"I used to have a window and a line. Now I have a stall and a plaza that's rotting from the drains up.",
]

const REPEAT_VISIT: PackedStringArray = [
	"You're back. Same steel. Same smell. Hive's still chewing east of here.",
	"I remember the last time. That's not a compliment. Most remnants don't keep the body.",
	"Still no queue. If you came for the node, say so. If you came to stand here, the orbs are what they are.",
]

const NODE_LINE := "Fine. Drawer node. Don't jack it in the plaza. Core still thinks it's starving the swarm. You get to be the lie."

var last_line: String = ""
var _repeat_i: int = 0
var _plaque: PanelContainer
var _body: Label
var _prompt: Label
var _near: bool = false
var _listen_cool: float = 0.0


func _ready() -> void:
	add_to_group("plaza_clerk")
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	monitorable = false
	z_index = 8
	_build_look()
	set_process(true)
	set_process_input(true)
	set_process_unhandled_input(true)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _build_look() -> void:
	_build_stall()
	var spr := Sprite2D.new()
	spr.name = "Body"
	spr.centered = true
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	spr.texture = ArtBank.illustrated("clerk")
	if spr.texture == null:
		spr.texture = ArtBank.illustrated_facing("hero", Vector2(1, 1))
	if spr.texture == null:
		spr.texture = ArtBank.illustrated("hero_SE")
	if spr.texture:
		ArtBank.fit_height(spr, 128.0, true)
	spr.modulate = Color.WHITE
	spr.position = Vector2(-10, 6)
	spr.z_index = 2
	add_child(spr)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 88.0
	shape.shape = circle
	add_child(shape)
	_prompt = Label.new()
	_prompt.position = Vector2(-48, 42)
	_prompt.add_theme_font_size_override("font_size", 13)
	_prompt.add_theme_color_override("font_color", Color(0.45, 0.92, 1.0))
	_prompt.text = "E  listen"
	_prompt.visible = false
	add_child(_prompt)
	_build_scrap_banner()


func _build_stall() -> void:
	var kiosk := Sprite2D.new()
	kiosk.name = "StallKiosk"
	kiosk.centered = true
	kiosk.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	kiosk.texture = ArtBank.illustrated("prop_pylon")
	if kiosk.texture == null:
		kiosk.texture = ArtBank.illustrated("wall_slab_S")
	if kiosk.texture:
		ArtBank.fit_height(kiosk, 148.0, true)
	kiosk.position = Vector2(36, -4)
	kiosk.modulate = Color.WHITE
	kiosk.z_index = -1
	add_child(kiosk)
	var lamp := Sprite2D.new()
	lamp.name = "StallLamp"
	lamp.centered = true
	lamp.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	lamp.texture = ArtBank.illustrated("prop_lamp")
	if lamp.texture:
		ArtBank.fit_height(lamp, 96.0, true)
	lamp.position = Vector2(-44, 8)
	lamp.modulate = Color.WHITE
	lamp.z_index = -1
	add_child(lamp)


func _build_scrap_banner() -> void:
	## Hades scrap: one line on the HUD, not a plaque covering the stall.
	var layer := CanvasLayer.new()
	layer.name = "ScrapLayer"
	layer.layer = 55
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	_plaque = PanelContainer.new()
	_plaque.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_plaque.anchor_left = 0.5
	_plaque.anchor_right = 0.5
	_plaque.anchor_top = 1.0
	_plaque.anchor_bottom = 1.0
	_plaque.offset_left = -360.0
	_plaque.offset_right = 360.0
	_plaque.offset_top = -138.0
	_plaque.offset_bottom = -72.0
	_plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plaque.add_theme_stylebox_override("panel", ArtBank.panel_style(&"card", Color(0.05, 0.1, 0.14, 0.92)))
	_plaque.visible = false
	root.add_child(_plaque)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 2)
	_plaque.add_child(col)
	var speaker := Label.new()
	speaker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	speaker.text = "Municipal issue"
	speaker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	speaker.add_theme_font_size_override("font_size", 12)
	speaker.add_theme_color_override("font_color", Color(0.45, 0.9, 0.98))
	var speaker_font := ArtBank.body_bold()
	if speaker_font:
		speaker.add_theme_font_override("font", speaker_font)
	col.add_child(speaker)
	_body = Label.new()
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.custom_minimum_size = Vector2(700, 44)
	_body.add_theme_font_size_override("font_size", 16)
	_body.add_theme_color_override("font_color", Color(0.86, 0.94, 0.98))
	_body.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_body.add_theme_constant_override("outline_size", 4)
	var font := ArtBank.body_font()
	if font:
		_body.add_theme_font_override("font", font)
	col.add_child(_body)


func _process(delta: float) -> void:
	_listen_cool = maxf(_listen_cool - delta, 0.0)
	var near := _player_in_range()
	if _prompt:
		_prompt.visible = near
		_prompt.modulate = Color(0.7, 1.05, 1.1, 1) if near else Color.WHITE
	if _plaque and _plaque.visible and not near:
		_plaque.visible = false
	if _listen_cool > 0.0:
		return
	if not near:
		return
	if Input.is_physical_key_pressed(KEY_E):
		speak()
		_listen_cool = 0.28


func _input(event: InputEvent) -> void:
	_try_listen(event)


func _unhandled_input(event: InputEvent) -> void:
	_try_listen(event)


func _try_listen(event: InputEvent) -> void:
	if event is not InputEventKey:
		return
	if not event.pressed or event.echo:
		return
	var key := event as InputEventKey
	if key.physical_keycode != KEY_E and key.keycode != KEY_E:
		return
	if not _player_in_range():
		return
	speak()
	_listen_cool = 0.28
	get_viewport().set_input_as_handled()


func _player_in_range() -> bool:
	if _near:
		return true
	var player := get_tree().get_first_node_in_group("player") as Node2D
	return player != null and player.global_position.distance_to(global_position) <= 200.0


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		_near = true
		_prompt.modulate = Color(0.7, 1.05, 1.1, 1)


func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		_near = false
		_prompt.modulate = Color.WHITE


func speak() -> String:
	var line := _next_line()
	last_line = line
	if _body:
		_body.text = line
	if _plaque:
		_plaque.visible = true
	if _prompt:
		_prompt.text = "E  listen"
	if FeelAudio:
		FeelAudio.play_ui()
	return line


func _next_line() -> String:
	if MetaSave.has_flag(MetaSave.FLAG_REMNANT):
		var line := REPEAT_VISIT[_repeat_i % REPEAT_VISIT.size()]
		_repeat_i += 1
		return line
	var idx := MetaSave.clerk_scrap_index()
	if idx < FIRST_VISIT.size():
		MetaSave.advance_clerk_scrap()
		return FIRST_VISIT[idx]
	MetaSave.note_remnant_spoken()
	SignalBus.remnant_spoken.emit()
	return NODE_LINE
