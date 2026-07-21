class_name BoardFactory
extends RefCounted
## Deterministic source of solver-verified normal and remixed boards.

const COLORS: Array[String] = ["red", "green", "blue", "purple"]
const MAX_ATTEMPTS := 12
const STANDARD_LAYOUTS := [
	[[3,1,3,0],[2,2,3,0],[1,2,2,1],[3,0,1,0]],
	[[0,2,0,2],[2,3,2,0],[1,1,3,3],[3,0,1,1]],
	[[0,1,1,2],[1,3,3,0],[3,0,2,1],[2,0,3,2]],
	[[1,1,2,3],[3,0,1,2],[2,1,3,0],[3,2,0,0]],
	[[2,2,1,3],[0,1,2,1],[1,2,0,3],[0,3,3,0]],
	[[1,0,2,2],[3,2,0,1],[0,0,3,3],[1,2,3,1]],
	[[1,2,0,0],[1,3,3,2],[0,0,1,1],[2,2,3,3]],
	[[1,0,2,3],[1,1,2,3],[1,2,3,0],[0,0,3,2]],
	[[2,0,1,0],[3,2,2,3],[1,1,2,0],[3,1,3,0]],
	[[3,2,1,1],[2,2,0,3],[3,2,3,1],[0,0,1,0]],
	[[3,3,0,0],[3,0,1,2],[3,2,1,2],[2,1,1,0]],
	[[0,1,1,0],[0,0,3,2],[3,1,3,2],[1,2,2,3]],
	[[1,2,3,3],[3,0,2,1],[3,1,2,0],[0,0,1,2]],
	[[1,3,3,2],[0,0,2,0],[1,1,3,3],[1,2,0,2]],
	[[2,1,1,2],[3,0,1,0],[1,0,3,2],[2,3,3,0]],
	[[1,3,1,0],[1,2,2,0],[2,2,3,0],[3,0,1,3]],
	[[3,0,0,3],[1,1,2,3],[2,2,3,2],[1,0,0,1]],
	[[0,0,3,3],[3,2,1,2],[1,3,2,1],[0,0,2,1]],
	[[1,3,3,2],[0,1,0,0],[2,1,2,1],[0,3,3,2]],
	[[3,3,1,1],[0,2,2,1],[0,3,2,0],[3,2,0,1]],
	[[3,1,0,0],[3,3,1,2],[1,2,2,3],[1,0,2,0]],
	[[3,0,2,2],[0,1,1,0],[1,1,3,3],[0,2,2,3]],
	[[0,2,3,2],[3,3,2,0],[0,3,1,1],[1,2,1,0]],
	[[1,0,3,2],[0,0,1,1],[2,3,2,3],[0,1,2,3]],
]
## Exact shortest-path lengths computed offline by BoardSolver for the layouts
## above. Renaming colors, reordering tubes, or appending empty tubes preserves
## these distances, so normal gameplay does not need to repeat an expensive BFS.
const STANDARD_LAYOUT_MOVES: Array[int] = [
	11, 10, 11, 11, 11, 11, 7, 12, 11, 10, 11, 11,
	11, 10, 12, 11, 10, 11, 11, 11, 11, 9, 12, 11,
]


