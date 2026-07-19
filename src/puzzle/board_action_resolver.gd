class_name BoardActionResolver
extends RefCounted
## Single validated boundary for enemy, modifier, and boss board mutations.


func apply(action: Dictionary, board: PuzzleBoard) -> Dictionary:
	var action_id := str(action.get("id", action.get("type", "")))
	if board == null:
		return _result(false, [], "Board is unavailable")
	match action_id:
		"corruption", "spore_corrupt":
			return _apply_corruption(board, int(action.get("count", 1)),
					int(action.get("seed", 0)))
		"heat_seal", "frost_bind":
			return _apply_lock(board, int(action.get("moves", 1)))
		"gravity_shift", "mutate_pair":
			return _apply_swap(board)
		"tidal_rotate":
			return _apply_rotate(board)
		_:
			return _result(false, [], "Unsupported board action: " + action_id)


func _apply_corruption(board: PuzzleBoard, requested_count: int, seed: int) -> Dictionary:
	var candidates: Array[int] = []
	for index in board.tubes.size():
		var tube := board.tubes[index]
		if tube.contents.is_empty():
			continue
		var layer := tube.contents.size() - 1
		if not tube.has_layer_effect(layer, "cursed"):
			candidates.append(index)
	if candidates.is_empty():
		return _result(false, [], "No eligible potion layer for corruption")
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var commands: Array[Dictionary] = []
	for _step in mini(maxi(requested_count, 1), candidates.size()):
		var picked := rng.randi_range(0, candidates.size() - 1)
		commands.append({"type": "append_corruption", "tube": candidates.pop_at(picked)})
	for command in commands:
		if not board.apply_board_command(command):
			return _result(false, commands, "Corruption target rejected")
	return _result(true, commands, "")


func _apply_lock(board: PuzzleBoard, moves: int) -> Dictionary:
	for index in board.tubes.size():
		if not board.tubes[index].contents.is_empty() and not board.tubes[index].is_locked():
			return _commit(board, [{"type": "lock_tube", "tube": index,
					"moves": maxi(moves, 1)}])
	return _result(false, [], "No eligible tube to lock")


func _apply_swap(board: PuzzleBoard) -> Dictionary:
	for first in board.tubes.size():
		if board.tubes[first].contents.is_empty():
			continue
		for second in range(first + 1, board.tubes.size()):
			if board.tubes[second].contents.is_empty():
				continue
			var commands: Array[Dictionary] = [{"type": "swap_top",
					"tube": first, "other": second}]
			if board.try_board_commands(commands):
				return _result(true, commands, "")
	return _result(false, [], "No solver-safe pair to swap")


func _apply_rotate(board: PuzzleBoard) -> Dictionary:
	var targets: Array[int] = []
	for index in board.tubes.size():
		if not board.tubes[index].contents.is_empty() and not board.tubes[index].is_locked():
			targets.append(index)
			if targets.size() == 3:
				break
	if targets.size() < 2:
		return _result(false, [], "Not enough eligible tubes to rotate")
	return _commit(board, [{"type": "rotate_top", "tubes": targets}])


func _commit(board: PuzzleBoard, commands: Array[Dictionary]) -> Dictionary:
	var applied := board.try_board_commands(commands)
	return _result(applied, commands,
			"" if applied else "Action would make the board unsolvable")


func _result(applied: bool, commands: Array, reason: String) -> Dictionary:
	return {"applied": applied, "commands": commands, "reason": reason}
