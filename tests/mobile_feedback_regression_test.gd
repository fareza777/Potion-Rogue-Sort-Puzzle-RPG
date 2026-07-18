extends Node

var checks := 0
var failures := 0


func _ready() -> void:
	var original_save := SaveSystem.data.duplicate(true)
	SaveSystem.data = SaveSystem.DEFAULT_DATA.duplicate(true)
	SaveSystem.data.tutorial_done = true
	RunState.start_new_run("ember_adept", "shadow_crypt")
	get_window().size = Vector2i(576, 1280)

	var packed := load("res://scenes/battle.tscn") as PackedScene
	var screen := packed.instantiate()
	add_child(screen)
	await get_tree().process_frame
	screen.call("_show_pause")
	await get_tree().process_frame
	var actions := screen.get("overlay_buttons") as Container
	check(actions is VBoxContainer, "pause actions stack vertically on narrow phones")
	var viewport_width := get_viewport().get_visible_rect().size.x
	var tactical := screen.find_child("TacticalReadout", true, false) as Control
	check(tactical != null and tactical.get_global_rect().end.x <= viewport_width,
			"tactical readout stays inside narrow viewport")
	var all_inside := true
	for button in actions.get_children():
		var rect := (button as Control).get_global_rect()
		all_inside = all_inside and rect.position.x >= 0.0 and rect.end.x <= viewport_width
	check(all_inside, "every pause action remains inside the visible viewport")
	screen.queue_free()
	await get_tree().process_frame

	check(SaveSystem.setting("color_patterns") == false,
			"potion symbols default off after migration")
	var tube_source := FileAccess.get_file_as_string("res://src/puzzle/potion_tube.gd")
	check(not tube_source.contains("_draw_color_pattern"),
			"battle bottles render clean liquid without decorative symbols")

	AudioManager.set_area("dungeon")
	AudioManager.set_combat_layer("battle")
	var active_index := int(AudioManager.get("_active_music_player"))
	var players: Array = AudioManager.get("_music_players")
	(players[active_index] as AudioStreamPlayer).stop()
	AudioManager.set_combat_layer("battle")
	check((players[int(AudioManager.get("_active_music_player"))] as AudioStreamPlayer).playing,
			"combat music self-recovers if its player stopped")
	check(AudioManager.has_method("ambient_gain_db") and float(AudioManager.call("ambient_gain_db")) >= 6.0,
			"ambient score has phone-audible output gain")
	var dev_source := FileAccess.get_file_as_string("res://src/autoload/dev_tools.gd")
	check(dev_source.contains("--phase=") and dev_source.contains("_prepare_capture_phase"),
			"visual QA supports deterministic capture phases")
	check(dev_source.contains("PHASE_MAP") and dev_source.contains("PHASE_BATTLE")
			and dev_source.contains("_prepare_boss"),
			"visual QA can prepare map, signature battle, and boss states")

	SaveSystem.data = original_save
	SaveSystem.save()
	print("---\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS  ", label)
	else:
		failures += 1
		print("FAIL  ", label)
