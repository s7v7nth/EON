extends CanvasLayer
## Combat HUD — HP, resources, gold, relics, style. No debug dumps.

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
var _last_hp: float = -1.0
var _artifact_label: Label
var _hp_flash: Tween
var _gold_label: Label
var _boss_wrap: PanelContainer
var _boss_name: Label
var _boss_bar: ProgressBar
var _boss_hp_label: Label
var _last_style_rank: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_hide_debug_dumps()
	_wrap_hud_chrome()
	_wrap_location_banner()
	_style_bar(health_bar, HP_FILL)
	_style_bar(energy_bar, ENERGY_FILL)
	_style_bar(adrenaline_bar, ADRENALINE_FILL)
	health_bar.modulate = Color.WHITE
	energy_bar.modulate = Color.WHITE
	adrenaline_bar.modulate = Color.WHITE
	_paint_label(location_banner, 22, Color(0.94, 0.96, 1.0, 0.98), true)
	_paint_label(style_label, 16, Color(1.0, 0.86, 0.42))
	_paint_label(status_label, 13, Color(1.0, 0.82, 0.28))
	status_label.visible = false
	var weapon_label := health_bar.get_parent().get_node_or_null("WeaponLabel")
	if weapon_label:
		weapon_label.visible = false
	_hp_label = Label.new()
	_hp_label.name = "HealthValue"
	_paint_label(_hp_label, 15, Color(1.0, 0.93, 0.93))
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
	SignalBus.player_health_changed.connect(_on_health_changed)
	SignalBus.player_energy_changed.connect(_on_energy_changed)
	SignalBus.player_adrenaline_changed.connect(_on_adrenaline_changed)
	SignalBus.player_economy_hud_changed.connect(_on_economy_hud)
	SignalBus.player_died.connect(_on_player_died)
	SignalBus.style_score_changed.connect(_on_style_changed)
	SignalBus.player_statuses_changed.connect(_on_statuses_changed)
	SignalBus.architecture_changed.connect(_on_architecture_changed)
	SignalBus.biome_changed.connect(_on_biome_changed)
	SignalBus.room_entered.connect(_on_room_entered)
	call_deferred("_refresh_location_from_run_state")
	_ensure_artifact_label()
	_ensure_gold_label()
	_ensure_boss_bar()
	SignalBus.upgrade_crafted.connect(_on_upgrade_crafted)
	SignalBus.combo_unlocked.connect(_on_combo_hud)
	SignalBus.gold_changed.connect(_on_gold_changed)
	SignalBus.boss_spawned.connect(_on_boss_spawned)
	SignalBus.boss_health_changed.connect(_on_boss_health)
	SignalBus.boss_phase.connect(_on_boss_phase)
	SignalBus.run_won.connect(_hide_boss_bar)
	SignalBus.player_died.connect(_hide_boss_bar)


func _hide_debug_dumps() -> void:
	if arch_label:
		arch_label.visible = false
		arch_label.text = ""
	if biome_label:
		biome_label.visible = false
		biome_label.text = ""
	if damage_label:
		damage_label.visible = false
		damage_label.text = ""


func _wrap_hud_chrome() -> void:
	var margin := $Margin as MarginContainer
	var vbox := $Margin/VBox as VBoxContainer
	if margin == null or vbox == null:
		return
	var parent := vbox.get_parent()
	if parent is PanelContainer:
		return
	if parent is MarginContainer and parent.get_parent() is PanelContainer:
		return
	var chrome := PanelContainer.new()
	chrome.name = "Chrome"
	chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chrome.add_theme_stylebox_override("panel", ArtBank.panel_style(&"glass", Color(0.78, 0.82, 0.95, 0.94)))
	var inner := MarginContainer.new()
	inner.name = "ChromePad"
	inner.add_theme_constant_override("margin_left", 12)
	inner.add_theme_constant_override("margin_right", 12)
	inner.add_theme_constant_override("margin_top", 10)
	inner.add_theme_constant_override("margin_bottom", 10)
	margin.remove_child(vbox)
	inner.add_child(vbox)
	chrome.add_child(inner)
	margin.add_child(chrome)


