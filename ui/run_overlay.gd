extends CanvasLayer
## Death / wave / win / reward overlay. Always processes while tree is paused.

enum Mode { HIDDEN, DEATH, WAVE_BANNER, WIN, REWARD }

var _mode: Mode = Mode.HIDDEN

@onready var _panel: PanelContainer = $Center/Panel
@onready var _title: Label = $Center/Panel/Margin/VBox/Title
@onready var _subtitle: Label = $Center/Panel/Margin/VBox/Subtitle
@onready var _wave_label: Label = $WaveLabel
@onready var _rewards: VBoxContainer = $Center/Panel/Margin/VBox/Rewards


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel.visible = false
	_rewards.visible = false
	_wave_label.text = ""
	SignalBus.player_died.connect(_on_player_died)
	SignalBus.wave_started.connect(_on_wave_started)
	SignalBus.wave_cleared.connect(_on_wave_cleared)
	SignalBus.run_won.connect(_on_run_won)
	SignalBus.exit_reached.connect(_on_exit_reached)
	_rewards.get_node("BtnDamage").pressed.connect(_on_pick_damage)
	_rewards.get_node("BtnSpeed").pressed.connect(_on_pick_speed)
	_rewards.get_node("BtnDash").pressed.connect(_on_pick_dash)


func _unhandled_input(event: InputEvent) -> void:
	if _mode == Mode.DEATH or _mode == Mode.WIN:
		if event.is_action_pressed("restart") or _is_restart_key(event):
			RunState.restart_run()
			get_viewport().set_input_as_handled()


func _is_restart_key(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		return (event as InputEventKey).physical_keycode == KEY_R
	return false


func _on_player_died() -> void:
	_show(Mode.DEATH, "You Died", "Press R to restart")
	get_tree().paused = true


func _on_wave_started(index: int, total: int) -> void:
	_wave_label.text = "Room %d — Wave %d / %d" % [RunState.room_index + 1, index + 1, total]


func _on_wave_cleared(index: int) -> void:
	_wave_label.text = "Wave %d cleared" % [index + 1]


func _on_run_won() -> void:
	_show(Mode.WIN, "Run Complete", "Press R to start a new run")
	_rewards.visible = false
	get_tree().paused = true


func _on_exit_reached() -> void:
	if RunState.is_last_room():
		return
	_show(Mode.REWARD, "Room Cleared", "Choose a boon")
	_rewards.visible = true
	get_tree().paused = true


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
	_mode = Mode.HIDDEN
	_panel.visible = false
	_rewards.visible = false
	RunState.advance_to_next_room()


func _show(mode: Mode, title: String, subtitle: String) -> void:
	_mode = mode
	_title.text = title
	_subtitle.text = subtitle
	_panel.visible = true
	_rewards.visible = mode == Mode.REWARD
