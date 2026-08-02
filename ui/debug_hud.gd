extends CanvasLayer
## Debug bars driven only by SignalBus — no direct entity refs.

@onready var health_bar: ProgressBar = $Margin/VBox/HealthBar
@onready var energy_bar: ProgressBar = $Margin/VBox/EnergyBar
@onready var adrenaline_bar: ProgressBar = $Margin/VBox/AdrenalineBar
@onready var style_label: Label = $Margin/VBox/StyleLabel
@onready var status_label: Label = $Margin/VBox/StatusLabel
@onready var arch_label: Label = $Margin/VBox/ArchLabel
@onready var biome_label: Label = $Margin/VBox/BiomeLabel
@onready var damage_label: Label = $Margin/VBox/DamageLabel

var _primary_label: Label
var _secondary_label: Label
var _economy_drives_bars: bool = false
var _last_damage: float = 0.0
var _total_damage: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var weapon_label := get_node_or_null("Margin/VBox/WeaponLabel")
	if weapon_label:
		weapon_label.visible = false
	_primary_label = Label.new()
	_primary_label.add_theme_font_size_override("font_size", 11)
	_primary_label.text = "Energy"
	energy_bar.get_parent().add_child(_primary_label)
	energy_bar.get_parent().move_child(_primary_label, energy_bar.get_index())
	_secondary_label = Label.new()
	_secondary_label.add_theme_font_size_override("font_size", 11)
	_secondary_label.text = "Adrenaline"
	adrenaline_bar.get_parent().add_child(_secondary_label)
	adrenaline_bar.get_parent().move_child(_secondary_label, adrenaline_bar.get_index())
	SignalBus.player_health_changed.connect(_on_health_changed)
	SignalBus.player_energy_changed.connect(_on_energy_changed)
	SignalBus.player_adrenaline_changed.connect(_on_adrenaline_changed)
	SignalBus.player_economy_hud_changed.connect(_on_economy_hud)
	SignalBus.player_died.connect(_on_player_died)
	SignalBus.style_score_changed.connect(_on_style_changed)
	SignalBus.player_statuses_changed.connect(_on_statuses_changed)
	SignalBus.architecture_changed.connect(_on_architecture_changed)
	SignalBus.biome_changed.connect(_on_biome_changed)
	SignalBus.damage_dealt.connect(_on_damage_dealt)
	_refresh_damage_label()


func _on_health_changed(current: float, max_value: float) -> void:
	health_bar.max_value = max_value
	health_bar.value = current


func _on_energy_changed(current: float, max_value: float) -> void:
	if _economy_drives_bars:
		return
	energy_bar.max_value = max_value
	energy_bar.value = current


func _on_adrenaline_changed(current: float, max_value: float) -> void:
	if _economy_drives_bars:
		return
	adrenaline_bar.max_value = max_value
	adrenaline_bar.value = current


func _on_economy_hud(primary: Dictionary, secondary: Dictionary) -> void:
	_economy_drives_bars = true
	_apply_bar(energy_bar, _primary_label, primary)
	_apply_bar(adrenaline_bar, _secondary_label, secondary)


func _apply_bar(bar: ProgressBar, label: Label, data: Dictionary) -> void:
	if data.is_empty() or float(data.get("max", 0.0)) <= 0.0:
		bar.visible = false
		if label:
			label.visible = false
		return
	bar.visible = true
	if label:
		label.visible = true
		label.text = str(data.get("label", ""))
	bar.max_value = float(data.get("max", 100.0))
	bar.value = float(data.get("value", 0.0))
	if data.has("color"):
		bar.modulate = data["color"] as Color


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


func _on_damage_dealt(amount: float, target: Node, _source: Node) -> void:
	## Debug outgoing damage only (hits on non-player targets).
	if target is Player or amount <= 0.0:
		return
	_last_damage = amount
	_total_damage += amount
	_refresh_damage_label()


func _refresh_damage_label() -> void:
	if damage_label == null:
		return
	if _last_damage <= 0.0 and _total_damage <= 0.0:
		damage_label.text = "Dmg: —"
		return
	damage_label.text = "Dmg: %.1f  (Σ %.0f)" % [_last_damage, _total_damage]


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
	_last_damage = 0.0
	_total_damage = 0.0
	_refresh_damage_label()
	print("Player died")