func _wrap_location_banner() -> void:
	if location_banner == null or location_banner.get_parent() is PanelContainer:
		return
	var plaque := PanelContainer.new()
	plaque.name = "LocationChrome"
	plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plaque.set_anchors_preset(Control.PRESET_CENTER_TOP)
	plaque.anchor_left = 0.5
	plaque.anchor_right = 0.5
	plaque.offset_left = -170.0
	plaque.offset_right = 170.0
	plaque.offset_top = 14.0
	plaque.offset_bottom = 52.0
	plaque.add_theme_stylebox_override("panel", ArtBank.panel_style(&"card", Color(0.86, 0.9, 1.0, 0.94)))
	var parent := location_banner.get_parent()
	parent.remove_child(location_banner)
	plaque.add_child(location_banner)
	parent.add_child(plaque)
	location_banner.set_anchors_preset(Control.PRESET_FULL_RECT)
	location_banner.offset_left = 8.0
	location_banner.offset_right = -8.0
	location_banner.offset_top = 2.0
	location_banner.offset_bottom = -2.0
	location_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	location_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plaque.visible = location_banner.text != ""


func _style_bar(bar: ProgressBar, fill: Color) -> void:
	if bar == null:
		return
	var bg := ArtBank.panel_style(&"bar", Color(0.14, 0.16, 0.2, 0.95))
	bar.add_theme_stylebox_override("background", bg)
	var fg: StyleBox = ArtBank.nine_slice(ArtBank.BAR_GLOSS, 8.0, fill)
	if fg == null:
		var flat := StyleBoxFlat.new()
		flat.bg_color = fill
		flat.set_corner_radius_all(6)
		fg = flat
	bar.add_theme_stylebox_override("fill", fg)
	bar.modulate = Color.WHITE
	bar.show_percentage = false


func _paint_label(label: Label, size: int, color: Color, title: bool = false) -> void:
	if label == null:
		return
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	label.add_theme_constant_override("outline_size", 6 if title else 5)
	var font := ArtBank.title_font() if title else ArtBank.ui_font()
	if font:
		label.add_theme_font_override("font", font)


func _on_room_entered(_coord: Vector2i) -> void:
	_hide_boss_bar()


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
		style_label.text = "STYLE  %s   ×%.1f   %d" % [rank, multiplier, score]
		if rank != _last_style_rank and _last_style_rank != "":
			style_label.modulate = Color(1.4, 1.2, 0.6)
			var tw := create_tween()
			tw.tween_property(style_label, "modulate", Color.WHITE, 0.4)
		_last_style_rank = rank


func _on_statuses_changed(statuses: PackedStringArray) -> void:
	if status_label == null:
		return
	if statuses.is_empty():
		status_label.text = ""
		status_label.visible = false
		return
	status_label.visible = true
	status_label.text = " · ".join(statuses)
	_paint_label(status_label, 13, Color(1.0, 0.82, 0.28))


func _on_architecture_changed(_architecture_id: int) -> void:
	if arch_label:
		arch_label.visible = false


func _on_biome_changed(biome_id: int) -> void:
	var loc := _location_display_name(biome_id)
	if biome_label:
		biome_label.visible = false
	if location_banner:
		location_banner.text = loc
		var chrome := location_banner.get_parent() as CanvasItem
		if chrome and chrome != self:
			chrome.visible = loc != ""


func _refresh_location_from_run_state() -> void:
	if RunState.current_biome:
		_on_biome_changed(RunState.current_biome.biome_id)


func _location_display_name(biome_id: int) -> String:
	if RunState.current_biome and int(RunState.current_biome.biome_id) == biome_id:
		var named := RunState.current_biome.display_name
		if named != "":
			return named
	return _biome_name(biome_id)


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
	pass


func _ensure_artifact_label() -> void:
	if _artifact_label:
		return
	_artifact_label = Label.new()
	_artifact_label.name = "RelicLabel"
	_paint_label(_artifact_label, 12, Color(0.82, 0.9, 1.0))
	_artifact_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_artifact_label.custom_minimum_size = Vector2(300, 28)
	_artifact_label.text = "Relics  —"
	health_bar.get_parent().add_child(_artifact_label)
	_refresh_artifacts()


func _on_upgrade_crafted(_id: StringName) -> void:
	_refresh_artifacts()


