class_name CombatVisualComponent
extends Node2D
## Combat readability: stylized body pose, weapon prop, swing arcs, telegraphs.

var body: Node2D
var weapon: Polygon2D
var swing_arc: Polygon2D
var telegraph: Polygon2D
var aura: Polygon2D
var parry_shield: Polygon2D
## Synthetic charge-throw: feet bar + aim beam (Isaac-readable, EON HUD style).
var charge_bar_bg: Polygon2D
var charge_bar_fill: Polygon2D
var charge_aim_beam: Polygon2D

var _body_rest_poly: PackedVector2Array
var _body_rest_color: Color = Color.WHITE
var _weapon_rest_pos := Vector2(18, -22)
var _tween: Tween
var _aura_tween: Tween
var _accent := Color(0.7, 0.85, 1.0, 1.0)
var _charge_bar_width: float = 36.0
var _pose_locked: bool = false
var _shape_tag: String = "blade"
var _last_aim: Vector2 = Vector2.RIGHT


func _ready() -> void:
	_resolve_body()
	_ensure_nodes()
	reset_pose()
	set_process(true)


func _process(_delta: float) -> void:
	_hide_illustrated_weapon_poly()
	if _pose_locked:
		return
	var dir := _aim_from_host()
	if dir.length_squared() > 0.01:
		hold_aim(dir)


func _hide_illustrated_weapon_poly() -> void:
	if weapon == null:
		return
	if body and body.has_method("uses_illustrated") and bool(body.call("uses_illustrated")):
		weapon.visible = false
		var wspr := weapon.get_node_or_null("Sprite") as Sprite2D
		if wspr:
			wspr.visible = false


func _resolve_body() -> void:
	## Always resolve sibling Visual from parent — exported NodePaths were unreliable.
	if get_parent():
		body = get_parent().get_node_or_null("Visual") as Node2D
	if body:
		body.visible = true
		body.modulate = Color.WHITE
		if "polygon" in body:
			_body_rest_poly = body.polygon
		if "color" in body:
			_body_rest_color = body.color


func _set_body_color(c: Color) -> void:
	if body and "color" in body:
		body.color = c


func _set_body_polygon(poly: PackedVector2Array) -> void:
	if body and "polygon" in body:
		body.polygon = poly


func _set_body_style(style_name: StringName) -> void:
	if body and body.has_method("set_body_style_name"):
		body.call("set_body_style_name", style_name)


func _set_body_combat_lock(active: bool) -> void:
	if body and body.has_method("set_combat_pose_active"):
		body.call("set_combat_pose_active", active)


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
	_ensure_weapon_sprite()
	charge_bar_bg = _make_poly("ChargeBarBg", Color(0.06, 0.1, 0.16, 0.0), _bar_poly(_charge_bar_width, 5.0))
	charge_bar_bg.z_index = 5
	charge_bar_bg.position = Vector2(0, 18)
	charge_bar_fill = _make_poly("ChargeBarFill", Color(0.4, 0.85, 1.0, 0.0), _bar_poly(_charge_bar_width, 5.0))
	charge_bar_fill.z_index = 6
	charge_bar_fill.position = Vector2(0, 18)
	charge_aim_beam = _make_poly("ChargeAimBeam", Color(0.45, 0.85, 1.0, 0.0), _aim_beam_poly(48.0))
	charge_aim_beam.z_index = 0
	charge_aim_beam.position = Vector2(0, -16)


func _ensure_weapon_sprite() -> void:
	if weapon == null:
		return
	var wspr := weapon.get_node_or_null("Sprite") as Sprite2D
	if wspr == null:
		wspr = Sprite2D.new()
		wspr.name = "Sprite"
		wspr.centered = true
		wspr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		weapon.add_child(wspr)
	wspr.position = Vector2.ZERO
	wspr.rotation = 0.0
	wspr.modulate = Color(0.62, 0.52, 0.42, 1)
	wspr.visible = false


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
	_set_body_color(Color(arch.visual_tint.r, arch.visual_tint.g, arch.visual_tint.b, 1.0))
	_body_rest_color = Color(arch.visual_tint.r, arch.visual_tint.g, arch.visual_tint.b, 1.0)
	match arch.architecture_id:
		GameplayEnums.ArchitectureId.NANOMACHINES:
			_set_body_polygon(_nano_body_poly())
			_set_body_style(&"nano")
			aura.color = Color(0.28, 0.42, 0.26, 0.18)
			aura.polygon = _ring_poly(18.0, 28.0)
			aura.visible = true
		GameplayEnums.ArchitectureId.ELECTRO_TRAIN:
			_set_body_polygon(_train_body_poly())
			_set_body_style(&"train")
			aura.color = Color(0.45, 0.32, 0.16, 0.22)
			aura.polygon = _ring_poly(16.0, 30.0)
			aura.visible = true
		GameplayEnums.ArchitectureId.NEURO_HACKER:
			_set_body_polygon(_default_body_poly())
			_set_body_style(&"neuro")
			aura.color = Color(0.38, 0.22, 0.42, 0.18)
			aura.polygon = _ring_poly(15.0, 26.0)
			aura.visible = true
		_:
			_set_body_polygon(_default_body_poly())
			_set_body_style(&"player")
			aura.color = Color(0.4, 0.38, 0.32, 0.12)
			aura.polygon = _ring_poly(14.0, 22.0)
			aura.visible = true
	if "polygon" in body:
		_body_rest_poly = body.polygon
	_kill_tween()
	if _aura_tween and _aura_tween.is_valid():
		_aura_tween.kill()
	aura.scale = Vector2.ONE
	aura.modulate = Color.WHITE
	# Pulse alpha only — kit economies own aura scale (swarm / heat / drones).
	_aura_tween = create_tween().set_loops()
	_aura_tween.tween_property(aura, "modulate:a", 0.78, 0.55).set_trans(Tween.TRANS_SINE)
	_aura_tween.tween_property(aura, "modulate:a", 1.0, 0.55).set_trans(Tween.TRANS_SINE)


