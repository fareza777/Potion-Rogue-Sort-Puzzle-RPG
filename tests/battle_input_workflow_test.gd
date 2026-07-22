extends Node

var checks := 0
var failures := 0


func _ready() -> void:
	await _test_bottle_input_round_trip()
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


func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS  " + label)
	else: failures += 1; push_error("FAIL  " + label)
