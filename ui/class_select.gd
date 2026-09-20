extends Control
## Run boot: pick route + architecture, then dive into the first room.

const _Autopilot := preload("res://components/combat_autopilot.gd")

const HINTS := {
	0: {
		"title": "Синтетик",
		"role": "Blade · Parry · Geometry",
		"kit": "LMB combo / hold-throw   RMB shield+parry   Space dash   Q Lattice Collapse",
		"fantasy": "Ricochet an energy blade through summoned mirrors. Perfect parries write geometry into the room.",
	},
	1: {
		"title": "Улей",
		"role": "Nano swarm · Blood harvest",
		"kit": "LMB nano-blade   RMB whip/toad   hold Space Dissipate   Q swarm burst",
		"fantasy": "Spend flesh to keep the swarm alive. Hits and kills drink HP back. Hold Space to puddle.",
	},
	2: {
		"title": "Паровоз",
		"role": "Plasma · Overheat · Vent",
		"kit": "LMB plasma   RMB gun/mortar   Space dash   Q Vent dump",
		"fantasy": "Ride the heat gauge. Yellow and red are power — Vent before you cook.",
	},
	3: {
		"title": "Нейро-хакер",
		"role": "Pistol · Drones · Glitch",
		"kit": "LMB smart pistol / holo   Space dash   Q drone slot",
		"fantasy": "RAM is a battlefield. Park drones, glitch robots, never stand still.",
	},
}

var _selected_route_id: StringName = &"tutorial"
var _selected_arch: ArchitectureData
var _route_buttons: Array[Button] = []
var _arch_buttons: Array[Button] = []
var _start: Button
var _flavor: Label


func _ready() -> void:
	set_anchors_preset(PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	print("CLASS_SELECT_READY")
	_select_route_by_id(&"tutorial")
	var arches := RunState.get_architectures()
	if not arches.is_empty():
		for arch in arches:
			if MetaSave.is_architecture_unlocked(int(arch.architecture_id)):
				_select_arch(arch)
				break
	if _Autopilot.is_requested():
		call_deferred("_autopilot_begin")


func _build() -> void:
	var bg := TextureRect.new()
	bg.set_anchors_preset(PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.texture = ArtBank.illustrated("sky_dusk")
	add_child(bg)
	if bg.texture == null:
		var fallback := ColorRect.new()
		fallback.set_anchors_preset(PRESET_FULL_RECT)
		fallback.color = Color(0.04, 0.05, 0.08, 1)
		add_child(fallback)

	var glow := ColorRect.new()
	glow.set_anchors_preset(PRESET_FULL_RECT)
	glow.color = Color(0.03, 0.04, 0.06, 0.22)
	add_child(glow)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	margin.add_child(col)

	var title := Label.new()
	title.text = "EON"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(0.86, 0.9, 0.94))
	title.add_theme_color_override("font_outline_color", Color(0.02, 0.08, 0.12, 0.9))
	title.add_theme_constant_override("outline_size", 8)
	var title_font := ArtBank.title_font()
	if title_font == null:
		title_font = ArtBank.body_heavy()
	if title_font:
		title.add_theme_font_override("font", title_font)
	col.add_child(title)

	var sub := Label.new()
	sub.text = "A remnant architecture against a dying city. Pick a route. Pick a language of violence."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", Color(0.68, 0.72, 0.76))
	var sub_font := ArtBank.body_font()
	if sub_font:
		sub.add_theme_font_override("font", sub_font)
	col.add_child(sub)

	var route_label := Label.new()
	route_label.text = "Route"
	route_label.add_theme_font_size_override("font_size", 14)
	route_label.add_theme_color_override("font_color", Color(0.45, 0.88, 0.95))
	var section_font := ArtBank.body_bold()
	if section_font:
		route_label.add_theme_font_override("font", section_font)
	col.add_child(route_label)

	var route_row := HBoxContainer.new()
	route_row.add_theme_constant_override("separation", 10)
	col.add_child(route_row)
	for choice in RunState.route_choices():
		var btn := Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 44)
		var rid: StringName = choice.get("id", &"tutorial")
		btn.text = "%s  ·  %d rooms" % [str(choice.get("display_name", "")), int(choice.get("rooms", 0))]
		btn.set_meta("route_id", rid)
		btn.pressed.connect(_select_route_by_id.bind(rid))
		var route_style := ArtBank.button_style(false, Color(0.18, 0.42, 0.52, 1))
		var route_hover := ArtBank.button_style(true, Color(0.28, 0.7, 0.82, 1))
		if route_style:
			btn.add_theme_stylebox_override("normal", route_style)
		if route_hover:
			btn.add_theme_stylebox_override("hover", route_hover)
		var route_font := ArtBank.body_bold()
		if route_font:
			btn.add_theme_font_override("font", route_font)
		btn.add_theme_font_size_override("font_size", 15)
		route_row.add_child(btn)
		_route_buttons.append(btn)

	var arch_label := Label.new()
	arch_label.text = "Architecture"
	arch_label.add_theme_font_size_override("font_size", 14)
	arch_label.add_theme_color_override("font_color", Color(0.55, 0.95, 1.0))
	if section_font:
		arch_label.add_theme_font_override("font", section_font)
	col.add_child(arch_label)

	var arch_row := HBoxContainer.new()
	arch_row.add_theme_constant_override("separation", 12)
	arch_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(arch_row)
	for arch in RunState.get_architectures():
		var card := _make_arch_card(arch)
		arch_row.add_child(card)

	_flavor = Label.new()
	_flavor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_flavor.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_flavor.add_theme_font_size_override("font_size", 15)
	_flavor.add_theme_color_override("font_color", Color(0.7, 0.86, 0.92))
	var flavor_font := ArtBank.body_font()
	if flavor_font:
		_flavor.add_theme_font_override("font", flavor_font)
	_flavor.custom_minimum_size = Vector2(0, 48)
	col.add_child(_flavor)

	_start = Button.new()
	_start.text = "Begin run"
	_start.custom_minimum_size = Vector2(0, 56)
	_start.add_theme_font_size_override("font_size", 22)
	var start_font := ArtBank.body_heavy()
	if start_font:
		_start.add_theme_font_override("font", start_font)
	_start.add_theme_color_override("font_color", Color(0.04, 0.08, 0.1, 1))
	var start_style := ArtBank.button_style(false, Color(0.32, 0.86, 0.95, 1))
	var start_hover := ArtBank.button_style(true, Color(0.55, 0.96, 1.0, 1))
	if start_style:
		_start.add_theme_stylebox_override("normal", start_style)
	if start_hover:
		_start.add_theme_stylebox_override("hover", start_hover)
		_start.add_theme_stylebox_override("pressed", start_hover)
	_start.pressed.connect(_begin_run)
	col.add_child(_start)

	var help := Label.new()
	help.text = "T / C / P pick route · 1–4 pick architecture (locked kits refuse) · Enter begin · in run: WASD · LMB attack · RMB special/block · Space dash/Dissipate · Q cast · R restart · F9 skip room"
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 13)
	help.add_theme_color_override("font_color", Color(0.5, 0.68, 0.76))
	if flavor_font:
		help.add_theme_font_override("font", flavor_font)
	col.add_child(help)