func set_kit_aura(color: Color, aura_scale: Vector2, enabled: bool) -> void:
	_ensure_nodes()
	if aura == null:
		return
	aura.visible = enabled
	if not enabled:
		aura.scale = Vector2.ONE
		return
	aura.color = color
	aura.scale = aura_scale


func _hand_pos(aim_angle: float) -> Vector2:
	var fwd := Vector2.from_angle(aim_angle)
	return fwd * 20.0 + Vector2(0, -22)


func muzzle_offset(dir: Vector2) -> Vector2:
	var aim := dir.normalized() if dir != Vector2.ZERO else Vector2.RIGHT
	return _hand_pos(aim.angle()) + aim * 18.0


func _aim_from_host() -> Vector2:
	var host := get_parent()
	if host == null:
		return _last_aim
	var facing = host.get("facing_direction")
	if facing is Vector2 and (facing as Vector2).length_squared() > 0.01:
		return (facing as Vector2).normalized()
	if host is CharacterBody2D and (host as CharacterBody2D).velocity.length() > 8.0:
		return (host as CharacterBody2D).velocity.normalized()
	return _last_aim


func _uses_iso_gun() -> bool:
	return _shape_tag == "gun" or _shape_tag == "mortar"


func _apply_held_prop(dir: Vector2) -> void:
	if weapon == null:
		return
	var wspr := weapon.get_node_or_null("Sprite") as Sprite2D
	if _uses_iso_gun():
		weapon.rotation = 0.0
		weapon.color = Color(weapon.color.r, weapon.color.g, weapon.color.b, 0.0)
		if wspr:
			var stem := "weapon_rifle" if _shape_tag == "mortar" else "weapon_gun"
			var tex := ArtBank.space_facing(stem, dir)
			if tex == null:
				tex = ArtBank.space_facing("weapon_gun", dir)
			wspr.texture = tex
			wspr.visible = tex != null
			wspr.position = Vector2.ZERO
			wspr.rotation = 0.0
			wspr.modulate = Color(0.58, 0.48, 0.38, 1)
			if tex:
				ArtBank.fit_height(wspr, 26.0, false)
	else:
		weapon.rotation = dir.angle()
		if weapon.color.a < 0.4:
			weapon.color.a = 1.0
		if wspr:
			wspr.visible = false


func hold_aim(dir: Vector2) -> void:
	if weapon == null or dir.length_squared() < 0.01:
		return
	var aim := dir.normalized()
	_last_aim = aim
	var ang := aim.angle()
	var hold := _hand_pos(ang)
	weapon.visible = true
	weapon.position = hold
	weapon.scale = Vector2.ONE
	_weapon_rest_pos = hold
	_apply_held_prop(aim)
	_apply_weapon_depth(ang)
	_sync_body_facing(aim)


func _apply_weapon_depth(aim_angle: float) -> void:
	if weapon == null:
		return
	# South-facing (toward camera) draws in front of the body.
	weapon.z_index = 4 if sin(aim_angle) > -0.2 else -1


func _sync_body_facing(dir: Vector2) -> void:
	if body and body.has_method("set_facing"):
		body.call("set_facing", dir)
	if body:
		body.rotation = 0.0
		body.scale = Vector2.ONE


func _lock_pose() -> void:
	_pose_locked = true
	_kill_tween()


func _unlock_pose() -> void:
	_pose_locked = false


func apply_weapon_look(weapon_data: WeaponData, arch: ArchitectureData = null) -> void:
	if weapon == null or weapon_data == null:
		return
	var tint := weapon_data.visual_tint
	if arch:
		tint = weapon_data.visual_tint.lerp(arch.visual_tint, 0.35)
		_accent = _element_color_from_tag(weapon_data.element_tag).lerp(arch.visual_tint, 0.25)
	else:
		_accent = _element_color_from_tag(weapon_data.element_tag)
	_shape_tag = String(weapon_data.shape_tag)
	var steel := Color(0.42, 0.38, 0.32).lerp(tint, 0.4)
	weapon.color = steel
	weapon.modulate = Color.WHITE
	match _shape_tag:
		"whip":
			weapon.polygon = _whip_poly()
		"toad":
			weapon.polygon = _toad_poly()
		"gun", "mortar":
			weapon.polygon = _gun_poly()
		_:
			weapon.polygon = _blade_poly()
	weapon.scale = Vector2.ONE
	_ensure_weapon_sprite()
	var wspr := weapon.get_node_or_null("Sprite") as Sprite2D
	if wspr and not _uses_iso_gun():
		wspr.visible = false
	hold_aim(_aim_from_host())


