extends Node
## Authored Kenney / OGA SFX with a small player pool. Procedural blip is fallback only.

const MASTER_BUS := &"Master"
const POOL_SIZE := 12

var _players: Array[AudioStreamPlayer] = []
var _player_i: int = 0

var _hits: Array[AudioStream] = []
var _hurts: Array[AudioStream] = []
var _dashes: Array[AudioStream] = []
var _pickups: Array[AudioStream] = []
var _deaths: Array[AudioStream] = []
var _swings: Array[AudioStream] = []
var _ui: Array[AudioStream] = []
var _errors: Array[AudioStream] = []
var _coins: Array[AudioStream] = []
var _boss: Array[AudioStream] = []
var _specials: Array[AudioStream] = []
var _parries: Array[AudioStream] = []
var _jingle_win: Array[AudioStream] = []
var _jingle_boss: Array[AudioStream] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.name = "FeelSfx_%d" % i
		p.bus = String(MASTER_BUS)
		p.volume_db = -8.0
		add_child(p)
		_players.append(p)
	## SFX banks wait until first play so boot can paint class select.
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
	if not SignalBus.player_died.is_connected(_on_player_died):
		SignalBus.player_died.connect(_on_player_died)
	if not SignalBus.room_cleared.is_connected(_on_room_cleared):
		SignalBus.room_cleared.connect(_on_room_cleared)


var _banks_loaded: bool = false


func _ensure_banks() -> void:
	if _banks_loaded:
		return
	_banks_loaded = true
	_load_banks()


func _load_banks() -> void:
	_fill_bank(_hits, [
		"res://assets/sfx/impact/impactPunch_medium_000.ogg",
		"res://assets/sfx/impact/impactPunch_medium_001.ogg",
		"res://assets/sfx/impact/impactPunch_heavy_000.ogg",
		"res://assets/sfx/impact/impactMetal_medium_000.ogg",
		"res://assets/sfx/impact/impactMetal_medium_001.ogg",
		"res://assets/sfx/sci-fi/impactMetal_000.ogg",
		"res://assets/sfx/rpg-pack/swing.wav",
	])
	_fill_bank(_hurts, [
		"res://assets/sfx/impact/impactGeneric_light_000.ogg",
		"res://assets/sfx/impact/impactPlate_medium_000.ogg",
		"res://assets/sfx/impact/impactPunch_heavy_001.ogg",
	])
	_fill_bank(_dashes, [
		"res://assets/sfx/sci-fi/thrusterFire_000.ogg",
		"res://assets/sfx/sci-fi/thrusterFire_001.ogg",
		"res://assets/sfx/sci-fi/forceField_000.ogg",
		"res://assets/sfx/sci-fi/spaceEngineSmall_000.ogg",
	])
	_fill_bank(_pickups, [
		"res://assets/sfx/interface/confirmation_001.ogg",
		"res://assets/sfx/rpg/handleCoins.ogg",
		"res://assets/sfx/rpg-pack/coin.wav",
		"res://assets/sfx/digital/pepSound1.ogg",
	])
	_fill_bank(_deaths, [
		"res://assets/sfx/sci-fi/explosionCrunch_000.ogg",
		"res://assets/sfx/sci-fi/explosionCrunch_001.ogg",
		"res://assets/sfx/oga-scifi/explosion_01.ogg",
		"res://assets/sfx/rpg-pack/mnstr1.wav",
	])
	_fill_bank(_swings, [
		"res://assets/sfx/rpg-pack/swing.wav",
		"res://assets/sfx/rpg-pack/swing2.wav",
		"res://assets/sfx/rpg/knifeSlice.ogg",
		"res://assets/sfx/sci-fi/laserSmall_000.ogg",
	])
	_fill_bank(_ui, [
		"res://assets/sfx/interface/click_001.ogg",
		"res://assets/sfx/ui/click-a.ogg",
		"res://assets/sfx/interface/drop_001.ogg",
	])
	_fill_bank(_errors, [
		"res://assets/sfx/interface/error_001.ogg",
		"res://assets/sfx/interface/error_002.ogg",
		"res://assets/sfx/digital/lowThreeTone.ogg",
	])
	_fill_bank(_coins, [
		"res://assets/sfx/rpg/handleCoins.ogg",
		"res://assets/sfx/rpg-pack/coin.wav",
		"res://assets/sfx/rpg-pack/coin2.wav",
	])
	_fill_bank(_boss, [
		"res://assets/sfx/sci-fi/lowFrequency_explosion_000.ogg",
		"res://assets/sfx/rpg-pack/ogre1.wav",
		"res://assets/sfx/sci-fi/explosionCrunch_002.ogg",
		"res://assets/sfx/digital/phaserDown1.ogg",
	])
	_fill_bank(_specials, [
		"res://assets/sfx/sci-fi/laserLarge_000.ogg",
		"res://assets/sfx/sci-fi/forceField_001.ogg",
		"res://assets/sfx/rpg-pack/spell.wav",
		"res://assets/sfx/digital/laser1.ogg",
	])
	_fill_bank(_parries, [
		"res://assets/sfx/impact/impactPlate_heavy_000.ogg",
		"res://assets/sfx/sci-fi/forceField_002.ogg",
		"res://assets/sfx/digital/highUp.ogg",
		"res://assets/sfx/space-shooter/sfx_shieldUp.ogg",
	])
	_fill_bank(_jingle_win, [
		"res://assets/sfx/jingles/jingles_HIT01.ogg",
		"res://assets/sfx/jingles/jingles_HIT05.ogg",
		"res://assets/sfx/jingles/jingles_HIT10.ogg",
		"res://assets/sfx/jingles/jingles_STEEL03.ogg",
	])
	_fill_bank(_jingle_boss, [
		"res://assets/sfx/jingles/jingles_SAX00.ogg",
		"res://assets/sfx/jingles/jingles_SAX05.ogg",
		"res://assets/sfx/jingles/jingles_SAX08.ogg",
		"res://assets/sfx/jingles/jingles_STEEL07.ogg",
	])


