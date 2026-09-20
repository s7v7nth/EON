extends State
## Hive Dissipate: hold Space to fall into a nanobot puddle. No dash burst.

@onready var player: Player = owner as Player

var _spent: float = 0.0
var _tick: float = 0.0
var _splat: float = 0.0
var _active: bool = false
var _remnant: Node2D
var _saved_scale: Vector2 = Vector2.ONE


func enter(_msg: Dictionary = {}) -> void:
	_spent = 0.0
	_tick = 0.0
	_splat = 0.0
	_active = false
	if not player.dissipate_ready():
		_return_to_locomotion()
		return
	var econ := player.active_economy
	if econ == null or not econ.has_method("tick_dissipate"):
		_return_to_locomotion()
		return
	if not econ.spend(player, &"dissipate", 0.0):
		_return_to_locomotion()
		return
	_active = true
	player.hurtbox.set_invincible(true, false)
	var vis := player.get_node_or_null("Visual") as Node2D
	if vis:
		_saved_scale = vis.scale
		vis.scale = Vector2(1.15, 0.38)
		vis.modulate = Color(0.42, 0.48, 0.28, 0.72)
	_spawn_remnant()
	if FeelAudio:
		FeelAudio.play_dash()


func physics_update(delta: float) -> void:
	if not _active:
		return
	if not Input.is_action_pressed("dash"):
		_reform()
		return
	var econ := player.active_economy
	var drained := 0.0
	if econ and econ.has_method("tick_dissipate"):
		drained = float(econ.call("tick_dissipate", player, delta))
	_spent += drained
	if drained <= 0.001:
		_reform()
		return
	var move := player.get_input_direction()
	var saved := player.move_speed_multiplier
	player.move_speed_multiplier = saved * 0.72
	if move != Vector2.ZERO:
		player.apply_movement(move)
	else:
		player.stop_movement()
	player.move_speed_multiplier = saved
	_tick_puddle(delta)
	_pulse_visual(delta)


func exit() -> void:
	if not _active:
		return
	player.hurtbox.set_invincible(false, false)
	var vis := player.get_node_or_null("Visual") as Node2D
	if vis:
		vis.scale = _saved_scale
		vis.modulate = Color.WHITE
	if _remnant and is_instance_valid(_remnant):
		_remnant.queue_free()
	_remnant = null
	_active = false


func _reform() -> void:
	var econ := player.active_economy
	if econ and econ.has_method("reform_dissipate"):
		econ.call("reform_dissipate", player, _spent)
	if player is Node2D:
		HitVFX.spawn_optic_burst(
			(player as Node2D).get_parent(),
			(player as Node2D).global_position,
			Color(0.4, 0.48, 0.22, 1),
			Vector2.UP,
			1.1
		)
	_return_to_locomotion()


func _tick_puddle(delta: float) -> void:
	_tick += delta
	_splat += delta
	var dmg := 5.0
	var econ := player.active_economy
	if econ:
		dmg = float(econ.get("dissipate_puddle_damage")) if econ.get("dissipate_puddle_damage") != null else 5.0
	if _tick >= 0.28:
		_tick = 0.0
		_hurt_nearby(dmg)
	if _splat >= 0.55:
		_splat = 0.0
		_drop_stain()


func _hurt_nearby(dmg: float) -> void:
	if not player.is_inside_tree():
		return
	var origin := player.global_position
	for node in player.get_tree().get_nodes_in_group("enemies"):
		if node is not Node2D:
			continue
		if origin.distance_to((node as Node2D).global_position) > 58.0:
			continue
		var health = node.get("health")
		if health and health.has_method("take_damage"):
			health.call("take_damage", dmg)
		var status = node.get("status")
		if status and status.has_method("apply_status"):
			status.call("apply_status", StatusComponent.STATUS_ACID, 4.0, 1.2)


func _drop_stain() -> void:
	var parent := player.get_parent()
	if parent == null:
		return
	var stain := Sprite2D.new()
	stain.texture = ArtBank.tex("res://assets/kenney/splat/splat05.png")
	if stain.texture == null:
		stain.texture = ArtBank.particle("smoke_04")
	stain.centered = true
	stain.z_index = -2
	stain.modulate = Color(0.38, 0.48, 0.18, 0.55)
	if stain.texture:
		ArtBank.fit_height(stain, 42.0, false)
	parent.add_child(stain)
	stain.global_position = player.global_position + Vector2(0, 10)
	var tw := stain.create_tween()
	tw.tween_interval(0.8)
	tw.tween_property(stain, "modulate:a", 0.0, 0.45)
	tw.tween_callback(stain.queue_free)


func _spawn_remnant() -> void:
	_remnant = Node2D.new()
	_remnant.name = "DissipateRemnant"
	_remnant.z_index = 7
	player.add_child(_remnant)
	var spr := Sprite2D.new()
	spr.centered = true
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	spr.texture = ArtBank.illustrated_facing("hero", Vector2(1, 1))
	if spr.texture == null:
		spr.texture = ArtBank.illustrated("hero_SE")
	if spr.texture:
		ArtBank.fit_height(spr, 52.0, true)
	spr.modulate = Color(0.55, 0.7, 0.42, 0.55)
	spr.position = Vector2(0, -18)
	_remnant.add_child(spr)
	var cloud := Sprite2D.new()
	cloud.texture = ArtBank.particle("smoke_04")
	cloud.centered = true
	cloud.modulate = Color(0.4, 0.48, 0.22, 0.5)
	cloud.scale = Vector2(0.55, 0.28)
	cloud.position = Vector2(0, 8)
	_remnant.add_child(cloud)


func _pulse_visual(delta: float) -> void:
	if _remnant == null:
		return
	var t := Time.get_ticks_msec() * 0.012
	_remnant.position = Vector2(sin(t) * 3.0, -6.0 + cos(t * 1.3) * 2.0)
	var vis := player.get_node_or_null("Visual") as Node2D
	if vis:
		vis.rotation = sin(t * 2.0) * 0.08


func _return_to_locomotion() -> void:
	if player.get_input_direction() != Vector2.ZERO:
		transition_to(&"Move")
	else:
		transition_to(&"Idle")
