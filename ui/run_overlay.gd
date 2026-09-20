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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel.visible = false
	_rewards.visible = false
	_craft.visible = false
	_arch.visible = false
	_ensure_route_box()
	_route.visible = false
	_wave_label.text = ""
	if _style_banner:
		_style_banner.text = ""
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
	_ensure_boss_banner()
	SignalBus.boss_spawned.connect(_on_boss_spawned)
	SignalBus.boss_phase.connect(_on_boss_phase)
	var font := ArtBank.ui_font()
	if font:
		_title.add_theme_font_override("font", font)
		_wave_label.add_theme_font_override("font", font)
		if _style_banner:
			_style_banner.add_theme_font_override("font", font)


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


func _ensure_boss_banner() -> void:
	_boss_banner = get_node_or_null("BossBanner") as Label
	if _boss_banner:
		return
	_boss_banner = Label.new()
	_boss_banner.name = "BossBanner"
	_boss_banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_boss_banner.offset_top = 72.0
	_boss_banner.offset_bottom = 128.0
	_boss_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_banner.add_theme_font_size_override("font_size", 34)
	_boss_banner.add_theme_color_override("font_color", Color(1.0, 0.32, 0.28))
	_boss_banner.add_theme_color_override("font_outline_color", Color(0.05, 0, 0, 0.95))
	_boss_banner.add_theme_constant_override("outline_size", 8)
	var font := ArtBank.title_font()
	if font:
		_boss_banner.add_theme_font_override("font", font)
	_boss_banner.text = ""
	add_child(_boss_banner)


func _on_boss_spawned(boss_name: String) -> void:
	_flash_boss_banner("BOSS  —  %s" % boss_name.to_upper(), Color(1.0, 0.32, 0.28))


func _on_boss_phase(phase: int, boss_name: String) -> void:
	_flash_boss_banner("PHASE %d  —  %s" % [phase, boss_name.to_upper()], Color(1.0, 0.55, 0.2))


func _flash_boss_banner(text: String, color: Color) -> void:
	if _boss_banner == null:
		_ensure_boss_banner()
	_boss_banner.text = text
	_boss_banner.add_theme_color_override("font_color", color)
	_boss_banner.modulate = Color.WHITE
	if _boss_tween and _boss_tween.is_valid():
		_boss_tween.kill()
	_boss_tween = create_tween()
	_boss_tween.tween_interval(1.8)
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
	_show(Mode.DEATH, "You Died", "Rank %s — R new run (same class) · C change class" % RunState.current_room_rank())
	get_tree().paused = true


func _on_wave_started(index: int, total: int) -> void:
	_wave_label.text = "Room %d/%d — Wave %d / %d" % [
		RunState.room_index + 1, RunState.room_count(), index + 1, total
	]


func _on_wave_cleared(index: int) -> void:
	_wave_label.text = "Wave %d cleared — Rank %s" % [index + 1, RunState.current_room_rank()]


func _on_run_won() -> void:
	_show(Mode.WIN, "Run Complete", "Style %s — %d pts — R again · C class select" % [
		RunState.current_room_rank(), RunState.style_score
	])
	_rewards.visible = false
	_craft.visible = false
	_arch.visible = false
	if _route:
		_route.visible = false
	get_tree().paused = true


func _on_exit_reached() -> void:
	_populate_craft()
	_populate_reward_upgrades()
	var loot_line := "Choose one artifact — click a card or press 1 / 2 / 3"
	if not RunState.last_loot.is_empty():
		loot_line = "Loot: %s — then pick an artifact (1–3)" % RunState.loot_summary()
	if RunState.last_combo_name != "":
		loot_line = "COMBO %s — %s" % [RunState.last_combo_name, loot_line]
	var title := "Room Cleared — Rank %s" % RunState.current_room_rank()
	if RunState.is_last_room():
		title = "Act Clear — Rank %s" % RunState.current_room_rank()
		loot_line = "%s — then finish the run" % loot_line
	_show(Mode.REWARD, title, loot_line)
	_rewards.visible = true
	_craft.visible = true
	_arch.visible = false
	if _route:
		_route.visible = false
	get_tree().paused = true


func _on_style_changed(score: int, multiplier: float, rank: String) -> void:
	if _style_banner:
		_style_banner.text = "STYLE %s  x%.1f  %d" % [rank, multiplier, score]


func _show_route_pick() -> void:
	_ensure_route_box()
	_populate_route_pick()
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
	_arch.visible = false
	if _route:
		_route.visible = false
	get_tree().paused = false


func _find_player() -> Player:
	var root := get_tree().current_scene
	if root == null:
		return null
	return root.find_child("Player", true, false) as Player


func _populate_craft() -> void:
	for node in _craft_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_craft_nodes.clear()
	var upgrades := RunState.get_craftable_upgrades()
	if upgrades.is_empty():
		var empty := Label.new()
		empty.text = "No crafts available (need tags/arch)"
		_craft.add_child(empty)
		_craft_nodes.append(empty)
		return
	for upgrade in upgrades:
		var btn := Button.new()
		btn.text = "%s — %s" % [upgrade.display_name, upgrade.description]
		btn.pressed.connect(_on_craft.bind(upgrade))
		_craft.add_child(btn)
		_craft_nodes.append(btn)


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


func _make_boon_card(upgrade: UpgradeData, hotkey: int = 0) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(210, 248)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var house := UpgradeData.house_name(upgrade.house)
	var rare := UpgradeData.rarity_name(upgrade.rarity)
	var key_line := "[ %d ]" % hotkey if hotkey > 0 else ""
	btn.text = "%s\n%s · %s\n\n%s\n\n%s" % [key_line, rare, house, upgrade.display_name, upgrade.description]
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var tint := UpgradeData.rarity_color(upgrade.rarity)
	var house_c := UpgradeData.house_color(upgrade.house)
	btn.add_theme_color_override("font_color", Color(0.94, 0.96, 1.0))
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_font_size_override("font_size", 15)
	btn.add_theme_stylebox_override("normal", _card_style(tint, Color(0.06, 0.07, 0.11, 0.96)))
	btn.add_theme_stylebox_override("hover", _card_style(tint.lightened(0.18), Color(0.12, 0.13, 0.2, 0.98)))
	btn.add_theme_stylebox_override("pressed", _card_style(house_c, Color(0.16, 0.17, 0.24, 1)))
	btn.pressed.connect(_on_reward_upgrade.bind(upgrade))
	return btn


func _card_style(border: Color, bg: Color) -> StyleBoxFlat:
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
	if _style_banner:
		_style_banner.text = "COMBO  %s  —  %s" % [combo_name, description]


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
	_mode = Mode.HIDDEN
	_panel.visible = false
	_rewards.visible = false
	_craft.visible = false
	for node in _reward_extra_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_reward_extra_nodes.clear()
	RunState.finish_room_reward()


func _show(mode: Mode, title: String, subtitle: String) -> void:
	_mode = mode
	_title.text = title
	_subtitle.text = subtitle
	_panel.visible = true
	_rewards.visible = mode == Mode.REWARD
	_craft.visible = mode == Mode.REWARD
	_arch.visible = mode == Mode.ARCH_PICK
	if _route:
		_route.visible = mode == Mode.ROUTE_PICK
