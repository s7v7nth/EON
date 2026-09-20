class_name StylizedBodyVisual
extends Node2D
## One human clone body. Architecture kits are overlays on `hero`, never a new species.
## Duck-types Polygon2D API (color / polygon / scale / modulate) for CombatVisual.

enum BodyStyle {
	PLAYER,
	NANO,
	TRAIN,
	NEURO,
	SAVAGE,
	ANDROID,
	CYBORG,
	BEAST,
}

## Duck-typed for CombatVisualComponent (color / polygon / scale / modulate).
var color: Color = Color(0.86, 0.9, 0.95, 1.0):
	set(value):
		color = value
		_apply_tint()

var polygon: PackedVector2Array = PackedVector2Array([
	Vector2(-12, 2), Vector2(12, 2), Vector2(10, -42), Vector2(-10, -42)
]):
	set(value):
		polygon = value
		queue_redraw()

@export var body_style: BodyStyle = BodyStyle.PLAYER:
	set(value):
		body_style = value
		_refresh_stem()
		_apply_texture()
		_refresh_kit_overlay()

var _phase: float = 0.0
var _walk_amount: float = 0.0
var _facing: Vector2 = Vector2(1, 1)
var _combat_locked: bool = false
var _sprite: Sprite2D
var _shadow: Sprite2D
var _rim: PointLight2D
var _kit_fx: Node2D
var _stem: String = "hero"
var _target_h: float = 92.0
var _last_dir_key: String = ""
var _custom_stem: String = ""
var _illustrated: bool = true


func uses_illustrated() -> bool:
	return _illustrated


func _ready() -> void:
	z_index = 0
	_ensure_sprites()
	_refresh_stem()
	_apply_texture()
	_apply_tint()
	_refresh_kit_overlay()
	queue_redraw()


func set_body_style_name(style_name: StringName) -> void:
	match String(style_name):
		"nano", "nanomachines":
			body_style = BodyStyle.NANO
		"train", "electro_train":
			body_style = BodyStyle.TRAIN
		"neuro", "neuro_hacker":
			body_style = BodyStyle.NEURO
		"savage":
			body_style = BodyStyle.SAVAGE
		"android":
			body_style = BodyStyle.ANDROID
		"cyborg":
			body_style = BodyStyle.CYBORG
		"beast", "bio_mutant", "robo_beast":
			body_style = BodyStyle.BEAST
		_:
			body_style = BodyStyle.PLAYER


func set_combat_pose_active(active: bool) -> void:
	_combat_locked = active


func apply_custom_stem(stem: String, target_h: float = 0.0) -> void:
	if stem.strip_edges() == "":
		return
	## Only honor stems that exist in the illustrated pack (never Kenney fallback).
	if ArtBank.illustrated(stem) == null and ArtBank.illustrated_facing(stem, Vector2(1, 1)) == null:
		return
	_custom_stem = stem
	_stem = stem
	if target_h > 8.0:
		_target_h = target_h
	_last_dir_key = ""
	_apply_texture()


func current_texture() -> Texture2D:
	if _sprite:
		return _sprite.texture
	return null


func sprite_node() -> Sprite2D:
	return _sprite


func current_stem() -> String:
	return _stem


func _ensure_sprites() -> void:
	_sprite = get_node_or_null("Sprite") as Sprite2D
	if _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.name = "Sprite"
		_sprite.centered = true
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(_sprite)
	_shadow = get_node_or_null("ContactShadow") as Sprite2D
	if _shadow == null:
		_shadow = Sprite2D.new()
		_shadow.name = "ContactShadow"
		_shadow.centered = true
		_shadow.z_index = -1
		_shadow.modulate = Color(0, 0, 0, 0.5)
		_shadow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(_shadow)
	_rim = get_node_or_null("RimLight") as PointLight2D
	if _rim:
		_rim.queue_free()
		_rim = null


func _refresh_stem() -> void:
	if _custom_stem != "":
		_stem = _custom_stem
		return
	match body_style:
		BodyStyle.NANO, BodyStyle.TRAIN, BodyStyle.NEURO, BodyStyle.PLAYER:
			## Player kits share the clone silhouette.
			_stem = "hero"
			_target_h = 92.0
		BodyStyle.ANDROID:
			_stem = "enemy_nano"
			_target_h = 86.0
		BodyStyle.CYBORG:
			_stem = "enemy_scrap"
			_target_h = 96.0
		BodyStyle.BEAST:
			_stem = "hive_boss"
			_target_h = 128.0
		BodyStyle.SAVAGE:
			_stem = "enemy_swarm"
			_target_h = 72.0
		_:
			_stem = "hero"
			_target_h = 92.0


func set_facing(dir: Vector2) -> void:
	if dir.length_squared() < 0.01:
		return
	_facing = dir
	_apply_texture()


func _process(delta: float) -> void:
	var speed := 0.0
	var parent_body := get_parent() as CharacterBody2D
	if parent_body:
		speed = parent_body.velocity.length()
		var facing_prop = parent_body.get("facing_direction")
		if facing_prop is Vector2 and (facing_prop as Vector2).length_squared() > 0.01:
			_facing = facing_prop as Vector2
		elif parent_body.velocity.length() > 8.0:
			_facing = parent_body.velocity
	var target_walk := clampf(speed / 180.0, 0.0, 1.0)
	_walk_amount = lerpf(_walk_amount, target_walk, 1.0 - exp(-12.0 * delta))
	var rate := lerpf(2.2, 9.0, _walk_amount)
	_phase += delta * rate
	var key := "%s:%s" % [_stem, ArtBank.dir8_from(_facing)]
	if key != _last_dir_key:
		_apply_texture()
	_bob()


