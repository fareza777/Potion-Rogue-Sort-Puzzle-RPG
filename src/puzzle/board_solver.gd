class_name BoardSolver
extends RefCounted
## Bounded water-sort solver used to reject impossible generated boards.
##
## Results carry a `status` field so callers can distinguish a proven dead end
## ("unsolvable") from an aborted search ("budget_exhausted"). Combat hazards
## fail open on exhaustion while board generation stays strict.
## The search understands "wild" units with the same conversion rules as
## PuzzleBoard._try_pour. Tube locks are intentionally ignored: they expire
## after a bounded number of moves, so lock-free solvability is the correct
## long-term recoverability question.

const DEFAULT_CAPACITY := 4

const STATUS_SOLVED := "solved"
const STATUS_SOLVABLE := "solvable"
const STATUS_UNSOLVABLE := "unsolvable"
const STATUS_EXHAUSTED := "budget_exhausted"


static func has_solution(raw_state: Array, capacity: int,
		max_states := 50000) -> bool:
	return bool(_analyze(raw_state, capacity, max_states).solvable)


## True unless the board is PROVEN unsolvable. Budget exhaustion passes,
## which makes this the right check for mid-combat hazards that must not
## reject a probably-fine board just because the phone ran out of search time.
static func is_not_proven_unsolvable(raw_state: Array, capacity: int,
		max_states := 50000) -> bool:
	return str(_analyze(raw_state, capacity, max_states).status) != STATUS_UNSOLVABLE


static func analyze(raw_state: Array, max_states := 50000,
		capacity := DEFAULT_CAPACITY) -> Dictionary:
	return _analyze(raw_state, capacity, max_states)


static func _analyze(raw_state: Array, capacity: int, max_states: int) -> Dictionary:
	if capacity < 1 or raw_state.is_empty() or max_states < 1:
		return _result(false, -1, 0, STATUS_UNSOLVABLE)
	var palette := _palette_map(raw_state)
	var initial := _copy_state(raw_state)
	_clear_completed(initial, capacity)
	if _is_solved(initial):
		return _result(true, 0, 1, STATUS_SOLVED)
	var queue: Array = [{"state": initial, "depth": 0}]
	var cursor := 0
	var visited := {_key(initial, palette): true}
	while cursor < queue.size() and visited.size() < max_states:
		var item: Dictionary = queue[cursor]
		var state: Array = item.state
		var depth := int(item.depth)
		cursor += 1
		for move in _legal_moves(state, capacity):
			var next := _copy_state(state)
			_pour(next, move.x, move.y, capacity)
			_clear_completed(next, capacity)
			var key := _key(next, palette)
			if visited.has(key):
				continue
			if visited.size() >= max_states:
				return _result(false, -1, visited.size(), STATUS_EXHAUSTED)
			visited[key] = true
			if _is_solved(next):
				return _result(true, depth + 1, visited.size(), STATUS_SOLVABLE)
			queue.append({"state": next, "depth": depth + 1})
	if visited.size() >= max_states:
		return _result(false, -1, visited.size(), STATUS_EXHAUSTED)
	return _result(false, -1, visited.size(), STATUS_UNSOLVABLE)


static func _result(solvable: bool, moves: int, states: int,
		status: String) -> Dictionary:
	return {"solvable": solvable, "estimated_moves": moves,
			"visited_states": states, "status": status}


static func _legal_moves(state: Array, capacity: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for from_index in state.size():
		var source: Array = state[from_index]
		if source.is_empty():
			continue
		var color := str(source.back())
		for to_index in state.size():
			if from_index == to_index:
				continue
			var destination: Array = state[to_index]
			if destination.size() >= capacity:
				continue
			if destination.is_empty() or str(destination.back()) == color \
					or str(destination.back()) == "wild" or color == "wild":
				result.append(Vector2i(from_index, to_index))
	return result


## Mirrors PuzzleBoard._try_pour: wild adopts the destination color, and a
## wild destination surface converts to the incoming color before receiving.
static func _pour(state: Array, from_index: int, to_index: int,
		capacity: int) -> void:
	var source: Array = state[from_index]
	var destination: Array = state[to_index]
	var color := str(source.back())
	var poured_color := color
	if color == "wild" and not destination.is_empty() \
			and str(destination.back()) != "wild":
		poured_color = str(destination.back())
	elif not destination.is_empty() and str(destination.back()) == "wild" \
			and color != "wild":
		for i in range(destination.size() - 1, -1, -1):
			if str(destination[i]) != "wild":
				break
			destination[i] = color
	var run := 0
	for i in range(source.size() - 1, -1, -1):
		if str(source[i]) != color:
			break
		run += 1
	var count: int = mini(run, capacity - destination.size())
	for i in count:
		var moved := str(source.pop_back())
		destination.append(poured_color if moved == "wild" \
				and poured_color != "wild" else moved)


static func _clear_completed(state: Array, capacity: int) -> void:
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
			tube.clear()


static func _is_solved(state: Array) -> bool:
	for tube in state:
		if not tube.is_empty():
			return false
	return true


static func _copy_state(state: Array) -> Array:
	var copy: Array = []
	for raw_tube in state:
		var tube: Array = raw_tube
		copy.append(tube.duplicate())
	return copy


static func _palette_map(state: Array) -> Dictionary:
	var palette := {}
	for tube in state:
		for value in tube:
			var color := str(value)
			if not palette.has(color):
				palette[color] = char(65 + palette.size())
	return palette


## Compact canonical key: one character per unit, tubes sorted so states that
## differ only by tube order collapse into one visited entry. Far cheaper than
## the previous JSON.stringify key and shrinks the search space substantially.
static func _key(state: Array, palette: Dictionary) -> String:
	var tubes: Array[String] = []
	for tube in state:
		var encoded := ""
		for value in tube:
			encoded += str(palette.get(str(value), "?"))
		tubes.append(encoded)
	tubes.sort()
	return "|".join(tubes)
