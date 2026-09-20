class_name FocusLens
extends Area2D
## Hard-light lens — amplifies player blades/projectiles that pass through.
## Action budget (like Energy Mirrors): fades after MAX_ACTIONS amplifications. No timer.

const LENS_COLOR := Color(1.0, 0.85, 0.35, 0.7)
const DAMAGE_MULT := 2.5
const MAX_ACTIONS := 3

var owner_player: Node
var field: Object
## Deprecated: lenses use action budget, not timers. Kept for API compatibility.
var lifetime: float = -1.0
var _actions: int = 0
var _spent: bool = false
var _visual: Polygon2D
var _amplified: Dictionary = {} # instance_id -> true
var _action_pips: Array[Polygon2D] = []


func _ready() -> void:
	z_index = 7
	monitoring = true
	monitorable = true
	collision_layer = 1 << 5 # same as energy mirrors so blades detect us
	collision_mask = 0
	add_to_group("focus_lens")
	area_entered.connect(_on_area_entered)
	_ensure_visual()
	_ensure_action_pips()
	_refresh_action_pips()


func configure(player: Node, econ_field: Object = null, _life: float = -1.0) -> void:
	owner_player = player
	field = econ_field
	lifetime = -1.0


func remaining_actions() -> int:
	return maxi(MAX_ACTIONS - _actions, 0)


func try_amplify_projectile(proj: Node) -> bool:
	if _spent or proj == null or not is_instance_valid(proj):
		return false
	if not proj.has_method("apply_lens_amplify"):
		return false
	var id := proj.get_instance_id()
	if _amplified.has(id):
		return false
	if bool(proj.call("apply_lens_amplify", DAMAGE_MULT)):
		_amplified[id] = true
		_actions = mini(_actions + 1, MAX_ACTIONS)
		_refresh_action_pips()
		_flash()
		if _actions >= MAX_ACTIONS:
			_fade_out()
		return true
	return false


func _on_area_entered(area: Area2D) -> void:
	# Projectiles are Area2D; they also detect us via their mask. Dual path is fine.
	if area != null and area.has_method("apply_lens_amplify"):
		try_amplify_projectile(area)


func _flash() -> void:
	CameraFx.flash(Color(1.0, 0.9, 0.4, 0.35), 0.06)
	if _visual:
		var base := _visual.color
		var tw := create_tween()
		tw.tween_property(_visual, "color", Color(1, 1, 1, 1), 0.05)
		tw.tween_property(_visual, "color", base, 0.12)


func _fade_out() -> void:
	if _spent:
		return
	_spent = true
	set_deferred("monitoring", false)
	remove_from_group("focus_lens")
	if field != null and field.has_method("unregister_lens"):
		field.call("unregister_lens", self)
	HitVFX.spawn_optic_ring(get_parent(), global_position, Color(1.0, 0.85, 0.35, 0.7), 0.9)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.18)
	tw.tween_callback(queue_free)


func _expire() -> void:
	_fade_out()


func _ensure_visual() -> void:
	_visual = get_node_or_null("Visual") as Polygon2D
	if _visual == null:
		_visual = Polygon2D.new()
		_visual.name = "Visual"
		add_child(_visual)
	_visual.polygon = PackedVector2Array([
		Vector2(0, -22), Vector2(18, 0), Vector2(0, 22), Vector2(-18, 0)
	])
	_visual.color = LENS_COLOR
	var shape := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape == null:
		shape = CollisionShape2D.new()
		shape.name = "CollisionShape2D"
		add_child(shape)
	var circle := shape.shape as CircleShape2D
	if circle == null:
		circle = CircleShape2D.new()
		shape.shape = circle
	circle.radius = 26.0


func _ensure_action_pips() -> void:
	if not _action_pips.is_empty():
		return
	for i in MAX_ACTIONS:
		var pip := Polygon2D.new()
		pip.name = "ActionPip_%d" % i
		pip.polygon = PackedVector2Array([
			Vector2(-3, -3), Vector2(3, -3), Vector2(3, 3), Vector2(-3, 3)
		])
		pip.color = Color(1.0, 0.85, 0.35, 0.9)
		pip.z_index = 3
		pip.position = Vector2(-10.0 + float(i) * 10.0, 28.0)
		add_child(pip)
		_action_pips.append(pip)


func _refresh_action_pips() -> void:
	for i in _action_pips.size():
		var pip := _action_pips[i]
		var spent := i < _actions
		pip.color = Color(0.25, 0.2, 0.1, 0.55) if spent else Color(1.0, 0.85, 0.35, 0.9)
