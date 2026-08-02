extends State
## Melee attack — windup → active → recover; combo module feeds index / circular.

@onready var player: Player = owner as Player

enum Phase { WINDUP, ACTIVE, RECOVER }

var _phase: Phase = Phase.WINDUP
var _elapsed: float = 0.0
var _attack: AttackData
var _combo_buffered: bool = false
var _combo_index: int = 0
var _aim_angle: float = 0.0
var _circular: bool = false


func enter(msg: Dictionary = {}) -> void:
	_elapsed = 0.0
	_phase = Phase.WINDUP
	_combo_buffered = false
	_combo_index = int(msg.get("combo_index", 0))
	_circular = bool(msg.get("circular", false))

	if msg.has("attack"):
		_attack = msg["attack"] as AttackData
		_circular = _circular or (_attack != null and _attack.circular)
	elif player.pending_combo:
		_attack = player.pending_combo
		player.pending_combo = null
	else:
		_attack = player.combo_root if player.combo_root else player.hitbox.attack_data
		var cursor := _attack
		for _i in _combo_index:
			if cursor and cursor.combo_next:
				cursor = cursor.combo_next
			else:
				break
		if cursor:
			_attack = cursor

	if _attack == null:
		push_warning("PlayerAttack: missing AttackData")
		_return_to_locomotion()
		return
	if player.attack_cooldown and not player.attack_cooldown.is_stopped() and _combo_index == 0 and not _circular:
		_return_to_locomotion()
		return
	if not player.try_spend_attack_energy(_attack):
		_return_to_locomotion()
		return

	player.configure_hitbox_for_attack(_attack)
	_aim_hitbox_at_cursor()
	var speed := player.get_attack_speed_multiplier()
	if player.combat_visual:
		if _circular:
			player.combat_visual.play_circle_slash(_attack.active_duration / speed)
		else:
			player.combat_visual.play_melee_windup(_aim_angle, _attack.windup / speed)
	if not player.hitbox.hit_landed.is_connected(_on_hit_landed):
		player.hitbox.hit_landed.connect(_on_hit_landed)


func physics_update(delta: float) -> void:
	var move_dir := player.get_input_direction()
	if move_dir != Vector2.ZERO:
		player.apply_movement(move_dir)
	else:
		player.stop_movement()

	var speed := player.get_attack_speed_multiplier()
	_elapsed += delta * speed
	if not _circular:
		_aim_hitbox_at_cursor()

	if player.uses_synthetic_kit():
		_poll_synthetic_combo()
	else:
		if Input.is_action_just_pressed("attack") and _attack and _attack.combo_next:
			_combo_buffered = true
		if Input.is_action_just_pressed("special"):
			player.try_special()
		if Input.is_action_just_pressed("parry") and player.parry_ready():
			transition_to(&"Parry")
			return

	if Input.is_action_just_pressed("dash") and player.dash_ready():
		transition_to(&"Dash")
		return

	match _phase:
		Phase.WINDUP:
			if _elapsed >= _attack.windup:
				_elapsed = 0.0
				_phase = Phase.ACTIVE
				player.hitbox.activate()
				if player.combat_visual and not _circular:
					var swing_color := Color(0, 0, 0, 0)
					if _combo_index >= 2:
						swing_color = Color(0.72, 0.28, 1.0, 1.0)
					player.combat_visual.play_melee_swing(
						_aim_angle, _attack.active_duration / speed, _attack.damage_type, swing_color
					)
		Phase.ACTIVE:
			if _elapsed >= _attack.active_duration:
				player.hitbox.deactivate()
				_elapsed = 0.0
				_phase = Phase.RECOVER
				if _combo_buffered and _attack.combo_next and not _circular:
					SignalBus.style_action.emit(GameplayEnums.StyleAction.COMBO, 40)
					transition_to(&"Attack", {"combo_index": _combo_index + 1})
					return
				if player.attack_cooldown:
					player.attack_cooldown.start(_attack.cooldown / speed)
				_return_to_locomotion()
		Phase.RECOVER:
			_return_to_locomotion()


func _poll_synthetic_combo() -> void:
	if Input.is_action_just_pressed("ranged_attack"):
		if player.combo_expects(&"ranged_attack"):
			player.push_combo_input(&"ranged_attack")
		else:
			transition_to(&"Block")
			return
	if Input.is_action_just_pressed("attack"):
		player.begin_attack_hold_tracking()
	if player.is_tracking_attack_hold():
		if player.attack_hold_exceeded():
			player.clear_attack_hold_tracking()
			if not player.blade_in_flight():
				transition_to(&"ChargeThrow")
			return
		if Input.is_action_just_released("attack"):
			player.clear_attack_hold_tracking()
			var result := player.push_combo_input(&"attack")
			if result == &"circle_slash":
				_combo_buffered = false
				SignalBus.style_action.emit(GameplayEnums.StyleAction.COMBO, 60)
				transition_to(&"Attack", {"attack": Player.CIRCLE_SLASH_ATTACK, "circular": true})
				return
			if result == &"melee_string" or (_attack and _attack.combo_next):
				_combo_buffered = true


func exit() -> void:
	player.hitbox.deactivate()
	if player.hitbox.hit_landed.is_connected(_on_hit_landed):
		player.hitbox.hit_landed.disconnect(_on_hit_landed)
	# Always clear swing arcs — interrupting mid-ACTIVE (e.g. block) used to leave purple trail.
	if player.combat_visual:
		player.combat_visual.reset_pose()
	# Restore default rectangular hitbox after circular.
	if _circular and player.combo_root:
		player.configure_hitbox_for_attack(player.combo_root)


func _aim_hitbox_at_cursor() -> void:
	if _circular:
		player.hitbox_pivot.rotation = 0.0
		_aim_angle = player.get_aim_direction().angle()
		return
	var mouse := player.get_global_mouse_position()
	var aim := mouse - player.global_position
	if aim == Vector2.ZERO:
		aim = player.facing_direction
	_aim_angle = aim.angle()
	player.hitbox_pivot.rotation = _aim_angle
	player.facing_direction = aim.normalized()


func _on_hit_landed(target: HurtboxComponent) -> void:
	player.on_melee_hit(target)
	if target and target.get_parent() and target.get_parent().has_node("CombatVisual"):
		var cv := target.get_parent().get_node("CombatVisual") as CombatVisualComponent
		if cv:
			cv.play_hit_flash()
	_spawn_hit_vfx(target)


func _spawn_hit_vfx(target: HurtboxComponent) -> void:
	if target == null or player.get_parent() == null or _attack == null:
		return
	var pos := target.global_position
	if target.get_parent() is Node2D:
		pos = (target.get_parent() as Node2D).global_position + Vector2(0, -22)
	var impact := pos - player.global_position
	HitVFX.spawn_at(player.get_parent(), pos, _attack.damage_type, impact)


func _return_to_locomotion() -> void:
	if player.combat_visual:
		player.combat_visual.reset_pose()
	if player.get_input_direction() != Vector2.ZERO:
		transition_to(&"Move")
	else:
		transition_to(&"Idle")
