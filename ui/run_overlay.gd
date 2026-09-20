extends CanvasLayer
## Death / wave / win / reward / craft overlay. Always processes while tree is paused.

enum Mode { HIDDEN, DEATH, WAVE_BANNER, WIN, REWARD, ARCH_PICK, ROUTE_PICK }

var _mode: Mode = Mode.HIDDEN
var _craft_nodes: Array[Node] = []
var _reward_extra_nodes: Array[Node] = []
var _arch_nodes: Array[Node] = []
var _route_nodes: Array[Node] = []

@onready var _panel: PanelContainer = $Center/Panel
@onready var _title: Label = $Center/Panel/Margin/VBox/Title
@onready var _subtitle: Label = $Center/Panel/Margin/VBox/Subtitle
@onready var _wave_label: Label = $WaveLabel
@onready var _style_banner: Label = $StyleBanner
@onready var _rewards: VBoxContainer = $Center/Panel/Margin/VBox/Rewards
@onready var _craft: VBoxContainer = $Center/Panel/Margin/VBox/Craft
@onready var _arch: VBoxContainer = $Center/Panel/Margin/VBox/ArchPick
@onready var _vbox: VBoxContainer = $Center/Panel/Margin/VBox

var _route: VBoxContainer
var _offer_buttons: Array[Button] = []
var _boss_banner: Label
var _boss_tween: Tween
var _dimmer: ColorRect
var _last_style_rank: String = ""
var _style_tween: Tween
var _end_nodes: Array[Node] = []
var _win_nodes: Array[Node] = []
var _wave_plaque: PanelContainer
var _combo_toast: PanelContainer
var _combo_title: Label
var _combo_body: Label
var _combo_tween: Tween
var _finishing_reward: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_dimmer()
	_skin_panel(&"glass", Color(0.85, 0.9, 1.0, 0.96))
	_panel.visible = false
	_rewards.visible = false
	_craft.visible = false
	_arch.visible = false
	_ensure_route_box()
	_route.visible = false
	_wave_label.text = ""
	if _style_banner:
		_style_banner.text = ""
		_style_banner.modulate.a = 0.0
		_style_banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
		_style_banner.offset_top = 86.0
		_style_banner.offset_bottom = 128.0
		_style_banner.offset_left = 0.0
		_style_banner.offset_right = 0.0
		_style_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	SignalBus.player_died.connect(_on_player_died)
	SignalBus.wave_started.connect(_on_wave_started)
	SignalBus.wave_cleared.connect(_on_wave_cleared)
	SignalBus.run_won.connect(_on_run_won)
	SignalBus.exit_reached.connect(_on_exit_reached)
	SignalBus.style_score_changed.connect(_on_style_changed)
	_rewards.get_node("BtnDamage").pressed.connect(_on_pick_damage)
	_rewards.get_node("BtnSpeed").pressed.connect(_on_pick_speed)
	_rewards.get_node("BtnDash").pressed.connect(_on_pick_dash)
	# Route → architecture at run start only when this overlay owns the live scene.
	if get_parent() == get_tree().current_scene and RunState.room_index == 0 and not RunState.architecture_picked:
		call_deferred("_show_start_flow")
	SignalBus.combo_unlocked.connect(_on_combo_unlocked)
	SignalBus.combo_proc.connect(_on_combo_proc)
	SignalBus.synergy_triggered.connect(_on_synergy_triggered)
	SignalBus.room_cleared.connect(_on_room_cleared)
	_ensure_boss_banner()
	SignalBus.boss_spawned.connect(_on_boss_spawned)
	SignalBus.boss_phase.connect(_on_boss_phase)
	var body := ArtBank.body_font()
	var heavy := ArtBank.body_heavy()
	if heavy:
		_title.add_theme_font_override("font", heavy)
	elif body:
		_title.add_theme_font_override("font", body)
	if body:
		_subtitle.add_theme_font_override("font", body)
		_wave_label.add_theme_font_override("font", body)
		if _style_banner:
			_style_banner.add_theme_font_override("font", heavy if heavy else body)
	_title.add_theme_font_size_override("font_size", 28)
	_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_title.add_theme_constant_override("outline_size", 6)
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wrap_wave_plaque()
	_ensure_combo_toast()


