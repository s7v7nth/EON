class_name StylizedBodyVisual
extends Node2D
## Illustrated isometric body (hero / scrap / nano / hive) with facing + walk bob.
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

var _phase: float = 0.0
var _walk_amount: float = 0.0
var _facing: Vector2 = Vector2(1, 1)
var _combat_locked: bool = false
var _sprite: Sprite2D
var _shadow: Sprite2D
var _rim: PointLight2D
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
	if _rim == null:
		_rim = PointLight2D.new()
		_rim.name = "RimLight"
		_rim.texture = ArtBank.radial_light()
		_rim.energy = 0.95
		_rim.texture_scale = 1.35
		_rim.position = Vector2(10, -28)
		add_child(_rim)


func _refresh_stem() -> void:
	if _custom_stem != "":
		_stem = _custom_stem
		return
	match body_style:
		BodyStyle.NANO:
			_stem = "hero"
			_target_h = 92.0
		BodyStyle.TRAIN:
			_stem = "hero"
			_target_h = 94.0
		BodyStyle.NEURO:
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
	_apply_texture()
	_bob()
	queue_redraw()


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
		_shadow.modulate = Color(0, 0, 0, 0.48)
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
	match body_style:
		BodyStyle.NANO, BodyStyle.SAVAGE, BodyStyle.BEAST:
			_rim.color = Color(0.55, 1.0, 0.32, 1)
			_rim.energy = 1.15
		BodyStyle.ANDROID, BodyStyle.NEURO:
			_rim.color = Color(0.35, 0.9, 1.0, 1)
			_rim.energy = 1.05
		BodyStyle.CYBORG, BodyStyle.TRAIN:
			_rim.color = Color(1.0, 0.35, 0.22, 1)
			_rim.energy = 1.2
		_:
			_rim.color = Color(0.55, 0.85, 1.0, 1)
			_rim.energy = 0.9


func _apply_tint() -> void:
	if _sprite == null:
		return
	## Kit tints ride on illustrated paint; never a grey voxel wash.
	_sprite.modulate = Color.WHITE.lerp(color, 0.28)


func _bob() -> void:
	if _sprite == null:
		return
	var bob := sin(_phase * TAU) * (1.2 + _walk_amount * 2.4)
	if _combat_locked:
		bob *= 0.22
	_sprite.position = Vector2(0.0, bob)


func _draw() -> void:
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(-18, 2), Vector2(18, 2), Vector2(13, 10), Vector2(-13, 10)
		]),
		Color(0, 0, 0, 0.38)
	)
