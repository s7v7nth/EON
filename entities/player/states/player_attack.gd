extends State
## Melee attack — can move while attacking; windup → active → optional combo buffer.

@onready var player: Player = owner as Player

enum Phase { WINDUP, ACTIVE, RECOVER }

var _phase: Phase = Phase.WINDUP
var _elapsed: float = 0.0
var _attack: AttackData
var _combo_buffered: bool = false
var _combo_index: int = 0
var _aim_angle: float = 0.0


func enter(msg: Dictionary = {}) -> void:
	_elapsed = 0.0
	_phase = Phase.WINDUP
	_combo_buffered = false
	_combo_index = int(msg.get("combo_index", 0))

	if msg.has("attack"):
		_attack = msg["attack"] as AttackData
	elif player.pending_combo:
		_attack = player.pending_combo
		player.pending_combo = null
	else:
		_attack = player.hitbox.attack_data if player.combo_root == null else player.combo_root
		if player.combo_root:
			_attack = player.combo_root

	var cursor := player.combo_root if player.combo_root else player.hitbox.attack_data
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
	if player.attack_cooldown and not player.attack_cooldown.is_stopped() and _combo_index == 0:
		_return_to_locomotion()
		return
	if not player.try_spend_attack_energy(_attack):
		_return_to_locomotion()
		return

	player.hitbox.attack_data = _attack
	_aim_hitbox_at_cursor()
	if player.combat_visual:
		player.combat_visual.play_melee_windup(_aim_angle, _attack.windup)
	if not player.hitbox.hit_landed.is_connected(_on_hit_landed):
		player.hitbox.hit_landed.connect(_on_hit_landed)


func physics_update(delta: float) -> void:
	var move_dir := player.get_input_direction()
	if move_dir != Vector2.ZERO:
		player.apply_movement(move_dir)
	else:
		player.stop_movement()

	_elapsed += delta
	# Keep aim live while swinging so movement + attacks stay readable.
	_aim_hitbox_at_cursor()

	if Input.is_action_just_pressed("attack") and _attack and _attack.combo_next:
		_combo_buffered = true
	if Input.is_action_just_pressed("dash") and player.dash_ready():
		transition_to(&"Dash")
		return
	if Input.is_action_just_pressed("parry") and player.parry_ready():
		transition_to(&"Parry")
		return

	match _phase:
		Phase.WINDUP:
			if _elapsed >= _attack.windup:
				_elapsed = 0.0
				_phase = Phase.ACTIVE
				player.hitbox.activate()
				if player.combat_visual:
					player.combat_visual.play_melee_swing(
						_aim_angle, _attack.active_duration, _attack.damage_type
					)
		Phase.ACTIVE:
			if _elapsed >= _attack.active_duration:
				player.hitbox.deactivate()
				_elapsed = 0.0
				_phase = Phase.RECOVER
				if _combo_buffered and _attack.combo_next:
					SignalBus.style_action.emit(GameplayEnums.StyleAction.COMBO, 40)
					transition_to(&"Attack", {"combo_index": _combo_index + 1})
					return
				if player.attack_cooldown:
					player.attack_cooldown.start(_attack.cooldown)
				_return_to_locomotion()
		Phase.RECOVER:
			_return_to_locomotion()


func exit() -> void:
	player.hitbox.deactivate()
	if player.hitbox.hit_landed.is_connected(_on_hit_landed):
		player.hitbox.hit_landed.disconnect(_on_hit_landed)
	if player.combat_visual and _phase != Phase.ACTIVE:
		player.combat_visual.reset_pose()


func _aim_hitbox_at_cursor() -> void:
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
