class_name ModifierController
extends RefCounted
## Owns encounter modifier state and talks to PuzzleBoard through public APIs.

signal curse_cleansed(count: int)
signal volatile_expired(tube_index: int)
signal board_changed
signal modifier_fizzled(modifier_id: String)

var active_ids: Array[String] = []

var _board: PuzzleBoard
var _rng := RandomNumberGenerator.new()
var _frozen_index := -1
var _volatile: Dictionary = {}
var _tide_countdown := 0
var _brittle_pressure := 0
var _ink_index := -1


func configure(ids: Array[String], seed: int, board: PuzzleBoard) -> bool:
	_board = board
	if not _board.curse_cleansed.is_connected(_on_board_curse_cleansed):
		_board.curse_cleansed.connect(_on_board_curse_cleansed)
	_rng.seed = seed
	active_ids.clear()
	_frozen_index = -1
	_volatile.clear()
	_tide_countdown = 0
	_brittle_pressure = 0
	_ink_index = -1
	for id in ids:
		if GameState.modifiers.has(id) and not id in active_ids:
			if id == "chain_lock" and "frozen_tube" in active_ids:
				continue
			active_ids.append(id)
	for id in active_ids:
		_apply_initial(id)
	board_changed.emit()
	if _board.legal_moves().is_empty():
		for tube in _board.tubes:
			tube.capacity = PotionTube.CAPACITY
			tube.locked_moves = 0
		_board.generate_tutorial_board()
		active_ids.clear()
		return false
	return true


func effect_count(effect: String) -> int:
	var count := 0
	if _board == null:
		return count
	for tube in _board.tubes:
		count += tube.effect_count(effect)
	return count


func after_move() -> void:
	var expired_indices: Array[int] = []
	for raw_index in _volatile:
		var index := int(raw_index)
		_volatile[index] = int(_volatile[index]) - 1
		if int(_volatile[index]) <= 0:
			expired_indices.append(index)
	for index in expired_indices:
		_volatile.erase(index)
		if index < _board.tubes.size():
			var tube := _board.tubes[index]
			for layer in tube.contents.size():
				tube.remove_layer_effect(layer, "volatile")
		volatile_expired.emit(index)
	if "rising_tide" in active_ids:
		_tide_countdown -= 1
		if _tide_countdown <= 0:
			_apply_tide()
			_tide_countdown = maxi(int(GameState.modifiers.rising_tide.get("countdown", 3)), 1)


func after_enemy_action() -> void:
	if not "corruption" in active_ids or _board == null:
		return
	var candidates: Array[int] = []
	for index in _board.tubes.size():
		if _board.tubes[index].free_space() > 0:
			candidates.append(index)
	if candidates.is_empty():
		return
	var index := candidates[_rng.randi_range(0, candidates.size() - 1)]
	if _board.apply_board_command({"type": "append_layer", "tube": index,
			"color": "purple"}):
		_board.tubes[index].add_layer_effect(
				_board.tubes[index].contents.size() - 1, "cursed")
		board_changed.emit()


func on_potion_completed(_color: String) -> void:
	if _frozen_index >= 0 and _frozen_index < _board.tubes.size():
		_board.apply_board_command({"type": "unlock_tube", "tube": _frozen_index})
		_frozen_index = -1


func release_permafrost() -> void:
	if _board != null and _frozen_index >= 0 and _frozen_index < _board.tubes.size():
		_board.apply_board_command({"type": "unlock_tube", "tube": _frozen_index})
	_frozen_index = -1


func on_invalid_pour() -> int:
	if "brittle_glass" not in active_ids:
		return 0
	_brittle_pressure += 1
	return 1


func brittle_pressure() -> int:
	return _brittle_pressure


func snapshot() -> Dictionary:
	return {
		"version": 1,
		"active_ids": active_ids.duplicate(),
		"rng_state": _rng.state,
		"frozen_index": _frozen_index,
		"volatile": _volatile.duplicate(true),
		"tide_countdown": _tide_countdown,
		"brittle_pressure": _brittle_pressure,
		"ink_index": _ink_index,
		"layer_effects": _layer_effect_snapshot(),
	}


