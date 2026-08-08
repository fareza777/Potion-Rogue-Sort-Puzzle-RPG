extends Node

var checks := 0
var failures := 0


func _ready() -> void:
	var scene_path := "res://scenes/storyboard_player.tscn"
	var service_path := "res://src/autoload/storyboard_service.gd"
	check(ResourceLoader.exists(scene_path), "Storyboard Player scene exists")
	check(ResourceLoader.exists(service_path), "Storyboard Service exists")
	if failures > 0:
		finish()
		return
	RunState.start_new_run("ember_adept", "shadow_crypt", "normal", 77)
	var phase_before := RunState.phase
	var player: Control = load(scene_path).instantiate()
	add_child(player)
	await get_tree().process_frame
	for layer_name in ["BackgroundLayer", "AtmosphereLayer", "SubjectLayer",
			"ForegroundLayer", "CaptionLayer"]:
		check(player.find_child(layer_name, true, false) != null,
				"cinematic owns " + layer_name)
	check(player.find_child("StoryboardSkip", true, false) is Button,
			"cinematic has a dedicated hold-to-skip action")
	check(player.find_child("ProgressPips", true, false) != null,
			"cinematic exposes sequence progress")
	player.call("set_reduced_effects", true)
	var beat := StoryboardDirector.new().compose("battle_intro", {
			"seed":1, "node_id":"test", "area_id":"shadow_crypt",
			"area_name":"Shadow Crypt", "kit_id":"ember_adept",
			"enemy_id":"slime", "enemy_name":"Cave Slime", "kind":"battle",
			"floor":1, "story_flags":{}})[0]
	player.call("play", [beat])
	await get_tree().process_frame
	check(player.has_method("active_motion"),
			"cinematic exposes its authored motion profile for verification")
	if player.has_method("active_motion"):
		check(str(player.call("active_motion")) == str(beat.motion),
				"player applies the beat-specific handcrafted motion profile")
	check(bool(player.call("reduced_effects")),
			"Reduced Effects replaces camera motion with a crossfade")
	check((player.find_child("StoryBackground", true, false) as TextureRect).texture != null,
			"beat background is presented")
	check(RunState.phase == phase_before,
			"story playback never becomes the authoritative run phase")
	var completion := {"called":false, "skipped":false}
	player.finished.connect(func(skipped: bool) -> void:
		completion.called = true
		completion.skipped = skipped)
	player.call("skip")
	await get_tree().process_frame
	check(bool(completion.called) and bool(completion.skipped),
			"skip completes and cleans the active sequence")
	var service_source := FileAccess.get_file_as_string(service_path)
	check(service_source.contains("_pending") and service_source.contains("CRITICAL_TRIGGERS"),
			"service queues one critical story trigger while busy")
	check(service_source.contains("RunState.record_replay"),
			"story service journals compact beat identities")
	player.queue_free()
	AudioManager.stop_music()
	await get_tree().create_timer(0.08).timeout
	finish()


func check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("PASS  ", label)
	else:
		failures += 1
		print("FAIL  ", label)


func finish() -> void:
	print("---\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)
