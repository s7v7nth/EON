class_name CombatVisualComponent
extends Node2D
## Greybox combat readability: body pose, weapon prop, swing arcs, telegraphs.

var body: Polygon2D
var weapon: Polygon2D
var swing_arc: Polygon2D
var telegraph: Polygon2D
var aura: Polygon2D
var parry_shield: Polygon2D

var _body_rest_poly: PackedVector2Array
var _body_rest_color: Color = Color.WHITE
var _weapon_rest_pos := Vector2(18, -22)
var _tween: Tween
var _aura_tween: Tween
var _accent := Color(0.7, 0.85, 1.0, 1.0)


func _ready() -> void:
	_resolve_body()
	_ensure_nodes()
	reset_pose()


func _resolve_body() -> void:
	## Always resolve sibling Visual from parent — exported NodePaths were unreliable.
	if get_parent():
		body = get_parent().get_node_or_null("Visual") as Polygon2D
	if body:
		body.visible = true
		body.modulate = Color.WHITE
		_body_rest_poly = body.polygon
		_body_rest_color = body.color


func _ensure_nodes() -> void:
	weapon = _make_poly("Weapon", Color(0.85, 0.9, 1.0, 1.0), _blade_poly())
	weapon.position = _weapon_rest_pos
	weapon.z_index = 2
	swing_arc = _make_poly("SwingArc", Color(1, 1, 1, 0.0), _arc_poly(48.0))
	swing_arc.z_index = 3
	telegraph = _make_poly("Telegraph", Color(1, 0.3, 0.2, 0.0), _diamond_poly(16.0))
	telegraph.z_index = 1
	aura = _make_poly("Aura", Color(1, 1, 1, 0.0), _ring_poly(20.0, 26.0))
	aura.z_index = -1
	aura.position = Vector2(0, -20)
	parry_shield = _make_poly("ParryShield", Color(1, 1, 0.55, 0.0), _shield_poly())
	parry_shield.z_index = 4
	parry_shield.position = Vector2(10, -22)


func _make_poly(node_name: String, color: Color, poly: PackedVector2Array) -> Polygon2D:
	var existing := get_node_or_null(node_name) as Polygon2D
	if existing:
		existing.color = color
		existing.polygon = poly
		return existing
	var p := Polygon2D.new()
	p.name = node_name
	p.color = color
	p.polygon = poly
	add_child(p)
	return p


func apply_architecture_look(arch: ArchitectureData) -> void:
	_resolve_body()
	_ensure_nodes()
	if arch == null or body == null:
		return
	body.visible = true
	body.modulate = Color.WHITE
	body.scale = Vector2.ONE
	_accent = arch.visual_tint.lightened(0.25)
	body.color = Color(arch.visual_tint.r, arch.visual_tint.g, arch.visual_tint.b, 1.0)
	_body_rest_color = body.color
	match arch.architecture_id:
		GameplayEnums.ArchitectureId.NANOMACHINES:
			body.polygon = _nano_body_poly()
			aura.color = Color(0.35, 0.95, 0.45, 0.28)
			aura.polygon = _ring_poly(18.0, 28.0)
			aura.visible = true
		GameplayEnums.ArchitectureId.ELECTRO_TRAIN:
			body.polygon = _train_body_poly()
			aura.color = Color(0.35, 0.7, 1.0, 0.35)
			aura.polygon = _ring_poly(16.0, 30.0)
			aura.visible = true
		GameplayEnums.ArchitectureId.NEURO_HACKER:
			body.polygon = _default_body_poly()
			aura.color = Color(0.7, 0.4, 1.0, 0.32)
			aura.polygon = _ring_poly(15.0, 26.0)
			aura.visible = true
		_:
			body.polygon = _default_body_poly()
			aura.color = Color(0.7, 0.85, 1.0, 0.18)
			aura.polygon = _ring_poly(14.0, 22.0)
			aura.visible = true
	_body_rest_poly = body.polygon
	_kill_tween()
	if _aura_tween and _aura_tween.is_valid():
		_aura_tween.kill()
	aura.scale = Vector2.ONE
	_aura_tween = create_tween().set_loops()
	_aura_tween.tween_property(aura, "scale", Vector2(1.08, 1.08), 0.55).set_trans(Tween.TRANS_SINE)
	_aura_tween.tween_property(aura, "scale", Vector2(0.94, 0.94), 0.55).set_trans(Tween.TRANS_SINE)