func restore(data: Dictionary, board: PuzzleBoard) -> bool:
	if int(data.get("version", 0)) != 1 or board == null:
		return false
	_board = board
	if not _board.curse_cleansed.is_connected(_on_board_curse_cleansed):
		_board.curse_cleansed.connect(_on_board_curse_cleansed)
	active_ids.clear()
	for id in data.get("active_ids", []):
		if GameState.modifiers.has(str(id)):
			active_ids.append(str(id))
	_rng.state = int(data.get("rng_state", _rng.state))
	_frozen_index = int(data.get("frozen_index", -1))
	_volatile = (data.get("volatile", {}) as Dictionary).duplicate(true)
	_tide_countdown = maxi(int(data.get("tide_countdown", 0)), 0)
	_brittle_pressure = maxi(int(data.get("brittle_pressure", 0)), 0)
	_ink_index = int(data.get("ink_index", -1))
	var saved_effects: Array = data.get("layer_effects", [])
	for index in mini(saved_effects.size(), _board.tubes.size()):
		_board.tubes[index].layer_effects = (saved_effects[index] as Array).duplicate(true)
		_board.tubes[index].queue_redraw()
	return true


func _layer_effect_snapshot() -> Array:
	var result: Array = []
	if _board == null:
		return result
	for tube in _board.tubes:
		result.append(tube.layer_effects.duplicate(true))
	return result


func _on_board_curse_cleansed(count: int) -> void:
	curse_cleansed.emit(count)


func _apply_initial(id: String) -> void:
	match id:
		"frozen_tube", "permafrost":
			var index := _pick_nonempty()
			if index >= 0:
				_frozen_index = index
				if not _board.try_board_commands([{"type": "lock_tube", "tube": index,
						"moves": 999}]):
					_frozen_index = -1
					modifier_fizzled.emit(id)
		"cursed_layer":
			_mark_random_top("cursed")
		"volatile_liquid":
			var index := _mark_random_top("volatile")
			if index >= 0:
				_volatile[index] = 3
		"hidden_layer":
			_mark_random_top("hidden")
		"wild_essence":
			var index := _pick_nonempty()
			if index >= 0:
				_board.apply_board_command({"type": "replace_top", "tube": index,
						"color": "wild"})
		"chain_lock":
			var candidates := _nonempty_indices()
			for i in mini(2, candidates.size()):
				var pick := _rng.randi_range(i, candidates.size() - 1)
				var swap := candidates[i]
				candidates[i] = candidates[pick]
				candidates[pick] = swap
				_board.apply_board_command({"type": "lock_tube",
						"tube": candidates[i], "moves": 2})
		"unstable_flask":
			var candidates: Array[int] = []
			for index in _board.tubes.size():
				if _board.tubes[index].contents.size() <= 3:
					candidates.append(index)
			if not candidates.is_empty():
				var index := candidates[_rng.randi_range(0, candidates.size() - 1)]
				_board.apply_board_command({"type": "set_capacity", "tube": index,
						"capacity": 3})
		"rising_tide":
			_tide_countdown = maxi(int(GameState.modifiers.rising_tide.get("countdown", 3)), 1)
		"abyssal_ink":
			_ink_index = _mark_random_top("hidden")
		"brittle_glass":
			_brittle_pressure = 0


func _apply_tide() -> void:
	if _board == null:
		return
	var candidates := _nonempty_indices()
	if candidates.size() < 2:
		modifier_fizzled.emit("rising_tide")
		return
	while candidates.size() > 3:
		candidates.remove_at(_rng.randi_range(0, candidates.size() - 1))
	var commands: Array[Dictionary] = [{"type":"rotate_top", "tubes":candidates}]
	if not _board.try_board_commands(commands):
		modifier_fizzled.emit("rising_tide")
	else:
		board_changed.emit()


func _mark_random_top(effect: String) -> int:
	var index := _pick_nonempty()
	if index >= 0:
		var tube := _board.tubes[index]
		tube.add_layer_effect(tube.contents.size() - 1, effect)
	return index


func _pick_nonempty() -> int:
	var candidates := _nonempty_indices()
	return -1 if candidates.is_empty() else candidates[
			_rng.randi_range(0, candidates.size() - 1)]


func _nonempty_indices() -> Array[int]:
	var result: Array[int] = []
	for index in _board.tubes.size():
		if not _board.tubes[index].contents.is_empty():
			result.append(index)
	return result
