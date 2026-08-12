extends Node
## Feel P2: lightweight SFX + gamepad rumble hooked to combat SignalBus events.
## Uses procedural AudioStreamGenerator tones (no asset pack required).

const MASTER_BUS := &"Master"

var _players: Array[AudioStreamPlayer] = []
var _player_i: int = 0
const POOL_SIZE := 6


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.name = "FeelSfx_%d" % i
		p.bus = String(MASTER_BUS)
		p.volume_db = -8.0
		add_child(p)
		_players.append(p)
	if not SignalBus.damage_dealt.is_connected(_on_damage_dealt):
		SignalBus.damage_dealt.connect(_on_damage_dealt)
	if not SignalBus.parry_success.is_connected(_on_parry):
		SignalBus.parry_success.connect(_on_parry)
	if not SignalBus.perfect_dodge.is_connected(_on_perfect_dodge):
		SignalBus.perfect_dodge.connect(_on_perfect_dodge)
	if not SignalBus.special_triggered.is_connected(_on_special):
		SignalBus.special_triggered.connect(_on_special)
	if not SignalBus.vent_triggered.is_connected(_on_vent):
		SignalBus.vent_triggered.connect(_on_vent)
	if not SignalBus.enemy_died.is_connected(_on_enemy_died):
		SignalBus.enemy_died.connect(_on_enemy_died)


func play_hit(amount: float = 10.0) -> void:
	var t := clampf(amount / 40.0, 0.15, 1.0)
	_blip(180.0 + 220.0 * t, 0.045 + 0.03 * t, 0.22 * t)
	_rumble(0.12 * t, 0.28 * t, 0.06 + 0.04 * t)


func play_parry() -> void:
	_blip(520.0, 0.08, 0.35)
	_blip(780.0, 0.05, 0.22)
	_rumble(0.45, 0.65, 0.12)


func play_perfect_dodge() -> void:
	_blip(640.0, 0.06, 0.28)
	_rumble(0.2, 0.35, 0.08)


func play_special() -> void:
	_blip(140.0, 0.12, 0.4)
	_blip(90.0, 0.16, 0.3)
	_rumble(0.55, 0.7, 0.18)


func play_death() -> void:
	_blip(110.0, 0.14, 0.32)
	_rumble(0.35, 0.5, 0.14)


func _on_damage_dealt(amount: float, target: Node, source: Node) -> void:
	if source == null:
		return
	# Player-sourced hits only (avoid enemy chip noise spam).
	if source is Player or (source.get("adrenaline") != null and source.get("energy") != null):
		play_hit(amount)
	elif target is Player:
		_blip(90.0, 0.05, 0.18)
		_rumble(0.25, 0.15, 0.07)


func _on_parry(_source: Node) -> void:
	play_parry()


func _on_perfect_dodge(_source: Node) -> void:
	play_perfect_dodge()


func _on_special(_source: Node) -> void:
	play_special()


func _on_vent(_source: Node) -> void:
	play_special()


func _on_enemy_died(_enemy: Node) -> void:
	play_death()


func _blip(hz: float, duration: float, amplitude: float) -> void:
	var player := _next_player()
	if player == null:
		return
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.1
	player.stream = gen
	player.play()
	var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return
	var sample_rate := gen.mix_rate
	var frames := int(duration * sample_rate)
	var phase := 0.0
	var phase_inc := TAU * hz / sample_rate
	for i in frames:
		var env := 1.0 - float(i) / float(maxi(frames, 1))
		env *= env
		var sample := sin(phase) * amplitude * env
		playback.push_frame(Vector2(sample, sample))
		phase += phase_inc


func _next_player() -> AudioStreamPlayer:
	if _players.is_empty():
		return null
	var p := _players[_player_i % _players.size()]
	_player_i += 1
	if p.playing:
		p.stop()
	return p


func _rumble(weak: float, strong: float, duration: float) -> void:
	# Godot 4 joy vibration; no-ops when no pad connected.
	for device in Input.get_connected_joypads():
		Input.start_joy_vibration(device, clampf(weak, 0.0, 1.0), clampf(strong, 0.0, 1.0), duration)