func _wrap_wave_plaque() -> void:
	if _wave_label == null or _wave_label.get_parent() is PanelContainer:
		return
	_wave_plaque = PanelContainer.new()
	_wave_plaque.name = "WavePlaque"
	_wave_plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wave_plaque.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_wave_plaque.anchor_top = 1.0
	_wave_plaque.anchor_bottom = 1.0
	_wave_plaque.offset_left = 12.0
	_wave_plaque.offset_right = 360.0
	_wave_plaque.offset_top = -64.0
	_wave_plaque.offset_bottom = -16.0
	_wave_plaque.add_theme_stylebox_override("panel", ArtBank.panel_style(&"card", Color(0.82, 0.88, 1.0, 0.94)))
	_wave_plaque.visible = false
	var parent := _wave_label.get_parent()
	parent.remove_child(_wave_label)
	_wave_plaque.add_child(_wave_label)
	parent.add_child(_wave_plaque)
	_wave_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wave_label.offset_left = 10.0
	_wave_label.offset_right = -10.0
	_wave_label.offset_top = 4.0
	_wave_label.offset_bottom = -4.0
	_wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_wave_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func _set_wave_text(text: String) -> void:
	if _wave_label:
		_wave_label.text = text
	if _wave_plaque:
		_wave_plaque.visible = text != ""


func _ensure_route_box() -> void:
	_route = _vbox.get_node_or_null("RoutePick") as VBoxContainer
	if _route:
		return
	_route = VBoxContainer.new()
	_route.name = "RoutePick"
	_route.add_theme_constant_override("separation", 8)
	# Insert above ArchPick.
	var arch_idx := _arch.get_index()
	_vbox.add_child(_route)
	_vbox.move_child(_route, arch_idx)


func _input(event: InputEvent) -> void:
	if _mode == Mode.REWARD:
		_handle_reward_hotkeys(event)
		return
	if _mode != Mode.DEATH and _mode != Mode.WIN:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if key.physical_keycode == KEY_C:
			get_viewport().set_input_as_handled()
			RunState.return_to_class_select()
			return
	if not event.is_action_pressed("restart") and not _is_restart_key(event):
		return
	get_viewport().set_input_as_handled()
	RunState.restart_run()


