extends Node
## HUD chrome: no debug dumps, Kenney nine-slice, tutorial waves readable.


func _ready() -> void:
	await get_tree().process_frame
	await _run()


func _run() -> void:
	var hud_packed: PackedScene = load("res://ui/debug_hud.tscn")
	var hud: Node = hud_packed.instantiate()
	add_child(hud)
	await get_tree().process_frame

	var arch := hud.find_child("ArchLabel", true, false) as CanvasItem
	var biome := hud.find_child("BiomeLabel", true, false) as CanvasItem
	var dmg := hud.find_child("DamageLabel", true, false) as CanvasItem
	assert(arch == null or not arch.visible, "Arch dump must be hidden")
	assert(biome == null or not biome.visible, "Biome dump must be hidden")
	assert(dmg == null or not dmg.visible, "Dmg dump must be hidden")
	assert(hud.find_child("HealthBar", true, false) != null)
	assert(hud.find_child("StyleLabel", true, false) != null)
	var chrome := hud.find_child("Chrome", true, false) as PanelContainer
	assert(chrome != null, "HUD should wrap in Kenney chrome")
	var sb: StyleBox = chrome.get_theme_stylebox("panel")
	assert(sb is StyleBoxTexture, "HUD chrome should be a nine-slice texture")

	RunState.reset()
	RunState.choose_route(RunState.TUTORIAL_ROUTE)
	RunState.choose_architecture(GameplayEnums.ArchitectureId.DEFAULT)

	var overlay_packed: PackedScene = load("res://ui/run_overlay.tscn")
	var overlay: Node = overlay_packed.instantiate()
	add_child(overlay)
	await get_tree().process_frame
	var panel := overlay.get_node("Center/Panel") as PanelContainer
	assert(panel != null)
	var overlay_sb: StyleBox = panel.get_theme_stylebox("panel")
	assert(overlay_sb is StyleBoxTexture, "reward/death panel should be Kenney nine-slice")

	var land := load("res://resources/waves/tutorial_landfill_waves.tres") as WaveSet
	assert(land != null and land.wave_count() == 3)
	assert(land.between_wave_heal >= 0.15)
	var w1 := 0
	for group in land.get_wave(0).spawns:
		w1 += group.count
	assert(w1 <= 2, "tutorial room 1 wave 1 should be two swarms or fewer")
	var w2 := 0
	for group2 in land.get_wave(1).spawns:
		w2 += group2.count
	assert(w2 <= 1, "tutorial room 1 wave 2 should be a single swarm")

	var trap: BiomeTrap = (load("res://entities/props/biome_trap.tscn") as PackedScene).instantiate() as BiomeTrap
	add_child(trap)
	await get_tree().process_frame
	var fill := trap.get_node_or_null("Fill") as CanvasItem
	assert(fill == null or not fill.visible, "acid polygon must be hidden")
	var splat := trap.get_node_or_null("Splat") as Sprite2D
	assert(splat != null and splat.visible)
	assert(hud.find_child("LocationChrome", true, false) != null, "location should sit in a Kenney plaque")
	assert(overlay.find_child("WavePlaque", true, false) != null, "wave counter should sit in a Kenney plaque")
	var toast := overlay.find_child("ComboToast", true, false) as Control
	assert(toast != null, "combo toast should exist")
	assert(is_equal_approx(toast.anchor_top, 0.5), "named combo toast should land center-screen after a pick")
	assert(toast.offset_top <= -60.0, "named combo toast should be tall enough to read over the arena")
	var chip := overlay.find_child("ComboChip", true, false) as Control
	assert(chip != null, "combat combo chip should exist")
	assert(chip.anchor_top >= 0.9, "combat combo chip should sit above the wave plaque, not on the Warden bar")
	var banner := overlay.find_child("BossBanner", true, false) as Control
	assert(banner != null, "boss flash banner should exist")
	assert(banner.offset_top >= 120.0, "boss flash should sit under the HP chrome, not on top of it")
	assert(ArtBank.body_font() != null, "Inter body font must load")
	assert(ArtBank.body_font() != ArtBank.title_font(), "body type should not be Kenney Future")
	var overlay_title := overlay.get_node("Center/Panel/Margin/VBox/Title") as Label
	assert(overlay_title != null)
	assert(overlay_title.get_theme_font("font") != ArtBank.title_font(), "overlay titles should be Inter, not Kenney Future")
	var body_path := str(ArtBank.body_font().resource_path)
	assert(body_path.find("Inter") >= 0, "body type must load Inter, not a Kenney fallback")
	assert(hud.find_child("GoldLabel", true, false) != null)
	var gold_lab := hud.find_child("GoldLabel", true, false) as Label
	assert(gold_lab != null)
	assert(gold_lab.text.begins_with("Gold"), "gold should be mixed-case")
	RunState.choose_route(RunState.CAMPAIGN_ROUTE)
	RunState.seek_room(2)
	assert(RunState.is_elite_room())
	assert(RunState.room_kind_label() == "Elite")
	RunState.seek_room(1)
	assert(RunState.room_kind_label() == "Shop")
	RunState.seek_room(RunState.room_count() - 1)
	assert(RunState.room_kind_label() == "Boss")

	print("HUD_CHROME_OK")
	get_tree().quit(0)
