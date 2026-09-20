class_name EconomyAdrenaline
extends "res://systems/economy/resource_economy.gd"
## Synthetic: Energy/Adrenaline + Geometry of Reflections (mirrors / ricochet / Lattice Collapse).

const MIRROR_SCENE := preload("res://entities/props/energy_mirror.tscn")

@export var max_attack_speed_bonus: float = 0.0
@export var max_mirrors: int = 3
## Deprecated: mirrors use action budget (3), not timers. Kept for resource compatibility.
@export var mirror_lifetime: float = -1.0
@export var collapse_energy_cost: float = 20.0
@export var dash_explode_radius: float = 96.0
@export var dash_explode_damage: float = 14.0
@export var collapse_scale: float = 1.35
@export var block_energy_cost: float = 4.0
## Geometry tree is opt-in via crafts. Base Synthetic is energy/adrenaline, not lattice-only.
var geometry_enabled: bool = false
## Blade bounce budget off Energy Mirrors (Prism Chain raises this).
@export var max_bounces: int = 1
@export var ricochet_damage_mult: float = 1.5
@export var extra_bounce_mult: float = 1.25
## Geometry reward upgrades.
var wall_bounce_enabled: bool = false
var dash_blade_intercept: bool = false
var spawn_crystal_on_return: bool = false
var mirror_confuse: bool = false
var spawn_lens_on_parry: bool = false

var _host: Node
var _mirrors: Array[Node] = []
var _lenses: Array[Node] = []
var _crystals: Array[Node] = []


func _init() -> void:
	policy = GameplayEnums.EconomyPolicy.ENERGY_ADRENALINE


func on_equip(host: Node) -> void:
	_host = host
	_mirrors.clear()
	_lenses.clear()
	_crystals.clear()
	wall_bounce_enabled = false
	dash_blade_intercept = false
	spawn_crystal_on_return = false
	mirror_confuse = false
	spawn_lens_on_parry = false
	geometry_enabled = false
	var energy: EnergyComponent = host.get("energy") as EnergyComponent
	if energy:
		energy.unlock_regen(1.0)
	if not SignalBus.parry_success.is_connected(_on_parry_success):
		SignalBus.parry_success.connect(_on_parry_success)


func on_unequip(_host: Node) -> void:
	if SignalBus.parry_success.is_connected(_on_parry_success):
		SignalBus.parry_success.disconnect(_on_parry_success)
	_clear_mirrors()
	_clear_nodes(_lenses)
	_clear_nodes(_crystals)
	_host = null


func can_afford(host: Node, action: StringName, cost: float = 0.0) -> bool:
	if action == &"parry":
		return false
	if action == &"special":
		return _alive_mirror_count() > 0 and _can_spend_energy(host, collapse_energy_cost)
	if action == &"block":
		return _can_spend_energy(host, block_energy_cost)
	var energy: EnergyComponent = host.get("energy") as EnergyComponent
	if action == &"attack" or action == &"ranged" or action == &"dash":
		if cost <= 0.0:
			return true
		return energy != null and energy.current_energy >= cost
	if cost <= 0.0:
		return true
	return energy != null and energy.current_energy >= cost


func spend(host: Node, action: StringName, cost: float = 0.0) -> bool:
	if not can_afford(host, action, cost):
		return false
	if action == &"parry":
		return false
	if action == &"special":
		return _spend_energy(host, collapse_energy_cost)
	if action == &"block":
		return _spend_energy(host, block_energy_cost)
	var energy: EnergyComponent = host.get("energy") as EnergyComponent
	if cost > 0.0:
		return energy != null and energy.try_spend(cost)
	return true


func attack_speed_multiplier(_host: Node) -> float:
	## Adrenaline is energy regen, not attack speed.
	return 1.0


func try_special(host: Node) -> bool:
	if not can_afford(host, &"special"):
		return false
	if not spend(host, &"special"):
		return false
	_collapse_all()
	SignalBus.special_triggered.emit(host)
	return true


