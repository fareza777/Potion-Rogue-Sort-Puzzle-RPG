class_name BoardFactory
extends RefCounted
## Deterministic source of solver-verified normal and remixed boards.

const COLORS: Array[String] = ["red", "green", "blue", "purple"]
const MAX_ATTEMPTS := 12


static func generate(seed: int, requested_band: String, color_count := 4,
		capacity := 4, tube_count := 6) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var target := _target_moves(requested_band)
	var best: Dictionary = {}
	var best_distance := 1_000_000
	for attempt in MAX_ATTEMPTS:
		var state := _template_state(rng, color_count, capacity, tube_count) \
				if attempt == 0 else _shuffled_state(rng, color_count, capacity, tube_count)
		var analysis := BoardSolver.analyze(state, 50000, capacity)
		if not _is_playable(state, analysis, capacity):
			continue
		var distance := absi(int(analysis.estimated_moves) - target)
		if distance < best_distance:
			best = {"state": state, "analysis": analysis, "attempt": attempt}
			best_distance = distance
		if BoardDifficulty.band(int(analysis.estimated_moves)) == requested_band:
			return best
	if not best.is_empty():
		return best
	# Invalid settings have no valid puzzle contract. Normal game settings always
	# reach the verified candidates above, so do not expose an unchecked shuffle.
	return {"state": [], "analysis": {"solvable": false,
			"estimated_moves": -1, "visited_states": 0}, "attempt": -1}


static func remix(state: Array, seed: int, requested_band := "standard",
		capacity := BoardSolver.DEFAULT_CAPACITY) -> Dictionary:
	var colors := _colors_in(state)
	var tube_count := state.size()
	var unique_colors: Array[String] = []
	for color in colors:
		if not color in unique_colors:
			unique_colors.append(color)
	if colors.size() == unique_colors.size() * capacity and tube_count > unique_colors.size():
		var generated := generate(seed, requested_band, unique_colors.size(), capacity,
				tube_count)
		if bool(generated.analysis.solvable):
			generated.state = _rename_colors(generated.state, unique_colors)
			generated.analysis = BoardSolver.analyze(generated.state, 50000, capacity)
			return generated

	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var target := _target_moves(requested_band)
	var best: Dictionary = {}
	var best_distance := 1_000_000
	for attempt in MAX_ATTEMPTS:
		var candidate := _shuffle_units(rng, colors, capacity, tube_count)
		var analysis := BoardSolver.analyze(candidate, 50000, capacity)
		if not _is_playable(candidate, analysis, capacity):
			continue
		var distance := absi(int(analysis.estimated_moves) - target)
		if distance < best_distance:
			best = {"state": candidate, "analysis": analysis, "attempt": attempt}
			best_distance = distance
		if BoardDifficulty.band(int(analysis.estimated_moves)) == requested_band:
			return best
	if not best.is_empty():
		return best
	var fallback := _copy_state(state)
	return {"state": fallback,
			"analysis": BoardSolver.analyze(fallback, 50000, capacity),
			"attempt": -1}


static func _template_state(rng: RandomNumberGenerator, color_count: int,
		capacity: int, tube_count: int) -> Array:
	if color_count == 4 and capacity == 4 and tube_count >= 6:
		var colors := _palette(color_count)
		_shuffle(colors, rng)
		var filled: Array = [
			[colors[0], colors[0], colors[0], colors[1]],
			[colors[1], colors[1], colors[1], colors[0]],
			[colors[2], colors[2], colors[2], colors[3]],
			[colors[3], colors[3], colors[3], colors[2]],
		]
		_shuffle(filled, rng)
		while filled.size() < tube_count:
			filled.append([])
		return filled
	return _cyclic_state(color_count, capacity, tube_count)


static func _shuffled_state(rng: RandomNumberGenerator, color_count: int,
		capacity: int, tube_count: int) -> Array:
	var units: Array[String] = []
	for color in _palette(color_count):
		for _unit in capacity:
			units.append(color)
	_shuffle(units, rng)
	return _deal(units, capacity, tube_count)


static func _shuffle_units(rng: RandomNumberGenerator, units: Array[String],
		capacity: int, tube_count: int) -> Array:
	var shuffled := units.duplicate()
	_shuffle(shuffled, rng)
	return _deal(shuffled, capacity, tube_count)


static func _deal(units: Array[String], capacity: int, tube_count: int) -> Array:
	var result: Array = []
	for tube_index in tube_count:
		var tube: Array[String] = []
		for layer in capacity:
			var index := tube_index * capacity + layer
			if index < units.size():
				tube.append(units[index])
		result.append(tube)
	return result


static func _cyclic_state(color_count: int, capacity: int, tube_count: int) -> Array:
	var result: Array = []
	var colors := _palette(color_count)
	for tube_index in tube_count:
		var tube: Array[String] = []
		if tube_index < color_count:
			for layer in capacity:
				tube.append(colors[(tube_index + layer) % colors.size()])
		result.append(tube)
	return result


static func _palette(color_count: int) -> Array[String]:
	var result: Array[String] = []
	for index in color_count:
		result.append(COLORS[index] if index < COLORS.size() else "color_%d" % index)
	return result


static func _rename_colors(state: Array, colors: Array[String]) -> Array:
	var renamed: Array = []
	var palette := _palette(colors.size())
	for tube in state:
		var copy: Array[String] = []
		for value in tube:
			var index := palette.find(str(value))
			copy.append(colors[index] if index >= 0 and index < colors.size() else str(value))
		renamed.append(copy)
	return renamed


static func _colors_in(state: Array) -> Array[String]:
	var result: Array[String] = []
	for tube in state:
		if typeof(tube) != TYPE_ARRAY:
			continue
		for value in tube:
			result.append(str(value))
	return result


static func _is_playable(state: Array, analysis: Dictionary, capacity: int) -> bool:
	return bool(analysis.get("solvable", false)) \
			and int(analysis.get("estimated_moves", -1)) > 0 \
			and not _has_complete_tube(state, capacity)


static func _has_complete_tube(state: Array, capacity: int) -> bool:
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


static func _copy_state(state: Array) -> Array:
	var copy: Array = []
	for raw_tube in state:
		copy.append(raw_tube.duplicate() if typeof(raw_tube) == TYPE_ARRAY else [])
	return copy


static func _target_moves(requested_band: String) -> int:
	match requested_band:
		"easy": return 4
		"hard": return 16
		_: return 9


static func _shuffle(values: Array, rng: RandomNumberGenerator) -> void:
	for index in range(values.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var held = values[index]
		values[index] = values[swap_index]
		values[swap_index] = held
