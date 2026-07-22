extends Node

var checks := 0
var failures := 0


func _ready() -> void:
	await _test_bottle_input_round_trip()
	await _test_android_emulated_mouse_does_not_double_tap()
	await _test_full_battle_viewport_dispatch()
	await _test_full_tutorial_input_dispatch()
	_test_reaction_tutorial_keeps_board_interactive()
	_test_modal_overlay_blocks_and_releases_battle()
	print("---\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _test_bottle_input_round_trip() -> void:
	var board := PuzzleBoard.new()
	add_child(board)
	await get_tree().process_frame
	board.import_state([["red", "blue"], ["blue"], ["green"], [], [], []])
	_tap(board.tubes[0])
	check(board.selected_tube == board.tubes[0], "first bottle tap selects a source")
	_tap(board.tubes[1])
	check(board.tubes[0].contents == ["red"] and board.tubes[1].contents == ["blue", "blue"],
			"second bottle tap performs a valid pour")
	check(board.can_undo() and board.undo(), "undo restores an interactive pour")
	check(board.tubes[0].contents == ["red", "blue"] and board.tubes[1].contents == ["blue"],
			"undo restores the exact bottle state")
	board.enabled = false
	_tap(board.tubes[0])
	check(board.selected_tube == null, "disabled board rejects bottle input")
	board.queue_free()


func _test_android_emulated_mouse_does_not_double_tap() -> void:
	var board := PuzzleBoard.new(); add_child(board)
	await get_tree().process_frame
	board.import_state([["red", "blue"], ["blue"], ["green"], [], [], []])
	var touch := InputEventScreenTouch.new(); touch.index = 0; touch.pressed = true
	board.tubes[0]._gui_input(touch)
	var emulated_mouse := InputEventMouseButton.new()
	emulated_mouse.device = InputEvent.DEVICE_ID_EMULATION
	emulated_mouse.button_index = MOUSE_BUTTON_LEFT; emulated_mouse.pressed = true
	board.tubes[0]._gui_input(emulated_mouse)
	check(board.selected_tube == board.tubes[0],
			"one Android touch cannot select and immediately deselect the same bottle")
	board.queue_free()


func _test_full_battle_viewport_dispatch() -> void:
	get_viewport().size = Vector2i(720, 1280)
	var original_save: Dictionary = SaveSystem.data.duplicate(true)
	var original_run: Dictionary = RunState.serialize_boundary()
	SaveSystem.data = SaveSystem.DEFAULT_DATA.duplicate(true)
	SaveSystem.data.tutorial_done = true
	SaveSystem.data.tutorial_state = "complete"
	RunState.start_new_run("ember_adept", "shadow_crypt", "normal", 90210)
	var screen := preload("res://scenes/battle.tscn").instantiate() as Control
	add_child(screen)
	await get_tree().process_frame
	await get_tree().process_frame
	var board := screen.find_child("PotionBoardBand", true, false) as PuzzleBoard
	check(board != null and board.enabled, "full battle opens with an enabled board")
	if board != null:
		board.import_state([["red", "blue"], ["blue"], ["green"], [], [], []])
		await get_tree().process_frame
		var source_center := board.tubes[0].get_global_rect().get_center()
		var hover := InputEventMouseMotion.new(); hover.position = source_center
		Input.parse_input_event(hover)
		await get_tree().process_frame
		var hit := get_viewport().gui_get_hovered_control()
		check(hit == board.tubes[0], "real viewport hit-test reaches the first bottle")
		await _parse_click(source_center)
		await get_tree().process_frame
		check(board.selected_tube == board.tubes[0], "real viewport click selects the first bottle")
		var target_center := board.tubes[1].get_global_rect().get_center()
		await _parse_click(target_center)
		await get_tree().process_frame
		check(board.tubes[1].contents == ["blue", "blue"],
				"real viewport click performs the second-bottle pour")
		board.undo()
		await _parse_touch(board.tubes[0].get_global_rect().get_center())
		check(board.selected_tube == board.tubes[0], "real touchscreen tap selects a bottle")
		await _parse_touch(board.tubes[1].get_global_rect().get_center())
		check(board.tubes[1].contents == ["blue", "blue"],
				"real touchscreen taps perform a bottle pour")
	screen.queue_free()
	RunState.resume_from_save(original_run)
	SaveSystem.data = original_save


func _test_full_tutorial_input_dispatch() -> void:
	var original_save: Dictionary = SaveSystem.data.duplicate(true)
	var original_run: Dictionary = RunState.serialize_boundary()
	SaveSystem.data = SaveSystem.DEFAULT_DATA.duplicate(true)
	RunState.start_new_run("ember_adept", "shadow_crypt", "normal", 7744)
	var screen := preload("res://scenes/battle.tscn").instantiate() as Control
	add_child(screen)
	await get_tree().process_frame
	await get_tree().process_frame
	var board := screen.find_child("PotionBoardBand", true, false) as PuzzleBoard
	var director: TutorialDirector = screen.tutorial_director
	var tutorial: Tutorial = screen.tutorial_overlay
	check(board != null and director != null and tutorial != null,
			"first battle creates the interactive tutorial")
	if board != null and director != null and tutorial != null:
		for action in ["select_source", "select_target", "complete_potion", "trigger_reaction"]:
			var index := _tutorial_index(director.steps, action)
			director.index = index
			tutorial._show_step(director.steps[index], index, director.steps.size())
			await get_tree().process_frame
			var tube_index := 1 if action == "select_target" else 0
			var point := board.tubes[tube_index].get_global_rect().get_center()
			var motion := InputEventMouseMotion.new(); motion.position = point
			Input.parse_input_event(motion)
			await get_tree().process_frame
			var hit := get_viewport().gui_get_hovered_control()
			check(hit == board.tubes[tube_index],
					"tutorial step %s passes input to its required bottle" % action)
	screen.queue_free()
	await get_tree().process_frame
	RunState.resume_from_save(original_run)
	SaveSystem.data = original_save


func _tutorial_index(steps: Array, action: String) -> int:
	for index in steps.size():
		if str(steps[index].get("action", "")) == action: return index
	return -1


func _test_reaction_tutorial_keeps_board_interactive() -> void:
	var host := Control.new(); host.size = Vector2(720, 1280); add_child(host)
	var chamber := Control.new(); chamber.name = "ReactionChamber"
	chamber.position = Vector2(280, 1030); chamber.size = Vector2(160, 70); host.add_child(chamber)
	var director := TutorialDirector.new()
	director.steps = [{"action":"trigger_reaction", "target":"ReactionChamber",
			"title":"Reaction", "body":"Complete a second potion."}]
	director.index = 0; director.active = true
	var tutorial := Tutorial.new(); host.add_child(tutorial)
	tutorial.setup(host, director, func(_target: String) -> Control: return chamber)
	var passthrough := true
	for panel in tutorial.dim_panels:
		passthrough = passthrough and panel.mouse_filter == Control.MOUSE_FILTER_IGNORE
	check(passthrough, "reaction lesson leaves the potion board clickable")
	host.queue_free()


func _test_modal_overlay_blocks_and_releases_battle() -> void:
	var root := Control.new(); root.visible = false
	var title := Label.new(); var body := Label.new()
	var choices := VBoxContainer.new(); var buttons := VBoxContainer.new()
	add_child(root); root.add_child(title); root.add_child(body); root.add_child(choices); root.add_child(buttons)
	var controller := BattleOverlayController.new()
	controller.configure(root, title, body, choices, buttons)
	controller.show_pause([["RESUME", Callable(controller, "hide")]])
	check(root.visible, "pause modal blocks battle while visible")
	controller.hide()
	check(not root.visible, "closing modal releases battle input")
	root.queue_free()


func _tap(tube: PotionTube) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	tube._gui_input(event)


func _parse_click(position: Vector2) -> void:
	var down := InputEventMouseButton.new()
	down.position = position; down.button_index = MOUSE_BUTTON_LEFT; down.pressed = true
	get_viewport().push_input(down)
	await get_tree().process_frame
	var up := InputEventMouseButton.new()
	up.position = position; up.button_index = MOUSE_BUTTON_LEFT; up.pressed = false
	get_viewport().push_input(up)


func _parse_touch(position: Vector2) -> void:
	var down := InputEventScreenTouch.new()
	down.position = position; down.index = 0; down.pressed = true
	get_viewport().push_input(down)
	await get_tree().process_frame
	var up := InputEventScreenTouch.new()
	up.position = position; up.index = 0; up.pressed = false
	get_viewport().push_input(up)
	await get_tree().process_frame


func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS  " + label)
	else: failures += 1; push_error("FAIL  " + label)