func _is_restart_key(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		return (event as InputEventKey).physical_keycode == KEY_R
	return false


func _ensure_dimmer() -> void:
	_dimmer = get_node_or_null("Dimmer") as ColorRect
	if _dimmer:
		return
	_dimmer = ColorRect.new()
	_dimmer.name = "Dimmer"
	_dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dimmer.color = Color(0.02, 0.03, 0.05, 0.62)
	_dimmer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dimmer.visible = false
	add_child(_dimmer)
	move_child(_dimmer, 0)


func _skin_panel(kind: StringName, tint: Color) -> void:
	if _panel == null:
		return
	_panel.add_theme_stylebox_override("panel", ArtBank.panel_style(kind, tint))


func _skin_button(btn: Button, tint: Color = Color(0.95, 0.97, 1.0, 1)) -> void:
	if btn == null:
		return
	btn.add_theme_stylebox_override("normal", ArtBank.button_style(false, tint))
	btn.add_theme_stylebox_override("hover", ArtBank.button_style(true, tint.lightened(0.12)))
	btn.add_theme_stylebox_override("pressed", ArtBank.button_style(true, tint.darkened(0.08)))
	btn.add_theme_color_override("font_color", Color(0.94, 0.96, 1.0))
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	var font := ArtBank.body_bold()
	if font:
		btn.add_theme_font_override("font", font)
	btn.add_theme_font_size_override("font_size", 16)
	btn.custom_minimum_size.y = maxf(btn.custom_minimum_size.y, 48.0)


func _ensure_combo_toast() -> void:
	if _combo_toast:
		return
	_combo_toast = PanelContainer.new()
	_combo_toast.name = "ComboToast"
	_combo_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_combo_toast.set_anchors_preset(Control.PRESET_CENTER)
	_combo_toast.anchor_left = 0.5
	_combo_toast.anchor_right = 0.5
	_combo_toast.anchor_top = 0.5
	_combo_toast.anchor_bottom = 0.5
	_combo_toast.offset_left = -300.0
	_combo_toast.offset_right = 300.0
	_combo_toast.offset_top = -86.0
	_combo_toast.offset_bottom = 86.0
	_combo_toast.z_index = 80
	_combo_toast.process_mode = Node.PROCESS_MODE_ALWAYS
	_combo_toast.add_theme_stylebox_override("panel", ArtBank.panel_style(&"card", Color(1.0, 0.92, 0.55, 0.97)))
	_combo_toast.modulate.a = 0.0
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 16)
	pad.add_theme_constant_override("margin_right", 16)
	pad.add_theme_constant_override("margin_top", 10)
	pad.add_theme_constant_override("margin_bottom", 10)
	_combo_toast.add_child(pad)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	pad.add_child(col)
	var kicker := Label.new()
	kicker.text = "Named combo"
	kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kicker.add_theme_font_size_override("font_size", 13)
	kicker.add_theme_color_override("font_color", Color(0.35, 0.22, 0.08, 1))
	var kicker_font := ArtBank.body_bold()
	if kicker_font:
		kicker.add_theme_font_override("font", kicker_font)
	col.add_child(kicker)
	_combo_title = Label.new()
	_combo_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_combo_title.add_theme_font_size_override("font_size", 26)
	_combo_title.add_theme_color_override("font_color", Color(0.12, 0.08, 0.04, 1))
	_combo_title.add_theme_color_override("font_outline_color", Color(1.0, 0.95, 0.7, 0.55))
	_combo_title.add_theme_constant_override("outline_size", 4)
	var title_font := ArtBank.body_heavy()
	if title_font:
		_combo_title.add_theme_font_override("font", title_font)
	col.add_child(_combo_title)
	_combo_body = Label.new()
	_combo_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_combo_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_combo_body.add_theme_font_size_override("font_size", 14)
	_combo_body.add_theme_color_override("font_color", Color(0.22, 0.16, 0.1, 1))
	var body := ArtBank.body_font()
	if body:
		_combo_body.add_theme_font_override("font", body)
	col.add_child(_combo_body)
	add_child(_combo_toast)


func _show_combo_toast(combo_name: String, description: String) -> void:
	_ensure_combo_toast()
	if _combo_title:
		_combo_title.text = combo_name
	if _combo_body:
		_combo_body.text = description
	_combo_toast.visible = true
	_combo_toast.modulate = Color.WHITE
	move_child(_combo_toast, get_child_count() - 1)
	_combo_toast.pivot_offset = _combo_toast.size * 0.5
	_combo_toast.scale = Vector2(1.12, 1.12)
	if _combo_tween and _combo_tween.is_valid():
		_combo_tween.kill()
	_combo_tween = create_tween()
	_combo_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_combo_tween.tween_property(_combo_toast, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK)
	_combo_tween.tween_interval(3.8)
	_combo_tween.tween_property(_combo_toast, "modulate:a", 0.0, 0.5)
	if FeelAudio:
		FeelAudio.play_ui()


