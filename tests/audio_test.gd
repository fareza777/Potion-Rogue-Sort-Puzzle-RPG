extends Node

var checks := 0
var failures := 0

func _ready() -> void:
	var original := SaveSystem.data.duplicate(true)
	SaveSystem.data.settings.music = 0.8
	AudioManager.set_music_volume(0.8); AudioManager.set_combat_layer("battle")
	check(AudioManager.current_combat_layer() == "battle", "battle music layer activates")
	check(AudioManager.music_is_audible(), "default music setting is audible")
	check(AudioManager.get("_stem_players").size() == 2, "music has melodic and percussion stems")
	check(AudioManager.has_method("stem_cache_size"), "generated music stems expose bounded cache telemetry")
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
	var preview := AudioManager.preview_music()
	check(preview != "battle" and AudioManager.current_combat_layer() == preview, "settings preview cycles soundtrack")
	SaveSystem.data.settings.music = 0.0; AudioManager.set_music_volume(0.0)
	check(not AudioManager.music_is_audible(), "zero percent remains a true mute")
	SaveSystem.data = original
	print("---\n%d checks, %d failures" % [checks, failures]); get_tree().quit(1 if failures else 0)

func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS  ", label)
	else: failures += 1; print("FAIL  ", label)