func apply_faction_look(faction: GameplayEnums.Faction, base_color: Color) -> void:
	_resolve_body()
	_ensure_nodes()
	if body == null:
		return
	body.visible = true
	body.modulate = Color.WHITE
	body.scale = Vector2.ONE
	var tint := Color(base_color.r, base_color.g, base_color.b, 1.0)
	_set_body_color(tint)
	_body_rest_color = tint
	_accent = base_color.lightened(0.35)
	match faction:
		GameplayEnums.Faction.ANDROID:
			_set_body_polygon(_android_body_poly())
			_set_body_style(&"android")
		GameplayEnums.Faction.CYBORG:
			_set_body_polygon(_cyborg_body_poly())
			_set_body_style(&"cyborg")
		GameplayEnums.Faction.ROBO_BEAST:
			_set_body_polygon(_beast_body_poly())
			_set_body_style(&"beast")
		GameplayEnums.Faction.BIO_MUTANT:
			_set_body_polygon(_beast_body_poly())
			_set_body_color(tint.lightened(0.1))
			_body_rest_color = tint.lightened(0.1)
			_set_body_style(&"beast")
		_:
			_set_body_polygon(_savage_body_poly())
			_set_body_style(&"savage")
	if "polygon" in body:
		_body_rest_poly = body.polygon
	if weapon:
		weapon.visible = true
		weapon.color = Color(base_color.r * 0.45, base_color.g * 0.38, base_color.b * 0.32, 1)
		weapon.polygon = _blade_poly() if faction != GameplayEnums.Faction.ANDROID else _gun_poly()
		_shape_tag = "gun" if faction == GameplayEnums.Faction.ANDROID else "blade"
		hold_aim(_aim_from_host())
	if aura:
		aura.visible = false


## Melee pose variants — combo index / enemy attack style.
## 0 slash, 1 reverse, 2 overhead, 3 thrust, 4 rising.
const MELEE_VARIANT_COUNT := 5
const MIN_WINDUP_VISUAL := 0.22
const MIN_SWING_VISUAL := 0.28
const MIN_HOSTILE_WINDUP := 0.32


func play_melee_windup(aim_angle: float, duration: float, variant: int = 0) -> void:
	_lock_pose()
	_set_body_combat_lock(true)
	rotation = 0.0
	weapon.visible = true
	var v := posmod(variant, MELEE_VARIANT_COUNT)
	var pose := _melee_pose(aim_angle, v)
	var hold := _hand_pos(aim_angle)
	var fwd := Vector2.from_angle(aim_angle)
	_last_aim = fwd
	weapon.position = hold
	weapon.scale = pose.weapon_scale_wind
	_apply_held_prop(fwd)
	if not _uses_iso_gun():
		weapon.rotation = pose.wind_from
	_apply_weapon_depth(aim_angle)
	telegraph.polygon = pose.tele_poly
	telegraph.rotation = aim_angle
	telegraph.position = fwd * 36.0 + Vector2(0, -10)
	telegraph.scale = Vector2.ONE
	telegraph.color = Color(_accent.r, _accent.g, _accent.b, 0.0)
	swing_arc.modulate.a = 0.0
	_sync_body_facing(fwd)
	_tween = create_tween()
	var wind := maxf(duration, MIN_WINDUP_VISUAL)
	_tween.tween_property(weapon, "rotation", pose.wind_to, wind * 0.75).set_trans(Tween.TRANS_BACK)
	_tween.parallel().tween_property(telegraph, "color:a", 0.55, wind)
	_tween.parallel().tween_property(telegraph, "scale", pose.tele_scale, wind)


func play_hostile_melee_windup(aim_angle: float, duration: float, variant: int = -1) -> void:
	## Strong readable telegraph so the player can time a dodge / parry.
	_lock_pose()
	rotation = 0.0
	weapon.visible = true
	var v := variant if variant >= 0 else randi() % MELEE_VARIANT_COUNT
	v = posmod(v, MELEE_VARIANT_COUNT)
	var pose := _melee_pose(aim_angle, v)
	var hold := _hand_pos(aim_angle)
	var fwd := Vector2.from_angle(aim_angle)
	_last_aim = fwd
	weapon.position = hold
	weapon.scale = Vector2(1.35, 1.35)
	_apply_held_prop(fwd)
	if not _uses_iso_gun():
		weapon.rotation = pose.wind_from
	_apply_weapon_depth(aim_angle)
	telegraph.polygon = _diamond_poly(32.0)
	telegraph.rotation = aim_angle
	telegraph.position = fwd * 38.0 + Vector2(0, -16)
	telegraph.scale = Vector2(0.55, 0.55)
	telegraph.color = Color(1.0, 0.12, 0.08, 0.0)
	swing_arc.polygon = _scale_poly(pose.arc_poly, 1.28)
	swing_arc.rotation = pose.arc_from
	swing_arc.position = Vector2.ZERO
	swing_arc.color = Color(0.85, 0.18, 0.12, 0.55)
	swing_arc.modulate.a = 0.0
	_sync_body_facing(fwd)
	_tween = create_tween()
	var wind := maxf(duration, MIN_HOSTILE_WINDUP)
	_tween.tween_property(weapon, "rotation", pose.wind_to, wind * 0.85).set_trans(Tween.TRANS_BACK)
	_tween.parallel().tween_property(telegraph, "color:a", 1.0, wind * 0.22)
	_tween.parallel().tween_property(telegraph, "scale", Vector2(2.15, 2.15), wind)
	_tween.parallel().tween_property(swing_arc, "modulate:a", 1.0, wind * 0.35)


func aim_hostile_telegraph(aim_angle: float) -> void:
	## Update telegraph facing during windup tracking without restarting the windup tween.
	if telegraph:
		telegraph.rotation = aim_angle
		telegraph.position = Vector2.from_angle(aim_angle) * 38.0 + Vector2(0, -16)
	if swing_arc:
		swing_arc.rotation = aim_angle - 0.9
		swing_arc.position = Vector2.ZERO


