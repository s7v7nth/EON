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
			player.combat_visual.play_melee_windup(
				_aim_angle,
				maxf(_attack.windup / speed, CombatVisualComponent.MIN_WINDUP_VISUAL),
				_melee_anim_variant()
			)
	if not player.hitbox.hit_landed.is_connected(_on_hit_landed):
		player.hitbox.hit_landed.connect(_on_hit_landed)
	if FeelAudio:
		FeelAudio.play_swing()


func physics_update(delta: float) -> void:
	_apply_attack_movement()
	player.capture_bufferable_inputs()

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

	if player.pressed_or_buffered(&"dash") and player.dash_ready():
		transition_to(&"Dash")
		return

	match _phase:
		Phase.WINDUP:
			if _elapsed >= _attack.windup:
				_elapsed = 0.0
				_phase = Phase.ACTIVE
				_apply_lunge()
				player.hitbox.activate()
				if player.combat_visual and not _circular:
					var swing_color := Color(0, 0, 0, 0)
					if _combo_index >= 2:
						swing_color = Color(0.72, 0.28, 1.0, 1.0)
					player.combat_visual.play_melee_swing(
						_aim_angle,
						maxf(_attack.active_duration / speed, CombatVisualComponent.MIN_SWING_VISUAL),
						_attack.damage_type,
						swing_color,
						_melee_anim_variant()
					)
		Phase.ACTIVE:
			if _elapsed >= _attack.active_duration:
				player.hitbox.deactivate()
				_elapsed = 0.0
				if _combo_buffered and _attack.combo_next and not _circular:
					SignalBus.style_action.emit(GameplayEnums.StyleAction.COMBO, 40)
					transition_to(&"Attack", {"combo_index": _combo_index + 1})
					return
				if player.attack_cooldown:
					player.attack_cooldown.start(_attack.cooldown / speed)
				if _attack.recovery > 0.0:
					_phase = Phase.RECOVER
				else:
					_return_to_locomotion()
		Phase.RECOVER:
			if _elapsed >= _attack.recovery:
				_return_to_locomotion()


func _apply_attack_movement() -> void:
	var move_dir := player.get_input_direction()
	var mult: float = _attack.move_mult if _attack else 1.0
	if move_dir == Vector2.ZERO or mult <= 0.0:
		player.stop_movement()
		return
	var saved: float = player.move_speed_multiplier
	player.move_speed_multiplier = saved * mult
	player.apply_movement(move_dir)
	player.move_speed_multiplier = saved


func _apply_lunge() -> void:
	if _attack == null or _attack.lunge_force <= 0.0:
		return
	var aim: Vector2 = Vector2.from_angle(_aim_angle)
	if aim == Vector2.ZERO:
		aim = player.facing_direction
	player.apply_knockback(aim.normalized(), _attack.lunge_force, 0.08)


func _poll_synthetic_combo() -> void:
	# RMB always cancels attack into Block (block priority).
	if player.pressed_or_buffered(&"ranged_attack"):
		if player.combo_expects(&"ranged_attack"):
			player.push_combo_input(&"ranged_attack")
			_combo_buffered = false
		transition_to(&"Block")
		return

	if Input.is_action_just_pressed("attack"):
		player.begin_attack_hold_tracking()
	elif (
		not player.is_tracking_attack_hold()
		and player.consume_buffered(&"attack")
	):
		_resolve_buffered_attack_tap()
		return

	if player.is_tracking_attack_hold():
		if player.attack_hold_exceeded():
			var seed := player.get_attack_hold_time()
			player.clear_attack_hold_tracking()
			if not player.blade_in_flight():
				transition_to(&"ChargeThrow", {"seed": seed})
			return
		if Input.is_action_just_released("attack"):
			player.clear_attack_hold_tracking()
			_resolve_buffered_attack_tap()


