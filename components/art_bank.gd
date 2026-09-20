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
const PATTERNS := "res://assets/kenney/patterns/"
const ABSTRACT := "res://assets/kenney/abstract/"
const FONT_TITLE := "res://assets/kenney/ui-scifi/fonts/Kenney Future.ttf"
const FONT_UI := "res://assets/kenney/ui-scifi/fonts/Kenney Future Narrow.ttf"

const DIR8: PackedStringArray = ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]

static var _cache: Dictionary = {}
static var _font_title: FontFile
static var _font_ui: FontFile


static func tex(path: String) -> Texture2D:
	if path == "":
		return null
	if _cache.has(path):
		return _cache[path] as Texture2D
	if not ResourceLoader.exists(path):
		_cache[path] = null
		return null
	var loaded: Texture2D = load(path) as Texture2D
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


static func rts_tile(index: int) -> Texture2D:
	return tex("%sscifiTile_%02d.png" % [RTS_TILE, index])


static func rts_unit(index: int) -> Texture2D:
	return tex("%sscifiUnit_%02d.png" % [RTS_UNIT, index])


static func rts_env(index: int) -> Texture2D:
	return tex("%sscifiEnvironment_%02d.png" % [RTS_ENV, index])


static func rts_struct(index: int) -> Texture2D:
	return tex("%sscifiStructure_%02d.png" % [RTS_STRUCT, index])


static func title_font() -> FontFile:
	if _font_title == null and ResourceLoader.exists(FONT_TITLE):
		_font_title = load(FONT_TITLE) as FontFile
	return _font_title


static func ui_font() -> FontFile:
	if _font_ui == null and ResourceLoader.exists(FONT_UI):
		_font_ui = load(FONT_UI) as FontFile
	return _font_ui


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
	s.scale = Vector2(scale, scale)
	s.z_index = z
	s.centered = true
	s.texture_filter = (
		CanvasItem.TEXTURE_FILTER_LINEAR if linear else CanvasItem.TEXTURE_FILTER_NEAREST
	)
	parent.add_child(s)
	return s