func _make_arch_card(arch: ArchitectureData) -> Button:
	var btn := Button.new()
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(200, 360)
	btn.text = ""
	btn.clip_text = false
	btn.icon = _portrait_for(arch)
	btn.expand_icon = true
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	btn.add_theme_constant_override("icon_max_width", 156)
	var tex_style := ArtBank.button_style(false, Color(0.08, 0.16, 0.22, 1))
	var tex_hover := ArtBank.button_style(true, Color(0.16, 0.42, 0.52, 1))
	if tex_style:
		btn.add_theme_stylebox_override("normal", tex_style)
	if tex_hover:
		btn.add_theme_stylebox_override("hover", tex_hover)
		btn.add_theme_stylebox_override("pressed", tex_hover)
	var hint: Dictionary = HINTS.get(int(arch.architecture_id), {})
	var pad := MarginContainer.new()
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	pad.offset_top = -176.0
	pad.add_theme_constant_override("margin_left", 10)
	pad.add_theme_constant_override("margin_right", 10)
	pad.add_theme_constant_override("margin_bottom", 12)
	btn.add_child(pad)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 4)
	pad.add_child(col)
	var title := Label.new()
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.text = str(hint.get("title", arch.display_name))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.72, 0.95, 1.0))
	var title_font := ArtBank.body_heavy()
	if title_font:
		title.add_theme_font_override("font", title_font)
	col.add_child(title)
	var role := Label.new()
	role.mouse_filter = Control.MOUSE_FILTER_IGNORE
	role.text = str(hint.get("role", arch.description))
	role.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	role.add_theme_font_size_override("font_size", 13)
	role.add_theme_color_override("font_color", Color(0.78, 0.84, 0.92))
	var body := ArtBank.body_font()
	if body:
		role.add_theme_font_override("font", body)
	col.add_child(role)
	if not MetaSave.is_architecture_unlocked(int(arch.architecture_id)):
		btn.disabled = false
		var lock := Label.new()
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lock.text = MetaSave.unlock_requirement(int(arch.architecture_id))
		lock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lock.custom_minimum_size = Vector2(0, 52)
		lock.add_theme_font_size_override("font_size", 11)
		lock.add_theme_color_override("font_color", Color(0.95, 0.45, 0.4))
		if body:
			lock.add_theme_font_override("font", body)
		col.add_child(lock)
		btn.modulate = Color(0.38, 0.36, 0.4)
	btn.pressed.connect(_select_arch.bind(arch))
	_arch_buttons.append(btn)
	return btn


