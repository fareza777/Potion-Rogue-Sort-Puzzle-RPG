extends Node
## Contracts for solver analysis and deterministic, verified board creation.

var _checks := 0
var _failures := 0


func _ready() -> void:
	if "--performance-only" in OS.get_cmdline_user_args():
		_test_catalog_generation_latency()
		print("---")
		print("%d checks, %d failures" % [_checks, _failures])
		get_tree().quit(1 if _failures > 0 else 0)
		return
	if "--variety-only" in OS.get_cmdline_user_args():
		_test_generation_variety()
		print("---")
		print("%d checks, %d failures" % [_checks, _failures])
		get_tree().quit(1 if _failures > 0 else 0)
		return
	_test_analysis()
	_test_analysis_bound()
	_test_partial_capacity_analysis()
	_test_deterministic_generation()
	_test_generation_variety()
	_test_generation_property()
	_test_remix_multiset()
	_test_remix_single_color_remainder()
	_test_remix_fallback_shape()
	_test_puzzle_board_remix_routing()
	print("---")
	print("%d checks, %d failures" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _test_catalog_generation_latency() -> void:
	var original: Array = [
		["red", "purple", "blue", "green"],
		["purple", "red", "blue", "green"],
		["blue", "purple", "red", "green"],
		["green", "blue", "purple", "red"], [], [],
	]
	var started := Time.get_ticks_msec()
	for seed in 4:
		BoardFactory.generate(70_000 + seed, "standard")
		BoardFactory.remix(original, 80_000 + seed, "standard")
	var elapsed := Time.get_ticks_msec() - started
	check(elapsed < 500,
			"four catalog deals and remixes finish below 500 ms (actual %d ms)" % elapsed)


func _test_analysis() -> void:
	var solved: Array = [["red", "red", "red", "red"], [], []]
	var solved_analysis := BoardSolver.analyze(solved)
	check(solved_analysis.solvable and solved_analysis.estimated_moves == 0,
			"a solved board reports zero estimated moves")

	var impossible: Array = [["red", "blue"], ["blue", "red"]]
	var impossible_analysis := BoardSolver.analyze(impossible, 200)
	check(not impossible_analysis.solvable,
			"a full mismatched board reports unsolvable")


func _test_analysis_bound() -> void:
	var state: Array = [
		["red", "purple", "blue", "green"],
		["purple", "red", "blue", "green"],
		["blue", "purple", "red", "green"],
		["green", "blue", "purple", "red"], [], [],
	]
	var analysis := BoardSolver.analyze(state, 2)
	check(analysis.visited_states <= 2,
			"analysis never visits more states than max_states")


func _test_partial_capacity_analysis() -> void:
	var partial: Array = [
		["red", "red", "red"], ["blue", "blue", "blue"],
		["green", "green", "green"], ["purple", "purple", "purple"],
		["red", "blue"], ["green", "purple"],
	]
	check(BoardSolver.analyze(partial).solvable,
			"analysis keeps capacity four when no current tube is full")


func _test_deterministic_generation() -> void:
	var first := BoardFactory.generate(1847, "standard")
	var second := BoardFactory.generate(1847, "standard")
	check(first.state == second.state and first.analysis == second.analysis
			and first.attempt == second.attempt,
			"identical seeds produce identical verified boards")


func _test_generation_variety() -> void:
	var structural_patterns := {}
	var shortcut_boards := 0
	for seed in 48:
		var state: Array = BoardFactory.generate(10_000 + seed, "standard").state
		structural_patterns[_structure_signature(state)] = true
		if _has_three_stack_shortcut(state):
			shortcut_boards += 1
	check(structural_patterns.size() >= 24,
			"forty-eight seeds produce at least twenty-four structural layouts")
	check(shortcut_boards <= 12,
			"at most one quarter of boards expose three-same-color shortcuts")


func _test_generation_property() -> void:
	var all_verified := true
	for seed in 500:
		var result := BoardFactory.generate(seed, "standard")
		var analysis: Dictionary = result.analysis
		var independent := BoardSolver.analyze(result.state)
		all_verified = all_verified and analysis.solvable and independent.solvable \
				and independent.estimated_moves > 0 and not _is_complete(result.state)
	check(all_verified,
			"five hundred generated boards are solvable and not already complete")


func _test_remix_multiset() -> void:
	var original: Array = [
		["red", "red", "red"], ["blue", "blue", "blue"],
		["green", "green", "green"], ["purple", "purple", "purple"],
		["red", "blue"], ["green", "purple"],
	]
	var remixed := BoardFactory.remix(original, 991, "standard")
	var independent := BoardSolver.analyze(remixed.state)
	check(_colors(remixed.state) == _colors(original) and remixed.analysis.solvable \
			and independent.solvable,
			"remix preserves the color multiset on a verified board")


func _test_remix_single_color_remainder() -> void:
	# A corruption layer or replace_top hazard can leave exactly one full color
	# set on the board (e.g. four purple in one tube). One color can never form
	# a playable puzzle, so New Mix must recover with a padded verified palette
	# rather than echoing the stuck board back.
	var cases := {
		"one full tube": [["purple", "purple", "purple", "purple"], [], [], [], [], []],
		"split complete set": [["purple", "purple"], ["purple", "purple"], [], [], [], []],
		"three-unit remainder": [["purple", "purple", "purple"], [], [], [], [], []],
	}
	for label in cases:
		var all_playable := true
		for seed in 25:
			var result := BoardFactory.remix((cases[label] as Array).duplicate(true),
					seed, "standard")
			var independent := BoardSolver.analyze(result.state)
			all_playable = all_playable and bool(result.analysis.solvable) \
					and independent.solvable and independent.estimated_moves > 0 \
					and not _is_complete(result.state)
		check(all_playable,
				"single-color remainder (%s) always remixes into a playable board" % label)


func _test_remix_fallback_shape() -> void:
	var exhausted: Array = [["red", "blue"], ["blue", "red"]]
	var first := BoardFactory.remix(exhausted, 73, "hard")
	var second := BoardFactory.remix(exhausted, 73, "hard")
	check(first.has("state") and first.has("analysis") and first.has("attempt") \
			and first == second and first.state == exhausted,
			"exhausted remix returns a deterministic safe result contract")


func _test_puzzle_board_remix_routing() -> void:
	var board := PuzzleBoard.new()
	add_child(board)
	var partial: Array = [
		["red", "red", "red"], ["blue", "blue", "blue"],
		["green", "green", "green"], ["purple", "purple", "purple"],
		["red", "blue"], ["green", "purple"],
	]
	board.import_state(partial)
	var has_route := board.has_method("remix_board")
	if has_route:
		board.call("remix_board", 441, "standard")
	var battle_source := FileAccess.get_file_as_string("res://src/ui/battle_screen.gd")
	check(has_route and _colors(board.export_state()) == _colors(partial) \
			and BoardSolver.analyze(board.export_state()).solvable,
			"PuzzleBoard New Mix preserves and independently verifies live colors")
	check(battle_source.contains("remix_jobs.request(") \
			and battle_source.contains("apply_remix_result(") \
			and battle_source.contains("battle.on_move()") \
			and battle_source.contains("_checkpoint_encounter()"),
			"production New Mix routes through remix and retains its move/checkpoint")
	board.free()


func _is_complete(state: Array) -> bool:
	var capacity := 1
	for tube in state:
		capacity = maxi(capacity, tube.size())
	for tube in state:
		if tube.size() != capacity:
			continue
		var color := str(tube[0])
		var complete := true
		for value in tube:
			if str(value) != color:
				complete = false
				break
		if complete:
			return true
	return false


func _colors(state: Array) -> Array[String]:
	var result: Array[String] = []
	for tube in state:
		for value in tube:
			result.append(str(value))
	result.sort()
	return result


func _structure_signature(state: Array) -> String:
	var color_ids := {}
	var next_id := 0
	var tubes: Array[String] = []
	for tube in state:
		var encoded: Array[String] = []
		for value in tube:
			var color := str(value)
			if not color_ids.has(color):
				color_ids[color] = next_id
				next_id += 1
			encoded.append(str(color_ids[color]))
		tubes.append("".join(encoded))
	tubes.sort()
	return "|".join(tubes)


func _has_three_stack_shortcut(state: Array) -> bool:
	for tube in state:
		for index in range(maxi(0, tube.size() - 2)):
			if str(tube[index]) == str(tube[index + 1]) \
					and str(tube[index]) == str(tube[index + 2]):
				return true
	return false


func check(condition: bool, what: String) -> void:
	_checks += 1
	if condition:
		print("PASS  ", what)
	else:
		_failures += 1
		print("FAIL  ", what)