func _ensure_boss_banner() -> void:
	_boss_banner = get_node_or_null("BossBanner") as Label
	if _boss_banner:
		return
	_boss_banner = Label.new()
	_boss_banner.name = "BossBanner"
	_boss_banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_boss_banner.offset_top = 64.0
	_boss_banner.offset_bottom = 132.0
	_boss_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_banner.add_theme_font_size_override("font_size", 42)
	_boss_banner.add_theme_color_override("font_color", Color(1.0, 0.32, 0.28))
	_boss_banner.add_theme_color_override("font_outline_color", Color(0.05, 0, 0, 0.95))
	_boss_banner.add_theme_constant_override("outline_size", 10)
	var font := ArtBank.body_heavy()
	if font:
		_boss_banner.add_theme_font_override("font", font)
	_boss_banner.text = ""
	add_child(_boss_banner)


func _on_boss_spawned(boss_name: String) -> void:
	_flash_boss_banner("Boss — %s" % boss_name, Color(1.0, 0.32, 0.28))
	if _dimmer:
		_dimmer.visible = true
		_dimmer.color = Color(0.18, 0.02, 0.02, 0.38)
		var tw := create_tween()
		tw.tween_property(_dimmer, "color:a", 0.0, 1.35)
		tw.tween_callback(func() -> void:
			if _dimmer and _mode == Mode.HIDDEN:
				_dimmer.visible = false
				_dimmer.color = Color(0.02, 0.03, 0.05, 0.62)
		)


func _on_boss_phase(phase: int, boss_name: String) -> void:
	_flash_boss_banner("Phase %d — %s" % [phase, boss_name], Color(1.0, 0.55, 0.2))


func _flash_boss_banner(text: String, color: Color) -> void:
	if _boss_banner == null:
		_ensure_boss_banner()
	_boss_banner.text = text
	_boss_banner.add_theme_color_override("font_color", color)
	_boss_banner.modulate = Color.WHITE
	_boss_banner.scale = Vector2(1.12, 1.12)
	if _boss_tween and _boss_tween.is_valid():
		_boss_tween.kill()
	_boss_tween = create_tween()
	_boss_tween.tween_property(_boss_banner, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK)
	_boss_tween.tween_interval(1.6)
	_boss_tween.tween_property(_boss_banner, "modulate:a", 0.0, 0.45)
	_boss_tween.tween_callback(func() -> void:
		if _boss_banner:
			_boss_banner.text = ""
			_boss_banner.modulate = Color.WHITE
	)


func _show_start_flow() -> void:
	if not RunState.route_picked:
		_show_route_pick()
	elif not RunState.architecture_picked:
		_show_arch_pick()


func _on_player_died() -> void:
	_skin_panel(&"glass", Color(1.0, 0.88, 0.88, 0.97))
	_show(Mode.DEATH, "You Died", "Rank %s" % RunState.current_room_rank())
	_populate_end_actions()
	get_tree().paused = true


func _on_wave_started(index: int, total: int) -> void:
	var tag := RunState.room_kind_label()
	var prefix := ("%s · " % tag) if tag != "" else ""
	_set_wave_text("%sRoom %d / %d   ·   Wave %d of %d" % [
		prefix, RunState.room_index + 1, RunState.room_count(), index + 1, total
	])


func _on_wave_cleared(index: int) -> void:
	_set_wave_text("Wave %d clear   ·   Rank %s" % [index + 1, RunState.current_room_rank()])


func _on_room_cleared() -> void:
	if RunState.current_room_kind() == DungeonRoom.RoomKind.SHOP:
		_set_wave_text("Shop  ·  walk an orb, then the south door")
	elif RunState.current_room_kind() == DungeonRoom.RoomKind.TREASURE:
		_set_wave_text("Cache  ·  walk an orb, then the south door")
	else:
		_set_wave_text("South door open   ·   Rank %s" % RunState.current_room_rank())


func _on_run_won() -> void:
	_skin_panel(&"glass", Color(1.0, 0.98, 0.9, 0.97))
	_show(Mode.WIN, "Run Complete", "Style %s  ·  %d pts  ·  Gold %d" % [
		RunState.current_room_rank(), RunState.style_score, RunState.gold
	])
	_rewards.visible = false
	_craft.visible = false
	_arch.visible = false
	if _route:
		_route.visible = false
	_populate_win_relics()
	_populate_end_actions()
	get_tree().paused = true


