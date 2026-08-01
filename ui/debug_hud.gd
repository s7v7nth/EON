extends CanvasLayer
## Debug bars driven only by SignalBus — no direct entity refs.

@onready var health_bar: ProgressBar = $Margin/VBox/HealthBar
@onready var energy_bar: ProgressBar = $Margin/VBox/EnergyBar
@onready var adrenaline_bar: ProgressBar = $Margin/VBox/AdrenalineBar


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	SignalBus.player_health_changed.connect(_on_health_changed)
	SignalBus.player_energy_changed.connect(_on_energy_changed)
	SignalBus.player_adrenaline_changed.connect(_on_adrenaline_changed)
	SignalBus.player_died.connect(_on_player_died)


func _on_health_changed(current: float, max_value: float) -> void:
	health_bar.max_value = max_value
	health_bar.value = current


func _on_energy_changed(current: float, max_value: float) -> void:
	energy_bar.max_value = max_value
	energy_bar.value = current


func _on_adrenaline_changed(current: float, max_value: float) -> void:
	adrenaline_bar.max_value = max_value
	adrenaline_bar.value = current


func _on_player_died() -> void:
	print("Player died")
	get_tree().paused = true
