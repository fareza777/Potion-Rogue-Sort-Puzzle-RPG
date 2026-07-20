extends Node

var checks := 0
var failures := 0


func _ready() -> void:
	await _test_complete_three_color_mix_is_immediate()
	await _test_mix_survives_variable_capacity_hazards()
	await _test_expedition_list_drags_from_any_card_content()
	await _test_route_has_generous_vertical_composition()
	print("---\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func _test_complete_three_color_mix_is_immediate() -> void:
	var state: Array = [
		["red", "green", "blue", "red"],
		["green", "blue", "red", "green"],
		["blue", "red", "green", "blue"], [], [], []]
	var started := Time.get_ticks_msec()
	var result := BoardFactory.remix(state, 71093, "standard", PotionTube.CAPACITY)
	var elapsed := Time.get_ticks_msec() - started
	check(elapsed < 100 and result.get("state", []) != state
			and bool(result.get("analysis", {}).get("solvable", false)),
			"New Mix with three complete remaining colors avoids the slow BFS path")
	var board := PuzzleBoard.new()
	add_child(board)
	await get_tree().process_frame
	board.import_state(state)
	started = Time.get_ticks_msec()
	var applied := board.apply_remix_result(result)
	elapsed = Time.get_ticks_msec() - started
	check(applied and elapsed < 100,
			"applying a verified three-color mix never reruns the expensive solver")
	board.queue_free()
	await get_tree().process_frame


func _test_mix_survives_variable_capacity_hazards() -> void:
	var board := PuzzleBoard.new()
	add_child(board)
	await get_tree().process_frame
	board.import_state([["red"], ["green"], [], [], [], []])
	var before := board.export_state()
	var result: Dictionary = {}
	var hazard_index := -1
	for index in board.tubes.size():
		if not board.tubes[index].contents.is_empty():
			continue
		for seed in range(1, 100):
			var candidate := BoardFactory.remix(before, seed, "standard", PotionTube.CAPACITY)
			if candidate.get("state", [])[index].size() > 3:
				hazard_index = index
				result = candidate
				break
		if not result.is_empty():
			break
	if hazard_index >= 0:
		board.tubes[hazard_index].capacity = 3
		board.tubes[hazard_index].locked_moves = 999
	check(not result.is_empty(),
			"test seed reproduces a remix landing four layers in a three-slot flask")
	var applied := board.apply_remix_result(result)
	var normalized := true
	for tube in board.tubes:
		normalized = normalized and tube.capacity == PotionTube.CAPACITY \
				and tube.locked_moves == 0 and tube.contents.size() <= tube.capacity
	check(applied and normalized and board.export_state() != before,
			"New Mix atomically clears capacity/lock hazards and applies the new board")
	var matrix_ok := true
	for seed in range(1, 101):
		board.import_state([["red"], ["green"], [], [], [], []])
		var varied_hazard := 2 + posmod(seed, 4)
		board.tubes[varied_hazard].capacity = 3
		board.tubes[varied_hazard].locked_moves = 2 if seed % 2 == 0 else 999
		var candidate := BoardFactory.remix(board.export_state(), seed, "standard",
				PotionTube.CAPACITY)
		matrix_ok = matrix_ok and board.apply_remix_result(candidate)
	check(matrix_ok, "one hundred hazard/seed combinations apply without Mix Failed")
	board.queue_free()
	await get_tree().process_frame


func _test_expedition_list_drags_from_any_card_content() -> void:
	var screen := preload("res://scenes/area_select.tscn").instantiate() as Control
	add_child(screen)
	await get_tree().process_frame
	await get_tree().process_frame
	var scroll := screen.find_child("ExpeditionScroll", true, false) as ScrollContainer
	var card := screen.find_child("AreaCard_*", true, false) as Control
	var action := card.find_child("AreaAction", true, false) as Button if card else null
	var drag := InputEventScreenDrag.new()
	drag.position = action.global_position + action.size * 0.5 if action else \
			scroll.global_position + scroll.size * 0.5
	drag.relative = Vector2(0, -180)
	if screen.has_method("_input"):
		screen.call("_input", drag)
	await get_tree().process_frame
	check(screen.has_method("_input") and card.mouse_filter == Control.MOUSE_FILTER_PASS
			and action.mouse_filter == Control.MOUSE_FILTER_PASS
			and scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_SHOW_NEVER
			and scroll.scroll_vertical > 0,
			"expedition list scrolls anywhere without exposing an awkward side scrollbar")
	screen.queue_free()
	await get_tree().process_frame


func _test_route_has_generous_vertical_composition() -> void:
	var original := RunState.serialize_boundary()
	RunState.pending_area_id = "shadow_crypt"
	RunState.start_new_run("ember_adept", "shadow_crypt", "normal", 991177)
	var screen := preload("res://scenes/map.tscn").instantiate() as Control
	add_child(screen)
	await get_tree().process_frame
	await get_tree().process_frame
	var route := screen.find_child("DungeonRoute", true, false) as Control
	var scroll := screen.find_child("DungeonRouteScroll", true, false) as ScrollContainer
	check(route != null and route.custom_minimum_size.y >= 1280.0,
			"battle route uses a spacious vertical composition instead of bunching upward")
	check(scroll != null and scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_SHOW_NEVER,
			"battle route also uses full-surface swipe without a side scrollbar")
	screen.queue_free()
	await get_tree().process_frame
	RunState.resume_from_save(original)


func check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("PASS  ", label)
	else:
		failures += 1
		print("FAIL  ", label)
