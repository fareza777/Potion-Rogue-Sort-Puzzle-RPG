extends Node
## Autoload: AudioManager
## Placeholder audio: every SFX and the music loops are synthesized at startup
## (no asset files), so they can be swapped for real audio later by replacing
## the streams in _build_sounds(). Manages Music/SFX buses, saved volume
## settings and handheld vibration.

const SAMPLE_RATE := 22050
const SFX_POOL_SIZE := 6

var _sfx: Dictionary = {}
var _music_streams: Dictionary = {}
var _music_players: Array[AudioStreamPlayer] = []
var _active_music_player := 0
var _music_tween: Tween
var _current_music := ""
var _sfx_players: Array[AudioStreamPlayer] = []
var _next_player := 0
var _combat_layer := "explore"


func _ready() -> void:
	_setup_buses()
	_build_sounds()
	for i in SFX_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx_players.append(p)
	for i in 2:
		var music_player := AudioStreamPlayer.new()
		music_player.bus = "Music"
		music_player.volume_db = -80.0
		add_child(music_player)
		_music_players.append(music_player)
	set_music_volume(float(SaveSystem.setting("music")))
	set_sfx_volume(float(SaveSystem.setting("sfx")))


func play(sound_name: String) -> void:
	var stream: AudioStream = _sfx.get(sound_name)
	if stream == null:
		return
	var p := _sfx_players[_next_player]
	_next_player = (_next_player + 1) % SFX_POOL_SIZE
	p.stream = stream
	p.play()


func play_music(track: String) -> void:
	if _current_music == track and _music_players[_active_music_player].playing:
		return
	crossfade_music(track)


func set_combat_layer(layer: String) -> void:
	if layer == _combat_layer and not _current_music.is_empty(): return
	_combat_layer = layer
	var track := "boss" if layer in ["elite", "boss_phase_1", "boss_phase_2", "boss_phase_3"] else "dungeon"
	crossfade_music(track, 0.65)


func crossfade_music(track: String, duration := 0.8) -> void:
	var stream: AudioStream = _music_streams.get(track)
	if stream == null:
		return
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	var previous := _music_players[_active_music_player]
	_active_music_player = 1 - _active_music_player
	var incoming := _music_players[_active_music_player]
	incoming.stream = stream
	incoming.volume_db = -36.0
	incoming.play()
	_current_music = track
	_music_tween = create_tween().set_parallel(true)
	_music_tween.tween_property(incoming, "volume_db", 0.0, duration)
	if previous.playing:
		_music_tween.tween_property(previous, "volume_db", -36.0, duration)
		_music_tween.chain().tween_callback(previous.stop)


func stop_music() -> void:
	_current_music = ""
	for player in _music_players:
		player.stop()
		player.volume_db = -80.0


func vibrate(ms := 30) -> void:
	if bool(SaveSystem.setting("vibration")):
		Input.vibrate_handheld(ms)


func set_music_volume(value: float) -> void:
	_set_bus_volume("Music", value)


func set_sfx_volume(value: float) -> void:
	_set_bus_volume("SFX", value)


func _set_bus_volume(bus_name: String, value: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		value = clampf(value, 0.0, 1.0)
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(value, 0.0001)))
		AudioServer.set_bus_mute(idx, value <= 0.001)


func _setup_buses() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")


# --- Synthesis ----------------------------------------------------------------

