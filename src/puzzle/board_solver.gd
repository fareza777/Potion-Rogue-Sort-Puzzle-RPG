class_name BoardSolver
extends RefCounted
## Bounded water-sort solver used to reject impossible generated boards.

const DEFAULT_CAPACITY := 4


static func has_solution(raw_state: Array, capacity: int,
		max_states := 50000) -> bool:
	return bool(_analyze(raw_state, capacity, max_states).solvable)


static func analyze(raw_state: Array, max_states := 50000,
		capacity := DEFAULT_CAPACITY) -> Dictionary:
	return _analyze(raw_state, capacity, max_states)


static func _analyze(raw_state: Array, capacity: int, max_states: int) -> Dictionary:
	if capacity < 1 or raw_state.is_empty() or max_states < 1:
		return {"solvable": false, "estimated_moves": -1, "visited_states": 0}
	var initial := _copy_state(raw_state)
	_clear_completed(initial, capacity)
	if _is_solved(initial):
		return {"solvable": true, "estimated_moves": 0, "visited_states": 1}
	var queue: Array = [{"state": initial, "depth": 0}]
	var cursor := 0
	var visited := {_key(initial): true}
	while cursor < queue.size() and visited.size() < max_states:
		var item: Dictionary = queue[cursor]
		var state: Array = item.state
		var depth := int(item.depth)
		cursor += 1
		for move in _legal_moves(state, capacity):
			var next := _copy_state(state)
			_pour(next, move.x, move.y, capacity)
			_clear_completed(next, capacity)
			var key := _key(next)
			if visited.has(key):
				continue
			if visited.size() >= max_states:
				return {"solvable": false, "estimated_moves": -1,
						"visited_states": visited.size()}
			visited[key] = true
			if _is_solved(next):
				return {"solvable": true, "estimated_moves": depth + 1,
						"visited_states": visited.size()}
			queue.append({"state": next, "depth": depth + 1})
	return {"solvable": false, "estimated_moves": -1,
			"visited_states": visited.size()}


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
			if destination.is_empty() or str(destination.back()) == color:
				result.append(Vector2i(from_index, to_index))
	return result


static func _pour(state: Array, from_index: int, to_index: int,
		capacity: int) -> void:
	var source: Array = state[from_index]
	var destination: Array = state[to_index]
	var color := str(source.back())
	var run := 0
	for i in range(source.size() - 1, -1, -1):
		if str(source[i]) != color:
			break
		run += 1
	var count: int = mini(run, capacity - destination.size())
	for i in count:
		destination.append(source.pop_back())


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


static func _key(state: Array) -> String:
	return JSON.stringify(state)