func apply_weapon_look(weapon_data: WeaponData, arch: ArchitectureData = null) -> void:
	if weapon == null or weapon_data == null:
		return
	var tint := weapon_data.visual_tint
	if arch:
		tint = weapon_data.visual_tint.lerp(arch.visual_tint, 0.35)
		_accent = _element_color_from_tag(weapon_data.element_tag).lerp(arch.visual_tint, 0.25)
	else:
		_accent = _element_color_from_tag(weapon_data.element_tag)
	weapon.color = tint
	weapon.modulate = Color(1, 1, 1, 1)
	match String(weapon_data.shape_tag):
		"whip":
			weapon.polygon = _whip_poly()
			_weapon_rest_pos = Vector2(16, -18)
		"toad":
			weapon.polygon = _toad_poly()
			_weapon_rest_pos = Vector2(14, -14)
		"gun", "mortar":
			weapon.polygon = _gun_poly()
			_weapon_rest_pos = Vector2(16, -20)
		_:
			weapon.polygon = _blade_poly()
			_weapon_rest_pos = Vector2(18, -22)
	weapon.position = _weapon_rest_pos
	weapon.rotation = -0.35
	weapon.scale = Vector2.ONE


func apply_faction_look(faction: GameplayEnums.Faction, base_color: Color) -> void:
	_resolve_body()
	_ensure_nodes()
	if body == null:
		return
	body.visible = true
	body.modulate = Color.WHITE
	body.scale = Vector2.ONE
	body.color = Color(base_color.r, base_color.g, base_color.b, 1.0)
	_body_rest_color = body.color
	_accent = base_color.lightened(0.35)
	match faction:
		GameplayEnums.Faction.ANDROID:
			body.polygon = _android_body_poly()
		GameplayEnums.Faction.CYBORG:
			body.polygon = _cyborg_body_poly()
		GameplayEnums.Faction.ROBO_BEAST:
			body.polygon = _beast_body_poly()
		GameplayEnums.Faction.BIO_MUTANT:
			body.polygon = _beast_body_poly()
			body.color = Color(base_color.r, base_color.g, base_color.b, 1.0).lightened(0.1)
		_:
			body.polygon = _savage_body_poly()
	_body_rest_poly = body.polygon
	if weapon:
		weapon.visible = true
		weapon.color = base_color.lightened(0.2)
		weapon.polygon = _blade_poly() if faction != GameplayEnums.Faction.ANDROID else _gun_poly()
		weapon.position = Vector2(16, -18)
	if aura:
		aura.visible = false


func play_melee_windup(aim_angle: float, duration: float) -> void:
	_kill_tween()
	rotation = 0.0
	weapon.visible = true
	weapon.rotation = aim_angle - 1.1
	weapon.position = _weapon_rest_pos.rotated(aim_angle * 0.15)
	telegraph.rotation = aim_angle
	telegraph.position = Vector2(28, -8).rotated(aim_angle)
	telegraph.color = Color(_accent.r, _accent.g, _accent.b, 0.0)
	swing_arc.modulate.a = 0.0
	if body:
		body.scale = Vector2(1, 1)
		body.modulate = Color(1.15, 1.05, 0.9, 1)
	_tween = create_tween()
	var wind := maxf(duration, 0.04)
	_tween.tween_property(weapon, "rotation", aim_angle - 1.35, wind * 0.7).set_trans(Tween.TRANS_BACK)
	_tween.parallel().tween_property(telegraph, "color:a", 0.55, wind)
	_tween.parallel().tween_property(telegraph, "scale", Vector2(1.25, 1.25), wind)
	if body:
		_tween.parallel().tween_property(body, "scale", Vector2(0.92, 1.08), wind)


