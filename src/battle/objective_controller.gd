class_name ObjectiveController
extends RefCounted
## Event-fed battle objective progress. It never owns combat or puzzle state.

signal progress_changed(current: int, target: int)
signal completed

var objective_id := "defeat"
var label := "Defeat the enemy"
var event_id := "enemy_defeated"
var current := 0
var target := 1

var _sequence: Array[String] = []
var _completed := false


func configure(id: String, config: Dictionary) -> void:
	objective_id = id
	label = str(config.get("label", id.capitalize()))
	event_id = str(config.get("event", "enemy_defeated"))
	current = 0
	_completed = false
	_sequence.clear()
	for value in config.get("sequence", []):
		_sequence.append(str(value))
	target = _sequence.size() if not _sequence.is_empty() \
			else maxi(int(config.get("target", 1)), 1)
	progress_changed.emit(current, target)


func is_completed() -> bool:
	return _completed


func on_enemy_defeated() -> void:
	if event_id == "enemy_defeated":
		_advance(1)


func on_enemy_attacked() -> void:
	if event_id == "enemy_attacked":
		_advance(1)


func on_potion_completed(color: String) -> void:
	if event_id != "potion_completed" or _completed:
		return
	if _sequence.is_empty():
		_advance(1)
		return
	if color == _sequence[current]:
		_advance(1)
	else:
		current = 1 if color == _sequence[0] else 0
		progress_changed.emit(current, target)


func on_armor_damaged(amount: int) -> void:
	if event_id == "armor_damaged":
		_advance(maxi(amount, 0))


func on_curse_cleansed(count: int) -> void:
	if event_id == "curse_cleansed":
		_advance(maxi(count, 0))


func _advance(amount: int) -> void:
	if _completed or amount <= 0:
		return
	current = mini(current + amount, target)
	progress_changed.emit(current, target)
	if current >= target:
		_completed = true
		completed.emit()
