class_name TutorialDirector
extends RefCounted

signal step_changed(step: Dictionary, index: int, total: int)
signal completed
signal skipped

var steps: Array = []
var index := 0
var active := false


func configure(replay := false) -> void:
	steps = GameState.load_data_file("tutorial_steps.json", {"steps": []}).get("steps", [])
	index = 0 if replay else clampi(SaveSystem.tutorial_step(), 0, maxi(steps.size() - 1, 0))
	active = replay or not SaveSystem.is_tutorial_done()
	if replay:
		SaveSystem.replay_tutorial()
	if active and not steps.is_empty():
		step_changed.emit(current_step(), index, steps.size())


func current_step() -> Dictionary:
	if not active or index < 0 or index >= steps.size():
		return {}
	return steps[index].duplicate(true)


func accept_action(action: String) -> bool:
	if not active or current_step().is_empty() or str(current_step().get("action", "")) != action:
		return false
	index += 1
	if index >= steps.size():
		active = false
		SaveSystem.complete_tutorial()
		completed.emit()
	else:
		SaveSystem.set_tutorial_step(index)
		step_changed.emit(current_step(), index, steps.size())
	return true


func skip() -> void:
	if not active: return
	active = false
	SaveSystem.skip_tutorial()
	skipped.emit()