func play_hostile_melee_windup(aim_angle: float, duration: float) -> void:
	## Strong readable telegraph so the player can time a dodge.
	_kill_tween()
	rotation = 0.0
	weapon.visible = true
	weapon.rotation = aim_angle - 1.25
	weapon.position = _weapon_rest_pos.rotated(aim_angle * 0.15)
	weapon.scale = Vector2(1.35, 1.35)
	telegraph.polygon = _diamond_poly(22.0)
	telegraph.rotation = aim_angle
	telegraph.position = Vector2.from_angle(aim_angle) * 36.0 + Vector2(0, -16)
	telegraph.scale = Vector2(0.6, 0.6)
	telegraph.color = Color(1.0, 0.2, 0.12, 0.0)
	swing_arc.polygon = _arc_poly(64.0)
	swing_arc.rotation = aim_angle - 0.9
	swing_arc.position = Vector2(8, -14)
	swing_arc.color = Color(1.0, 0.25, 0.15, 0.35)
	swing_arc.modulate.a = 0.0
	if body:
		body.scale = Vector2.ONE
		body.modulate = Color(1.35, 0.85, 0.75, 1)
	_tween = create_tween()
	var wind := maxf(duration, 0.12)
	_tween.tween_property(weapon, "rotation", aim_angle - 1.55, wind * 0.85).set_trans(Tween.TRANS_BACK)
	_tween.parallel().tween_property(telegraph, "color:a", 0.9, wind * 0.35)
	_tween.parallel().tween_property(telegraph, "scale", Vector2(1.6, 1.6), wind)
	_tween.parallel().tween_property(swing_arc, "modulate:a", 0.85, wind * 0.5)
	if body:
		_tween.parallel().tween_property(body, "scale", Vector2(0.88, 1.14), wind)
		_tween.parallel().tween_property(body, "modulate", Color(1.6, 0.55, 0.4, 1), wind)


func play_melee_swing(
	aim_angle: float,
	duration: float,
	damage_type: GameplayEnums.DamageType = GameplayEnums.DamageType.PHYSICAL,
	accent_override: Color = Color(0, 0, 0, 0)
) -> void:
	_kill_tween()
	var col := accent_override if accent_override.a > 0.0 else _element_color(damage_type)
	_accent = col
	var arc_r := 72.0 if accent_override.a > 0.0 else 64.0
	swing_arc.polygon = _arc_poly(arc_r)
	swing_arc.rotation = aim_angle - 0.9
	swing_arc.position = Vector2(12, -14)
	swing_arc.color = Color(col.r, col.g, col.b, 0.85)
	swing_arc.modulate.a = 1.0
	telegraph.color.a = 0.0
	weapon.rotation = aim_angle - 1.2
	weapon.scale = Vector2(1.25, 1.25) if accent_override.a > 0.0 else Vector2(1.1, 1.1)
	if accent_override.a > 0.0:
		weapon.modulate = Color(col.r, col.g, col.b, 1.0)
	_tween = create_tween()
	var active := maxf(duration, 0.06)
	_tween.tween_property(weapon, "rotation", aim_angle + 0.95, active).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(swing_arc, "rotation", aim_angle + 0.7, active)
	_tween.parallel().tween_property(swing_arc, "modulate:a", 0.0, active)
	if body:
		_tween.parallel().tween_property(body, "scale", Vector2(1.12, 0.9), active * 0.45)
		_tween.tween_property(body, "scale", Vector2.ONE, active * 0.55)
		_tween.parallel().tween_property(body, "modulate", Color.WHITE, active)
	_tween.parallel().tween_property(weapon, "modulate", Color.WHITE, active)
	_tween.parallel().tween_property(weapon, "scale", Vector2.ONE, active)


func play_ranged_windup(aim_angle: float, duration: float) -> void:
	_kill_tween()
	weapon.visible = true
	weapon.rotation = aim_angle
	weapon.position = Vector2(14, -18)
	telegraph.rotation = aim_angle
	telegraph.position = Vector2(34, -10).rotated(aim_angle * 0.05) + Vector2.from_angle(aim_angle) * 20.0
	telegraph.polygon = _diamond_poly(10.0)
	telegraph.color = Color(_accent.r, _accent.g, _accent.b, 0.0)
	if body:
		body.modulate = Color(1.1, 1.1, 1.2, 1)
	_tween = create_tween()
	var wind := maxf(duration, 0.05)
	_tween.tween_property(weapon, "position", Vector2(10, -18) + Vector2.from_angle(aim_angle) * -4.0, wind)
	_tween.parallel().tween_property(telegraph, "color:a", 0.7, wind)
	_tween.parallel().tween_property(telegraph, "scale", Vector2(1.4, 1.4), wind)


