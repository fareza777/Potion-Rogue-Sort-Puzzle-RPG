extends Node

var checks := 0
var failures := 0

func _ready() -> void:
	var original := SaveSystem.data.duplicate(true)
	SaveSystem.data = SaveSystem.DEFAULT_DATA.duplicate(true)
	var board := PuzzleBoard.new()
	add_child(board)
	await get_tree().process_frame
	board.lock_random_tube(999)
	board.generate_tutorial_board()
	check(board.has_method("tutorial_source_tube")
			and board.has_method("tutorial_target_tube"),
			"tutorial board exposes the highlighted legal pour")
	var locked := 0
	for tube in board.tubes:
		if tube.is_locked():
			locked += 1
	check(locked == 0, "tutorial board never starts with a locked flask")
	if board.has_method("tutorial_source_tube") and board.has_method("tutorial_target_tube"):
		var source := board.call("tutorial_source_tube") as PotionTube
		var target := board.call("tutorial_target_tube") as PotionTube
		var move := Vector2i(board.tubes.find(source), board.tubes.find(target))
		check(source != null and target != null and move in board.legal_moves(),
				"tutorial source can pour into the highlighted target")
		check(move == Vector2i(0, 1), "guided pour is the authored first-potion pair")
	var director := TutorialDirector.new()
	director.configure()
	check(director.active and director.steps.size() == 4, "first run starts four-step tutorial")
	check(not director.steps.any(func(step): return str(step.get("action", "")) in [
			"trigger_reaction", "cast_skill", "learn_remix", "choose_path"]),
			"battle tutorial stays on pour basics")
	check(not director.accept_action("wrong"), "incorrect action cannot advance tutorial")
	var actions := ["intro", "select_source", "select_target", "play"]
	for action in actions: check(director.accept_action(action), "tutorial accepts " + action)
	check(SaveSystem.is_tutorial_done() and SaveSystem.data.tutorial_state == "complete",
			"completion persists")
	director.configure(true)
	check(director.active and director.index == 0 and not SaveSystem.is_tutorial_done(),
			"replay resets tutorial only")
	director.skip()
	check(SaveSystem.data.tutorial_skipped and SaveSystem.is_tutorial_done(), "skip persists separately")
	var migrated := SaveSystem.migrate({"version":2,"tutorial_done":true,"settings":{}})
	check(migrated.version == SaveSystem.SAVE_VERSION and migrated.tutorial_state == "complete",
			"v2 tutorial migrates to current save schema")
	await _test_card_keeps_copy_inside_frame()
	_test_early_floors_have_no_frozen_flask()
	board.queue_free()
	SaveSystem.data = original
	print("---\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _test_card_keeps_copy_inside_frame() -> void:
	var host := Control.new()
	host.size = Vector2(720, 1280)
	add_child(host)
	var director := TutorialDirector.new()
	director.steps = GameState.load_data_file("tutorial_steps.json", {"steps": []}).get("steps", [])
	director.index = 0
	director.active = true
	var tutorial := Tutorial.new()
	host.add_child(tutorial)
	tutorial.setup(host, director, func(_target: String) -> Control: return host)
	await get_tree().process_frame
	for index in director.steps.size():
		director.index = index
		tutorial._show_step(director.steps[index], index, director.steps.size())
		await get_tree().process_frame
		var card := tutorial.card
		var body := tutorial.body_label
		var title := tutorial.title_label
		var continue_button := tutorial.continue_button
		check(card.get_combined_minimum_size().y <= card.size.y + 0.5,
				"step %d card is tall enough for its contents" % (index + 1))
		check(body.get_global_rect().end.y <= card.get_global_rect().end.y + 0.5,
				"step %d body stays inside the card" % (index + 1))
		check(title.get_global_rect().end.y <= card.get_global_rect().end.y + 0.5,
				"step %d title stays inside the card" % (index + 1))
		if continue_button.visible:
			check(continue_button.get_global_rect().end.y <= card.get_global_rect().end.y + 0.5,
					"step %d GOT IT stays inside the card" % (index + 1))
		check(not body.text.contains("Ultimate") and not body.text.contains("New Mix"),
				"step %d copy stays on the basic pour" % (index + 1))
	host.queue_free()


func _test_early_floors_have_no_frozen_flask() -> void:
	var graph := RunGenerator.new().generate(42, "shadow_crypt", 0)
	var clean := true
	for node in graph.get("nodes", []):
		if int(node.get("floor", 99)) > 1 or str(node.get("kind", "")) != "battle":
			continue
		var modifiers: Array = node.get("contract", {}).get("modifier_ids", [])
		if "frozen_tube" in modifiers or not modifiers.is_empty():
			clean = false
	check(clean, "first combat floor has no locked-flask modifiers")


func check(ok: bool, label: String) -> void:
	checks += 1
	if ok: print("PASS  ", label)
	else: failures += 1; print("FAIL  ", label)