func _resolve_buffered_attack_tap() -> void:
	var result := player.push_combo_input(&"attack")
	if result == &"circle_slash":
		_combo_buffered = false
		SignalBus.style_action.emit(GameplayEnums.StyleAction.COMBO, 60)
		transition_to(&"Attack", {"attack": Player.CIRCLE_SLASH_ATTACK, "circular": true})
		return
	if result == &"melee_string":
		_combo_buffered = false
		SignalBus.style_action.emit(GameplayEnums.StyleAction.COMBO, 40)
		transition_to(&"Attack", {"combo_index": 2})
		return
	if player.combo and not _combo_has_ranged_step():
		if _attack and _attack.combo_next:
			_combo_buffered = true


func _combo_has_ranged_step() -> bool:
	if player.combo == null:
		return false
	var steps := player.combo.get_sequence()
	for step in steps:
		if StringName(step) == &"ranged_attack":
			return true
	return false


func exit() -> void:
	player.hitbox.deactivate()
	if player.hitbox.hit_landed.is_connected(_on_hit_landed):
		player.hitbox.hit_landed.disconnect(_on_hit_landed)
	# Do not hard-reset pose here — Attack→Attack would kill readable swing variants.
	# Idle/Move/Dash/Block settle the pose on enter.
	if _circular and player.combo_root:
		player.configure_hitbox_for_attack(player.combo_root)


func _aim_hitbox_at_cursor() -> void:
	if _circular:
		player.hitbox_pivot.rotation = 0.0
		_aim_angle = player.get_aim_direction().angle()
		return
	var aim := player.get_aim_direction()
	if aim == Vector2.ZERO:
		aim = player.facing_direction
	_aim_angle = aim.angle()
	player.hitbox_pivot.rotation = _aim_angle
	player.facing_direction = aim.normalized()


func _melee_anim_variant() -> int:
	## Distinct silhouettes across the string: slash → reverse → overhead/rising finisher.
	match _combo_index:
		0:
			return 0
		1:
			return 1
		2:
			return 2
		_:
			return 4 if (_combo_index % 2) == 0 else 3


func _on_hit_landed(target: HurtboxComponent) -> void:
	player.on_melee_hit(target)
	_spawn_hit_vfx(target)


func _spawn_hit_vfx(target: HurtboxComponent) -> void:
	if target == null or player.get_parent() == null or _attack == null:
		return
	var pos: Vector2 = target.global_position
	if target.get_parent() is Node2D:
		pos = (target.get_parent() as Node2D).global_position + Vector2(0, -22)
	var impact: Vector2 = pos - player.global_position
	HitVFX.spawn_at(player.get_parent(), pos, _attack.damage_type, impact, _attack.impact_scale)


func _return_to_locomotion() -> void:
	if player.combat_visual:
		player.combat_visual.reset_pose()
	# Flush buffered follow-ups at end of recovery.
	if player.pressed_or_buffered(&"dash") and player.dash_ready():
		transition_to(&"Dash")
		return
	if player.uses_synthetic_kit() and player.consume_buffered(&"ranged_attack"):
		if player.combo_expects(&"ranged_attack"):
			player.push_combo_input(&"ranged_attack")
		transition_to(&"Block")
		return
	if player.uses_synthetic_kit() and player.consume_buffered(&"attack") and player.attack_ready():
		var result := player.push_combo_input(&"attack")
		if result == &"circle_slash":
			SignalBus.style_action.emit(GameplayEnums.StyleAction.COMBO, 60)
			transition_to(&"Attack", {"attack": Player.CIRCLE_SLASH_ATTACK, "circular": true})
			return
		if result == &"melee_string":
			SignalBus.style_action.emit(GameplayEnums.StyleAction.COMBO, 40)
			transition_to(&"Attack", {"combo_index": 2})
			return
		var index := 0
		if player.combo:
			var steps := player.combo.get_sequence()
			var n := 0
			for step in steps:
				if StringName(step) == &"attack":
					n += 1
				else:
					n = 0
			index = maxi(n - 1, 0)
		transition_to(&"Attack", {"combo_index": index})
		return
	if player.get_input_direction() != Vector2.ZERO:
		transition_to(&"Move")
	else:
		transition_to(&"Idle")