func _on_exit_reached() -> void:
	var has_craft := _populate_craft()
	_populate_reward_upgrades()
	var loot_line := "Choose one artifact — click a card or press 1 / 2 / 3"
	if not RunState.last_loot.is_empty():
		loot_line = "Loot: %s — then pick an artifact (1–3)" % RunState.loot_summary()
	if RunState.last_combo_name != "":
		loot_line = "%s — %s" % [RunState.last_combo_name, loot_line]
	var title := "Room Cleared — Rank %s" % RunState.current_room_rank()
	if RunState.is_last_room():
		title = "Act Clear — Rank %s" % RunState.current_room_rank()
		loot_line = "%s — then finish the run" % loot_line
	_skin_panel(&"glass", Color(1.0, 0.97, 0.88, 0.97))
	_show(Mode.REWARD, title, loot_line)
	_rewards.visible = true
	_craft.visible = has_craft
	_arch.visible = false
	if _route:
		_route.visible = false
	get_tree().paused = true


func _on_style_changed(score: int, multiplier: float, rank: String) -> void:
	if _style_banner == null:
		return
	if rank == _last_style_rank:
		return
	var first := _last_style_rank == ""
	_last_style_rank = rank
	if first:
		return
	_style_banner.text = "Style  %s    ×%.1f    %d" % [rank, multiplier, score]
	_style_banner.modulate = Color.WHITE
	if _style_tween and _style_tween.is_valid():
		_style_tween.kill()
	_style_tween = create_tween()
	_style_tween.tween_interval(1.1)
	_style_tween.tween_property(_style_banner, "modulate:a", 0.0, 0.4)
	_style_tween.tween_callback(func() -> void:
		if _style_banner:
			_style_banner.text = ""
	)


func _show_route_pick() -> void:
	_ensure_route_box()
	_populate_route_pick()
	_skin_panel(&"glass", Color(0.82, 0.9, 1.0, 0.97))
	_show(Mode.ROUTE_PICK, "Choose Route", "Tutorial slice or full Acts 1–4 campaign")
	_route.visible = true
	_arch.visible = false
	_rewards.visible = false
	_craft.visible = false
	get_tree().paused = true


func _populate_route_pick() -> void:
	for node in _route_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_route_nodes.clear()
	for route in RunState.get_available_routes():
		var btn := Button.new()
		btn.text = "%s — %d rooms" % [route.display_name, route.total_rooms()]
		btn.pressed.connect(_on_route_pressed.bind(route))
		_skin_button(btn)
		_route.add_child(btn)
		_route_nodes.append(btn)


func _on_route_pressed(route: ActRoute) -> void:
	if _mode != Mode.ROUTE_PICK:
		return
	RunState.choose_route(route)
	_route.visible = false
	_show_arch_pick()


func _show_arch_pick() -> void:
	_populate_arch_pick()
	_skin_panel(&"glass", Color(0.9, 0.84, 0.62, 0.97))
	_show(Mode.ARCH_PICK, "Choose Architecture", "Defines your combat language — Q = special")
	_arch.visible = true
	if _route:
		_route.visible = false
	_rewards.visible = false
	_craft.visible = false
	get_tree().paused = true


func _populate_arch_pick() -> void:
	for node in _arch_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_arch_nodes.clear()
	# Hide legacy static buttons if present.
	for child in _arch.get_children():
		child.visible = false
	for arch in RunState.get_architectures():
		var btn := Button.new()
		var desc := arch.description if arch.description != "" else arch.display_name
		btn.text = "%s — %s" % [arch.display_name, desc]
		btn.pressed.connect(_on_arch_pressed.bind(arch))
		_skin_button(btn)
		_arch.add_child(btn)
		_arch_nodes.append(btn)


