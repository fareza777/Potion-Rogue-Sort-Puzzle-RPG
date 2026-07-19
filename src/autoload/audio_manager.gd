extends Node
## Autoload: AudioManager
## Layered area ambience plus synthesized responsive combat stems and SFX.
## Manages Music/SFX buses, saved volume settings and handheld vibration.

const SAMPLE_RATE := 22050
const SFX_POOL_SIZE := 6
const STEM_CACHE_LIMIT := 12
const AMBIENT_GAIN_DB := 8.0

var _sfx: Dictionary = {}
var _music_streams: Dictionary = {}
var _music_players: Array[AudioStreamPlayer] = []
var _active_music_player := 0
var _music_tween: Tween
var _current_music := ""
var _sfx_players: Array[AudioStreamPlayer] = []
var _next_player := 0
var _combat_layer := "explore"
var _stem_players: Array[AudioStreamPlayer] = []
var _preview_index := 0
var _area_music := "dungeon"
var _stem_cache: Dictionary = {}
var _duck_serial := 0


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
	for i in 2:
		var stem := AudioStreamPlayer.new()
		stem.bus = "Music"; stem.volume_db = -2.0 if i == 0 else -5.0
		add_child(stem); _stem_players.append(stem)
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
	var layer := "boss_phase_1" if track == "boss" else "explore"
	_combat_layer = layer
	_play_layer_stems(layer)


## Temporarily lowers the Music bus without changing the user's saved volume.
func duck_music(duration: float, depth_db: float) -> float:
	if float(SaveSystem.setting("music")) <= 0.001 or get_tree() == null:
		return 0.0
	var applied_depth := clampf(depth_db, 0.0, 18.0)
	if applied_depth <= 0.0:
		return 0.0
	var idx := AudioServer.get_bus_index("Music")
	if idx < 0:
		return 0.0
	_duck_serial += 1
	var serial := _duck_serial
	var user_value := maxf(float(SaveSystem.setting("music")), 0.0001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(user_value) - applied_depth)
	get_tree().create_timer(clampf(duration, 0.05, 1.5), true, false, true).timeout.connect(
			func() -> void:
				if serial == _duck_serial:
					set_music_volume(float(SaveSystem.setting("music"))))
	return applied_depth


func set_combat_layer(layer: String) -> void:
	var is_boss := layer in ["boss_phase_1", "boss_phase_2", "boss_phase_3"]
	var track := (_area_music + "_boss") if is_boss and _music_streams.has(_area_music + "_boss") else (
			"boss" if is_boss else _area_music)
	var active_player := _music_players[_active_music_player]
	var stems_playing := _stem_players.size() == 2 \
			and _stem_players[0].playing and _stem_players[1].playing
	if layer == _combat_layer and _current_music == track and active_player.playing and stems_playing:
		return
	_combat_layer = layer
	crossfade_music(track, 0.65)
	_play_layer_stems(layer)


func set_area(track: String) -> void:
	_area_music = track if _music_streams.has(track) else "dungeon"


func current_combat_layer() -> String:
	return _combat_layer


func stem_cache_size() -> int:
	return _stem_cache.size()


func ambient_gain_db() -> float:
	return AMBIENT_GAIN_DB


func music_is_audible() -> bool:
	return float(SaveSystem.setting("music")) > 0.001 and not _current_music.is_empty() \
			and _music_players[_active_music_player].playing


func preview_music() -> String:
	var layers := ["explore", "battle", "elite", "boss_phase_2"]
	var current := layers.find(_combat_layer)
	_preview_index = (maxi(current, -1) + 1) % layers.size()
	set_combat_layer(layers[_preview_index])
	return str(layers[_preview_index])


func set_scene_state(state: String) -> bool:
	match state:
		"hall", "explore", "event": set_combat_layer("explore")
		"battle": set_combat_layer("battle")
		"elite": set_combat_layer("elite")
		"boss": set_combat_layer("boss_phase_1")
		"victory":
			play("victory"); set_combat_layer("explore")
		"defeat":
			play("defeat"); set_combat_layer("explore")
		_: return false
	return true


func accepted_scene_states() -> Array:
	return ["hall", "explore", "event", "battle", "elite", "boss", "victory", "defeat"]


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
	incoming.volume_db = -24.0
	incoming.play()
	_current_music = track
	_music_tween = create_tween().set_parallel(true)
	_music_tween.tween_property(incoming, "volume_db", AMBIENT_GAIN_DB, duration)
	if previous.playing:
		_music_tween.tween_property(previous, "volume_db", -36.0, duration)
		_music_tween.chain().tween_callback(previous.stop)


