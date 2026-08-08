extends Control
## Headless layout contract and deterministic screenshot harness.


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var trigger := "battle_intro"
	var screenshot_requested := false
	var capture_path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--story-trigger="):
			trigger = arg.get_slice("=", 1)
		elif arg.begins_with("--screenshot="):
			screenshot_requested = true
		elif arg.begins_with("--capture-path="):
			capture_path = arg.get_slice("=", 1)
	var player: StoryboardPlayer = load("res://scenes/storyboard_player.tscn").instantiate()
	add_child(player)
	var context := {"seed":88319, "node_id":"f4_l2", "area_id":"shadow_crypt",
			"area_name":"Shadow Crypt", "kit_id":"ember_adept",
			"enemy_id":"crypt_knight", "enemy_name":"Crypt Knight",
			"event_id":"mirror_cauldron", "event_name":"Mirror Cauldron",
			"kind":"elite", "floor":4, "hp_ratio":0.42,
			"story_flags":{"mirror_marked":true},
			"result_summary":"Gain a relic and carry the mirror's mark."}
	player.play(StoryboardDirector.new().compose(trigger, context))
	if not capture_path.is_empty():
		await get_tree().create_timer(0.75).timeout
		await RenderingServer.frame_post_draw
		var capture := get_viewport().get_texture().get_image()
		var capture_error := capture.save_png(capture_path)
		print("PASS  storyboard capture saved" if capture_error == OK \
				else "FAIL  storyboard capture could not be saved")
		get_tree().quit(0 if capture_error == OK else 1)
		return
	if screenshot_requested:
		return
	await get_tree().process_frame
	await get_tree().process_frame
	var issues := MobileLayoutAudit.inspect(player, get_viewport_rect().size)
	var title := player.find_child("StoryTitle", true, false) as Label
	var body := player.find_child("StoryBody", true, false) as Label
	var passed := issues.is_empty() and title != null and body != null \
			and title.get_global_rect().end.x <= get_viewport_rect().end.x \
			and body.get_global_rect().end.y <= get_viewport_rect().end.y
	print("PASS  storyboard mobile composition" if passed \
			else "FAIL  storyboard mobile composition: " + str(issues))
	player.queue_free()
	AudioManager.stop_music()
	await get_tree().create_timer(0.08).timeout
	get_tree().quit(0 if passed else 1)
