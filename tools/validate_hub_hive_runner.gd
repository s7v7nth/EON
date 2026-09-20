extends Node
## Hub clerk voice, kit lock copy, Hive tells — match the written spec.

const _Remnant := preload("res://entities/props/remnant_npc.gd")
const _ReturnHive := preload("res://systems/enemies/behaviors/behavior_return_to_hive.gd")
const _Slam := preload("res://entities/hazards/hive_slam_circle.gd")
const _Bile := preload("res://entities/hazards/nano_bile_puddle.gd")
const _Enemy := preload("res://entities/enemies/dummy/enemy_dummy.tscn")
const HIVE := preload("res://resources/enemies/boss_hive.tres")
const CHUNK := preload("res://resources/enemies/hive_chunk.tres")
const SLAM := preload("res://resources/attacks/enemy_hive_slam.tres")
const BILE := preload("res://resources/attacks/enemy_hive_vomit.tres")
const HOOK := preload("res://resources/attacks/enemy_hive_hook.tres")
const WAVES := preload("res://resources/waves/hive_boss_waves.tres")


func _ready() -> void:
	await get_tree().process_frame
	await _run()


func _run() -> void:
	assert(_ReturnHive != null)
	MetaSave.wipe_for_tests()
	assert(MetaSave.is_architecture_unlocked(int(GameplayEnums.ArchitectureId.DEFAULT)))
	assert(not MetaSave.is_architecture_unlocked(int(GameplayEnums.ArchitectureId.NANOMACHINES)))
	assert(not MetaSave.is_architecture_unlocked(int(GameplayEnums.ArchitectureId.ELECTRO_TRAIN)))
	assert(not MetaSave.is_architecture_unlocked(int(GameplayEnums.ArchitectureId.NEURO_HACKER)))
	assert(MetaSave.unlock_requirement(int(GameplayEnums.ArchitectureId.DEFAULT)) == MetaSave.LOCK_SYNTHETIC)
	assert(MetaSave.unlock_requirement(int(GameplayEnums.ArchitectureId.NANOMACHINES)) == MetaSave.LOCK_HIVE)
	assert(MetaSave.unlock_requirement(int(GameplayEnums.ArchitectureId.ELECTRO_TRAIN)) == MetaSave.LOCK_PAROVOZ)
	assert(MetaSave.unlock_requirement(int(GameplayEnums.ArchitectureId.NEURO_HACKER)) == MetaSave.LOCK_NEURO)
	assert(MetaSave.LOCK_HIVE == "The sweeper still has the swarm. Take it off The Hive.")
	assert(MetaSave.LOCK_PAROVOZ == "Roundhouse is sealed. Warden's sitting on the last heat valve.")
	assert(MetaSave.LOCK_NEURO == "Core bricked the wires. The stall has the last live node. Talk first.")
	assert(not RunState.choose_architecture(GameplayEnums.ArchitectureId.NANOMACHINES))

	var clerk: RemnantNpc = _Remnant.new()
	add_child(clerk)
	await get_tree().process_frame
	assert(RemnantNpc.FIRST_VISIT.size() == 12)
	assert(RemnantNpc.REPEAT_VISIT.size() == 3)
	assert(RemnantNpc.NODE_LINE.begins_with("Fine. Drawer node."))
	for i in 12:
		var line := clerk.speak()
		assert(line == RemnantNpc.FIRST_VISIT[i], "first-visit scrap %d drifted" % i)
		assert(not MetaSave.is_architecture_unlocked(int(GameplayEnums.ArchitectureId.NEURO_HACKER)))
	var node_line := clerk.speak()
	assert(node_line == RemnantNpc.NODE_LINE)
	assert(MetaSave.is_architecture_unlocked(int(GameplayEnums.ArchitectureId.NEURO_HACKER)))
	assert(clerk.speak() == RemnantNpc.REPEAT_VISIT[0])
	assert(clerk.speak() == RemnantNpc.REPEAT_VISIT[1])
	assert(clerk.speak() == RemnantNpc.REPEAT_VISIT[2])
	clerk.queue_free()

	assert(SLAM.pattern_kind == AttackData.PatternKind.OVERHEAD_SLAM)
	assert(SLAM.circular)
	assert(SLAM.max_range >= 160.0)
	assert(BILE.leaves_puddle)
	assert(BILE.pattern_kind == AttackData.PatternKind.CHARGE_SHOT)
	assert(HOOK.hook_pull)
	assert(HOOK.pattern_kind == AttackData.PatternKind.HOOK)
	assert(HIVE.boss_id == &"hive")
	assert(HIVE.visual_stem == "hive_boss")
	assert(HIVE.unlock_flag == MetaSave.FLAG_HIVE)
	assert(CHUNK.visual_stem == "hive_boss")
	var chunk_tag := false
	for tag in CHUNK.tags:
		if String(tag) == "hive_chunk":
			chunk_tag = true
	assert(chunk_tag, "hive chunks must be tagged hive_chunk")
	assert(WAVES.wave_count() == 1)
	assert(WAVES.get_wave(0).spawns.size() == 1)
	assert(WAVES.get_wave(0).spawns[0].count == 1)

	var slam: Node2D = _Slam.new()
	add_child(slam)
	slam.call("setup", 128.0)
	await get_tree().process_frame
	assert(slam.modulate.a > 0.0 or slam.get_child_count() > 0)
	assert(slam.get_node_or_null("Rim") != null)
	assert(slam.get_node_or_null("OliveRim") != null)
	assert(slam.z_index > -12)
	slam.queue_free()

	var bile: Area2D = _Bile.new()
	add_child(bile)
	bile.call("setup", 5.0, 2.0, 40.0)
	await get_tree().process_frame
	assert(bile.is_in_group("nano_bile"))
	assert(bile.get_node_or_null("RustRim") != null)
	assert(bile.get_node_or_null("Slurry") != null)
	bile.queue_free()

	var hive: EnemyDummy = _Enemy.instantiate() as EnemyDummy
	add_child(hive)
	hive.apply_definition(HIVE)
	await get_tree().process_frame
	assert(hive.is_hive_boss())
	hive.shed_hive_chunk(1)
	await get_tree().process_frame
	await get_tree().process_frame
	var found_chunk := false
	for child in get_children():
		if child is EnemyDummy and (child as EnemyDummy).is_hive_chunk():
			found_chunk = true
			var chunk := child as EnemyDummy
			assert(chunk.try_return_to_hive())
	assert(found_chunk, "The Hive must shed a crawling chunk")
	hive.queue_free()

	print("HUB_HIVE_OK clerk scraps + lock lines + hive tells")
	get_tree().quit(0)