func play_melee_swing(
	aim_angle: float,
	duration: float,
	damage_type: GameplayEnums.DamageType = GameplayEnums.DamageType.PHYSICAL,
	accent_override: Color = Color(0, 0, 0, 0),
	variant: int = 0
) -> void:
	_lock_pose()
	var col := accent_override if accent_override.a > 0.0 else _element_color(damage_type)
	_accent = col
	var v := posmod(variant, MELEE_VARIANT_COUNT)
	var pose := _melee_pose(aim_angle, v)
	var hold := _hand_pos(aim_angle)
	var fwd := Vector2.from_angle(aim_angle)
	var finisher := accent_override.a > 0.0
	var arc_boost := 1.15 if finisher else 1.0
	swing_arc.polygon = _scale_poly(pose.arc_poly, arc_boost)
	swing_arc.rotation = pose.arc_from
	swing_arc.position = Vector2.ZERO
	swing_arc.color = Color(col.r * 0.7, col.g * 0.55, col.b * 0.4, 0.7)
	swing_arc.modulate.a = 1.0
	telegraph.color.a = 0.0
	weapon.position = hold
	weapon.scale = Vector2(1.25, 1.25) if finisher else pose.weapon_scale_swing
	_apply_held_prop(fwd)
	if not _uses_iso_gun():
		weapon.rotation = pose.swing_from
	_apply_weapon_depth(aim_angle)
	_sync_body_facing(fwd)
	_tween = create_tween()
	var active := maxf(duration, MIN_SWING_VISUAL)
	_tween.tween_property(weapon, "rotation", pose.swing_to, active).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.parallel().tween_property(weapon, "position", hold + fwd * 10.0, active)
	_tween.parallel().tween_property(swing_arc, "rotation", pose.arc_to, active)
	_tween.parallel().tween_property(swing_arc, "modulate:a", 0.0, active).set_ease(Tween.EASE_IN)
	_tween.parallel().tween_property(weapon, "scale", Vector2.ONE, active)
	_tween.tween_callback(_unlock_pose)


func _melee_pose(aim_angle: float, variant: int) -> Dictionary:
	var fwd := Vector2.from_angle(aim_angle)
	var rest := _hand_pos(aim_angle)
	match variant:
		1: # Reverse slash (counter-clockwise) — big opposite arc
			return {
				"wind_from": aim_angle + 1.35,
				"wind_to": aim_angle + 1.85,
				"swing_from": aim_angle + 1.7,
				"swing_to": aim_angle - 1.25,
				"arc_from": aim_angle + 1.2,
				"arc_to": aim_angle - 1.0,
				"arc_poly": _arc_poly_signed(78.0, true),
				"arc_pos": Vector2(10, -14),
				"weapon_pos": rest + fwd * 2.0,
				"weapon_end_pos": rest + fwd * 10.0,
				"weapon_scale_wind": Vector2(1.15, 1.15),
				"weapon_scale_swing": Vector2(1.3, 1.3),
				"tele_poly": _diamond_poly(16.0),
				"tele_rot": aim_angle,
				"tele_pos": fwd * 32.0 + Vector2(0, -8),
				"tele_scale": Vector2(1.35, 1.35),
				"body_wind_scale": Vector2(1.12, 0.88),
				"body_wind_rot": -0.22,
				"body_swing_scale": Vector2(0.88, 1.16),
				"body_swing_rot": 0.28,
				"thrust_extend": 0.0,
			}
		2: # Overhead chop — vertical, very readable
			return {
				"wind_from": aim_angle - 2.35,
				"wind_to": aim_angle - 2.7,
				"swing_from": aim_angle - 2.5,
				"swing_to": aim_angle + 0.55,
				"arc_from": aim_angle - 2.0,
				"arc_to": aim_angle + 0.7,
				"arc_poly": _arc_poly(82.0),
				"arc_pos": Vector2(2, -24),
				"weapon_pos": rest + Vector2(0, -16),
				"weapon_end_pos": rest + fwd * 14.0 + Vector2(0, 6),
				"weapon_scale_wind": Vector2(1.3, 1.3),
				"weapon_scale_swing": Vector2(1.35, 1.35),
				"tele_poly": _diamond_poly(14.0),
				"tele_rot": aim_angle,
				"tele_pos": fwd * 36.0 + Vector2(0, -22),
				"tele_scale": Vector2(1.2, 1.7),
				"body_wind_scale": Vector2(0.85, 1.22),
				"body_wind_rot": -0.12,
				"body_swing_scale": Vector2(1.22, 0.8),
				"body_swing_rot": 0.14,
				"thrust_extend": 0.0,
			}
		3: # Thrust / poke — forward lunge silhouette
			return {
				"wind_from": aim_angle - 0.2,
				"wind_to": aim_angle - 0.05,
				"swing_from": aim_angle,
				"swing_to": aim_angle + 0.1,
				"arc_from": aim_angle,
				"arc_to": aim_angle,
				"arc_poly": _muzzle_poly_scaled(2.4),
				"arc_pos": Vector2(20, -16),
				"weapon_pos": rest + fwd * -14.0,
				"weapon_end_pos": rest + fwd * 26.0,
				"weapon_scale_wind": Vector2(0.9, 1.1),
				"weapon_scale_swing": Vector2(1.5, 0.85),
				"tele_poly": _diamond_poly(11.0),
				"tele_rot": aim_angle,
				"tele_pos": fwd * 48.0 + Vector2(0, -10),
				"tele_scale": Vector2(1.9, 0.85),
				"body_wind_scale": Vector2(0.9, 1.1),
				"body_wind_rot": 0.0,
				"body_swing_scale": Vector2(1.22, 0.84),
				"body_swing_rot": 0.0,
				"thrust_extend": 1.0,
			}
		4: # Rising slash — low to high
			return {
				"wind_from": aim_angle + 1.6,
				"wind_to": aim_angle + 2.05,
				"swing_from": aim_angle + 1.85,
				"swing_to": aim_angle - 1.1,
				"arc_from": aim_angle + 1.45,
				"arc_to": aim_angle - 0.9,
				"arc_poly": _arc_poly_signed(80.0, true),
				"arc_pos": Vector2(8, -4),
				"weapon_pos": rest + Vector2(0, 12),
				"weapon_end_pos": rest + fwd * 10.0 + Vector2(0, -14),
				"weapon_scale_wind": Vector2(1.15, 1.15),
				"weapon_scale_swing": Vector2(1.3, 1.3),
				"tele_poly": _diamond_poly(15.0),
				"tele_rot": aim_angle - 0.45,
				"tele_pos": fwd * 28.0 + Vector2(0, 8),
				"tele_scale": Vector2(1.35, 1.35),
				"body_wind_scale": Vector2(1.14, 0.86),
				"body_wind_rot": 0.22,
				"body_swing_scale": Vector2(0.86, 1.2),
				"body_swing_rot": -0.24,
				"thrust_extend": 0.0,
			}
		_: # Classic horizontal slash
			return {
				"wind_from": aim_angle - 1.25,
				"wind_to": aim_angle - 1.65,
				"swing_from": aim_angle - 1.45,
				"swing_to": aim_angle + 1.15,
				"arc_from": aim_angle - 1.1,
				"arc_to": aim_angle + 0.9,
				"arc_poly": _arc_poly(76.0),
				"arc_pos": Vector2(12, -14),
				"weapon_pos": rest,
				"weapon_end_pos": rest + fwd * 8.0,
				"weapon_scale_wind": Vector2(1.1, 1.1),
				"weapon_scale_swing": Vector2(1.25, 1.25),
				"tele_poly": _diamond_poly(16.0),
				"tele_rot": aim_angle,
				"tele_pos": Vector2(28, -8).rotated(aim_angle * 0.05) + fwd * 10.0,
				"tele_scale": Vector2(1.35, 1.35),
				"body_wind_scale": Vector2(0.9, 1.12),
				"body_wind_rot": 0.14,
				"body_swing_scale": Vector2(1.16, 0.86),
				"body_swing_rot": -0.16,
				"thrust_extend": 0.0,
			}


