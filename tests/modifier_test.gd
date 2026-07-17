extends Node
## Headless contracts for board snapshots, commands, and solvability.

var _failures := 0
var _checks := 0


func _ready() -> void:
	_test_board_boundary()
	_test_solver()
	_test_modifiers()
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


func _test_modifiers() -> void:
	var frozen_board := _fresh_board()
	var frozen := ModifierController.new()
	check(frozen.configure(["frozen_tube"] as Array[String], 1, frozen_board),
			"frozen modifier configures safely")
	check(_locked_count(frozen_board) == 1, "frozen modifier locks one tube")
	frozen.on_potion_completed("red")
	check(_locked_count(frozen_board) == 0, "brewing thaws the frozen tube")
	frozen_board.free()

	var cursed_board := _fresh_board()
	var cursed := ModifierController.new()
	cursed.configure(["cursed_layer", "hidden_layer"] as Array[String], 2,
			cursed_board)
	check(cursed.effect_count("cursed") == 1, "cursed modifier marks one layer")
	check(cursed.effect_count("hidden") == 1, "hidden modifier conceals one layer")
	cursed_board.free()

	var volatile_board := _fresh_board()
	var volatile := ModifierController.new()
	var expired := [0]
	volatile.volatile_expired.connect(func(_tube: int) -> void: expired[0] += 1)
	volatile.configure(["volatile_liquid"] as Array[String], 3, volatile_board)
	for i in 3:
		volatile.after_move()
	check(expired[0] == 1, "volatile liquid expires after three moves")
	volatile_board.free()

	var wild_board := _fresh_board()
	var wild := ModifierController.new()
	wild.configure(["wild_essence"] as Array[String], 4, wild_board)
	check(_color_count(wild_board, "wild") == 1, "wild essence replaces one exposed layer")
	wild_board.free()

	var chain_board := _fresh_board()
	var chain := ModifierController.new()
	chain.configure(["chain_lock"] as Array[String], 5, chain_board)
	check(_locked_count(chain_board) == 2, "chain lock binds two tubes")
	chain_board.free()

	var corruption_board := _fresh_board()
	var corruption := ModifierController.new()
	corruption.configure(["corruption"] as Array[String], 6, corruption_board)
	var units_before := corruption_board.total_units()
	corruption.after_enemy_action()
	check(corruption_board.total_units() == units_before + 1
			and corruption.effect_count("cursed") == 1,
			"corruption appends one cursed layer")
	corruption_board.free()

	var unstable_board := _fresh_board()
	var unstable := ModifierController.new()
	unstable.configure(["unstable_flask"] as Array[String], 7, unstable_board)
	var changed_capacity := false
	for tube in unstable_board.tubes:
		changed_capacity = changed_capacity or tube.capacity != PotionTube.CAPACITY
	check(changed_capacity, "unstable flask changes one tube capacity")
	unstable_board.free()

	var property_board := _fresh_board()
	var modifier_ids: Array[String] = ["frozen_tube", "cursed_layer",
			"volatile_liquid", "hidden_layer", "wild_essence", "chain_lock",
			"corruption", "unstable_flask"]
	var safe_seeds := 0
	for seed in 1000:
		for tube in property_board.tubes:
			tube.capacity = PotionTube.CAPACITY
			tube.locked_moves = 0
		property_board.generate_tutorial_board()
		var property_modifier := ModifierController.new()
		var configured := property_modifier.configure(
				[modifier_ids[seed % modifier_ids.size()]], seed, property_board)
		if configured and not property_board.legal_moves().is_empty():
			safe_seeds += 1
	check(safe_seeds == 1000,
			"one thousand seeded modifier boards retain a legal move")
	property_board.free()


func _fresh_board() -> PuzzleBoard:
	var board := PuzzleBoard.new()
	add_child(board)
	board.generate_tutorial_board()
	return board


func _locked_count(board: PuzzleBoard) -> int:
	var count := 0
	for tube in board.tubes:
		count += 1 if tube.is_locked() else 0
	return count


func _color_count(board: PuzzleBoard, color: String) -> int:
	var count := 0
	for tube in board.tubes:
		count += tube.contents.count(color)
	return count


func check(condition: bool, what: String) -> void:
	_checks += 1
	if condition:
		print("PASS  ", what)
	else:
		_failures += 1
		print("FAIL  ", what)
