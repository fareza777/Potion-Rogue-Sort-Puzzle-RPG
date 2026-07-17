class_name BossPhaseController
extends RefCounted

signal phase_changed(index: int, config: Dictionary)

var boss_id := "fire_golem"
var phase_index := -1
var max_hp := 1
var phases: Array = []

func configure(id: String, maximum_hp: int, restored_phase := -1) -> void:
	boss_id = id; max_hp = maxi(maximum_hp, 1)
	var bosses := GameState.load_data_file("bosses.json", {})
	phases = bosses.get(id, {}).get("phases", []).duplicate(true)
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
	return {"boss_id": boss_id, "phase_index": phase_index, "max_hp": max_hp}

func _enter_phase(index: int) -> void:
	if index <= phase_index or index >= phases.size(): return
	phase_index = index
	phase_changed.emit(index, phases[index].duplicate(true))