func play_ranged_windup(aim_angle: float, duration: float) -> void:
	_lock_pose()
	weapon.visible = true
	var hold := _hand_pos(aim_angle)
	var fwd := Vector2.from_angle(aim_angle)
	_last_aim = fwd
	weapon.position = hold
	_apply_held_prop(fwd)
	_apply_weapon_depth(aim_angle)
	_sync_body_facing(fwd)
	telegraph.rotation = aim_angle
	telegraph.position = hold + fwd * 28.0
	telegraph.polygon = _diamond_poly(10.0)
	telegraph.color = Color(_accent.r, _accent.g, _accent.b, 0.0)
	_tween = create_tween()
	var wind := maxf(duration, 0.05)
	_tween.tween_property(weapon, "position", hold + fwd * -4.0, wind)
	_tween.parallel().tween_property(telegraph, "color:a", 0.55, wind)
	_tween.parallel().tween_property(telegraph, "scale", Vector2(1.4, 1.4), wind)


func play_hostile_ranged_windup(aim_angle: float, duration: float) -> void:
	play_hostile_pattern_windup(AttackData.PatternKind.CHARGE_SHOT, aim_angle, duration, 0, 0.0)


func play_hostile_pattern_windup(
	pattern: int,
	aim_angle: float,
	duration: float,
	variant: int = -1,
	slam_radius: float = 0.0
) -> void:
	## Distinct tells per pattern so first contact reads as a new threat.
	_lock_pose()
	rotation = 0.0
	weapon.visible = true
	var fwd := Vector2.from_angle(aim_angle)
	_last_aim = fwd
	var hold := _hand_pos(aim_angle)
	var wind := maxf(duration, MIN_HOSTILE_WINDUP)
	_apply_held_prop(fwd)
	_apply_weapon_depth(aim_angle)
	_sync_body_facing(fwd)
	match pattern:
		AttackData.PatternKind.OVERHEAD_SLAM:
			var radius := slam_radius if slam_radius > 0.0 else 72.0
			telegraph.polygon = _ring_poly(maxf(radius * 0.55, 18.0), radius)
			telegraph.rotation = 0.0
			telegraph.position = Vector2(0, -8)
			telegraph.scale = Vector2(0.35, 0.35)
			telegraph.color = Color(0.72, 0.22, 0.1, 0.0)
			swing_arc.polygon = _ring_poly(radius * 0.4, radius * 0.55)
			swing_arc.rotation = 0.0
			swing_arc.position = Vector2.ZERO
			swing_arc.color = Color(0.7, 0.28, 0.12, 0.5)
			swing_arc.modulate.a = 0.0
			weapon.position = hold
			if not _uses_iso_gun():
				weapon.rotation = aim_angle - 2.4
			weapon.scale = Vector2(1.35, 1.35)
			_tween = create_tween()
			_tween.tween_property(telegraph, "color:a", 0.9, wind * 0.35)
			_tween.parallel().tween_property(telegraph, "scale", Vector2.ONE, wind)
			_tween.parallel().tween_property(swing_arc, "modulate:a", 0.85, wind * 0.5)
			if not _uses_iso_gun():
				_tween.parallel().tween_property(weapon, "rotation", aim_angle - 2.7, wind * 0.85)
		AttackData.PatternKind.LUNGE:
			telegraph.polygon = _line_poly(78.0, 10.0)
			telegraph.rotation = aim_angle
			telegraph.position = fwd * 18.0 + Vector2(0, -12)
			telegraph.scale = Vector2(0.4, 0.85)
			telegraph.color = Color(0.72, 0.38, 0.16, 0.0)
			swing_arc.polygon = _muzzle_poly_scaled(2.2)
			swing_arc.rotation = aim_angle
			swing_arc.position = hold
			swing_arc.color = Color(0.7, 0.4, 0.18, 0.55)
			swing_arc.modulate.a = 0.0
			weapon.position = hold + fwd * -8.0
			_tween = create_tween()
			_tween.tween_property(telegraph, "color:a", 0.95, wind * 0.3)
			_tween.parallel().tween_property(telegraph, "scale", Vector2(1.35, 1.0), wind)
			_tween.parallel().tween_property(swing_arc, "modulate:a", 0.9, wind * 0.45)
			_tween.parallel().tween_property(weapon, "position", hold + fwd * -14.0, wind)
		AttackData.PatternKind.CHARGE_SHOT:
			telegraph.polygon = _line_poly(96.0, 7.0)
			telegraph.rotation = aim_angle
			telegraph.position = fwd * 28.0 + Vector2(0, -12)
			telegraph.scale = Vector2(0.25, 0.7)
			telegraph.color = Color(0.62, 0.42, 0.22, 0.0)
			swing_arc.polygon = _diamond_poly(16.0)
			swing_arc.rotation = aim_angle
			swing_arc.position = hold + fwd * 22.0
			swing_arc.color = Color(0.7, 0.48, 0.22, 0.55)
			swing_arc.modulate.a = 0.0
			weapon.position = hold
			_tween = create_tween()
			_tween.tween_property(telegraph, "color:a", 1.0, wind * 0.35)
			_tween.parallel().tween_property(telegraph, "scale", Vector2(1.55, 1.05), wind)
			_tween.parallel().tween_property(swing_arc, "modulate:a", 0.95, wind * 0.55)
			_tween.parallel().tween_property(weapon, "position", hold + fwd * -6.0, wind)
		AttackData.PatternKind.FAN_SHOT:
			telegraph.polygon = _fan_poly(54.0, 0.9)
			telegraph.rotation = aim_angle
			telegraph.position = fwd * 20.0 + Vector2(0, -12)
			telegraph.scale = Vector2(0.45, 0.45)
			telegraph.color = Color(0.7, 0.36, 0.16, 0.0)
			swing_arc.polygon = _fan_poly(40.0, 0.75)
			swing_arc.rotation = aim_angle
			swing_arc.position = hold
			swing_arc.color = Color(0.7, 0.4, 0.2, 0.5)
			swing_arc.modulate.a = 0.0
			weapon.position = hold
			_tween = create_tween()
			_tween.tween_property(telegraph, "color:a", 0.92, wind * 0.35)
			_tween.parallel().tween_property(telegraph, "scale", Vector2(1.35, 1.35), wind)
			_tween.parallel().tween_property(swing_arc, "modulate:a", 0.85, wind * 0.5)
		AttackData.PatternKind.HOOK:
			telegraph.polygon = _line_poly(118.0, 8.0)
			telegraph.rotation = aim_angle
			telegraph.position = fwd * 10.0 + Vector2(0, -12)
			telegraph.scale = Vector2(0.3, 0.9)
			telegraph.color = Color(0.52, 0.22, 0.14, 0.0)
			swing_arc.polygon = _line_poly(36.0, 14.0)
			swing_arc.rotation = aim_angle
			swing_arc.position = hold + fwd * -12.0
			swing_arc.color = Color(0.48, 0.28, 0.16, 0.7)
			swing_arc.modulate.a = 0.0
			weapon.position = hold + fwd * -16.0
			_tween = create_tween()
			_tween.tween_property(telegraph, "color:a", 0.95, wind * 0.28)
			_tween.parallel().tween_property(telegraph, "scale", Vector2(1.45, 1.0), wind)
			_tween.parallel().tween_property(weapon, "position", hold + fwd * -22.0, wind)
			_tween.parallel().tween_property(swing_arc, "modulate:a", 0.9, wind * 0.45)
		_:
			play_hostile_melee_windup(aim_angle, duration, variant)