func _build_sounds() -> void:
	_sfx = {
		"click": _synth(0.08, func(t: float, d: float) -> float:
			return _sq(900.0, t) * 0.25 * _decay(t, d, 8.0)),
		"pour": _synth(0.18, func(t: float, d: float) -> float:
			return (randf() * 2.0 - 1.0) * 0.18 * _decay(t, d, 4.0) \
					+ _sin(300.0 + 500.0 * t / d, t) * 0.10),
		"complete": _synth(0.35, func(t: float, d: float) -> float:
			var f := 523.0 if t < d * 0.5 else 784.0
			return _sin(f, t) * 0.30 * _decay(t, d, 3.0)),
		"fire": _synth(0.30, func(t: float, d: float) -> float:
			return (randf() * 2.0 - 1.0) * 0.35 * _decay(t, d, 6.0) \
					+ _sin(110.0, t) * 0.25 * _decay(t, d, 5.0)),
		"heal": _synth(0.35, func(t: float, d: float) -> float:
			return _sin(440.0 + 440.0 * t / d, t) * 0.25 * _decay(t, d, 3.0)),
		"shield": _synth(0.25, func(t: float, d: float) -> float:
			return _sin(220.0, t) * 0.30 * _decay(t, d, 5.0) \
					+ _sin(330.0, t) * 0.15 * _decay(t, d, 5.0)),
		"poison": _synth(0.40, func(t: float, d: float) -> float:
			return _sin(180.0 + 40.0 * sin(t * 30.0), t) * 0.28 * _decay(t, d, 3.0)),
		"enemy_hit": _synth(0.22, func(t: float, d: float) -> float:
			return (randf() * 2.0 - 1.0) * 0.30 * _decay(t, d, 9.0) \
					+ _sin(90.0, t) * 0.30 * _decay(t, d, 7.0)),
		"player_hit": _synth(0.30, func(t: float, d: float) -> float:
			return _sq(70.0, t) * 0.30 * _decay(t, d, 5.0) \
					+ (randf() * 2.0 - 1.0) * 0.20 * _decay(t, d, 6.0)),
		"lock": _synth(0.20, func(t: float, d: float) -> float:
			return _sq(1200.0, t) * 0.12 * _decay(t, d, 10.0) \
					+ _sin(150.0, t) * 0.20 * _decay(t, d, 8.0)),
		"victory": _synth(0.9, func(t: float, d: float) -> float:
			var notes: Array = [523.0, 659.0, 784.0, 1047.0]
			var f: float = notes[mini(int(t / d * 4.0), 3)]
			return _sin(f, t) * 0.28 * _decay(fmod(t, d / 4.0), d / 4.0, 4.0)),
		"defeat": _synth(1.0, func(t: float, d: float) -> float:
			var notes: Array = [392.0, 330.0, 262.0, 196.0]
			var f: float = notes[mini(int(t / d * 4.0), 3)]
			return _sin(f, t) * 0.28 * _decay(fmod(t, d / 4.0), d / 4.0, 3.0)),
	}
	_music_streams = {
		"dungeon": _load_ambient("res://assets/audio/dungeon_ambient.wav",
				_make_drone([55.0, 82.5, 110.0], 6.0, 0.10)),
		"boss": _load_ambient("res://assets/audio/boss_ambient.wav",
				_make_drone([65.4, 98.0, 130.8, 155.6], 4.0, 0.13)),
	}


func _load_ambient(path: String, fallback: AudioStreamWAV) -> AudioStream:
	if not ResourceLoader.exists(path):
		return fallback
	var stream := load(path)
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.mix_rate * 24.0)
	return stream


func _sin(freq: float, t: float) -> float:
	return sin(TAU * freq * t)


func _sq(freq: float, t: float) -> float:
	return 1.0 if sin(TAU * freq * t) >= 0.0 else -1.0


func _decay(t: float, duration: float, speed: float) -> float:
	return exp(-t * speed) * (1.0 - t / duration)


func _synth(duration: float, wave: Callable) -> AudioStreamWAV:
	var frames := int(SAMPLE_RATE * duration)
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	for i in frames:
		var t := float(i) / SAMPLE_RATE
		var v: float = clampf(wave.call(t, duration), -1.0, 1.0)
		bytes.encode_s16(i * 2, int(v * 32000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.data = bytes
	return stream


## Looping ambient drone from stacked sines with a slow amplitude LFO.
func _make_drone(freqs: Array, duration: float, volume: float) -> AudioStreamWAV:
	var frames := int(SAMPLE_RATE * duration)
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	for i in frames:
		var t := float(i) / SAMPLE_RATE
		var v := 0.0
		for f_idx in freqs.size():
			var lfo := 0.6 + 0.4 * sin(TAU * (0.08 + f_idx * 0.03) * t)
			v += sin(TAU * float(freqs[f_idx]) * t) * lfo
		v = v / float(freqs.size()) * volume
		bytes.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.data = bytes
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = frames
	return stream
