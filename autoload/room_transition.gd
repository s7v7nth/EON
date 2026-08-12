extends CanvasLayer
## Soft fade between arena scene swaps so procedural door travel feels continuous.

const FADE_OUT := 0.12
const FADE_IN := 0.16

var _rect: ColorRect
var _busy: bool = false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.name = "Fade"
	_rect.color = Color(0.02, 0.03, 0.05, 0.0)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_rect)


func is_busy() -> bool:
	return _busy


func go_to(path: String) -> void:
	if path == "" or _busy:
		return
	_busy = true
	Engine.time_scale = 1.0
	get_tree().paused = false
	var tw := create_tween()
	tw.tween_property(_rect, "color:a", 1.0, FADE_OUT).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished
	if not is_inside_tree():
		_busy = false
		return
	get_tree().change_scene_to_file(path)
	await get_tree().process_frame
	await get_tree().process_frame
	var tw_in := create_tween()
	tw_in.tween_property(_rect, "color:a", 0.0, FADE_IN).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tw_in.finished
	_busy = false
