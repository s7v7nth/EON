extends CanvasLayer
## Debug bars driven only by SignalBus — no direct entity refs.

@onready var health_bar: ProgressBar = $Margin/VBox/HealthBar
@onready var energy_bar: ProgressBar = $Margin/VBox/EnergyBar
@onready var adrenaline_bar: ProgressBar = $Margin/VBox/AdrenalineBar
@onready var style_label: Label = $Margin/VBox/StyleLabel
@onready var status_label: Label = $Margin/VBox/StatusLabel
@onready var arch_label: Label = $Margin/VBox/ArchLabel
@onready var biome_label: Label = $Margin/VBox/BiomeLabel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var weapon_label := get_node_or_null("Margin/VBox/WeaponLabel")
	if weapon_label:
		weapon_label.visible = false
	SignalBus.player_health_changed.connect(_on_health_changed)
	SignalBus.player_energy_changed.connect(_on_energy_changed)
	SignalBus.player_adrenaline_changed.connect(_on_adrenaline_changed)
	SignalBus.player_died.connect(_on_player_died)
	SignalBus.style_score_changed.connect(_on_style_changed)
	SignalBus.player_statuses_changed.connect(_on_statuses_changed)
	SignalBus.architecture_changed.connect(_on_architecture_changed)
	SignalBus.biome_changed.connect(_on_biome_changed)


func _on_health_changed(current: float, max_value: float) -> void:
	health_bar.max_value = max_value
	health_bar.value = current


func _on_energy_changed(current: float, max_value: float) -> void:
	energy_bar.max_value = max_value
	energy_bar.value = current


func _on_adrenaline_changed(current: float, max_value: float) -> void:
	adrenaline_bar.max_value = max_value
	adrenaline_bar.value = current


func _on_style_changed(score: int, multiplier: float, rank: String) -> void:
	if style_label:
		style_label.text = "Style %s  x%.1f  %d pts" % [rank, multiplier, score]


func _on_statuses_changed(statuses: PackedStringArray) -> void:
	if status_label:
		status_label.text = "Status: %s" % (", ".join(statuses) if not statuses.is_empty() else "—")


func _on_architecture_changed(architecture_id: int) -> void:
	if arch_label:
		arch_label.text = "Arch: %s" % GameplayEnums.architecture_name(architecture_id as GameplayEnums.ArchitectureId)


func _on_biome_changed(biome_id: int) -> void:
	if biome_label:
		biome_label.text = "Biome: %s" % _biome_name(biome_id)


func _biome_name(biome_id: int) -> String:
	match biome_id as GameplayEnums.BiomeId:
		GameplayEnums.BiomeId.JUNGLE:
			return "Jungle"
		GameplayEnums.BiomeId.DATA_CENTER:
			return "Data Center"
		GameplayEnums.BiomeId.DOWNTOWN:
			return "Downtown"
		GameplayEnums.BiomeId.RESIDENTIAL:
			return "Residential"
		GameplayEnums.BiomeId.TAIGA:
			return "Taiga"
		GameplayEnums.BiomeId.ALLEY:
			return "Alleys"
		GameplayEnums.BiomeId.LANDFILL:
			return "Landfill"
		GameplayEnums.BiomeId.MALL:
			return "Mall"
		GameplayEnums.BiomeId.WASTELAND:
			return "Wasteland"
		GameplayEnums.BiomeId.GATEWAY:
			return "Gateway"
	return "Unknown"


func _on_player_died() -> void:
	print("Player died")
