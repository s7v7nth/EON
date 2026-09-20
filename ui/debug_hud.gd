extends CanvasLayer
## Combat HUD driven only by SignalBus — no direct entity refs.

const HP_FILL := Color(0.92, 0.22, 0.28, 1)
const HP_FILL_LOW := Color(1.0, 0.45, 0.12, 1)
const ENERGY_FILL := Color(0.28, 0.62, 0.98, 1)
const ADRENALINE_FILL := Color(0.98, 0.78, 0.18, 1)

@onready var health_bar: ProgressBar = $Margin/VBox/HealthBar
@onready var energy_bar: ProgressBar = $Margin/VBox/EnergyBar
@onready var adrenaline_bar: ProgressBar = $Margin/VBox/AdrenalineBar
@onready var style_label: Label = $Margin/VBox/StyleLabel
@onready var status_label: Label = $Margin/VBox/StatusLabel
@onready var arch_label: Label = $Margin/VBox/ArchLabel
@onready var biome_label: Label = $Margin/VBox/BiomeLabel
@onready var damage_label: Label = $Margin/VBox/DamageLabel
@onready var location_banner: Label = $LocationBanner

var _primary_label: Label
var _secondary_label: Label
var _hp_label: Label
var _economy_drives_bars: bool = false
var _last_damage: float = 0.0
var _total_damage: float = 0.0
var _last_hp: float = -1.0
var _seed_label: Label
var _artifact_label: Label
var _hp_flash: Tween
var _gold_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_wrap_hud_chrome()
	_style_bar(health_bar, HP_FILL)
	_style_bar(energy_bar, ENERGY_FILL)
	_style_bar(adrenaline_bar, ADRENALINE_FILL)
	health_bar.modulate = Color.WHITE
	energy_bar.modulate = Color.WHITE
	adrenaline_bar.modulate = Color.WHITE
	_paint_label(location_banner, 20, Color(0.94, 0.96, 1.0, 0.98))
	_paint_label(style_label, 14, Color(1.0, 0.86, 0.42))
	_paint_label(status_label, 13, Color(0.82, 0.86, 0.92))
	_paint_label(arch_label, 13, Color(0.78, 0.82, 0.9))
	_paint_label(biome_label, 13, Color(0.78, 0.82, 0.9))
	_paint_label(damage_label, 13, Color(0.95, 0.7, 0.55))
	var weapon_label := health_bar.get_parent().get_node_or_null("WeaponLabel")
	if weapon_label:
		weapon_label.visible = false
	_hp_label = Label.new()
	_hp_label.name = "HealthValue"
	_paint_label(_hp_label, 14, Color(1.0, 0.93, 0.93))
	_hp_label.text = "HP  — / —"
	health_bar.get_parent().add_child(_hp_label)
	health_bar.get_parent().move_child(_hp_label, health_bar.get_index())
	_primary_label = Label.new()
	_paint_label(_primary_label, 12, Color(0.75, 0.86, 1.0))
	_primary_label.text = "Energy"
	energy_bar.get_parent().add_child(_primary_label)
	energy_bar.get_parent().move_child(_primary_label, energy_bar.get_index())
	_secondary_label = Label.new()
	_paint_label(_secondary_label, 12, Color(1.0, 0.88, 0.45))
	_secondary_label.text = "Adrenaline"
	adrenaline_bar.get_parent().add_child(_secondary_label)
	adrenaline_bar.get_parent().move_child(_secondary_label, adrenaline_bar.get_index())
	_seed_label = Label.new()
	_paint_label(_seed_label, 12, Color(0.7, 0.74, 0.82))
	_seed_label.text = "Seed: —"
	health_bar.get_parent().add_child(_seed_label)
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
	SignalBus.room_entered.connect(_on_room_entered)
	_refresh_damage_label()
	call_deferred("_refresh_location_from_run_state")
	call_deferred("_refresh_seed_label")
	_ensure_artifact_label()
	_ensure_gold_label()
	SignalBus.upgrade_crafted.connect(_on_upgrade_crafted)
	SignalBus.combo_unlocked.connect(_on_combo_hud)
	SignalBus.gold_changed.connect(_on_gold_changed)


func _wrap_hud_chrome() -> void:
	var margin := $Margin as MarginContainer
	var vbox := $Margin/VBox as VBoxContainer
	if margin == null or vbox == null or vbox.get_parent() is PanelContainer:
		return
	var chrome := PanelContainer.new()
	chrome.name = "Chrome"
	chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.04, 0.07, 0.78)
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(1)
	sb.border_color = Color(0.55, 0.62, 0.78, 0.45)
	sb.content_margin_left = 10
	sb.content_margin_top = 8
	sb.content_margin_right = 10
	sb.content_margin_bottom = 8
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 8
	chrome.add_theme_stylebox_override("panel", sb)
	margin.remove_child(vbox)
	chrome.add_child(vbox)
	margin.add_child(chrome)


func _style_bar(bar: ProgressBar, fill: Color) -> void:
	if bar == null:
		return
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.07, 0.08, 0.11, 0.95)
	bg.set_corner_radius_all(4)
	bg.set_border_width_all(1)
	bg.border_color = Color(0.0, 0.0, 0.0, 0.75)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	fg.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)
	bar.modulate = Color.WHITE
	bar.show_percentage = false


