class_name BossPhaseController
extends RefCounted

signal phase_changed(index: int, config: Dictionary)

var boss_id := "fire_golem"
var phase_index := -1
var max_hp := 1
var phases: Array = []
var _pending_board_actions: Array[String] = []
var _applied_phase_actions: Array[int] = []

func configure(id: String, maximum_hp: int, restored_phase := -1,
		restored_actions: Array = []) -> void:
	boss_id = id; max_hp = maxi(maximum_hp, 1)
	var bosses := GameState.load_data_file("bosses.json", {})
	phases = bosses.get(id, {}).get("phases", []).duplicate(true)
	_pending_board_actions.clear()
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
			"applied_phase_actions": _applied_phase_actions.duplicate()}

func pending_board_action() -> String:
	return "" if _pending_board_actions.is_empty() else _pending_board_actions.pop_front()

func _enter_phase(index: int) -> void:
	if index <= phase_index or index >= phases.size(): return
	phase_index = index
	var action := str(phases[index].get("board_action", ""))
	if not action.is_empty() and index not in _applied_phase_actions:
		_applied_phase_actions.append(index)
		_pending_board_actions.append(action)
	phase_changed.emit(index, phases[index].duplicate(true))
