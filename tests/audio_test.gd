extends Node

var checks := 0
var failures := 0

func _ready() -> void:
	var original := SaveSystem.data.duplicate(true)
	SaveSystem.data.settings.music = 0.8
	AudioManager.set_music_volume(0.8); AudioManager.set_combat_layer("battle")
	check(AudioManager.current_combat_layer() == "battle", "battle music layer activates")
	check(AudioManager.music_is_audible(), "default music setting is audible")
	check(AudioManager.has_method("duck_music"), "soundtrack exposes bounded impact ducking")
	if AudioManager.has_method("duck_music"):
		check(is_equal_approx(float(AudioManager.call("duck_music", 0.01, 99.0)), 18.0),
				"music duck depth is clamped to safe maximum")
	check(AudioManager.get("_stem_players").size() == 2, "music has melodic and percussion stems")
	check(AudioManager.has_method("stem_cache_size"), "generated music stems expose bounded cache telemetry")
	check(AudioManager.has_method("set_combat_intensity"), "music supports adaptive danger intensity")
	if AudioManager.has_method("set_combat_intensity"):
		check(AudioManager.call("set_combat_intensity", 0.1, 1) == "danger",
				"low HP and imminent attack select danger layer")
	check(AudioManager.has_method("haptic"), "named haptic language is available")
	AudioManager.set_combat_layer("battle")
	check(AudioManager.current_combat_layer() == "battle", "same layer does not change identity")
	check(AudioManager.has_method("set_area"), "soundtrack exposes area identity")
	if AudioManager.has_method("set_area"):
		AudioManager.call("set_area", "verdant")
		AudioManager.set_combat_layer("elite")
		check(str(AudioManager.get("_current_music")) == "verdant", "verdant battles use verdant score")
		AudioManager.set_combat_layer("boss_phase_1")
		check(str(AudioManager.get("_current_music")) == "verdant_boss", "verdant boss uses distinct score")
		if AudioManager.has_method("stem_cache_size"):
			var cached := int(AudioManager.call("stem_cache_size"))
			AudioManager.call("_play_layer_stems", "boss_phase_1")
			check(int(AudioManager.call("stem_cache_size")) == cached and cached <= 12,
					"repeated layers reuse stems within a fixed cache budget")
		for realm in ["frost", "abyss"]:
			var ambient_path := "res://assets/audio/%s_ambient.ogg" % realm
			var boss_path := "res://assets/audio/%s_boss.ogg" % realm
			check(ResourceLoader.exists(ambient_path) and ResourceLoader.exists(boss_path),
					"%s OGG ambience and boss assets load" % realm)
			AudioManager.call("set_area", realm)
			AudioManager.set_combat_layer("battle")
			check(str(AudioManager.get("_current_music")) == realm and AudioManager.music_is_audible(),
					"%s battle routes to audible area score" % realm)
			var ambient_stream: AudioStream = AudioManager.get("_music_streams").get(realm)
			check(ambient_stream != null and ambient_stream.get("loop") == true,
					"%s ambience loops seamlessly" % realm)
			AudioManager.set_combat_layer("boss_phase_2")
			check(str(AudioManager.get("_current_music")) == realm + "_boss",
					"%s boss crossfades to its boss score" % realm)
	var preview := AudioManager.preview_music()
	check(preview != "battle" and AudioManager.current_combat_layer() == preview, "settings preview cycles soundtrack")
	SaveSystem.data.settings.music = 0.0; AudioManager.set_music_volume(0.0)
	check(not AudioManager.music_is_audible(), "zero percent remains a true mute")
	if AudioManager.has_method("duck_music"):
		check(is_zero_approx(float(AudioManager.call("duck_music", 0.2, 8.0))),
				"muted soundtrack never becomes audible through duck recovery")
	SaveSystem.data = original
	print("---\n%d checks, %d failures" % [checks, failures]); get_tree().quit(1 if failures else 0)

func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS  ", label)
	else: failures += 1; print("FAIL  ", label)