func _on_arch_pressed(arch: ArchitectureData) -> void:
	if _mode != Mode.ARCH_PICK:
		return
	RunState.choose_architecture_data(arch)
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null:
		player = _find_player()
	if player:
		RunState.apply_to_player(player)
	_mode = Mode.HIDDEN
	_panel.visible = false
	if _dimmer:
		_dimmer.visible = false
	_arch.visible = false
	if _route:
		_route.visible = false
	get_tree().paused = false


func _find_player() -> Player:
	var root := get_tree().current_scene
	if root == null:
		return null
	return root.find_child("Player", true, false) as Player


func _populate_craft() -> bool:
	for node in _craft_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_craft_nodes.clear()
	var upgrades := RunState.get_craftable_upgrades()
	if upgrades.is_empty():
		_craft.visible = false
		return false
	var cap := mini(upgrades.size(), 3)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_craft.add_child(row)
	_craft_nodes.append(row)
	for i in cap:
		var card := _make_boon_card(upgrades[i], 0, _on_craft.bind(upgrades[i]))
		card.custom_minimum_size = Vector2(200, 176)
		row.add_child(card)
	return true


func _populate_reward_upgrades() -> void:
	for node in _reward_extra_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_reward_extra_nodes.clear()
	_offer_buttons.clear()
	for child in _rewards.get_children():
		child.visible = false
	var offers := RunState.roll_boon_offers(3)
	if offers.is_empty():
		var empty := Label.new()
		empty.text = "No artifacts remain — take a craft or skip"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_rewards.add_child(empty)
		_reward_extra_nodes.append(empty)
		var skip := Button.new()
		skip.text = "Continue"
		skip.pressed.connect(_finish_reward)
		_skin_button(skip)
		_rewards.add_child(skip)
		_reward_extra_nodes.append(skip)
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_rewards.add_child(row)
	_reward_extra_nodes.append(row)
	for i in offers.size():
		var card := _make_boon_card(offers[i], i + 1)
		row.add_child(card)
		_offer_buttons.append(card)


func _make_boon_card(upgrade: UpgradeData, hotkey: int = 0, on_pick: Callable = Callable()) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(228, 268)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.text = ""
	btn.clip_text = false
	var tint := UpgradeData.rarity_color(upgrade.rarity)
	var house_c := UpgradeData.house_color(upgrade.house)
	btn.add_theme_stylebox_override("normal", _card_style(tint, Color(0.92, 0.94, 1.0, 1)))
	btn.add_theme_stylebox_override("hover", _card_style(tint.lightened(0.18), Color(1.05, 1.05, 1.08, 1)))
	btn.add_theme_stylebox_override("pressed", _card_style(house_c, Color(0.9, 0.9, 1.0, 1)))
	if on_pick.is_valid():
		btn.pressed.connect(on_pick)
	else:
		btn.pressed.connect(_on_reward_upgrade.bind(upgrade))
	var pad := MarginContainer.new()
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	pad.add_theme_constant_override("margin_left", 14)
	pad.add_theme_constant_override("margin_right", 14)
	pad.add_theme_constant_override("margin_top", 14)
	pad.add_theme_constant_override("margin_bottom", 14)
	btn.add_child(pad)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 6)
	pad.add_child(col)
	var key := Label.new()
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key.text = "[ %d ]" % hotkey if hotkey > 0 else ""
	key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key.add_theme_font_size_override("font_size", 12)
	key.add_theme_color_override("font_color", Color(0.78, 0.82, 0.9))
	var key_font := ArtBank.body_bold()
	if key_font:
		key.add_theme_font_override("font", key_font)
	col.add_child(key)
	var meta := Label.new()
	meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meta.text = "%s · %s" % [UpgradeData.rarity_name(upgrade.rarity), UpgradeData.house_name(upgrade.house)]
	meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	meta.add_theme_font_size_override("font_size", 12)
	meta.add_theme_color_override("font_color", tint.lightened(0.25))
	var meta_font := ArtBank.body_font()
	if meta_font:
		meta.add_theme_font_override("font", meta_font)
	col.add_child(meta)
	var title := Label.new()
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.text = upgrade.display_name
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.96, 0.97, 1.0))
	var title_font := ArtBank.body_heavy()
	if title_font:
		title.add_theme_font_override("font", title_font)
	col.add_child(title)
	var desc := Label.new()
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc.text = upgrade.description
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc.add_theme_font_size_override("font_size", 13)
	desc.add_theme_color_override("font_color", Color(0.78, 0.82, 0.9))
	var desc_font := ArtBank.body_font()
	if desc_font:
		desc.add_theme_font_override("font", desc_font)
	col.add_child(desc)
	return btn


