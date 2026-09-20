class_name ArtBank
extends RefCounted
## Cached CC0 textures. Missing files return null; callers must tolerate that.

const SPACE := "res://assets/kenney/space-kit/"
const DUNGEON := "res://assets/kenney/iso-dungeon/"
const RTS_TILE := "res://assets/kenney/sci-fi-rts/Tile/"
const RTS_UNIT := "res://assets/kenney/sci-fi-rts/Unit/"
const RTS_ENV := "res://assets/kenney/sci-fi-rts/Environment/"
const RTS_STRUCT := "res://assets/kenney/sci-fi-rts/Structure/"
const PARTICLES := "res://assets/kenney/particles/"
const SPLAT := "res://assets/kenney/splat/"
const SMOKE := "res://assets/kenney/smoke/"
const SHOOTER := "res://assets/kenney/space-shooter/"
const SHOOTER_BG := "res://assets/kenney/space-shooter/bg/"
const ICONS := "res://assets/kenney/icons/"
const UI := "res://assets/kenney/ui-scifi/"
const UI_PACK := "res://assets/kenney/ui-pack/"
const PATTERNS := "res://assets/kenney/patterns/"
const ABSTRACT := "res://assets/kenney/abstract/"
const FONT_TITLE := "res://assets/kenney/ui-scifi/fonts/Kenney Future.ttf"
const FONT_UI := "res://assets/kenney/ui-scifi/fonts/Kenney Future Narrow.ttf"
const PORTRAITS := "res://assets/portraits/"
const PANEL_GLASS := "res://assets/kenney/ui-scifi/panel_glass.png"
const PANEL_RECT := "res://assets/kenney/ui-scifi/panel_rectangle.png"
const CARD_BORDER := "res://assets/kenney/ui-pack/button_rectangle_depth_border.png"
const CARD_GLOSS := "res://assets/kenney/ui-pack/button_rectangle_depth_gloss.png"
const BAR_GLOSS := "res://assets/kenney/ui-scifi/bar_round_gloss_large.png"

const DIR8: PackedStringArray = ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]

static var _cache: Dictionary = {}
static var _opaque_rects: Dictionary = {}
static var _font_title: FontFile
static var _font_ui: FontFile


static func tex(path: String) -> Texture2D:
	if path == "":
		return null
	if _cache.has(path):
		return _cache[path] as Texture2D
	var loaded: Texture2D = null
	if ResourceLoader.exists(path):
		loaded = load(path) as Texture2D
	if loaded == null and FileAccess.file_exists(path):
		var img := Image.new()
		if img.load(path) == OK:
			loaded = ImageTexture.create_from_image(img)
	_cache[path] = loaded
	return loaded


static func space(stem: String) -> Texture2D:
	return tex(SPACE + stem + ".png")


static func dungeon(stem: String) -> Texture2D:
	return tex(DUNGEON + stem + ".png")


static func particle(stem: String) -> Texture2D:
	return tex(PARTICLES + stem + ".png")


static func shooter(stem: String) -> Texture2D:
	return tex(SHOOTER + stem + ".png")


static func icon(stem: String) -> Texture2D:
	return tex(ICONS + stem + ".png")


static func ui(stem: String) -> Texture2D:
	return tex(UI + stem + ".png")


static func ui_pack(stem: String) -> Texture2D:
	return tex(UI_PACK + stem + ".png")


## Kenney nine-slice. Callers must tolerate a null when the PNG is missing.
static func nine_slice(path: String, margin: float = 16.0, tint: Color = Color.WHITE) -> StyleBoxTexture:
	var texture := tex(path)
	if texture == null:
		return null
	var sb := StyleBoxTexture.new()
	sb.texture = texture
	sb.set_texture_margin_all(margin)
	sb.modulate_color = tint
	sb.content_margin_left = margin
	sb.content_margin_right = margin
	sb.content_margin_top = margin * 0.65
	sb.content_margin_bottom = margin * 0.65
	return sb


static func panel_style(kind: StringName = &"glass", tint: Color = Color(1, 1, 1, 1)) -> StyleBox:
	var path := PANEL_GLASS
	var margin := 18.0
	match kind:
		&"rect":
			path = PANEL_RECT
			margin = 20.0
		&"card":
			path = CARD_BORDER
			margin = 22.0
		&"card_hover":
			path = CARD_GLOSS
			margin = 22.0
		&"bar":
			path = BAR_GLOSS
			margin = 10.0
	var sb := nine_slice(path, margin, tint)
	if sb:
		return sb
	var flat := StyleBoxFlat.new()
	flat.bg_color = Color(0.05, 0.06, 0.09, 0.92)
	flat.set_corner_radius_all(10)
	flat.set_border_width_all(2)
	flat.border_color = Color(0.55, 0.62, 0.78, 0.55)
	flat.content_margin_left = 12
	flat.content_margin_right = 12
	flat.content_margin_top = 10
	flat.content_margin_bottom = 10
	return flat


static func button_style(hover: bool = false, tint: Color = Color.WHITE) -> StyleBox:
	return panel_style(&"card_hover" if hover else &"card", tint)


static func rts_tile(index: int) -> Texture2D:
	return tex("%sscifiTile_%02d.png" % [RTS_TILE, index])


static func rts_unit(index: int) -> Texture2D:
	return tex("%sscifiUnit_%02d.png" % [RTS_UNIT, index])


static func rts_env(index: int) -> Texture2D:
	return tex("%sscifiEnvironment_%02d.png" % [RTS_ENV, index])


static func rts_struct(index: int) -> Texture2D:
	return tex("%sscifiStructure_%02d.png" % [RTS_STRUCT, index])


static func title_font() -> FontFile:
	if _font_title == null:
		_font_title = _load_font(FONT_TITLE)
	return _font_title


