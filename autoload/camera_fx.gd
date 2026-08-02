extends Node
## Screen trauma applied to the active Camera2D (no per-scene wiring).

var _trauma: float = 0.0
var _decay: float = 1.15
var _max_offset: float = 22.0
var _base_offset: Vector2 = Vector2.ZERO
var _camera: Camera2D = null
var _noise_t: float = 0.0


func add_trauma(amount: float) -> void:
	if amount <= 0.0:
		return
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


func flash(color: Color = Color(1, 1, 1, 0.55), duration: float = 0.08) -> void:
	## Fullscreen punch flash (parry / heavy impact).
	var tree := get_tree()
	if tree == null or tree.root == null:
		return
	var layer := CanvasLayer.new()
	layer.layer = 80
	var rect := ColorRect.new()
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	tree.root.add_child(layer)
	layer.add_child(rect)
	var tween := layer.create_tween()
	tween.tween_property(rect, "color:a", 0.0, maxf(duration, 0.04))
	tween.tween_callback(layer.queue_free)


func _process(delta: float) -> void:
	var cam: Camera2D = get_viewport().get_camera_2d()
	if cam != _camera:
		if _camera != null and is_instance_valid(_camera):
			_camera.offset = _base_offset
		_camera = cam
		if cam != null:
			_base_offset = cam.offset
		else:
			_base_offset = Vector2.ZERO
	if _camera == null or not is_instance_valid(_camera):
		_trauma = 0.0
		return
	if _trauma <= 0.0:
		_camera.offset = _base_offset
		return
	# Decay in real time so shake isn't stretched by HitStop mush.
	var real_delta: float = delta / maxf(Engine.time_scale, 0.05)
	_trauma = maxf(0.0, _trauma - _decay * real_delta)
	_noise_t += real_delta * 36.0
	var shake: float = _trauma * _trauma
	var ox: float = sin(_noise_t * 1.7) * _max_offset * shake
	var oy: float = cos(_noise_t * 2.3) * _max_offset * shake
	_camera.offset = _base_offset + Vector2(ox, oy)
