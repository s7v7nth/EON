extends Control
## Isaac-style procedural dungeon mini-map (explored / current / boss).

const CELL := 14.0
const GAP := 3.0
const PAD := 8.0

var _dirty: bool = true


func _ready() -> void:
	custom_minimum_size = Vector2(160, 140)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	SignalBus.route_chosen.connect(_on_map_event)
	SignalBus.room_cleared.connect(_on_map_event)
	SignalBus.room_entered.connect(_on_map_event)
	SignalBus.biome_changed.connect(_on_biome)
	call_deferred("_refresh_visibility")
	queue_redraw()


func _on_biome(_biome_id: int) -> void:
	_dirty = true
	_refresh_visibility()
	queue_redraw()


func _on_map_event(_a = null) -> void:
	_dirty = true
	_refresh_visibility()
	queue_redraw()


func _refresh_visibility() -> void:
	visible = RunState.dungeon != null


func _draw() -> void:
	if RunState.dungeon == null:
		return
	var rooms: Array = RunState.dungeon.all_rooms() if RunState.dungeon.has_method("all_rooms") else []
	if rooms.is_empty() and "rooms" in RunState.dungeon:
		var dict: Dictionary = RunState.dungeon.rooms
		for key in dict.keys():
			rooms.append(dict[key])
	if rooms.is_empty():
		return

	var min_c := Vector2i(999, 999)
	var max_c := Vector2i(-999, -999)
	for room in rooms:
		if room == null:
			continue
		min_c.x = mini(min_c.x, room.coord.x)
		min_c.y = mini(min_c.y, room.coord.y)
		max_c.x = maxi(max_c.x, room.coord.x)
		max_c.y = maxi(max_c.y, room.coord.y)

	var cols := maxi(max_c.x - min_c.x + 1, 1)
	var rows := maxi(max_c.y - min_c.y + 1, 1)
	var grid_w := float(cols) * (CELL + GAP) - GAP
	var grid_h := float(rows) * (CELL + GAP) - GAP
	var origin := Vector2(size.x - grid_w - PAD, PAD)

	# Thin dying-city plate — Isaac cells, not clone-pod chrome.
	draw_rect(Rect2(origin - Vector2(6, 6), Vector2(grid_w + 12, grid_h + 12)), Color(0.05, 0.03, 0.03, 0.82), true)
	draw_rect(Rect2(origin - Vector2(6, 6), Vector2(grid_w + 12, grid_h + 12)), Color(0.62, 0.38, 0.22, 0.5), false, 1.0)

	var current := RunState.current_coord
	for room in rooms:
		if room == null:
			continue
		var explored: bool = bool(room.explored) if "explored" in room else bool(room.cleared)
		var known := explored or _is_adjacent_explored(room.coord, rooms)
		if not known and room.kind != DungeonRoom.RoomKind.START:
			continue
		var local: Vector2i = room.coord - min_c
		var pos := origin + Vector2(float(local.x) * (CELL + GAP), float(local.y) * (CELL + GAP))
		var fill := _cell_color(room, room.coord == current, explored)
		draw_rect(Rect2(pos, Vector2(CELL, CELL)), fill, true)
		draw_rect(Rect2(pos, Vector2(CELL, CELL)), Color(0.55, 0.4, 0.28, 0.35), false, 1.0)
		if room.kind == DungeonRoom.RoomKind.BOSS:
			draw_circle(pos + Vector2(CELL * 0.5, CELL * 0.5), 2.6, Color(0.95, 0.35, 0.4, 0.95))
		elif room.kind == DungeonRoom.RoomKind.START:
			draw_circle(pos + Vector2(CELL * 0.5, CELL * 0.5), 2.0, Color(0.45, 0.85, 1.0, 0.9))
		elif room.kind == DungeonRoom.RoomKind.SHOP:
			draw_circle(pos + Vector2(CELL * 0.5, CELL * 0.5), 2.2, Color(0.35, 0.9, 0.55, 0.95))
		elif room.kind == DungeonRoom.RoomKind.TREASURE:
			draw_circle(pos + Vector2(CELL * 0.5, CELL * 0.5), 2.2, Color(0.95, 0.8, 0.25, 0.95))
		elif room.kind == DungeonRoom.RoomKind.SECRET:
			draw_circle(pos + Vector2(CELL * 0.5, CELL * 0.5), 2.0, Color(0.75, 0.45, 1.0, 0.9))
		elif room.kind == DungeonRoom.RoomKind.REMNANT:
			draw_circle(pos + Vector2(CELL * 0.5, CELL * 0.5), 2.0, Color(0.55, 0.85, 1.0, 0.95))
		# Door ticks
		for dir in room.door_dirs():
			var mid := pos + Vector2(CELL * 0.5, CELL * 0.5)
			var tick := Vector2(float(dir.x), float(dir.y)) * (CELL * 0.5)
			draw_line(mid + tick * 0.35, mid + tick * 0.95, Color(0.55, 0.8, 1.0, 0.55), 1.5)
		if room.coord == current:
			draw_rect(Rect2(pos - Vector2(1.5, 1.5), Vector2(CELL + 3, CELL + 3)), Color(0.95, 0.95, 1.0, 0.85), false, 1.5)


func _cell_color(room: DungeonRoom, is_current: bool, explored: bool) -> Color:
	if is_current:
		return Color(0.45, 0.85, 1.0, 0.95)
	if room.cleared:
		return Color(0.22, 0.32, 0.42, 0.9)
	if explored:
		return Color(0.18, 0.22, 0.3, 0.85)
	return Color(0.1, 0.12, 0.16, 0.7)


func _is_adjacent_explored(coord: Vector2i, rooms: Array) -> bool:
	var dirs := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	for room in rooms:
		if room == null or not bool(room.explored):
			continue
		for dir in dirs:
			if room.coord + dir == coord and room.has_door(dir):
				return true
	return false
