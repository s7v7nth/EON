extends Node
## Facing: weapon sits in the aim hand. Walls: more than one iso facing. Atmosphere exists.


func _ready() -> void:
	await get_tree().process_frame
	await _run()


func _run() -> void:
	RunState.reset()
	var player: Player = (load("res://entities/player/player.tscn") as PackedScene).instantiate() as Player
	add_child(player)
	await get_tree().process_frame
	await get_tree().process_frame
	assert(player.combat_visual != null)
	player.combat_visual.hold_aim(Vector2.LEFT)
	assert(player.combat_visual.weapon.position.x < 0.0, "blade should sit on the aim-left hand")
	assert(absf(player.combat_visual.weapon.rotation) > 1.2, "weapon rotation should follow left aim")
	var muzzle_l: Vector2 = player.combat_visual.muzzle_offset(Vector2.LEFT)
	assert(muzzle_l.x < 0.0, "muzzle must sit on the aim side")
	player.combat_visual.hold_aim(Vector2.RIGHT)
	assert(player.combat_visual.weapon.position.x > 0.0, "blade should sit on the aim-right hand")
	var muzzle_r: Vector2 = player.combat_visual.muzzle_offset(Vector2.RIGHT)
	assert(muzzle_r.x > 0.0, "muzzle must sit on the aim side")
	var wspr := player.combat_visual.weapon.get_node_or_null("Sprite") as Sprite2D
	assert(wspr == null or not wspr.visible, "prototype slash/laser weapon sprite must stay hidden")
	player.queue_free()
	await get_tree().process_frame

	var arena: Node2D = (load("res://levels/arena/arena.tscn") as PackedScene).instantiate() as Node2D
	add_child(arena)
	await get_tree().process_frame
	var biome := load("res://resources/biomes/landfill.tres") as BiomeDefinition
	if biome == null:
		biome = BiomeDefinition.new()
	RoomDresser.dress(arena, biome)
	await get_tree().process_frame
	var walls := arena.find_child("IsoWalls", true, false) as Node2D
	assert(walls != null, "iso walls should exist")
	assert(walls.get_child_count() >= 12, "iso perimeter should have connected wall pieces")
	var facings: Dictionary = {}
	for child in walls.get_children():
		var spr := child as Sprite2D
		if spr and spr.texture:
			facings[spr.texture.resource_path] = true
	assert(facings.size() >= 3, "iso walls must use more than one facing so edges meet")
	var has_n := false
	var has_e := false
	for k in facings.keys():
		var p := String(k)
		if p.ends_with("_N.png"):
			has_n = true
		if p.ends_with("_E.png"):
			has_e = true
	assert(has_n and has_e, "N and E wall tiles must both be used")
	var grade := arena.find_child("Grade", true, false) as CanvasModulate
	assert(grade != null, "night grade should exist")
	assert(grade.color.r < 0.52, "grade should be a dark remnant wash")
	assert(grade != null, "night grade should exist")
	var vignette := arena.find_child("Vignette", true, false)
	assert(vignette != null, "vignette should exist")
	print("FACING_ATMOSPHERE_OK weapon hand + iso walls + night grade")
	get_tree().quit(0)