static func generate(seed: int, requested_band: String, color_count := 4,
		capacity := 4, tube_count := 6) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	if requested_band == "standard" and color_count == 4 and capacity == 4 \
			and tube_count >= 6:
		var catalog_state := _catalog_state(seed, rng, tube_count)
		var catalog_analysis := _catalog_analysis(seed)
		if _is_playable(catalog_state, catalog_analysis, capacity) \
				and BoardDifficulty.band(int(catalog_analysis.estimated_moves)) == "standard":
			return {"state": catalog_state, "analysis": catalog_analysis, "attempt": 0}
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
	# A single-color remainder (e.g. one full purple set left by a corruption
	# layer) can never form a playable one-color puzzle: every reshuffle is a
	# complete tube or a no-op. Route it through recovery, which pads the
	# palette to two verified colors, instead of falling back to the old board.
	if unique_colors.size() < 2 \
			or not _forms_complete_color_sets(colors, unique_colors, capacity):
		var recovered := _recovery_remix(seed, requested_band, unique_colors,
				capacity, tube_count)
		if not recovered.is_empty():
			return recovered
	if colors.size() == unique_colors.size() * capacity and tube_count > unique_colors.size():
		var immediate := _fast_recovery_catalog(seed, unique_colors, capacity, tube_count)
		if not immediate.is_empty():
			return immediate
		var generated := generate(seed, requested_band, unique_colors.size(), capacity,
				tube_count)
		if bool(generated.analysis.solvable):
			generated.state = _rename_colors(generated.state, unique_colors)
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


static func _forms_complete_color_sets(colors: Array[String],
		unique_colors: Array[String], capacity: int) -> bool:
	if colors.is_empty() or capacity < 1:
		return false
	for color in unique_colors:
		if colors.count(color) % capacity != 0:
			return false
	return true


static func _recovery_remix(seed: int, requested_band: String,
		live_colors: Array[String], capacity: int, tube_count: int) -> Dictionary:
	if tube_count < 3:
		return {}
	var palette: Array[String] = []
	for color in live_colors:
		if color in COLORS and color not in palette:
			palette.append(color)
	for color in COLORS:
		if palette.size() >= 2:
			break
		if color not in palette:
			palette.append(color)
	var color_count := mini(palette.size(), tube_count - 1)
	if color_count < 2:
		return {}
	palette.resize(color_count)
	# Small endgame remainders previously invoked a full BFS and could take
	# seconds on phones. These two/three-color layouts are solver-verified offline;
	# color/tube permutations preserve the proof while varying each recovery seed.
	var immediate := _fast_recovery_catalog(seed, palette, capacity, tube_count)
	if not immediate.is_empty():
		return immediate
	var generated := generate(seed, requested_band, color_count, capacity, tube_count)
	if not bool(generated.get("analysis", {}).get("solvable", false)):
		return {}
	generated.state = _rename_colors(generated.state, palette)
	generated["recovered"] = true
	return generated


static func _fast_recovery_catalog(seed: int, palette: Array[String],
		capacity: int, tube_count: int) -> Dictionary:
	if palette.size() not in [2, 3] or capacity != 4 \
			or tube_count < palette.size() + 1:
		return {}
	var ordered := palette.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	_shuffle(ordered, rng)
	var state: Array = []
	for tube_index in ordered.size():
		var tube: Array[String] = []
		for layer in capacity:
			tube.append(str(ordered[(tube_index + layer) % ordered.size()]))
		state.append(tube)
	while state.size() < tube_count:
		state.append([])
	_shuffle(state, rng)
	return {"state": state,
			"analysis": {"solvable": true,
					"estimated_moves": 7 if ordered.size() == 2 else 10,
					"visited_states": 0, "verified_catalog": true},
			"attempt": 0, "recovered": true}


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


static func _catalog_state(seed: int, rng: RandomNumberGenerator, tube_count: int) -> Array:
	var source: Array = STANDARD_LAYOUTS[posmod(seed, STANDARD_LAYOUTS.size())]
	var palette := COLORS.duplicate()
	_shuffle(palette, rng)
	var result: Array = []
	for raw_tube in source:
		var tube: Array[String] = []
		for color_index in raw_tube:
			tube.append(str(palette[int(color_index)]))
		result.append(tube)
	_shuffle(result, rng)
	while result.size() < tube_count:
		result.append([])
	return result


static func _catalog_analysis(seed: int) -> Dictionary:
	var layout_index := posmod(seed, STANDARD_LAYOUTS.size())
	return {"solvable": true,
			"estimated_moves": STANDARD_LAYOUT_MOVES[layout_index],
			"visited_states": 0, "verified_catalog": true}


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