func play_hostile_ranged_windup(aim_angle: float, duration: float) -> void:
	_kill_tween()
	weapon.visible = true
	weapon.rotation = aim_angle
	weapon.position = Vector2(14, -18)
	telegraph.polygon = _diamond_poly(18.0)
	telegraph.rotation = aim_angle
	telegraph.position = Vector2.from_angle(aim_angle) * 42.0 + Vector2(0, -12)
	telegraph.scale = Vector2(0.7, 0.7)
	telegraph.color = Color(1.0, 0.35, 0.15, 0.0)
	swing_arc.polygon = _muzzle_poly()
	swing_arc.rotation = aim_angle
	swing_arc.position = Vector2(18, -16)
	swing_arc.color = Color(1.0, 0.4, 0.2, 0.55)
	swing_arc.modulate.a = 0.0
	if body:
		body.modulate = Color(1.35, 0.9, 0.75, 1)
	_tween = create_tween()
	var wind := maxf(duration, 0.15)
	_tween.tween_property(weapon, "position", Vector2(8, -18) + Vector2.from_angle(aim_angle) * -8.0, wind)
	_tween.parallel().tween_property(telegraph, "color:a", 0.95, wind * 0.4)
	_tween.parallel().tween_property(telegraph, "scale", Vector2(1.7, 1.7), wind)
	_tween.parallel().tween_property(swing_arc, "modulate:a", 0.8, wind * 0.55)
	if body:
		_tween.parallel().tween_property(body, "modulate", Color(1.55, 0.55, 0.4, 1), wind)


func play_ranged_fire(aim_angle: float, damage_type: GameplayEnums.DamageType = GameplayEnums.DamageType.PHYSICAL) -> void:
	_kill_tween()
	var col := _element_color(damage_type)
	weapon.rotation = aim_angle
	swing_arc.polygon = _muzzle_poly()
	swing_arc.rotation = aim_angle
	swing_arc.position = Vector2(22, -16)
	swing_arc.color = Color(col.r, col.g, col.b, 0.9)
	swing_arc.modulate.a = 1.0
	telegraph.color.a = 0.0
	_tween = create_tween()
	_tween.tween_property(weapon, "position", Vector2(18, -18) + Vector2.from_angle(aim_angle) * 6.0, 0.05)
	_tween.parallel().tween_property(swing_arc, "modulate:a", 0.0, 0.18)
	_tween.tween_property(weapon, "position", _weapon_rest_pos, 0.12)
	if body:
		_tween.parallel().tween_property(body, "modulate", Color.WHITE, 0.12)


func play_parry_start() -> void:
	_kill_tween()
	parry_shield.color = Color(1.0, 0.95, 0.45, 0.85)
	parry_shield.scale = Vector2(0.7, 0.7)
	if body:
		body.modulate = Color(1.25, 1.2, 0.8, 1)
	_tween = create_tween()
	_tween.tween_property(parry_shield, "scale", Vector2(1.15, 1.15), 0.08)
	_tween.parallel().tween_property(parry_shield, "color:a", 0.95, 0.08)


func play_parry_end() -> void:
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(parry_shield, "color:a", 0.0, 0.12)
	if body:
		_tween.parallel().tween_property(body, "modulate", Color.WHITE, 0.12)


func play_block_start(parry_flash: bool = true) -> void:
	_kill_tween()
	if parry_flash:
		parry_shield.color = Color(1.0, 0.95, 0.45, 0.9)
	else:
		parry_shield.color = Color(0.45, 0.75, 1.0, 0.7)
	parry_shield.scale = Vector2(0.75, 0.75)
	if body:
		body.modulate = Color(1.2, 1.15, 0.85, 1) if parry_flash else Color(0.9, 1.05, 1.2, 1)
	_tween = create_tween()
	_tween.tween_property(parry_shield, "scale", Vector2(1.2, 1.2), 0.08)
	_tween.parallel().tween_property(parry_shield, "color:a", 0.95, 0.08)