func _paint_label(label: Label, size: int, color: Color) -> void:
	if label == null:
		return
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	label.add_theme_constant_override("outline_size", 5)
	var font := ArtBank.ui_font()
	if font:
		label.add_theme_font_override("font", font)


func _on_room_entered(_coord: Vector2i) -> void:
	_refresh_seed_label()


func _refresh_seed_label() -> void:
	if _seed_label == null:
		return
	if RunState.is_procedural_run() and RunState.run_seed != 0:
		var coord := RunState.current_coord
		_seed_label.text = "Seed: %d  @%d,%d" % [RunState.run_seed, coord.x, coord.y]
	else:
		_seed_label.text = "Seed: —"


func _on_health_changed(current: float, max_value: float) -> void:
	health_bar.max_value = max_value
	health_bar.value = current
	if _hp_label:
		_hp_label.text = "HP  %d / %d" % [roundi(current), roundi(max_value)]
	var ratio := current / max_value if max_value > 0.0 else 0.0
	_style_bar(health_bar, HP_FILL_LOW if ratio <= 0.32 else HP_FILL)
	if _last_hp >= 0.0 and current < _last_hp:
		_flash_hurt()
	_last_hp = current


func _flash_hurt() -> void:
	if _hp_label == null:
		return
	if _hp_flash and _hp_flash.is_valid():
		_hp_flash.kill()
	_hp_label.modulate = Color(1.0, 0.45, 0.35)
	_hp_flash = create_tween()
	_hp_flash.tween_property(_hp_label, "modulate", Color.WHITE, 0.28)


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
		_style_bar(bar, data["color"] as Color)


func _on_style_changed(score: int, multiplier: float, rank: String) -> void:
	if style_label:
		style_label.text = "Style %s  x%.1f  %d pts" % [rank, multiplier, score]


func _on_statuses_changed(statuses: PackedStringArray) -> void:
	if status_label == null:
		return
	if statuses.is_empty():
		status_label.text = "Status: —"
		_paint_label(status_label, 13, Color(0.82, 0.86, 0.92))
		return
	status_label.text = "Status: %s" % ", ".join(statuses)
	_paint_label(status_label, 13, Color(1.0, 0.82, 0.28))


func _on_architecture_changed(architecture_id: int) -> void:
	if arch_label:
		arch_label.text = "Arch: %s" % GameplayEnums.architecture_name(architecture_id as GameplayEnums.ArchitectureId)


func _on_biome_changed(biome_id: int) -> void:
	var loc := _location_display_name(biome_id)
	if biome_label:
		biome_label.text = "Biome: %s" % loc
	if location_banner:
		location_banner.text = loc
	_refresh_seed_label()


func _refresh_location_from_run_state() -> void:
	if RunState.current_biome:
		_on_biome_changed(RunState.current_biome.biome_id)


func _location_display_name(biome_id: int) -> String:
	if RunState.current_biome and int(RunState.current_biome.biome_id) == biome_id:
		var named := RunState.current_biome.display_name
		if named != "":
			return named
	return _biome_name(biome_id)


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


func _ensure_artifact_label() -> void:
	if _artifact_label:
		return
	_artifact_label = Label.new()
	_paint_label(_artifact_label, 13, Color(0.82, 0.9, 1.0))
	_artifact_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_artifact_label.custom_minimum_size = Vector2(280, 44)
	_artifact_label.text = "Artifacts: —"
	health_bar.get_parent().add_child(_artifact_label)
	_refresh_artifacts()


func _on_upgrade_crafted(_id: StringName) -> void:
	_refresh_artifacts()


func _on_combo_hud(combo_name: String, _desc: String) -> void:
	if _artifact_label:
		_artifact_label.text = "COMBO %s\n%s" % [combo_name, _artifact_line()]
		return
	_refresh_artifacts()


func _refresh_artifacts() -> void:
	if _artifact_label == null:
		return
	_artifact_label.text = _artifact_line()


func _artifact_line() -> String:
	var names: PackedStringArray = []
	for upgrade in RunState.crafted_upgrades:
		if upgrade:
			names.append(upgrade.display_name)
	if names.is_empty():
		return "Artifacts: —"
	if names.size() > 6:
		var shown: PackedStringArray = PackedStringArray()
		for i in 6:
			shown.append(names[i])
		return "Artifacts (%d): %s…" % [names.size(), ", ".join(shown)]
	return "Artifacts: %s" % ", ".join(names)


func _ensure_gold_label() -> void:
	if _gold_label:
		return
	var row := HBoxContainer.new()
	row.name = "GoldRow"
	row.add_theme_constant_override("separation", 6)
	var coin := TextureRect.new()
	coin.custom_minimum_size = Vector2(18, 18)
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin.texture = ArtBank.shooter("bolt_gold")
	if coin.texture == null:
		coin.texture = ArtBank.icon("star")
	row.add_child(coin)
	_gold_label = Label.new()
	_gold_label.name = "GoldLabel"
	_paint_label(_gold_label, 16, Color(1.0, 0.86, 0.32))
	_gold_label.text = "Gold  0"
	row.add_child(_gold_label)
	health_bar.get_parent().add_child(row)
	health_bar.get_parent().move_child(row, 0)
	_on_gold_changed(RunState.gold)


func _on_gold_changed(amount: int) -> void:
	if _gold_label:
		_gold_label.text = "Gold  %d" % amount