func _card_style(border: Color, bg: Color) -> StyleBox:
	var tint := border.lerp(bg, 0.35)
	var sb := ArtBank.nine_slice(ArtBank.CARD_BORDER, 22.0, tint)
	if sb:
		sb.content_margin_left = 16
		sb.content_margin_right = 16
		sb.content_margin_top = 18
		sb.content_margin_bottom = 16
		return sb
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(3)
	s.set_corner_radius_all(10)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 14
	s.content_margin_bottom = 14
	s.shadow_color = Color(0, 0, 0, 0.4)
	s.shadow_size = 6
	return s


func _handle_reward_hotkeys(event: InputEvent) -> void:
	if event is not InputEventKey or not event.pressed or event.echo:
		return
	var idx := -1
	match (event as InputEventKey).physical_keycode:
		KEY_1, KEY_KP_1:
			idx = 0
		KEY_2, KEY_KP_2:
			idx = 1
		KEY_3, KEY_KP_3:
			idx = 2
		_:
			return
	if idx < 0 or idx >= _offer_buttons.size():
		return
	var btn := _offer_buttons[idx]
	if btn == null or not is_instance_valid(btn):
		return
	get_viewport().set_input_as_handled()
	btn.emit_signal("pressed")


func _on_combo_unlocked(combo_name: String, description: String) -> void:
	_show_combo_toast(combo_name, description)


func _on_combo_proc(combo_name: String, description: String) -> void:
	_show_combo_toast(combo_name, description)


func _on_synergy_triggered(_target: Node, recipe_id: StringName) -> void:
	_show_combo_toast(ArtifactCombos.synergy_title(recipe_id), ArtifactCombos.synergy_blurb(recipe_id))


func _on_reward_upgrade(upgrade: UpgradeData) -> void:
	if _mode != Mode.REWARD:
		return
	if not RunState.grant_upgrade(upgrade):
		return
	var player := _find_player()
	if player:
		RunState.apply_to_player(player)
	_finish_reward()


func _on_craft(upgrade: UpgradeData) -> void:
	if _mode != Mode.REWARD:
		return
	if not RunState.craft_upgrade(upgrade):
		return
	var player := _find_player()
	if player:
		RunState.apply_to_player(player)
	_finish_reward()


func _on_pick_damage() -> void:
	_take_modifier(&"damage")


func _on_pick_speed() -> void:
	_take_modifier(&"speed")


func _on_pick_dash() -> void:
	_take_modifier(&"dash")


func _take_modifier(id: StringName) -> void:
	if _mode != Mode.REWARD:
		return
	RunState.choose_modifier(id)
	_finish_reward()


func _finish_reward() -> void:
	if _finishing_reward:
		return
	_finishing_reward = true
	_mode = Mode.HIDDEN
	var hold_toast := _combo_toast != null and _combo_toast.visible and _combo_toast.modulate.a > 0.35
	if hold_toast:
		get_tree().paused = true
		await get_tree().create_timer(3.1, true, false, true).timeout
	_panel.visible = false
	if _dimmer:
		_dimmer.visible = false
	_rewards.visible = false
	_craft.visible = false
	for node in _reward_extra_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_reward_extra_nodes.clear()
	RunState.finish_room_reward()
	_finishing_reward = false


