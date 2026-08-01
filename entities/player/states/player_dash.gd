extends State
## Dash — spends energy, grants i-frames, fixed burst velocity, then cooldown.
## Leaves fading afterimage ghosts behind.

const GHOST_INTERVAL: float = 0.035
const GHOST_FADE_TIME: float = 0.25
const GHOST_TINT := Color(0.6, 0.8, 1.0, 0.65)

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
	player.hurtbox.set_invincible(true)
	player.velocity = Iso.apply_velocity(_dash_dir, player.stats.dash_speed)
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
	if _elapsed >= player.stats.dash_duration:
		_return_to_locomotion()


func exit() -> void:
	if not _active:
		return
	player.hurtbox.set_invincible(false)
	if player.dash_cooldown and player.stats:
		player.dash_cooldown.start(player.stats.dash_cooldown)
	_active = false


func _spawn_ghost() -> void:
	var visual := player.get_node_or_null("Visual") as Polygon2D
	if visual == null:
		return
	var ghost := Polygon2D.new()
	ghost.polygon = visual.polygon
	ghost.color = visual.color
	ghost.modulate = GHOST_TINT
	ghost.z_index = -1
	player.get_parent().add_child(ghost)
	ghost.global_position = player.global_position
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, GHOST_FADE_TIME)
	tween.tween_callback(ghost.queue_free)


func _return_to_locomotion() -> void:
	if player.get_input_direction() != Vector2.ZERO:
		transition_to(&"Move")
	else:
		transition_to(&"Idle")
