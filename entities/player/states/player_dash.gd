extends State
## Dash — spends energy, grants i-frames (detectable for perfect dodge), then cooldown.

const GHOST_INTERVAL: float = 0.035
const GHOST_FADE_TIME: float = 0.25
const GHOST_TINT := Color(0.6, 0.8, 1.0, 0.65)
const GHOST_HIVE := Color(0.35, 1.0, 0.48, 0.7)
const GHOST_TRAIN := Color(1.0, 0.55, 0.22, 0.7)
const GHOST_NEURO := Color(0.78, 0.42, 1.0, 0.72)

@onready var player: Player = owner as Player

var _elapsed: float = 0.0
var _ghost_timer: float = 0.0
var _dash_dir: Vector2 = Vector2.RIGHT
var _active: bool = false


func enter(_msg: Dictionary = {}) -> void:
	_elapsed = 0.0
	_ghost_timer = 0.0
	_active = false
	if not player.dash_ready():
		_return_to_locomotion()
		return

	if not player.try_spend_dash():
		_return_to_locomotion()
		return

	_active = true
	var input_dir := player.get_input_direction()
	_dash_dir = input_dir.normalized() if input_dir != Vector2.ZERO else player.facing_direction
	if _dash_dir == Vector2.ZERO:
		_dash_dir = Vector2.RIGHT

	player.facing_direction = _dash_dir
	# detect_hits=true keeps hurtbox receivable for perfect-dodge callbacks.
	player.hurtbox.set_invincible(true, true)
	player.velocity = Iso.apply_velocity(_dash_dir, player.stats.dash_speed)
	player.notify_dash_started(_dash_dir)
	if FeelAudio:
		FeelAudio.play_dash()
	_spawn_ghost()


func physics_update(delta: float) -> void:
	if not _active:
		return
	_elapsed += delta
	_ghost_timer += delta
	if _ghost_timer >= GHOST_INTERVAL:
		_ghost_timer = 0.0
		_spawn_ghost()
	player.velocity = Iso.apply_velocity(_dash_dir, player.stats.dash_speed)
	player.move_and_slide()
	_try_blade_intercept()
	if _elapsed >= player.stats.dash_duration:
		_return_to_locomotion()


func _try_blade_intercept() -> void:
	var economy = player.active_economy
	if economy == null:
		return
	# Only Synthetic Kinetic Ping-Pong sets this; other economies lack the property
	# and bool(null) hard-errors on Godot 4.7.
	var intercept = economy.get("dash_blade_intercept")
	if intercept == null or not intercept:
		return
	var blade := player.get_active_blade()
	if blade == null:
		return
	if player.global_position.distance_to(blade.global_position) > 52.0:
		return
	if blade.has_method("apply_dash_intercept"):
		blade.call("apply_dash_intercept")


func exit() -> void:
	if not _active:
		return
	player.hurtbox.set_invincible(false, false)
	if player.dash_iframe_bonus > 0.0:
		player.hurtbox.set_invincible(true, false)
		player._iframe_bonus_left = player.dash_iframe_bonus
	if player.dash_cooldown and player.stats:
		player.dash_cooldown.start(player.stats.dash_cooldown * player.dash_cooldown_mult)
	_active = false


func _spawn_ghost() -> void:
	var visual := player.get_node_or_null("Visual") as Node2D
	if visual == null:
		return
	var spr := visual.get_node_or_null("Sprite") as Sprite2D
	if spr and spr.texture:
		var ghost := ArtBank.clone_sprite_look(spr)
		ghost.scale = visual.scale * spr.scale
		ghost.modulate = _ghost_tint()
		ghost.z_index = -1
		player.get_parent().add_child(ghost)
		ghost.global_position = player.global_position + spr.position
		var puff := ArtBank.particle("smoke_04")
		if puff:
			var cloud := Sprite2D.new()
			cloud.texture = puff
			cloud.centered = true
			cloud.modulate = Color(0.65, 0.85, 1.0, 0.55)
			cloud.scale = Vector2(0.35, 0.35)
			cloud.z_index = -2
			player.get_parent().add_child(cloud)
			cloud.global_position = player.global_position + Vector2(0, 8)
			var puff_tw := cloud.create_tween()
			puff_tw.tween_property(cloud, "modulate:a", 0.0, 0.22)
			puff_tw.parallel().tween_property(cloud, "scale", Vector2(0.7, 0.45), 0.22)
			puff_tw.tween_callback(cloud.queue_free)
		var tween := ghost.create_tween()
		tween.tween_property(ghost, "modulate:a", 0.0, GHOST_FADE_TIME)
		tween.tween_callback(ghost.queue_free)
		return
	var ghost_poly := Polygon2D.new()
	if "polygon" in visual and not (visual.polygon as PackedVector2Array).is_empty():
		ghost_poly.polygon = visual.polygon
	else:
		ghost_poly.polygon = PackedVector2Array([
			Vector2(-10, 0), Vector2(10, 0), Vector2(8, -36), Vector2(-8, -36)
		])
	if "color" in visual:
		ghost_poly.color = visual.color
	else:
		ghost_poly.color = Color(0.55, 0.58, 0.62, 1)
	ghost_poly.modulate = _ghost_tint()
	ghost_poly.z_index = -1
	player.get_parent().add_child(ghost_poly)
	ghost_poly.global_position = player.global_position
	var tween_poly := ghost_poly.create_tween()
	tween_poly.tween_property(ghost_poly, "modulate:a", 0.0, GHOST_FADE_TIME)
	tween_poly.tween_callback(ghost_poly.queue_free)


func _ghost_tint() -> Color:
	if player.architecture:
		match player.architecture.architecture_id:
			GameplayEnums.ArchitectureId.NANOMACHINES:
				return GHOST_HIVE
			GameplayEnums.ArchitectureId.ELECTRO_TRAIN:
				return GHOST_TRAIN
			GameplayEnums.ArchitectureId.NEURO_HACKER:
				return GHOST_NEURO
	return GHOST_TINT


func _return_to_locomotion() -> void:
	if player.get_input_direction() != Vector2.ZERO:
		transition_to(&"Move")
	else:
		transition_to(&"Idle")
