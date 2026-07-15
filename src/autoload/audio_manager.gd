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
var _music_player: AudioStreamPlayer
var _current_music := ""
var _sfx_players: Array[AudioStreamPlayer] = []
var _next_player := 0


func _ready() -> void:
	_setup_buses()
	_build_sounds()
	for i in SFX_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx_players.append(p)
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Music"
	add_child(_music_player)
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
	if _current_music == track and _music_player.playing:
		return
	_current_music = track
	_music_player.stream = _music_streams.get(track)
	if _music_player.stream != null:
		_music_player.play()


func stop_music() -> void:
	_current_music = ""
	_music_player.stop()


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
		"dungeon": _make_drone([55.0, 82.5, 110.0], 6.0, 0.10),
		"boss": _make_drone([65.4, 98.0, 130.8, 155.6], 4.0, 0.13),
	}


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