func aim_hostile_pattern_telegraph(pattern: int, aim_angle: float, slam_radius: float = 0.0) -> void:
	if telegraph == null:
		return
	var fwd := Vector2.from_angle(aim_angle)
	match pattern:
		AttackData.PatternKind.OVERHEAD_SLAM:
			telegraph.rotation = 0.0
			telegraph.position = Vector2(0, -8)
		AttackData.PatternKind.LUNGE, AttackData.PatternKind.CHARGE_SHOT, AttackData.PatternKind.HOOK:
			telegraph.rotation = aim_angle
			telegraph.position = fwd * (22.0 if pattern == AttackData.PatternKind.LUNGE else 28.0) + Vector2(0, -12)
			if swing_arc:
				swing_arc.rotation = aim_angle
		AttackData.PatternKind.FAN_SHOT:
			telegraph.rotation = aim_angle
			telegraph.position = fwd * 20.0 + Vector2(0, -12)
		_:
			aim_hostile_telegraph(aim_angle)
	# silence unused when not slam
	if slam_radius < 0.0:
		pass


func play_ranged_fire(aim_angle: float, damage_type: GameplayEnums.DamageType = GameplayEnums.DamageType.PHYSICAL) -> void:
	_lock_pose()
	var col := _element_color(damage_type)
	var hold := _hand_pos(aim_angle)
	var fwd := Vector2.from_angle(aim_angle)
	_last_aim = fwd
	weapon.position = hold
	_apply_held_prop(fwd)
	_apply_weapon_depth(aim_angle)
	_sync_body_facing(fwd)
	swing_arc.polygon = _muzzle_poly()
	swing_arc.rotation = aim_angle
	swing_arc.position = hold + fwd * 16.0
	swing_arc.color = Color(col.r * 0.85, col.g * 0.55, col.b * 0.35, 0.9)
	swing_arc.modulate.a = 1.0
	telegraph.color.a = 0.0
	_tween = create_tween()
	_tween.tween_property(weapon, "position", hold + fwd * 6.0, 0.05)
	_tween.parallel().tween_property(swing_arc, "modulate:a", 0.0, 0.16)
	_tween.tween_property(weapon, "position", hold, 0.1)
	_tween.tween_callback(_unlock_pose)


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
	if swing_arc:
		swing_arc.modulate.a = 0.0
	if telegraph:
		telegraph.color.a = 0.0
	if parry_flash:
		parry_shield.color = Color(1.0, 0.95, 0.45, 0.95)
	else:
		parry_shield.color = Color(0.45, 0.75, 1.0, 0.85)
	# Snap shield up immediately — no long "raise" feel.
	parry_shield.scale = Vector2(1.15, 1.15)
	parry_shield.color.a = 0.95
	if body:
		body.modulate = Color(1.25, 1.2, 0.9, 1) if parry_flash else Color(0.9, 1.05, 1.2, 1)
	_tween = create_tween()
	_tween.tween_property(parry_shield, "scale", Vector2(1.25, 1.25), 0.04).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(parry_shield, "scale", Vector2(1.12, 1.12), 0.06)