func _button_style(path: String) -> StyleBoxTexture:
	var tex := ArtBank.tex(path)
	if tex == null:
		return null
	var sb := StyleBoxTexture.new()
	sb.texture = tex
	sb.set_texture_margin_all(16)
	return sb


func _portrait_for(arch: ArchitectureData) -> Texture2D:
	## One human clone. Architecture is a kit overlay, never a sweeper/robot species.
	var stem := "synthetic"
	if arch:
		match arch.architecture_id:
			GameplayEnums.ArchitectureId.NANOMACHINES:
				stem = "hive"
			GameplayEnums.ArchitectureId.ELECTRO_TRAIN:
				stem = "train"
			GameplayEnums.ArchitectureId.NEURO_HACKER:
				stem = "neuro"
			_:
				stem = "synthetic"
	var portrait := ArtBank.portrait(stem)
	if portrait:
		return portrait
	var hero := ArtBank.illustrated("hero_SE")
	return hero if hero else ArtBank.portrait("synthetic")


func _select_route_by_id(route_id: StringName) -> void:
	_selected_route_id = route_id
	for btn in _route_buttons:
		var bid: StringName = btn.get_meta("route_id", &"")
		btn.modulate = Color(0.72, 0.96, 1.0) if bid == route_id else Color(0.55, 0.62, 0.68)


func _select_arch(arch: ArchitectureData) -> void:
	if arch == null:
		return
	if not MetaSave.is_architecture_unlocked(int(arch.architecture_id)):
		_flavor.text = MetaSave.unlock_requirement(int(arch.architecture_id))
		SignalBus.architecture_unlock_denied.emit(int(arch.architecture_id), MetaSave.unlock_requirement(int(arch.architecture_id)))
		return
	_selected_arch = arch
	for i in _arch_buttons.size():
		var btn := _arch_buttons[i]
		var match_arch := RunState.get_architectures()
		var locked := i < match_arch.size() and not MetaSave.is_architecture_unlocked(int(match_arch[i].architecture_id))
		btn.modulate = Color(0.38, 0.4, 0.46) if locked else Color(0.55, 0.62, 0.68)
		if i < match_arch.size() and match_arch[i] == arch:
			btn.modulate = Color(0.78, 0.96, 1.0)
	var hint: Dictionary = HINTS.get(int(arch.architecture_id), {})
	_flavor.text = "%s\n%s" % [str(hint.get("kit", "")), str(hint.get("fantasy", arch.description))]


func _unhandled_input(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo:
		return
	var key := event as InputEventKey
	var arches := RunState.get_architectures()
	match key.physical_keycode:
		KEY_T:
			_select_route_by_id(&"tutorial")
		KEY_C:
			_select_route_by_id(&"campaign")
		KEY_P:
			_select_route_by_id(&"procedural")
		KEY_1, KEY_KP_1:
			if arches.size() > 0:
				_select_arch(arches[0])
		KEY_2, KEY_KP_2:
			if arches.size() > 1:
				_select_arch(arches[1])
		KEY_3, KEY_KP_3:
			if arches.size() > 2:
				_select_arch(arches[2])
		KEY_4, KEY_KP_4:
			if arches.size() > 3:
				_select_arch(arches[3])
		KEY_ENTER, KEY_KP_ENTER:
			_begin_run()


func _begin_run() -> void:
	if _selected_arch == null:
		return
	if not MetaSave.is_architecture_unlocked(int(_selected_arch.architecture_id)):
		_flavor.text = MetaSave.unlock_requirement(int(_selected_arch.architecture_id))
		return
	var route := RunState.load_route_by_id(_selected_route_id)
	if route == null:
		return
	RunState.reset()
	RunState.choose_route(route)
	if not RunState.choose_architecture_data(_selected_arch):
		_flavor.text = MetaSave.unlock_requirement(int(_selected_arch.architecture_id))
		return
	var path := RunState.layout_scene_for_current_room()
	if path == "":
		path = "res://levels/floor/floor_world.tscn"
	print("BEGIN_RUN t=%d scene=%s" % [Time.get_ticks_msec(), path])
	if FeelAudio:
		FeelAudio.play_ui()
	get_tree().change_scene_to_file(path)


func _autopilot_begin() -> void:
	await get_tree().create_timer(2.2).timeout
	if not is_inside_tree():
		return
	_begin_run()
