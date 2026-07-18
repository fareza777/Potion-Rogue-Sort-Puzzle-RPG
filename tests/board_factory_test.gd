extends Node
## Contracts for solver analysis and deterministic, verified board creation.

var _checks := 0
var _failures := 0


func _ready() -> void:
	_test_analysis()
	_test_analysis_bound()
	_test_partial_capacity_analysis()
	_test_deterministic_generation()
	_test_generation_property()
	_test_remix_multiset()
	_test_remix_fallback_shape()
	_test_puzzle_board_remix_routing()
	print("---")
	print("%d checks, %d failures" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


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
	check(battle_source.contains("board.remix_board()") \
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


func check(condition: bool, what: String) -> void:
	_checks += 1
	if condition:
		print("PASS  ", what)
	else:
		_failures += 1
		print("FAIL  ", what)