func get_hud_values(host: Node) -> Dictionary:
	var energy: EnergyComponent = host.get("energy") as EnergyComponent
	var adrenaline: AdrenalineComponent = host.get("adrenaline") as AdrenalineComponent
	var energy_v := energy.current_energy if energy else 0.0
	var energy_m := energy.get_max_energy() if energy else 50.0
	var adr_v := adrenaline.current_adrenaline if adrenaline else 0.0
	var adr_m := adrenaline.get_max_adrenaline() if adrenaline else 100.0
	return {
		"primary": _bar(energy_v, energy_m, "Energy", Color(0.25, 0.55, 0.95, 1)),
		"secondary": _bar(adr_v, adr_m, "Adrenaline", Color(0.95, 0.8, 0.2, 1)),
	}


func set_prism_chain(bounces: int, bounce_mult: float) -> void:
	geometry_enabled = true
	max_bounces = maxi(bounces, 1)
	extra_bounce_mult = maxf(bounce_mult, 1.0)


func set_optic_labyrinth(cap: int = 5) -> void:
	geometry_enabled = true
	max_mirrors = maxi(cap, max_mirrors)
	mirror_confuse = true


func enable_kinetic_pingpong() -> void:
	geometry_enabled = true
	wall_bounce_enabled = true
	dash_blade_intercept = true


func enable_prism_trap() -> void:
	geometry_enabled = true
	spawn_crystal_on_return = true


func enable_focus_lens() -> void:
	geometry_enabled = true
	spawn_lens_on_parry = true


func spawn_mirror_at(global_pos: Vector2, _life: float = -1.0) -> Node:
	if _host == null or not is_instance_valid(_host) or _host is not Node2D:
		return null
	var parent := _host.get_parent()
	if parent == null:
		return null
	_prune_mirrors()
	while _mirrors.size() >= max_mirrors:
		var oldest := _mirrors[0]
		_mirrors.remove_at(0)
		if is_instance_valid(oldest) and oldest.has_method("detonate"):
			oldest.explode_radius_mult = 0.55
			oldest.call("detonate", &"overflow")
		elif is_instance_valid(oldest):
			oldest.queue_free()
	var mirror := MIRROR_SCENE.instantiate() as Node2D
	if mirror == null:
		return null
	parent.add_child(mirror)
	mirror.global_position = global_pos
	if mirror.has_method("configure"):
		mirror.call("configure", _host, -1.0, self)
	_mirrors.append(mirror)
	return mirror


func spawn_echo_shade(source: Node, _life: float = -1.0) -> Node:
	geometry_enabled = true
	if source == null or source is not Node2D or _host == null or _host is not Node2D:
		return null
	var behind: Vector2 = (source as Node2D).global_position
	var away := ((source as Node2D).global_position - (_host as Node2D).global_position).normalized()
	if away == Vector2.ZERO:
		away = Vector2.RIGHT
	behind += away * 36.0
	return spawn_mirror_at(behind)


func spawn_prism_crystal(global_pos: Vector2) -> Node:
	if not spawn_crystal_on_return:
		return null
	if _host == null or not is_instance_valid(_host) or _host is not Node2D:
		return null
	var parent := _host.get_parent()
	if parent == null:
		return null
	_prune_list(_crystals)
	while _crystals.size() >= 3:
		var old := _crystals[0]
		if is_instance_valid(old) and old.has_method("force_explode"):
			# Oldest detonates into rays; unregister happens inside expire.
			old.call("force_explode")
		elif is_instance_valid(old):
			_crystals.remove_at(0)
			old.queue_free()
		else:
			_crystals.remove_at(0)
		_prune_list(_crystals)
	var crystal_scene: PackedScene = load("res://entities/props/prism_crystal.tscn") as PackedScene
	if crystal_scene == null:
		return null
	var crystal := crystal_scene.instantiate() as Node2D
	parent.add_child(crystal)
	crystal.global_position = global_pos
	if crystal.has_method("configure"):
		crystal.call("configure", _host, self)
	_crystals.append(crystal)
	return crystal


func spawn_focus_lens(global_pos: Vector2) -> Node:
	if not spawn_lens_on_parry:
		return null
	if _host == null or not is_instance_valid(_host) or _host is not Node2D:
		return null
	var parent := _host.get_parent()
	if parent == null:
		return null
	_prune_list(_lenses)
	while _lenses.size() >= 2:
		var old := _lenses[0]
		_lenses.remove_at(0)
		if is_instance_valid(old):
			old.queue_free()
	var lens_scene: PackedScene = load("res://entities/props/focus_lens.tscn") as PackedScene
	if lens_scene == null:
		return null
	var lens := lens_scene.instantiate() as Node2D
	parent.add_child(lens)
	lens.global_position = global_pos
	if lens.has_method("configure"):
		lens.call("configure", _host, self)
	_lenses.append(lens)
	return lens