func play_block_hold() -> void:
	_kill_tween()
	parry_shield.color = Color(0.4, 0.7, 1.0, 0.75)
	_tween = create_tween()
	_tween.tween_property(parry_shield, "scale", Vector2(1.1, 1.1), 0.1)
	if body:
		_tween.parallel().tween_property(body, "modulate", Color(0.9, 1.05, 1.2, 1), 0.1)


func play_block_end() -> void:
	play_parry_end()


func play_charge_start(aim_angle: float, charge: float = 0.0) -> void:
	_lock_pose()
	weapon.visible = true
	var fwd := Vector2.from_angle(aim_angle)
	_last_aim = fwd
	weapon.position = _hand_pos(aim_angle)
	_apply_held_prop(fwd)
	if not _uses_iso_gun():
		weapon.rotation = aim_angle - 0.4
	_apply_weapon_depth(aim_angle)
	_sync_body_facing(fwd)
	telegraph.rotation = aim_angle
	telegraph.position = fwd * 36.0 + Vector2(0, -10)
	telegraph.polygon = _diamond_poly(12.0)
	telegraph.color = Color(0.62, 0.42, 0.22, 0.0)
	_set_charge_ui(aim_angle, charge)
	_tween = create_tween()
	_tween.tween_property(telegraph, "color:a", 0.55, 0.08)
	if charge_bar_bg:
		_tween.parallel().tween_property(charge_bar_bg, "color:a", 0.75, 0.08)


func play_charge_tick(aim_angle: float, charge: float) -> void:
	var fwd := Vector2.from_angle(aim_angle)
	_last_aim = fwd
	var hold := _hand_pos(aim_angle)
	weapon.position = hold + fwd * (-6.0 * charge)
	_apply_held_prop(fwd)
	if not _uses_iso_gun():
		weapon.rotation = aim_angle - 0.4 - charge * 0.5
	_apply_weapon_depth(aim_angle)
	_sync_body_facing(fwd)
	telegraph.rotation = aim_angle
	telegraph.position = fwd * (36.0 + 20.0 * charge) + Vector2(0, -10)
	telegraph.scale = Vector2.ONE * (1.0 + charge * 0.8)
	telegraph.color.a = 0.4 + charge * 0.5
	_set_charge_ui(aim_angle, charge)


func _set_charge_ui(aim_angle: float, charge: float) -> void:
	var c := clampf(charge, 0.0, 1.0)
	if charge_bar_bg:
		charge_bar_bg.color = Color(0.06, 0.1, 0.16, 0.75)
		charge_bar_bg.position = Vector2(0, 18)
	if charge_bar_fill:
		var w := maxf(_charge_bar_width * c, 1.0)
		charge_bar_fill.polygon = _bar_poly(w, 5.0)
		# Grow from left edge of the feet bar.
		charge_bar_fill.position = Vector2((-_charge_bar_width + w) * 0.5, 18)
		charge_bar_fill.color = Color(
			lerpf(0.45, 0.85, c),
			lerpf(0.32, 0.42, c),
			lerpf(0.16, 0.18, c),
			0.55 + c * 0.4
		)
	if charge_aim_beam:
		var len := 42.0 + 70.0 * c
		charge_aim_beam.polygon = _aim_beam_poly(len)
		charge_aim_beam.rotation = aim_angle
		charge_aim_beam.position = Vector2(0, -16)
		charge_aim_beam.color = Color(0.62, 0.38, 0.16, 0.18 + c * 0.35)


func play_circle_slash(duration: float) -> void:
	_lock_pose()
	var active := maxf(duration, 0.12)
	var fwd := _last_aim if _last_aim.length_squared() > 0.01 else Vector2.RIGHT
	var hold := _hand_pos(fwd.angle())
	swing_arc.polygon = _arc_poly(78.0)
	swing_arc.position = Vector2.ZERO
	swing_arc.rotation = -PI
	swing_arc.color = Color(0.62, 0.42, 0.28, 0.8)
	swing_arc.modulate.a = 1.0
	weapon.visible = true
	weapon.position = hold
	_apply_held_prop(fwd)
	_tween = create_tween()
	_tween.tween_property(swing_arc, "rotation", PI, active).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if not _uses_iso_gun():
		_tween.parallel().tween_property(weapon, "rotation", weapon.rotation + TAU, active)
	_tween.parallel().tween_property(swing_arc, "modulate:a", 0.0, active)
	_tween.tween_callback(_unlock_pose)


func play_hit_flash() -> void:
	if body == null:
		return
	var t := create_tween()
	t.tween_property(body, "modulate", Color(2.0, 2.0, 2.0, 1), 0.04)
	t.tween_property(body, "modulate", Color.WHITE, 0.1)


