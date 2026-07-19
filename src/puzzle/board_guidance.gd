class_name BoardGuidance
extends RefCounted
## Computes visual affordances and plain-language invalid-move explanations.


func for_selection(state: Array, source_index: int, capacity: int) -> Dictionary:
	var targets: Array[int] = []
	if source_index < 0 or source_index >= state.size() or (state[source_index] as Array).is_empty():
		return {"valid_targets":targets}
	var source: Array = state[source_index]
	var color := str(source.back())
	for index in state.size():
		if index == source_index: continue
		var target: Array = state[index]
		if target.size() >= capacity: continue
		if target.is_empty() or str(target.back()) in [color, "wild"] or color == "wild":
			targets.append(index)
	return {"valid_targets":targets}


func invalid_reason(state: Array, source_index: int, target_index: int, capacity: int) -> String:
	if source_index < 0 or source_index >= state.size(): return "Choose a filled potion first"
	if target_index < 0 or target_index >= state.size(): return "Choose another bottle"
	var source: Array = state[source_index]; var target: Array = state[target_index]
	if source.is_empty(): return "That bottle is empty"
	if target.size() >= capacity: return "That bottle is already full"
	if target_index == source_index: return "Choose a different bottle"
	if not target.is_empty() and str(source.back()) != str(target.back()) \
			and str(source.back()) != "wild" and str(target.back()) != "wild":
		return "Only matching colors can be poured together"
	return "That pour is currently blocked"