static func ui_font() -> FontFile:
	if _font_ui == null:
		_font_ui = _load_font(FONT_UI)
	return _font_ui


static func _load_font(path: String) -> FontFile:
	if ResourceLoader.exists(path):
		var loaded := load(path) as FontFile
		if loaded:
			return loaded
	if FileAccess.file_exists(path):
		var font := FontFile.new()
		if font.load_dynamic_font(path) == OK:
			return font
	return null


static func dir8_from(v: Vector2) -> String:
	if v == Vector2.ZERO:
		return "SE"
	var idx := posmod(int(round(v.angle() / (PI * 0.25))), 8)
	return DIR8[idx]


static func dir4_from(v: Vector2) -> String:
	if absf(v.x) >= absf(v.y):
		return "E" if v.x >= 0.0 else "W"
	return "S" if v.y >= 0.0 else "N"


static func dir_diag_from(v: Vector2) -> String:
	var east := v.x >= 0.0
	var south := v.y >= 0.0
	if east and south:
		return "SE"
	if east:
		return "NE"
	if south:
		return "SW"
	return "NW"


static func facing(folder: String, stem: String, v: Vector2) -> Texture2D:
	var d8 := dir8_from(v)
	var found := tex("%s%s_%s.png" % [folder, stem, d8])
	if found:
		return found
	var d_diag := dir_diag_from(v)
	found = tex("%s%s_%s.png" % [folder, stem, d_diag])
	if found:
		return found
	return tex("%s%s_%s.png" % [folder, stem, dir4_from(v)])


static func space_facing(stem: String, v: Vector2) -> Texture2D:
	return facing(SPACE, stem, v)


static func dungeon_facing(stem: String, v: Vector2) -> Texture2D:
	return facing(DUNGEON, stem, v)


static func portrait(stem: String) -> Texture2D:
	return tex(PORTRAITS + stem + ".png")


## Kenney iso renders sit on huge transparent canvases. Crop to opaque pixels.
static func opaque_rect(texture: Texture2D) -> Rect2:
	if texture == null:
		return Rect2()
	var key: String = texture.resource_path
	if key.is_empty():
		key = "id:%d" % texture.get_instance_id()
	if _opaque_rects.has(key):
		return _opaque_rects[key] as Rect2
	var full := Rect2(0, 0, float(texture.get_width()), float(texture.get_height()))
	var img: Image = texture.get_image()
	if img == null:
		_opaque_rects[key] = full
		return full
	if img.is_compressed():
		var err := img.decompress()
		if err != OK:
			_opaque_rects[key] = full
			return full
	var used: Rect2i = img.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		_opaque_rects[key] = full
		return full
	used = used.grow(1).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var rect := Rect2(used)
	_opaque_rects[key] = rect
	return rect


static func apply_opaque_region(sprite: Sprite2D) -> Vector2:
	if sprite == null or sprite.texture == null:
		return Vector2.ZERO
	var rect := opaque_rect(sprite.texture)
	var tw := float(sprite.texture.get_width())
	var th := float(sprite.texture.get_height())
	if rect.size.x <= 1.0 or rect.size.y <= 1.0:
		sprite.region_enabled = false
		return Vector2(tw, th)
	if rect.size.x >= tw - 1.0 and rect.size.y >= th - 1.0:
		sprite.region_enabled = false
		return Vector2(tw, th)
	sprite.region_enabled = true
	sprite.region_rect = rect
	return rect.size


static func drawn_size(sprite: Sprite2D) -> Vector2:
	if sprite == null or sprite.texture == null:
		return Vector2.ZERO
	if sprite.region_enabled:
		return sprite.region_rect.size
	return Vector2(float(sprite.texture.get_width()), float(sprite.texture.get_height()))


static func fit_height(sprite: Sprite2D, target_h: float, grounded: bool = true) -> void:
	if sprite == null or sprite.texture == null:
		return
	var sz := apply_opaque_region(sprite)
	var sc := target_h / maxf(sz.y, 1.0)
	sprite.scale = Vector2(sc, sc)
	sprite.centered = true
	if grounded:
		sprite.offset = Vector2(0.0, -sz.y * 0.5)
	else:
		sprite.offset = Vector2.ZERO


static func clone_sprite_look(src: Sprite2D) -> Sprite2D:
	var ghost := Sprite2D.new()
	if src == null:
		return ghost
	ghost.texture = src.texture
	ghost.region_enabled = src.region_enabled
	ghost.region_rect = src.region_rect
	ghost.offset = src.offset
	ghost.centered = src.centered
	ghost.flip_h = src.flip_h
	ghost.flip_v = src.flip_v
	ghost.scale = src.scale
	ghost.rotation = src.rotation
	ghost.texture_filter = src.texture_filter
	return ghost


static func add_sprite(
	parent: Node,
	texture: Texture2D,
	local_pos: Vector2,
	scale: float = 1.0,
	z: int = 0,
	linear: bool = true
) -> Sprite2D:
	if parent == null or texture == null:
		return null
	var s := Sprite2D.new()
	s.texture = texture
	s.position = local_pos
	s.z_index = z
	s.centered = true
	s.texture_filter = (
		CanvasItem.TEXTURE_FILTER_LINEAR if linear else CanvasItem.TEXTURE_FILTER_NEAREST
	)
	apply_opaque_region(s)
	s.scale = Vector2(scale, scale)
	parent.add_child(s)
	return s


static func add_fitted(
	parent: Node,
	texture: Texture2D,
	local_pos: Vector2,
	target_h: float,
	z: int = 0,
	grounded: bool = true,
	linear: bool = true
) -> Sprite2D:
	var s := add_sprite(parent, texture, local_pos, 1.0, z, linear)
	if s:
		fit_height(s, target_h, grounded)
	return s