func play_block_hold() -> void:
	_kill_tween()
	parry_shield.color = Color(0.4, 0.7, 1.0, 0.75)
	_tween = create_tween()
	_tween.tween_property(parry_shield, "scale", Vector2(1.1, 1.1), 0.1)
	if body:
		_tween.parallel().tween_property(body, "modulate", Color(0.9, 1.05, 1.2, 1), 0.1)


func play_block_end() -> void:
	play_parry_end()


func play_charge_start(aim_angle: float) -> void:
	_kill_tween()
	weapon.visible = true
	weapon.rotation = aim_angle - 0.4
	telegraph.rotation = aim_angle
	telegraph.position = Vector2.from_angle(aim_angle) * 36.0 + Vector2(0, -10)
	telegraph.polygon = _diamond_poly(12.0)
	telegraph.color = Color(0.45, 0.85, 1.0, 0.0)
	_tween = create_tween()
	_tween.tween_property(telegraph, "color:a", 0.55, 0.12)


func play_charge_tick(aim_angle: float, charge: float) -> void:
	weapon.rotation = aim_angle - 0.4 - charge * 0.5
	weapon.position = _weapon_rest_pos + Vector2.from_angle(aim_angle) * (-6.0 * charge)
	telegraph.rotation = aim_angle
	telegraph.position = Vector2.from_angle(aim_angle) * (36.0 + 20.0 * charge) + Vector2(0, -10)
	telegraph.scale = Vector2.ONE * (1.0 + charge * 0.8)
	telegraph.color.a = 0.4 + charge * 0.5


func play_circle_slash(duration: float) -> void:
	_kill_tween()
	var active := maxf(duration, 0.12)
	swing_arc.polygon = _arc_poly(78.0)
	swing_arc.position = Vector2(0, -12)
	swing_arc.rotation = -PI
	swing_arc.color = Color(0.55, 0.9, 1.0, 0.85)
	swing_arc.modulate.a = 1.0
	weapon.visible = true
	if body:
		body.modulate = Color(1.2, 1.25, 1.4, 1)
	_tween = create_tween()
	_tween.tween_property(swing_arc, "rotation", PI, active).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(weapon, "rotation", weapon.rotation + TAU, active)
	_tween.parallel().tween_property(swing_arc, "modulate:a", 0.0, active)
	if body:
		_tween.parallel().tween_property(body, "scale", Vector2(1.15, 0.9), active * 0.4)
		_tween.tween_property(body, "scale", Vector2.ONE, active * 0.6)
		_tween.parallel().tween_property(body, "modulate", Color.WHITE, active)


func play_hit_flash() -> void:
	if body == null:
		return
	var t := create_tween()
	t.tween_property(body, "modulate", Color(2.0, 2.0, 2.0, 1), 0.04)
	t.tween_property(body, "modulate", Color.WHITE, 0.1)


func reset_pose() -> void:
	_kill_tween()
	if body:
		body.scale = Vector2.ONE
		body.modulate = Color.WHITE
		if not _body_rest_poly.is_empty():
			body.polygon = _body_rest_poly
		body.color = _body_rest_color
	if weapon:
		weapon.position = _weapon_rest_pos
		weapon.rotation = -0.35
		weapon.scale = Vector2.ONE
		weapon.modulate = Color.WHITE
	if swing_arc:
		swing_arc.modulate.a = 0.0
	if telegraph:
		telegraph.color.a = 0.0
		telegraph.scale = Vector2.ONE
	if parry_shield:
		parry_shield.color.a = 0.0


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null


func _element_color(t: GameplayEnums.DamageType) -> Color:
	match t:
		GameplayEnums.DamageType.ELECTRICITY:
			return Color(0.45, 0.8, 1.0, 1)
		GameplayEnums.DamageType.CORROSION:
			return Color(0.45, 0.95, 0.35, 1)
		GameplayEnums.DamageType.FIRE:
			return Color(1.0, 0.45, 0.15, 1)
		GameplayEnums.DamageType.BLEED:
			return Color(0.95, 0.2, 0.25, 1)
		_:
			return Color(0.9, 0.92, 1.0, 1)


