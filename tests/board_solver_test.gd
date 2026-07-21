extends Node
## Contracts for solver status reporting, wild handling, and canonical keys.

var _checks := 0
var _failures := 0


func _ready() -> void:
	_test_status_field()
	_test_exhausted_is_not_unsolvable()
	_test_wild_pours_like_gameplay()
	_test_tube_order_is_canonical()
	print("---")
	print("%d checks, %d failures" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _test_status_field() -> void:
	var solved := BoardSolver.analyze([["red", "red", "red", "red"], [], []])
	check(str(solved.status) == BoardSolver.STATUS_SOLVED,
			"a solved board reports the solved status")
	var solvable := BoardSolver.analyze([
		["red", "red", "red"], ["blue", "blue", "blue"],
		["red", "blue"], [],
	])
	check(bool(solvable.solvable) and str(solvable.status) == BoardSolver.STATUS_SOLVABLE,
			"a winnable board reports the solvable status")
	var dead := BoardSolver.analyze([["red", "blue"], ["blue", "red"]], 10000, 2)
	check(not bool(dead.solvable) and str(dead.status) == BoardSolver.STATUS_UNSOLVABLE,
			"a proven dead board reports the unsolvable status")


func _test_exhausted_is_not_unsolvable() -> void:
	var complex: Array = [
		["red", "purple", "blue", "green"],
		["purple", "red", "blue", "green"],
		["blue", "purple", "red", "green"],
		["green", "blue", "purple", "red"], [], [],
	]
	var starved := BoardSolver.analyze(complex, 3)
	check(str(starved.status) == BoardSolver.STATUS_EXHAUSTED,
			"an aborted search reports budget_exhausted, not unsolvable")
	check(BoardSolver.is_not_proven_unsolvable(complex, 4, 3),
			"hazard policy fails open when the budget runs out")
	check(not BoardSolver.is_not_proven_unsolvable(
			[["red", "blue"], ["blue", "red"]], 2),
			"hazard policy still rejects proven dead boards")


func _test_wild_pours_like_gameplay() -> void:
	# wild adopts red on pour: [red,red,red] + wild -> complete red set.
	var winnable_with_wild: Array = [
		["red", "red", "red"], ["wild"], [], [],
	]
	var analysis := BoardSolver.analyze(winnable_with_wild)
	check(bool(analysis.solvable),
			"solver understands wild converting to the destination color")
	# Without wild conversion this board would be judged unsolvable: the
	# wild unit can only ever finish the set by becoming red.
	var wild_surface: Array = [
		["red", "red", "wild"], ["red"], [], [],
	]
	check(bool(BoardSolver.analyze(wild_surface).solvable),
			"solver converts a wild destination surface on receive")


func _test_tube_order_is_canonical() -> void:
	var a: Array = [["red", "red"], ["blue", "blue"], [], []]
	var b: Array = [["blue", "blue"], ["red", "red"], [], []]
	var first := BoardSolver.analyze(a)
	var second := BoardSolver.analyze(b)
	check(first.solvable == second.solvable \
			and first.estimated_moves == second.estimated_moves,
			"tube-order permutations produce identical verdicts")


func check(condition: bool, what: String) -> void:
	_checks += 1
	if condition:
		print("PASS  ", what)
	else:
		_failures += 1
		print("FAIL  ", what)