func _on_combo_hud(combo_name: String, _desc: String) -> void:
	if _artifact_label:
		_artifact_label.text = "COMBO  %s\n%s" % [combo_name, _artifact_line()]
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
		return "Relics  —"
	if names.size() > 5:
		var shown: PackedStringArray = PackedStringArray()
		for i in 5:
			shown.append(names[i])
		return "Relics  (%d)  %s…" % [names.size(), ", ".join(shown)]
	return "Relics  %s" % ", ".join(names)


func _ensure_gold_label() -> void:
	if _gold_label:
		return
	var row := HBoxContainer.new()
	row.name = "GoldRow"
	row.add_theme_constant_override("separation", 6)
	var coin := TextureRect.new()
	coin.custom_minimum_size = Vector2(20, 20)
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin.texture = ArtBank.shooter("bolt_gold")
	if coin.texture == null:
		coin.texture = ArtBank.icon("star")
	row.add_child(coin)
	_gold_label = Label.new()
	_gold_label.name = "GoldLabel"
	_paint_label(_gold_label, 18, Color(1.0, 0.86, 0.32))
	_gold_label.text = "GOLD  0"
	row.add_child(_gold_label)
	health_bar.get_parent().add_child(row)
	health_bar.get_parent().move_child(row, 0)
	_on_gold_changed(RunState.gold)


func _on_gold_changed(amount: int) -> void:
	if _gold_label:
		_gold_label.text = "GOLD  %d" % amount


func _ensure_boss_bar() -> void:
	if _boss_wrap:
		return
	_boss_wrap = PanelContainer.new()
	_boss_wrap.name = "BossChrome"
	_boss_wrap.visible = false
	_boss_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_boss_wrap.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_boss_wrap.offset_left = 280.0
	_boss_wrap.offset_right = -280.0
	_boss_wrap.offset_top = 58.0
	_boss_wrap.offset_bottom = 118.0
	_boss_wrap.add_theme_stylebox_override("panel", ArtBank.panel_style(&"glass", Color(1.0, 0.72, 0.68, 0.96)))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	_boss_wrap.add_child(col)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 8)
	col.add_child(margin)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 2)
	margin.add_child(inner)
	_boss_name = Label.new()
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_paint_label(_boss_name, 16, Color(1.0, 0.82, 0.78), true)
	_boss_name.text = "WARDEN"
	inner.add_child(_boss_name)
	_boss_bar = ProgressBar.new()
	_boss_bar.custom_minimum_size = Vector2(0, 16)
	_boss_bar.show_percentage = false
	_style_bar(_boss_bar, Color(0.92, 0.22, 0.28, 1))
	inner.add_child(_boss_bar)
	_boss_hp_label = Label.new()
	_boss_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_paint_label(_boss_hp_label, 12, Color(1.0, 0.9, 0.88))
	inner.add_child(_boss_hp_label)
	add_child(_boss_wrap)


func _on_boss_spawned(boss_name: String) -> void:
	if _boss_wrap == null:
		_ensure_boss_bar()
	_boss_wrap.visible = true
	if _boss_name:
		_boss_name.text = boss_name.to_upper()


func _on_boss_health(current: float, max_value: float, boss_name: String) -> void:
	if _boss_wrap == null:
		_ensure_boss_bar()
	_boss_wrap.visible = current > 0.0
	if _boss_name and boss_name != "":
		_boss_name.text = boss_name.to_upper()
	if _boss_bar:
		_boss_bar.max_value = maxf(max_value, 1.0)
		_boss_bar.value = current
		var ratio := current / max_value if max_value > 0.0 else 0.0
		_style_bar(_boss_bar, HP_FILL_LOW if ratio <= 0.35 else Color(0.86, 0.18, 0.22, 1))
	if _boss_hp_label:
		_boss_hp_label.text = "%d / %d" % [roundi(current), roundi(max_value)]
	if current <= 0.0:
		_hide_boss_bar()


func _on_boss_phase(phase: int, boss_name: String) -> void:
	if _boss_name:
		_boss_name.text = "%s  —  PHASE %d" % [boss_name.to_upper(), phase]


func _hide_boss_bar(_a = null) -> void:
	if _boss_wrap:
		_boss_wrap.visible = false