func is_reward_open() -> bool:
	return _mode == Mode.REWARD


func is_run_over() -> bool:
	return _mode == Mode.DEATH or _mode == Mode.WIN


func try_autopilot_reward() -> bool:
	if _mode != Mode.REWARD or _offer_buttons.is_empty():
		return false
	var btn := _offer_buttons[0]
	if btn == null or not is_instance_valid(btn):
		return false
	btn.emit_signal("pressed")
	return true


func _show(mode: Mode, title: String, subtitle: String) -> void:
	_mode = mode
	_title.text = title
	_subtitle.text = subtitle
	_panel.visible = true
	_fit_panel(mode)
	if _dimmer:
		_dimmer.visible = true
		_dimmer.color = Color(0.02, 0.03, 0.05, 0.62)
	_rewards.visible = mode == Mode.REWARD
	_craft.visible = mode == Mode.REWARD
	_arch.visible = mode == Mode.ARCH_PICK
	if _route:
		_route.visible = mode == Mode.ROUTE_PICK
	if mode != Mode.DEATH and mode != Mode.WIN:
		_clear_end_nodes()
	if mode != Mode.WIN:
		_clear_win_nodes()


func _fit_panel(mode: Mode) -> void:
	if _panel == null:
		return
	match mode:
		Mode.REWARD:
			_panel.custom_minimum_size = Vector2(960, 520)
		Mode.DEATH:
			_panel.custom_minimum_size = Vector2(560, 280)
		Mode.WIN:
			_panel.custom_minimum_size = Vector2(640, 340)
		Mode.ROUTE_PICK, Mode.ARCH_PICK:
			_panel.custom_minimum_size = Vector2(720, 420)
		_:
			_panel.custom_minimum_size = Vector2(560, 240)


func _clear_end_nodes() -> void:
	for node in _end_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_end_nodes.clear()


func _clear_win_nodes() -> void:
	for node in _win_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_win_nodes.clear()


func _populate_end_actions() -> void:
	_clear_end_nodes()
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	_vbox.add_child(row)
	_end_nodes.append(row)
	var again := Button.new()
	again.text = "New run"
	again.pressed.connect(func() -> void: RunState.restart_run())
	_skin_button(again, Color(1.0, 0.9, 0.45, 1))
	row.add_child(again)
	var classes := Button.new()
	classes.text = "Class select"
	classes.pressed.connect(func() -> void: RunState.return_to_class_select())
	_skin_button(classes, Color(0.85, 0.9, 1.0, 1))
	row.add_child(classes)


func _populate_win_relics() -> void:
	_clear_win_nodes()
	var names: PackedStringArray = []
	for upgrade in RunState.crafted_upgrades:
		if upgrade:
			names.append(upgrade.display_name)
	var wrap := HBoxContainer.new()
	wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	wrap.add_theme_constant_override("separation", 8)
	_vbox.add_child(wrap)
	_vbox.move_child(wrap, _subtitle.get_index() + 1)
	_win_nodes.append(wrap)
	if names.is_empty():
		var empty := Label.new()
		empty.text = "No relics this run"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var font := ArtBank.body_font()
		if font:
			empty.add_theme_font_override("font", font)
		empty.add_theme_font_size_override("font_size", 14)
		empty.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85))
		wrap.add_child(empty)
		return
	for relic_name in names:
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", ArtBank.panel_style(&"card", Color(0.95, 0.88, 0.55, 0.95)))
		var lab := Label.new()
		lab.text = relic_name
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.add_theme_font_size_override("font_size", 13)
		lab.add_theme_color_override("font_color", Color(0.12, 0.1, 0.08))
		var font := ArtBank.body_font()
		if font:
			lab.add_theme_font_override("font", font)
		chip.add_child(lab)
		wrap.add_child(chip)
