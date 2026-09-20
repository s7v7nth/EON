class_name StylizedBodyVisual
extends Node2D
## Authored isometric body (Kenney Space Kit) with facing + walk bob.
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
var color: Color = Color(0.55, 0.58, 0.62, 1.0):
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
var _stem: String = "astronautA"
var _base_scale: float = 0.46
var _last_dir_key: String = ""


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
		_shadow.modulate = Color(0, 0, 0, 0.42)
		_shadow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		add_child(_shadow)


func _refresh_stem() -> void:
	match body_style:
		BodyStyle.NANO:
			_stem = "astronautB"
			_base_scale = 0.46
		BodyStyle.TRAIN:
			_stem = "rover"
			_base_scale = 0.42
		BodyStyle.NEURO:
			_stem = "astronautA"
			_base_scale = 0.46
		BodyStyle.ANDROID:
			_stem = "turret_single"
			_base_scale = 0.5
		BodyStyle.CYBORG:
			_stem = "craft_speederA"
			_base_scale = 0.4
		BodyStyle.BEAST:
			_stem = "alien"
			_base_scale = 0.52
		BodyStyle.SAVAGE:
			_stem = "alien"
			_base_scale = 0.48
		_:
			_stem = "astronautA"
			_base_scale = 0.46


func _process(delta: float) -> void:
	var speed := 0.0
	var parent_body := get_parent() as CharacterBody2D
	if parent_body:
		speed = parent_body.velocity.length()
		if parent_body.velocity.length() > 8.0:
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
	var tex := ArtBank.space_facing(_stem, _facing)
	if tex == null:
		tex = ArtBank.space(_stem + "_SE")
	if tex == null:
		return
	var key := "%s:%s" % [_stem, ArtBank.dir8_from(_facing)]
	if key == _last_dir_key and _sprite.texture == tex:
		return
	_last_dir_key = key
	_sprite.texture = tex
	_sprite.scale = Vector2(_base_scale, _base_scale)
	# Feet near origin so y-sort reads as a standing figure.
	var h := float(tex.get_height()) * _base_scale
	_sprite.offset = Vector2(0.0, -h * 0.38 / maxf(_base_scale, 0.01))
	if _shadow:
		_shadow.texture = tex
		_shadow.scale = Vector2(_base_scale * 0.92, _base_scale * 0.28)
		_shadow.offset = Vector2(0.0, 8.0)
		_shadow.modulate = Color(0, 0, 0, 0.4)


func _apply_tint() -> void:
	if _sprite == null:
		return
	# Keep Kenney paint readable; architecture color is a wash, not a recolor.
	_sprite.modulate = Color.WHITE.lerp(color, 0.32)


func _bob() -> void:
	if _sprite == null:
		return
	var bob := sin(_phase * TAU) * (1.2 + _walk_amount * 2.4)
	if _combat_locked:
		bob *= 0.22
	_sprite.position = Vector2(0.0, bob)


func _draw() -> void:
	# Ground contact ellipse so sprites don't float.
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(-14, 4), Vector2(14, 4), Vector2(10, 9), Vector2(-10, 9)
		]),
		Color(0, 0, 0, 0.28)
	)
