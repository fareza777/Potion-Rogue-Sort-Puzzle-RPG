class_name ComboResolver
extends RefCounted
## Resolves the longest matching potion suffix without applying battle effects.

signal combo_resolved(combo_id: String, payload: Dictionary)

const HISTORY_LIMIT := 3

var _history: Array[String] = []
var _patterns: Array[Dictionary] = []
var _ultimate_charge := 0


func _init() -> void:
	for id in GameState.combos:
		var config: Dictionary = GameState.combos[id].duplicate(true)
		config["id"] = str(id)
		_patterns.append(config)
	_patterns.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return (a.get("pattern", []) as Array).size() \
				> (b.get("pattern", []) as Array).size())


func push_potion(color: String) -> Dictionary:
	_history.append(color)
	while _history.size() > HISTORY_LIMIT:
		_history.pop_front()
	for config in _patterns:
		var pattern: Array = config.get("pattern", [])
		if _matches_suffix(pattern):
			var result: Dictionary = config.duplicate(true)
			_ultimate_charge = mini(_ultimate_charge
					+ int(result.get("charge", 0)), 100)
			combo_resolved.emit(str(result.id), result.duplicate(true))
			return result
	return {}


func history() -> Array[String]:
	return _history.duplicate()


func ultimate_charge() -> int:
	return _ultimate_charge


func consume_ultimate() -> bool:
	if _ultimate_charge < 100:
		return false
	_ultimate_charge = 0
	return true


func _matches_suffix(pattern: Array) -> bool:
	if pattern.is_empty() or pattern.size() > _history.size():
		return false
	var offset := _history.size() - pattern.size()
	for index in pattern.size():
		if str(pattern[index]) != _history[offset + index]:
			return false
	return true