func stop_music() -> void:
	_current_music = ""
	for player in _music_players:
		player.stop()
		player.volume_db = -80.0
	for stem in _stem_players: stem.stop()


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
		"dungeon": _load_ambient("res://assets/audio/dungeon_ambient.ogg",
				func(): return _make_drone([55.0, 82.5, 110.0], 6.0, 0.10)),
		"boss": _load_ambient("res://assets/audio/boss_ambient.ogg",
				func(): return _make_drone([65.4, 98.0, 130.8, 155.6], 4.0, 0.13)),
		"verdant": _load_ambient("res://assets/audio/verdant_ambient.ogg",
				func(): return _make_drone([65.4, 78.5, 98.1], 6.0, 0.10)),
		"verdant_boss": _load_ambient("res://assets/audio/verdant_boss.ogg",
				func(): return _make_drone([58.3, 87.3, 116.5], 5.0, 0.13)),
		"astral": _load_ambient("res://assets/audio/astral_ambient.ogg",
				func(): return _make_drone([55.0, 68.8, 82.5], 6.0, 0.10)),
		"astral_boss": _load_ambient("res://assets/audio/astral_boss.ogg",
				func(): return _make_drone([49.0, 73.5, 98.0], 5.0, 0.14)),
		"frost": _load_ambient("res://assets/audio/frost_ambient.ogg",
				func(): return _make_drone([41.25, 61.875, 82.5], 8.0, 0.10)),
		"frost_boss": _load_ambient("res://assets/audio/frost_boss.ogg",
				func(): return _make_drone([49.0, 73.5, 98.0], 6.0, 0.14)),
		"abyss": _load_ambient("res://assets/audio/abyss_ambient.ogg",
				func(): return _make_drone([36.56, 54.84, 73.12], 8.0, 0.10)),
		"abyss_boss": _load_ambient("res://assets/audio/abyss_boss.ogg",
				func(): return _make_drone([36.56, 48.75, 73.12], 6.0, 0.14)),
	}


func _load_ambient(path: String, fallback_factory: Callable) -> AudioStream:
	if not ResourceLoader.exists(path):
		return fallback_factory.call() as AudioStream
	var stream := load(path)
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.mix_rate * stream.get_length())
	elif stream is AudioStreamOggVorbis:
		stream.loop = true
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


func _play_layer_stems(layer: String) -> void:
	if _stem_players.size() < 2: return
	var cache_key := _area_music + ":" + layer
	if not _stem_cache.has(cache_key):
		if _stem_cache.size() >= STEM_CACHE_LIMIT:
			_stem_cache.erase(_stem_cache.keys()[0])
		_stem_cache[cache_key] = [_make_melodic_stem(layer), _make_percussion_stem(layer)]
	var streams: Array = _stem_cache[cache_key]
	_stem_players[0].stream = streams[0]
	_stem_players[1].stream = streams[1]
	for stem in _stem_players: stem.play()


func _layer_profile(layer: String) -> Dictionary:
	match layer:
		"battle": return {"tempo": 92.0, "root": 73.42, "energy": 0.13}
		"elite": return {"tempo": 108.0, "root": 65.41, "energy": 0.16}
		"boss_phase_1": return {"tempo": 116.0, "root": 61.74, "energy": 0.17}
		"boss_phase_2": return {"tempo": 128.0, "root": 61.74, "energy": 0.19}
		"boss_phase_3": return {"tempo": 142.0, "root": 58.27, "energy": 0.21}
		_: return {"tempo": 72.0, "root": 82.41, "energy": 0.10}


func _make_melodic_stem(layer: String) -> AudioStreamWAV:
	var profile := _layer_profile(layer); var duration := 8.0
	var frames := int(SAMPLE_RATE * duration); var bytes := PackedByteArray(); bytes.resize(frames * 2)
	var beat := 60.0 / float(profile.tempo); var ratios := [1.0, 1.2, 1.5, 1.333]
	for i in frames:
		var t := float(i) / SAMPLE_RATE; var note := int(t / beat) % ratios.size()
		var phase := fmod(t, beat) / beat; var envelope := pow(1.0 - phase, 2.2)
		var frequency := float(profile.root) * float(ratios[note])
		var value := (sin(TAU * frequency * t) + sin(TAU * frequency * 2.0 * t) * 0.22) \
				* envelope * float(profile.energy)
		bytes.encode_s16(i * 2, int(clampf(value, -0.8, 0.8) * 32000.0))
	var stream := AudioStreamWAV.new(); stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE; stream.data = bytes; stream.loop_mode = AudioStreamWAV.LOOP_FORWARD; stream.loop_end = frames
	return stream


func _make_percussion_stem(layer: String) -> AudioStreamWAV:
	var profile := _layer_profile(layer); var duration := 8.0
	var frames := int(SAMPLE_RATE * duration); var bytes := PackedByteArray(); bytes.resize(frames * 2)
	var beat := 60.0 / float(profile.tempo)
	for i in frames:
		var t := float(i) / SAMPLE_RATE; var phase := fmod(t, beat) / beat
		var kick := sin(TAU * (78.0 - phase * 38.0) * t) * exp(-phase * 15.0)
		var subdivision := fmod(t, beat * 0.5) / (beat * 0.5)
		var tick := (1.0 if sin(TAU * 3400.0 * t) > 0 else -1.0) * exp(-subdivision * 30.0)
		var value := (kick * 0.55 + tick * 0.08) * float(profile.energy)
		bytes.encode_s16(i * 2, int(clampf(value, -0.8, 0.8) * 32000.0))
	var stream := AudioStreamWAV.new(); stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE; stream.data = bytes; stream.loop_mode = AudioStreamWAV.LOOP_FORWARD; stream.loop_end = frames
	return stream