func _element_color_from_tag(tag: StringName) -> Color:
	match String(tag):
		"electricity", "elec":
			return _element_color(GameplayEnums.DamageType.ELECTRICITY)
		"corrosion", "corr":
			return _element_color(GameplayEnums.DamageType.CORROSION)
		"fire":
			return _element_color(GameplayEnums.DamageType.FIRE)
		"bleed":
			return _element_color(GameplayEnums.DamageType.BLEED)
		_:
			return _element_color(GameplayEnums.DamageType.PHYSICAL)


func _default_body_poly() -> PackedVector2Array:
	# Must use Vector2 entries — PackedVector2Array([x,y,...]) does NOT pair floats in GDScript.
	return PackedVector2Array([
		Vector2(-14, 0), Vector2(14, 0), Vector2(14, -48), Vector2(-14, -48)
	])


func _nano_body_poly() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-12, 0), Vector2(12, 0), Vector2(16, -18),
		Vector2(10, -48), Vector2(-8, -50), Vector2(-16, -22)
	])


func _train_body_poly() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-10, 0), Vector2(12, 0), Vector2(18, -10),
		Vector2(14, -48), Vector2(-8, -46), Vector2(-16, -16)
	])


func _savage_body_poly() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-13, 0), Vector2(13, 0), Vector2(15, -40),
		Vector2(0, -52), Vector2(-15, -40)
	])


func _cyborg_body_poly() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-14, 0), Vector2(14, 0), Vector2(16, -24),
		Vector2(10, -48), Vector2(-6, -50), Vector2(-16, -28)
	])


func _android_body_poly() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-12, 0), Vector2(12, 0), Vector2(12, -36),
		Vector2(6, -50), Vector2(-6, -50), Vector2(-12, -36)
	])


func _beast_body_poly() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-16, 0), Vector2(18, 0), Vector2(20, -20),
		Vector2(8, -36), Vector2(-4, -40), Vector2(-18, -22)
	])


func _blade_poly() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0, 4), Vector2(40, -2), Vector2(46, -8), Vector2(6, -12), Vector2(0, -4)
	])


func _whip_poly() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0, 0), Vector2(12, -4), Vector2(24, 2), Vector2(34, -8),
		Vector2(30, -10), Vector2(18, -2), Vector2(8, -8), Vector2(0, -4)
	])


func _gun_poly() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0, -2), Vector2(22, -4), Vector2(24, 2),
		Vector2(8, 4), Vector2(6, 10), Vector2(0, 8)
	])


func _toad_poly() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(2, 0), Vector2(14, -6), Vector2(18, 2), Vector2(12, 10), Vector2(0, 6)
	])


func _arc_poly(radius: float) -> PackedVector2Array:
	var pts: PackedVector2Array = [Vector2.ZERO]
	var steps := 7
	for i in steps + 1:
		var a := -0.9 + (1.8 * float(i) / float(steps))
		pts.append(Vector2(cos(a), sin(a)) * radius)
	return pts


func _muzzle_poly() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0, -6), Vector2(16, 0), Vector2(0, 6), Vector2(4, 0)
	])


func _diamond_poly(r: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(r, 0), Vector2(0, r * 0.6), Vector2(-r * 0.4, 0), Vector2(0, -r * 0.6)
	])


func _ring_poly(inner_r: float, outer_r: float) -> PackedVector2Array:
	var pts: PackedVector2Array = []
	var steps := 12
	for i in steps:
		var a := TAU * float(i) / float(steps)
		pts.append(Vector2(cos(a), sin(a)) * outer_r)
	for i in range(steps - 1, -1, -1):
		var a := TAU * float(i) / float(steps)
		pts.append(Vector2(cos(a), sin(a)) * inner_r)
	return pts


func _shield_poly() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0, -16), Vector2(14, -8), Vector2(14, 8), Vector2(0, 16), Vector2(-4, 0)
	])
