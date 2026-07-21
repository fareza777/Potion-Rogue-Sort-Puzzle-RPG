class_name ComboResolver
extends RefCounted
## Resolves the longest matching potion suffix without applying battle effects.

signal combo_resolved(combo_id: String, payload: Dictionary)

const HISTORY_LIMIT := 3
const VALID_ESSENCES: Array[String] = ["red", "green", "blue", "purple", "wild"]

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


func push_essence(color: String, context := {}) -> Dictionary:
	if not color in VALID_ESSENCES:
		return {}
	_history.append(color)
	while _history.size() > HISTORY_LIMIT:
		_history.pop_front()
	for config in _patterns:
		var pattern: Array = config.get("pattern", [])
		if _matches_suffix(pattern):
			var result: Dictionary = config.duplicate(true)
			result["history"] = _history.duplicate()
			result["context"] = (context as Dictionary).duplicate(true)
			# Retained in the snapshot for compatibility with active v19 runs.
			# SkillController remains the presentation/cast authority.
			_ultimate_charge = mini(_ultimate_charge
					+ int(result.get("charge", 0)), 100)
			combo_resolved.emit(str(result.id), result.duplicate(true))
			return result
	return {}


## Compatibility alias for older battle snapshots and callers.
func push_potion(color: String) -> Dictionary:
	return push_essence(color)


func history() -> Array[String]:
	return _history.duplicate()


func ultimate_charge() -> int:
	return _ultimate_charge


func consume_ultimate() -> bool:
	if _ultimate_charge < 100:
		return false
	_ultimate_charge = 0
	return true


func snapshot() -> Dictionary:
	return {"history": _history.duplicate(), "ultimate_charge": _ultimate_charge}


func restore(snapshot_data: Dictionary) -> bool:
	var candidate: Array = snapshot_data.get("history", [])
	if candidate.size() > HISTORY_LIMIT:
		return false
	var validated: Array[String] = []
	for color in candidate:
		var essence := str(color)
		if not essence in VALID_ESSENCES:
			return false
		validated.append(essence)
	_history = validated
	_ultimate_charge = clampi(int(snapshot_data.get("ultimate_charge", 0)), 0, 100)
	return true


func _matches_suffix(pattern: Array) -> bool:
	if pattern.is_empty() or pattern.size() > _history.size():
		return false
	var offset := _history.size() - pattern.size()
	for index in pattern.size():
		if str(pattern[index]) != _history[offset + index]:
			return false
	return true
