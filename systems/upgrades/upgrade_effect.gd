class_name UpgradeEffect
extends Resource
## One craft verb. Host is Node to avoid Player class cycles.


func apply(_host: Node) -> void:
	pass


func remove(_host: Node) -> void:
	pass


func tick(_host: Node, _delta: float) -> void:
	pass


func on_melee_hit(_host: Node, _target: Node) -> void:
	pass


func on_ranged_hit(_host: Node, _target: Node) -> void:
	pass


func on_perfect_dodge(_host: Node, _source: Node) -> void:
	pass


func on_parry(_host: Node, _source: Node) -> void:
	pass


func on_kill(_host: Node, _enemy: Node) -> void:
	pass


## Return true if fatal damage was prevented (Holographic Substitution, etc.).
func on_fatal_damage(_host: Node, _amount: float) -> bool:
	return false


func damage_multiplier(_host: Node) -> float:
	return 1.0


func _weapon_shape(host: Node) -> StringName:
	var weapons = host.get("weapons")
	var index = host.get("weapon_index")
	if weapons == null or index == null:
		return StringName()
	if int(index) < 0 or int(index) >= weapons.size():
		return StringName()
	var weapon = weapons[int(index)]
	if weapon == null:
		return StringName()
	return weapon.shape_tag if "shape_tag" in weapon else StringName()


func _enemies_near(host: Node, radius: float) -> Array:
	var out: Array = []
	if host is not Node2D:
		return out
	var parent := host.get_parent()
	if parent == null:
		return out
	var origin := (host as Node2D).global_position
	for child in parent.get_children():
		if child is not Node2D:
			continue
		if child.get("health") == null and not child.has_method("apply_knockback"):
			continue
		if origin.distance_to((child as Node2D).global_position) <= radius:
			out.append(child)
	return out
