extends State
## Melee attack — aim hitbox at cursor, windup → active → cooldown.

@onready var player: Player = owner as Player

enum Phase { WINDUP, ACTIVE, RECOVER }

var _phase: Phase = Phase.WINDUP
var _elapsed: float = 0.0
var _attack: AttackData


func enter(_msg: Dictionary = {}) -> void:
	_elapsed = 0.0
	_phase = Phase.WINDUP
	_attack = player.hitbox.attack_data
	if _attack == null:
		push_warning("PlayerAttack: missing AttackData")
		_return_to_locomotion()
		return
	if player.attack_cooldown and not player.attack_cooldown.is_stopped():
		_return_to_locomotion()
		return

	player.stop_movement()
	_aim_hitbox_at_cursor()
	if not player.hitbox.hit_landed.is_connected(_on_hit_landed):
		player.hitbox.hit_landed.connect(_on_hit_landed)


func physics_update(delta: float) -> void:
	player.stop_movement()
	_elapsed += delta
	match _phase:
		Phase.WINDUP:
			if _elapsed >= _attack.windup:
				_elapsed = 0.0
				_phase = Phase.ACTIVE
				player.hitbox.activate()
		Phase.ACTIVE:
			if _elapsed >= _attack.active_duration:
				player.hitbox.deactivate()
				_elapsed = 0.0
				_phase = Phase.RECOVER
				if player.attack_cooldown:
					player.attack_cooldown.start(_attack.cooldown)
				_return_to_locomotion()
		Phase.RECOVER:
			_return_to_locomotion()


func exit() -> void:
	player.hitbox.deactivate()
	if player.hitbox.hit_landed.is_connected(_on_hit_landed):
		player.hitbox.hit_landed.disconnect(_on_hit_landed)


func _aim_hitbox_at_cursor() -> void:
	var mouse := player.get_global_mouse_position()
	var aim := mouse - player.global_position
	if aim == Vector2.ZERO:
		aim = player.facing_direction
	player.hitbox_pivot.rotation = aim.angle()
	player.facing_direction = aim.normalized()


func _on_hit_landed(_target: HurtboxComponent) -> void:
	if player.stats:
		player.adrenaline.add(player.stats.adrenaline_gain_on_hit)


func _return_to_locomotion() -> void:
	if player.get_input_direction() != Vector2.ZERO:
		transition_to(&"Move")
	else:
		transition_to(&"Idle")
