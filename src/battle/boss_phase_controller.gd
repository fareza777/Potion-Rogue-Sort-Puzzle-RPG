class_name BossPhaseController
extends RefCounted

signal phase_changed(index: int, config: Dictionary)

var boss_id := "fire_golem"
var phase_index := -1
var max_hp := 1
var phases: Array = []
var _pending_board_actions: Array[String] = []
var _pending_phase_indices: Array[int] = []
var _applied_phase_actions: Array[int] = []

func configure(id: String, maximum_hp: int, restored_phase := -1,
		restored_actions: Array = []) -> void:
	boss_id = id; max_hp = maxi(maximum_hp, 1)
	var bosses := GameState.load_data_file("bosses.json", {})
	phases = bosses.get(id, {}).get("phases", []).duplicate(true)
	_pending_board_actions.clear()
	_pending_phase_indices.clear()
	_applied_phase_actions.clear()
	for raw_index in restored_actions:
		var restored_index := int(raw_index)
		if restored_index >= 0 and restored_index < phases.size():
			_applied_phase_actions.append(restored_index)
	phase_index = clampi(restored_phase, -1, phases.size() - 1)
	if phase_index < 0: _enter_phase(0)

func update_hp(current_hp: int) -> void:
	if phases.is_empty(): return
	var ratio := float(maxi(current_hp, 0)) / float(max_hp)
	var wanted := phase_index
	for index in phases.size():
		if ratio <= float(phases[index].get("threshold", 1.0)):
			wanted = maxi(wanted, index)
	while phase_index < wanted: _enter_phase(phase_index + 1)

func snapshot() -> Dictionary:
	return {"boss_id": boss_id, "phase_index": phase_index, "max_hp": max_hp,
			"applied_phase_actions": _applied_phase_actions.duplicate(),
			"pending_action_id": "" if _pending_board_actions.is_empty() \
					else _pending_board_actions[0],
			"pending_action_ids": _pending_board_actions.duplicate(),
			"pending_phase_indices": _pending_phase_indices.duplicate()}


func restore(data: Dictionary) -> bool:
	if str(data.get("boss_id", "")).is_empty() or int(data.get("max_hp", 0)) <= 0:
		return false
	configure(str(data.boss_id), int(data.max_hp), int(data.get("phase_index", -1)),
			data.get("applied_phase_actions", []))
	_pending_board_actions.clear()
	_pending_phase_indices.clear()
	var pending_ids: Array = data.get("pending_action_ids", [])
	if pending_ids.is_empty() and not str(data.get("pending_action_id", "")).is_empty():
		pending_ids = [str(data.pending_action_id)]
	for action in pending_ids:
		_pending_board_actions.append(str(action))
	for raw_index in data.get("pending_phase_indices", []):
		_pending_phase_indices.append(int(raw_index))
	while _pending_phase_indices.size() < _pending_board_actions.size():
		_pending_phase_indices.append(phase_index)
	return not phases.is_empty() and phase_index >= 0

func pending_board_action() -> String:
	if _pending_board_actions.is_empty():
		return ""
	var action: String = _pending_board_actions.pop_front()
	var applied_index: int = _pending_phase_indices.pop_front() \
			if not _pending_phase_indices.is_empty() else phase_index
	if applied_index not in _applied_phase_actions:
		_applied_phase_actions.append(applied_index)
	return action

func _enter_phase(index: int) -> void:
	if index <= phase_index or index >= phases.size(): return
	phase_index = index
	var action := str(phases[index].get("board_action", ""))
	if not action.is_empty() and index not in _applied_phase_actions \
			and index not in _pending_phase_indices:
		_pending_board_actions.append(action)
		_pending_phase_indices.append(index)
	phase_changed.emit(index, phases[index].duplicate(true))
