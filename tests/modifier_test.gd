extends Node
## Headless contracts for board snapshots, commands, and solvability.

var _failures := 0
var _checks := 0


func _ready() -> void:
	_test_board_boundary()
	_test_solver()
	print("---")
	print("%d checks, %d failures" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _test_board_boundary() -> void:
	var board := PuzzleBoard.new()
	add_child(board)
	var state: Array = [
		["red", "blue"], ["blue"], [], [], [], [],
	]
	board.import_state(state)
	check(board.export_state() == state, "board snapshot round-trips")
	var moves := board.legal_moves()
	check(Vector2i(0, 1) in moves and Vector2i(0, 2) in moves,
			"legal move API exposes matching and empty destinations")
	check(board.apply_board_command({"type": "lock_tube", "tube": 0, "moves": 2})
			and board.tubes[0].locked_moves == 2, "command locks a valid tube")
	check(board.apply_board_command({"type": "unlock_tube", "tube": 0})
			and not board.tubes[0].is_locked(), "command unlocks a tube")
	check(board.apply_board_command({"type": "replace_top", "tube": 0,
			"color": "green"}) and board.tubes[0].top_color() == "green",
			"command replaces an exposed layer")
	check(board.apply_board_command({"type": "append_layer", "tube": 2,
			"color": "purple"}) and board.tubes[2].top_color() == "purple",
			"command appends within capacity")
	check(board.apply_board_command({"type": "set_capacity", "tube": 2,
			"capacity": 3}) and board.tubes[2].capacity == 3,
			"command changes a safe tube capacity")
	check(not board.apply_board_command({"type": "set_capacity", "tube": 1,
			"capacity": 0}), "invalid capacity command is rejected")
	check(not board.apply_board_command({"type": "lock_tube", "tube": 99}),
			"out-of-range board command is rejected")
	board.free()


func _test_solver() -> void:
	var tutorial: Array = [
		["red", "purple", "blue", "green"],
		["purple", "red", "blue", "green"],
		["blue", "purple", "red", "green"],
		["green", "blue", "purple", "red"],
		[], [],
	]
	check(BoardSolver.has_solution(tutorial, 4),
			"tutorial board is solvable")
	var blocked: Array = [["red", "blue"], ["blue", "red"]]
	check(not BoardSolver.has_solution(blocked, 2, 200),
			"full mismatched board without a legal move is unsolvable")


func check(condition: bool, what: String) -> void:
	_checks += 1
	if condition:
		print("PASS  ", what)
	else:
		_failures += 1
		print("FAIL  ", what)
