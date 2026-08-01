extends CanvasLayer
## Death / wave / win / reward / craft overlay. Always processes while tree is paused.

enum Mode { HIDDEN, DEATH, WAVE_BANNER, WIN, REWARD, ARCH_PICK }

var _mode: Mode = Mode.HIDDEN
var _craft_nodes: Array[Node] = []

@onready var _panel: PanelContainer = $Center/Panel
@onready var _title: Label = $Center/Panel/Margin/VBox/Title
@onready var _subtitle: Label = $Center/Panel/Margin/VBox/Subtitle
@onready var _wave_label: Label = $WaveLabel
@onready var _style_banner: Label = $StyleBanner
@onready var _rewards: VBoxContainer = $Center/Panel/Margin/VBox/Rewards
@onready var _craft: VBoxContainer = $Center/Panel/Margin/VBox/Craft
@onready var _arch: VBoxContainer = $Center/Panel/Margin/VBox/ArchPick


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel.visible = false
	_rewards.visible = false
	_craft.visible = false
	_arch.visible = false
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
	_arch.get_node("BtnDefault").pressed.connect(_on_arch_default)
	_arch.get_node("BtnNano").pressed.connect(_on_arch_nano)
	_arch.get_node("BtnTrain").pressed.connect(_on_arch_train)
	# Offer architecture pick at run start once.
	if RunState.room_index == 0 and not RunState.architecture_picked:
		call_deferred("_show_arch_pick")


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


func _on_player_died() -> void:
	_show(Mode.DEATH, "You Died", "Rank %s — Press R to restart" % RunState.current_room_rank())
	get_tree().paused = true


func _on_wave_started(index: int, total: int) -> void:
	_wave_label.text = "Room %d — Wave %d / %d" % [RunState.room_index + 1, index + 1, total]


func _on_wave_cleared(index: int) -> void:
	_wave_label.text = "Wave %d cleared — Rank %s" % [index + 1, RunState.current_room_rank()]


func _on_run_won() -> void:
	_show(Mode.WIN, "Run Complete", "Style %s — %d pts — Press R" % [
		RunState.current_room_rank(), RunState.style_score
	])
	_rewards.visible = false
	_craft.visible = false
	_arch.visible = false
	get_tree().paused = true


func _on_exit_reached() -> void:
	if RunState.is_last_room():
		return
	_populate_craft()
	_show(Mode.REWARD, "Room Cleared — Rank %s" % RunState.current_room_rank(), "Craft or take a boon")
	_rewards.visible = true
	_craft.visible = true
	_arch.visible = false
	get_tree().paused = true


func _on_style_changed(score: int, multiplier: float, rank: String) -> void:
	if _style_banner:
		_style_banner.text = "STYLE %s  x%.1f  %d" % [rank, multiplier, score]


func _show_arch_pick() -> void:
	_show(Mode.ARCH_PICK, "Choose Architecture", "Defines your combat language")
	_arch.visible = true
	_rewards.visible = false
	_craft.visible = false
	get_tree().paused = true


func _on_arch_default() -> void:
	_pick_arch(GameplayEnums.ArchitectureId.DEFAULT)


func _on_arch_nano() -> void:
	_pick_arch(GameplayEnums.ArchitectureId.NANOMACHINES)


func _on_arch_train() -> void:
	_pick_arch(GameplayEnums.ArchitectureId.ELECTRO_TRAIN)


func _pick_arch(arch_id: GameplayEnums.ArchitectureId) -> void:
	if _mode != Mode.ARCH_PICK:
		return
	RunState.choose_architecture(arch_id)
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null:
		# Player may not be in a group — find in scene.
		player = _find_player()
	if player:
		RunState.apply_to_player(player)
	_mode = Mode.HIDDEN
	_panel.visible = false
	_arch.visible = false
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
	RunState.advance_to_next_room()


func _show(mode: Mode, title: String, subtitle: String) -> void:
	_mode = mode
	_title.text = title
	_subtitle.text = subtitle
	_panel.visible = true
	_rewards.visible = mode == Mode.REWARD
	_craft.visible = mode == Mode.REWARD
	_arch.visible = mode == Mode.ARCH_PICK
