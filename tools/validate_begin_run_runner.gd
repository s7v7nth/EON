extends Node
## Class-select Begin Run must reach a dressed first room in seconds, not minutes.


func _ready() -> void:
	await get_tree().process_frame
	await _run()


func _run() -> void:
	var t0 := Time.get_ticks_msec()
	RunState.reset()
	var route := RunState.load_route_by_id(&"tutorial")
	assert(route != null)
	RunState.choose_route(route)
	assert(RunState.choose_architecture(GameplayEnums.ArchitectureId.DEFAULT))
	var packed: PackedScene = load("res://levels/floor/floor_world.tscn")
	var floor_world: Node = packed.instantiate()
	add_child(floor_world)
	await get_tree().process_frame
	await get_tree().process_frame
	var ms := Time.get_ticks_msec() - t0
	print("BEGIN_RUN_MS %d" % ms)
	assert(ms < 8000, "first room must appear in seconds, got %d ms" % ms)
	var islands := floor_world.get_node_or_null("Islands")
	assert(islands != null)
	var dressed := 0
	for child in islands.get_children():
		if child.get_node_or_null("Dressing") != null:
			dressed += 1
	assert(dressed >= 1, "current island must be dressed before first paint")
	print("BEGIN_RUN_OK dressed=%d rooms=%d ms=%d" % [dressed, islands.get_child_count(), ms])
	get_tree().quit(0)
