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
	assert(land.between_wave_heal >= 0.4)
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

	print("HUD_CHROME_OK")
	get_tree().quit(0)