func unregister_mirror(mirror: Node) -> void:
	if mirror in _mirrors:
		_mirrors.erase(mirror)


func unregister_crystal(node: Node) -> void:
	if node in _crystals:
		_crystals.erase(node)


func unregister_lens(node: Node) -> void:
	if node in _lenses:
		_lenses.erase(node)


func get_ricochet_params() -> Dictionary:
	return {
		"max_bounces": max_bounces,
		"ricochet_damage_mult": ricochet_damage_mult,
		"extra_bounce_mult": extra_bounce_mult,
		"wall_bounce": wall_bounce_enabled,
	}


func _on_parry_success(source: Node) -> void:
	if _host == null or not is_instance_valid(_host) or _host is not Node2D:
		return
	var spawn_pos: Vector2 = (_host as Node2D).global_position
	if source != null and is_instance_valid(source) and source is Node2D:
		spawn_pos = ((_host as Node2D).global_position + (source as Node2D).global_position) * 0.5
	else:
		var facing: Vector2 = Vector2.RIGHT
		if _host.get("facing_direction") != null:
			facing = (_host.get("facing_direction") as Vector2)
			if facing == Vector2.ZERO:
				facing = Vector2.RIGHT
		spawn_pos += facing.normalized() * 40.0
	if not geometry_enabled:
		return
	spawn_mirror_at(spawn_pos)
	if spawn_lens_on_parry:
		var lens_pos := spawn_pos + Vector2(0, -36)
		spawn_focus_lens(lens_pos)


func _collapse_all() -> void:
	_prune_mirrors()
	if _mirrors.is_empty():
		return
	var centroid := Vector2.ZERO
	for mirror in _mirrors:
		if is_instance_valid(mirror) and mirror is Node2D:
			centroid += (mirror as Node2D).global_position
	centroid /= float(_mirrors.size())
	CameraFx.flash(Color(0.55, 0.9, 1.0, 0.45), 0.12)
	CameraFx.add_trauma(0.55)
	var snapshot: Array[Node] = _mirrors.duplicate()
	_mirrors.clear()
	for mirror in snapshot:
		if not is_instance_valid(mirror):
			continue
		if mirror is Node2D:
			var m2 := mirror as Node2D
			var tw := m2.create_tween()
			tw.tween_property(m2, "global_position", centroid, 0.08).set_trans(Tween.TRANS_QUAD)
			tw.tween_callback(func () -> void:
				if is_instance_valid(mirror) and mirror.has_method("detonate"):
					mirror.explode_radius_mult = collapse_scale
					mirror.call("detonate", &"collapse")
				elif is_instance_valid(mirror):
					mirror.queue_free()
			)
		elif mirror.has_method("detonate"):
			mirror.explode_radius_mult = collapse_scale
			mirror.call("detonate", &"collapse")


func _clear_mirrors() -> void:
	var snapshot: Array[Node] = _mirrors.duplicate()
	_mirrors.clear()
	for mirror in snapshot:
		if is_instance_valid(mirror):
			mirror.queue_free()


func _clear_nodes(list: Array[Node]) -> void:
	var snapshot: Array[Node] = list.duplicate()
	list.clear()
	for node in snapshot:
		if is_instance_valid(node):
			node.queue_free()


func _prune_mirrors() -> void:
	_prune_list(_mirrors)


func _prune_list(list: Array[Node]) -> void:
	var alive: Array[Node] = []
	for node in list:
		if is_instance_valid(node):
			alive.append(node)
	list.clear()
	for node in alive:
		list.append(node)


func _alive_mirror_count() -> int:
	_prune_mirrors()
	return _mirrors.size()


func _can_spend_energy(host: Node, amount: float) -> bool:
	var energy: EnergyComponent = host.get("energy") as EnergyComponent
	return energy != null and energy.current_energy >= amount


func _spend_energy(host: Node, amount: float) -> bool:
	var energy: EnergyComponent = host.get("energy") as EnergyComponent
	return energy != null and energy.try_spend(amount)
