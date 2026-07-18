class_name EnemySignatureController
extends RefCounted
## Seeded, snapshot-safe enemy mechanics that pressure the puzzle board.

signal signature_triggered(payload: Dictionary)

const VALID_IDS := ["mark", "seal", "hunt", "corrupt", "siphon", "split",
		"shift", "ward", "freeze", "mutate", "tide"]

var enemy_id := ""
var _signature: Dictionary = {}
var _moves := 0
var _marked_tube := -1
var _rng := RandomNumberGenerator.new()


func configure(id: String, enemy_config: Dictionary, seed: int) -> void:
	enemy_id = id
	_signature = (enemy_config.get("signature", {}) as Dictionary).duplicate(true)
	_moves = 0
	_marked_tube = -1
	_rng.seed = seed


func preview() -> Dictionary:
	var signature_id := str(_signature.get("id", ""))
	var cadence := maxi(int(_signature.get("every_moves", 1)), 1)
	return {
		"id": signature_id,
		"label": str(_signature.get("label",
				"No puzzle trick" if signature_id.is_empty() else signature_id.capitalize())),
		"every_moves": cadence,
		"moves_remaining": cadence - (_moves % cadence),
		"marked_tube": _marked_tube,
	}


func on_player_move(board: PuzzleBoard) -> Dictionary:
	var signature_id := str(_signature.get("id", ""))
	if signature_id not in VALID_IDS:
		return {"triggered": false, "fallback": "attack"}
	_moves += 1
	var cadence := maxi(int(_signature.get("every_moves", 1)), 1)
	if _moves % cadence != 0:
		return {"triggered": false, "id": signature_id,
				"moves_remaining": cadence - (_moves % cadence)}
	var payload := {"triggered": true, "id": signature_id,
			"label": str(preview().label)}
	match signature_id:
		"mark":
			_marked_tube = _pick_nonempty_tube(board)
			payload.target_tube = _marked_tube
			payload.warning = "Marked flask: move its top layer before the next attack."
		"seal":
			var tube := _pick_nonempty_tube(board)
			payload.applied = tube >= 0 and board != null and board.try_board_commands([
					{"type": "lock_tube", "tube": tube,
					"moves": maxi(int(_signature.get("lock_moves", 1)), 1)}])
			payload.target_tube = tube
			payload.warning = "Sealed flask: temporarily unavailable."
		"shift":
			var pair := _pick_nonempty_pair(board)
			payload.applied = pair.size() == 2 and board.try_board_commands([
					{"type": "swap_top", "tube": pair[0], "other": pair[1]}])
			payload.target_tubes = pair
			payload.warning = "Arcane shift: exposed colors changed places."
		"freeze":
			var tube := _pick_nonempty_tube(board)
			payload.applied = tube >= 0 and board != null and board.try_board_commands([
					{"type": "lock_tube", "tube": tube,
					"moves": maxi(int(_signature.get("lock_moves", 1)), 1)}])
			payload.target_tube = tube
			payload.warning = "Rime target: flask %d chills for one move." % (tube + 1) \
					if tube >= 0 else "Rime gathers, but finds no legal flask."
			_apply_fizzle(payload)
		"mutate":
			var pair := _pick_nonempty_pair(board)
			payload.applied = pair.size() == 2 and board != null and board.try_board_commands([
					{"type": "swap_top", "tube": pair[0], "other": pair[1]}])
			payload.target_tubes = pair
			payload.warning = "Mutation targets exposed flasks %s." % str(pair)
			_apply_fizzle(payload)
		"tide":
			var targets := _pick_nonempty_indices(board, 3)
			payload.applied = targets.size() >= 2 and board != null and board.try_board_commands([
					{"type": "rotate_top", "tubes": targets}])
			payload.target_tubes = targets
			payload.warning = "Tide rotates disclosed flasks %s." % str(targets)
			_apply_fizzle(payload)
		"hunt":
			payload.pressure = maxi(int(_signature.get("pressure", 1)), 1)
			payload.warning = "Predator's pace: ineffective moves hasten its attack."
		"siphon":
			payload.mana_loss = maxi(int(_signature.get("mana_loss", 10)), 0)
			payload.warning = "Mana siphon: brew quickly to protect your charge."
		"corrupt":
			payload.target_tube = _pick_nonempty_tube(board)
			payload.board_action = "corrupt"
			payload.warning = "Corruption gathers over an exposed layer."
		"split":
			payload.target_tube = _pick_nonempty_tube(board)
			payload.board_action = "split"
			payload.warning = "Unstable copy: the top essence threatens to spread."
		"ward":
			payload.required_color = str(_signature.get("color", "red"))
			payload.warning = "Color ward: brew %s to break it." % payload.required_color.capitalize()
	signature_triggered.emit(payload.duplicate(true))
	return payload


func _apply_fizzle(payload: Dictionary) -> void:
	if not bool(payload.get("applied", false)):
		payload["fizzle"] = true
		payload["warning"] = "The board rejects the mutation; the effect fizzles."


func snapshot() -> Dictionary:
	return {
		"version": 1,
		"enemy_id": enemy_id,
		"signature_id": str(_signature.get("id", "")),
		"moves": _moves,
		"marked_tube": _marked_tube,
		"rng_state": _rng.state,
	}


func restore(data: Dictionary) -> bool:
	if int(data.get("version", 0)) != 1 or str(data.get("enemy_id", "")) != enemy_id \
			or str(data.get("signature_id", "")) != str(_signature.get("id", "")):
		return false
	_moves = maxi(int(data.get("moves", 0)), 0)
	_marked_tube = int(data.get("marked_tube", -1))
	_rng.state = int(data.get("rng_state", _rng.state))
	return true


func _pick_nonempty_tube(board: PuzzleBoard) -> int:
	if board == null:
		return -1
	var candidates: Array[int] = []
	for index in board.tubes.size():
		if not board.tubes[index].contents.is_empty() and not board.tubes[index].is_locked():
			candidates.append(index)
	if candidates.is_empty():
		return -1
	return candidates[_rng.randi_range(0, candidates.size() - 1)]


func _pick_nonempty_pair(board: PuzzleBoard) -> Array[int]:
	if board == null:
		return []
	var candidates: Array[int] = []
	for index in board.tubes.size():
		if not board.tubes[index].contents.is_empty() and not board.tubes[index].is_locked():
			candidates.append(index)
	if candidates.size() < 2:
		return []
	var first_position := _rng.randi_range(0, candidates.size() - 1)
	var first := int(candidates.pop_at(first_position))
	var second := candidates[_rng.randi_range(0, candidates.size() - 1)]
	return [first, second]


func _pick_nonempty_indices(board: PuzzleBoard, limit: int) -> Array[int]:
	if board == null:
		return []
	var candidates: Array[int] = []
	for index in board.tubes.size():
		if not board.tubes[index].contents.is_empty() and not board.tubes[index].is_locked():
			candidates.append(index)
	for position in mini(limit, candidates.size()):
		var selected := _rng.randi_range(position, candidates.size() - 1)
		var swap := candidates[position]
		candidates[position] = candidates[selected]
		candidates[selected] = swap
	if candidates.size() > limit:
		candidates.resize(limit)
	return candidates
