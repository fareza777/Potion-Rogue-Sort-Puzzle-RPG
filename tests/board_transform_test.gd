extends Node

var checks := 0
var failures := 0


func _ready() -> void:
	var board := PuzzleBoard.new()
	add_child(board)
	board.generate_tutorial_board()
	var before := board.export_snapshot()
	check(board.has_method("try_board_commands"),
			"board exposes transactional transform API")
	check(not board.has_method("try_board_commands")
			or not board.try_board_commands([{"type":"swap_top","tube":0,"other":99}]),
			"invalid transform is rejected")
	if board.has_method("try_board_commands"):
		check(board.export_snapshot() == before, "rejected transform is atomic")
		check(board.try_board_commands([{"type":"swap_top","tube":0,"other":1}]),
				"valid solvable transform commits")
	print("---\n%d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)


func check(ok: bool, label: String) -> void:
	checks += 1
	if ok:
		print("PASS  ", label)
	else:
		failures += 1
		print("FAIL  ", label)
