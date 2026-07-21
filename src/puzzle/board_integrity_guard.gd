class_name BoardIntegrityGuard
extends RefCounted
## Pure post-mutation validation. It reports policy; PuzzleBoard remains the
## only object allowed to apply a replacement state.


func inspect(snapshot: Dictionary) -> Dictionary:
	if int(snapshot.get("version", 0)) != 1 \
			or typeof(snapshot.get("state")) != TYPE_ARRAY:
		return _report("invalid", "malformed")
	var state: Array = snapshot.get("state", [])
	var capacities: Array = snapshot.get("capacities", [])
	if state.is_empty() or capacities.size() != state.size():
		return _report("invalid", "shape")
	var capacity := 1
	for raw_capacity in capacities:
		capacity = maxi(capacity, int(raw_capacity))
	var counts := {}
	for index in state.size():
		if typeof(state[index]) != TYPE_ARRAY or state[index].size() > int(capacities[index]):
			return _report("invalid", "capacity")
		for value in state[index]:
			var color := str(value)
			if color.is_empty():
				return _report("invalid", "color")
			counts[color] = int(counts.get(color, 0)) + 1
	for color in counts:
		if int(counts[color]) % capacity != 0:
			return _report("recoverable", "incomplete_color_set")
	var analysis := BoardSolver.analyze(state, 50000, capacity)
	if str(analysis.get("status", "")) == BoardSolver.STATUS_EXHAUSTED:
		# Unknown is not stuck: keep the standard remix price instead of
		# handing out free emergency recoveries on merely complex boards.
		return _report("valid", "budget_exhausted", analysis)
	if not bool(analysis.get("solvable", false)):
		return _report("recoverable", "unsolvable", analysis)
	return _report("valid", "", analysis)


func _report(status: String, reason: String, analysis := {}) -> Dictionary:
	return {"status":status, "reason":reason, "analysis":analysis}
