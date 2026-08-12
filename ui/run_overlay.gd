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
	# Route → architecture at run start.
	if RunState.room_index == 0 and not RunState.architecture_picked:
		call_deferred("_show_start_flow")


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
	if _mode != Mode.DEATH and _mode != Mode.WIN:
		return
	if not event.is_action_pressed("restart") and not _is_restart_key(event):
		return
	get_viewport().set_input_as_handled()
	RunState.restart_run()


func _is_restart_key(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		return (event as InputEventKey).physical_keycode == KEY_R
	return false


func _show_start_flow() -> void:
	if not RunState.route_picked:
		_show_route_pick()
	elif not RunState.architecture_picked:
		_show_arch_pick()


func _on_player_died() -> void:
	_show(Mode.DEATH, "You Died", "Rank %s — Press R to restart" % RunState.current_room_rank())
	get_tree().paused = true


func _on_wave_started(index: int, total: int) -> void:
	_wave_label.text = "Room %d/%d — Wave %d / %d" % [
		RunState.room_index + 1, RunState.room_count(), index + 1, total
	]


func _on_wave_cleared(index: int) -> void:
	_wave_label.text = "Wave %d cleared — Rank %s" % [index + 1, RunState.current_room_rank()]


func _on_run_won() -> void:
	_show(Mode.WIN, "Run Complete", "Style %s — %d pts — Press R" % [
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
	var loot_line := "Craft, Geometry upgrade, or take a boon"
	if not RunState.last_loot.is_empty():
		loot_line = "Loot: %s — craft, Geometry upgrade, or boon" % RunState.loot_summary()
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
	# Keep static boons at top; insert Geometry picks after them.
	var upgrades := RunState.get_reward_upgrades()
	if upgrades.is_empty():
		return
	var sep := Label.new()
	sep.text = "— Geometry —"
	sep.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rewards.add_child(sep)
	_reward_extra_nodes.append(sep)
	for upgrade in upgrades:
		var btn := Button.new()
		btn.text = "%s — %s" % [upgrade.display_name, upgrade.description]
		btn.pressed.connect(_on_reward_upgrade.bind(upgrade))
		_rewards.add_child(btn)
		_reward_extra_nodes.append(btn)


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