func play_flinch() -> void:
	if body == null:
		return
	play_hit_flash()


func play_stun_stars(duration: float = 1.0) -> void:
	## Tom & Jerry style stars spinning above the head while stunned/staggered.
	var existing := get_node_or_null("StunStars")
	if existing:
		existing.queue_free()
	var stars_script: Script = load("res://components/stun_stars_runtime.gd") as Script
	var holder := Node2D.new()
	holder.name = "StunStars"
	holder.set_script(stars_script)
	holder.set("duration", maxf(duration, 0.2))
	holder.position = Vector2(0, -52)
	add_child(holder)


func play_parry_impact() -> void:
	## Big golden "BAM" ring for God-of-War style parries.
	_ensure_nodes()
	if parry_shield:
		parry_shield.color = Color(1.0, 0.95, 0.35, 1.0)
		parry_shield.scale = Vector2(1.4, 1.4)
	var ring := Polygon2D.new()
	ring.polygon = _ring_poly(10.0, 18.0)
	ring.color = Color(1.0, 0.9, 0.3, 0.95)
	ring.z_index = 30
	ring.position = Vector2(8, -22)
	add_child(ring)
	var t := create_tween()
	t.tween_property(ring, "scale", Vector2(4.5, 4.5), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(ring, "modulate:a", 0.0, 0.18)
	t.tween_callback(ring.queue_free)
	if body:
		var bt := create_tween()
		bt.tween_property(body, "modulate", Color(2.0, 1.8, 0.8, 1), 0.05)
		bt.tween_property(body, "modulate", Color.WHITE, 0.15)


func reset_pose() -> void:
	_kill_tween()
	_unlock_pose()
	_set_body_combat_lock(false)
	if body:
		body.scale = Vector2.ONE
		body.rotation = 0.0
		body.modulate = Color.WHITE
		if not _body_rest_poly.is_empty():
			_set_body_polygon(_body_rest_poly)
		_set_body_color(_body_rest_color)
	if swing_arc:
		swing_arc.modulate.a = 0.0
	if telegraph:
		telegraph.color.a = 0.0
		telegraph.scale = Vector2.ONE
	if parry_shield:
		parry_shield.color.a = 0.0
	if charge_bar_bg:
		charge_bar_bg.color.a = 0.0
	hold_aim(_aim_from_host())
	if charge_bar_fill:
		charge_bar_fill.color.a = 0.0
		charge_bar_fill.polygon = _bar_poly(1.0, 5.0)
	if charge_aim_beam:
		charge_aim_beam.color.a = 0.0


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null


func _element_color(t: GameplayEnums.DamageType) -> Color:
	match t:
		GameplayEnums.DamageType.ELECTRICITY:
			return Color(0.55, 0.62, 0.48, 1)
		GameplayEnums.DamageType.CORROSION:
			return Color(0.38, 0.48, 0.28, 1)
		GameplayEnums.DamageType.FIRE:
			return Color(0.85, 0.38, 0.14, 1)
		GameplayEnums.DamageType.BLEED:
			return Color(0.62, 0.12, 0.12, 1)
		_:
			return Color(0.72, 0.68, 0.58, 1)


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
	return _arc_poly_signed(radius, false)


func _arc_poly_signed(radius: float, reverse: bool) -> PackedVector2Array:
	var pts: PackedVector2Array = [Vector2.ZERO]
	var steps := 7
	for i in steps + 1:
		var t := float(i) / float(steps)
		var a := (-0.9 + 1.8 * t) if not reverse else (0.9 - 1.8 * t)
		pts.append(Vector2(cos(a), sin(a)) * radius)
	return pts


func _muzzle_poly() -> PackedVector2Array:
	return _muzzle_poly_scaled(1.0)


func _muzzle_poly_scaled(s: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0, -6 * s), Vector2(16 * s, 0), Vector2(0, 6 * s), Vector2(4 * s, 0)
	])


func _scale_poly(poly: PackedVector2Array, s: float) -> PackedVector2Array:
	if is_equal_approx(s, 1.0):
		return poly
	var out := PackedVector2Array()
	out.resize(poly.size())
	for i in poly.size():
		out[i] = poly[i] * s
	return out


func _diamond_poly(r: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(r, 0), Vector2(0, r * 0.6), Vector2(-r * 0.4, 0), Vector2(0, -r * 0.6)
	])


func _line_poly(length: float, width: float) -> PackedVector2Array:
	var hw := width * 0.5
	return PackedVector2Array([
		Vector2(0, -hw), Vector2(length, -hw * 0.6), Vector2(length, hw * 0.6), Vector2(0, hw)
	])


func _fan_poly(radius: float, half_angle: float) -> PackedVector2Array:
	var pts: PackedVector2Array = [Vector2.ZERO]
	var steps := 6
	for i in steps + 1:
		var t := float(i) / float(steps)
		var a := -half_angle + half_angle * 2.0 * t
		pts.append(Vector2(cos(a), sin(a)) * radius)
	return pts


func _bar_poly(width: float, height: float) -> PackedVector2Array:
	var hx := width * 0.5
	var hy := height * 0.5
	return PackedVector2Array([
		Vector2(-hx, -hy), Vector2(hx, -hy), Vector2(hx, hy), Vector2(-hx, hy)
	])


func _aim_beam_poly(length: float) -> PackedVector2Array:
	## Thin forward wedge so throw direction reads clearly while charging.
	var tip := maxf(length, 16.0)
	return PackedVector2Array([
		Vector2(8, -3), Vector2(tip, -1.5), Vector2(tip, 1.5), Vector2(8, 3)
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