func _fill_bank(target: Array[AudioStream], paths: PackedStringArray) -> void:
	target.clear()
	for stream in _load_many(paths):
		target.append(stream)


func _load_many(paths: PackedStringArray) -> Array[AudioStream]:
	var out: Array[AudioStream] = []
	for path in paths:
		var stream: AudioStream = null
		if ResourceLoader.exists(path):
			stream = load(path) as AudioStream
		if stream == null and FileAccess.file_exists(path):
			if path.ends_with(".ogg"):
				stream = AudioStreamOggVorbis.load_from_file(path)
		if stream:
			out.append(stream)
	return out


func play_hit(amount: float = 10.0) -> void:
	var t := clampf(amount / 40.0, 0.15, 1.0)
	_play_bank(_hits, -10.0 + 4.0 * t, randf_range(0.92, 1.08), 0.0)
	if t > 0.55:
		_play_bank(_swings, -14.0, randf_range(0.95, 1.12), 0.0)
	_rumble(0.12 * t, 0.28 * t, 0.06 + 0.04 * t)


func play_hurt() -> void:
	_play_bank(_hurts, -8.0, randf_range(0.85, 1.0), 0.0)
	_rumble(0.25, 0.15, 0.07)


func play_dash() -> void:
	_play_bank(_dashes, -7.0, randf_range(1.02, 1.18), 0.0)
	_rumble(0.18, 0.32, 0.08)


func play_pickup() -> void:
	_play_bank(_pickups, -6.0, randf_range(0.98, 1.08), 0.0)
	_play_bank(_jingle_win, -12.0, 1.08, 0.02)


func play_death() -> void:
	_play_bank(_deaths, -5.0, randf_range(0.88, 1.02), 0.0)
	_rumble(0.35, 0.5, 0.14)


func play_player_death() -> void:
	_play_bank(_deaths, -2.0, 0.78, 0.0)
	_play_bank(_boss, -8.0, 0.7, 0.05)
	_rumble(0.55, 0.7, 0.22)


func play_swing() -> void:
	if _swings.is_empty():
		_fill_bank(_swings, [
			"res://assets/sfx/rpg-pack/swing.wav",
			"res://assets/sfx/rpg-pack/swing2.wav",
			"res://assets/sfx/rpg/knifeSlice.ogg",
			"res://assets/sfx/sci-fi/laserSmall_000.ogg",
		])
	_play_bank(_swings, -11.0, randf_range(0.94, 1.12), 0.0)


func warmup() -> void:
	_ensure_banks()


func play_ui() -> void:
	_play_bank(_ui, -10.0, 1.0, 0.0)


func play_error() -> void:
	_play_bank(_errors, -6.0, 1.0, 0.0)


func play_coin() -> void:
	_play_bank(_coins, -8.0, randf_range(0.96, 1.08), 0.0)


func play_boss() -> void:
	_play_bank(_boss, -3.0, 0.9, 0.0)
	_play_bank(_jingle_boss, -6.0, 0.92, 0.04)
	_rumble(0.6, 0.8, 0.28)


func play_parry() -> void:
	_play_bank(_parries, -5.0, randf_range(0.95, 1.05), 0.0)
	_rumble(0.45, 0.65, 0.12)


func play_perfect_dodge() -> void:
	_play_bank(_dashes, -8.0, 1.25, 0.0)
	_play_bank(_ui, -12.0, 1.4, 0.03)
	_rumble(0.2, 0.35, 0.08)


func play_special() -> void:
	_play_bank(_specials, -5.0, randf_range(0.9, 1.05), 0.0)
	_rumble(0.55, 0.7, 0.18)


func _on_damage_dealt(amount: float, target: Node, source: Node) -> void:
	if source == null:
		return
	if source is Player or (source.get("adrenaline") != null and source.get("energy") != null):
		play_hit(amount)
	elif target is Player:
		play_hurt()


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


func _on_player_died() -> void:
	play_player_death()


func _on_room_cleared() -> void:
	_play_bank(_jingle_win, -8.0, 1.0, 0.0)
	_rumble(0.2, 0.3, 0.1)


func _play_bank(bank: Array[AudioStream], volume_db: float, pitch: float, delay: float) -> void:
	if bank.is_empty():
		_ensure_banks()
	if bank.is_empty():
		_blip(180.0, 0.05, 0.18)
		return
	var stream: AudioStream = bank[randi() % bank.size()]
	if delay > 0.0:
		_play_stream_later(stream, volume_db, pitch, delay)
		return
	_play_stream(stream, volume_db, pitch)


func _play_stream_later(stream: AudioStream, volume_db: float, pitch: float, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	_play_stream(stream, volume_db, pitch)


func _play_stream(stream: AudioStream, volume_db: float, pitch: float) -> void:
	if stream == null:
		return
	var player := _next_player()
	if player == null:
		return
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = maxf(pitch, 0.5)
	player.play()


func _blip(hz: float, duration: float, amplitude: float) -> void:
	var player := _next_player()
	if player == null:
		return
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.1
	player.stream = gen
	player.pitch_scale = 1.0
	player.volume_db = -8.0
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
	for device in Input.get_connected_joypads():
		Input.start_joy_vibration(device, clampf(weak, 0.0, 1.0), clampf(strong, 0.0, 1.0), duration)