func _apply_texture() -> void:
	if _sprite == null:
		return
	var tex := _illustrated_tex()
	if tex == null:
		return
	var key := "%s:%s" % [_stem, ArtBank.dir8_from(_facing)]
	if key == _last_dir_key and _sprite.texture == tex:
		return
	_last_dir_key = key
	_sprite.texture = tex
	ArtBank.fit_height(_sprite, _target_h, true)
	if _shadow:
		_shadow.texture = tex
		ArtBank.apply_opaque_region(_shadow)
		var sz := ArtBank.drawn_size(_shadow)
		var sc := _target_h / maxf(sz.y, 1.0)
		_shadow.scale = Vector2(sc * 0.92, sc * 0.28)
		_shadow.centered = true
		_shadow.offset = Vector2(0.0, 6.0)
		_shadow.modulate = Color(0, 0, 0, 0.4)
	_tune_rim()


func _illustrated_tex() -> Texture2D:
	var facing := ArtBank.illustrated_facing(_stem, _facing)
	if facing:
		return facing
	var plain := ArtBank.illustrated(_stem)
	if plain:
		return plain
	if _stem != "hero":
		return ArtBank.illustrated_facing("hero", _facing)
	return ArtBank.illustrated("hero_SE")


func _tune_rim() -> void:
	if _rim == null:
		return
	## Compatibility 2D lights grain the floor on Mac. Nobody gets a PointLight2D.
	_rim.enabled = false
	_rim.energy = 0.0


func _apply_tint() -> void:
	if _sprite == null:
		return
	## Keep the clone paint. Kit color is overlay geometry, not a slime wash.
	_sprite.modulate = Color.WHITE


func _bob() -> void:
	if _sprite == null:
		return
	## No floaty walk cycle. Facing swap is the only motion.
	_sprite.position = Vector2.ZERO


func _refresh_kit_overlay() -> void:
	if _kit_fx and is_instance_valid(_kit_fx):
		_kit_fx.queue_free()
	_kit_fx = null
	## Sit on the Visual (92px body space), never as a child of the scaled sprite.
	_kit_fx = Node2D.new()
	_kit_fx.name = "KitFx"
	_kit_fx.z_index = 2
	add_child(_kit_fx)
	match body_style:
		BodyStyle.NANO:
			## Same clone; integrity visor + faint veins. Not a pudge, not a sweeper.
			_kit_poly(_kit_fx, PackedVector2Array([
				Vector2(-7, -80), Vector2(7, -80), Vector2(6, -70), Vector2(-6, -70)
			]), Color(0.28, 0.95, 0.42, 0.42))
			_kit_poly(_kit_fx, PackedVector2Array([
				Vector2(-2, -68), Vector2(0, -36), Vector2(2, -36), Vector2(1, -68)
			]), Color(0.35, 0.9, 0.45, 0.28))
			_kit_poly(_kit_fx, PackedVector2Array([
				Vector2(-8, -58), Vector2(-11, -28), Vector2(-9, -28), Vector2(-6, -58)
			]), Color(0.3, 0.85, 0.4, 0.22))
		BodyStyle.TRAIN:
			_kit_poly(_kit_fx, PackedVector2Array([
				Vector2(-18, -62), Vector2(-6, -66), Vector2(-7, -46), Vector2(-18, -44)
			]), Color(0.92, 0.42, 0.14, 0.5))
			_kit_poly(_kit_fx, PackedVector2Array([
				Vector2(6, -64), Vector2(18, -60), Vector2(17, -42), Vector2(5, -46)
			]), Color(0.95, 0.38, 0.12, 0.5))
			_kit_poly(_kit_fx, PackedVector2Array([
				Vector2(-6, -80), Vector2(6, -80), Vector2(5, -70), Vector2(-5, -70)
			]), Color(1.0, 0.55, 0.15, 0.4))
		BodyStyle.NEURO:
			_kit_poly(_kit_fx, PackedVector2Array([
				Vector2(-9, -82), Vector2(-7, -30), Vector2(-5, -30), Vector2(-7, -82)
			]), Color(0.45, 0.9, 1.0, 0.45))
			_kit_poly(_kit_fx, PackedVector2Array([
				Vector2(5, -80), Vector2(10, -32), Vector2(8, -32), Vector2(3, -80)
			]), Color(0.55, 0.78, 1.0, 0.35))
			_kit_poly(_kit_fx, PackedVector2Array([
				Vector2(-6, -80), Vector2(6, -80), Vector2(5, -70), Vector2(-5, -70)
			]), Color(0.4, 0.85, 1.0, 0.35))
		BodyStyle.PLAYER:
			## Grey suit already paints the visor; tiny energy edge so Synthetic reads.
			_kit_poly(_kit_fx, PackedVector2Array([
				Vector2(-6, -80), Vector2(6, -80), Vector2(5, -71), Vector2(-5, -71)
			]), Color(0.45, 0.92, 1.0, 0.28))
		_:
			pass


func _kit_poly(parent: Node2D, poly: PackedVector2Array, col: Color) -> void:
	var p := Polygon2D.new()
	p.polygon = poly
	p.color = col
	parent.add_child(p)


func _draw() -> void:
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(-16, 2), Vector2(16, 2), Vector2(12, 8), Vector2(-12, 8)
		]),
		Color(0, 0, 0, 0.28)
	)
